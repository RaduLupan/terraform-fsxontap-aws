#!/bin/bash

set -e

# Log and exit if an error occurs
trap 'echo "Error occurred, exiting"; exit 1' ERR

# Clean up resources
function cleanup {
    rm -rf awscliv2.zip aws
}
trap cleanup EXIT

# Injected variables from Terraform
region="${region}"
s3_bucket_name="${s3_bucket_name}"
s3_key_create_iscsi_luns="${s3_key_create_iscsi_luns}"
s3_key_mount_iscsi_lun="${s3_key_mount_iscsi_lun}"

# Variables
AWS_CLI_ZIP_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
NODE_SESSION_TIMEOUT=5

# Define the SSM parameter path prefix
SSM_PARAMETER_PATH_PREFIX="/fsxontap-poc/iscsi-initiator-name"

# Update package lists
sudo apt update -y

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
sudo apt install unzip -y
curl "$AWS_CLI_ZIP_URL" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install open-iscsi package
sudo apt install open-iscsi -y

# Set replacement timeout for faster failover in /etc/iscsi/iscsid.conf
sudo sed -i "s/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = $NODE_SESSION_TIMEOUT/" /etc/iscsi/iscsid.conf
grep -q "node.session.timeo.replacement_timeout" /etc/iscsi/iscsid.conf || echo "node.session.timeo.replacement_timeout = $NODE_SESSION_TIMEOUT" | sudo tee -a /etc/iscsi/iscsid.conf
sudo cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout

# Enable and start iSCSI service
sudo systemctl enable --now iscsid
sudo systemctl is-active iscsid

# Install multipath tools
sudo apt install multipath-tools multipath-tools-boot -y

# Create and configure multipath.conf
sudo tee /etc/multipath.conf > /dev/null <<EOF
defaults {
    user_friendly_names yes
    find_multipaths yes
    no_path_retry 6   
}
EOF

# Start and enable multipath service
sudo systemctl enable --now multipathd
sudo systemctl restart multipathd
sudo systemctl is-active multipathd

# Use IMDSv2 to fetch instance metadata
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

# Get the Name tag from AWS
INSTANCE_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)

# If the instance has no Name tag, set a default value
if [ -z "$INSTANCE_NAME" ]; then
    INSTANCE_NAME="Ubuntu-Client"
fi

# Sanitize INSTANCE_NAME to remove any invalid characters for the SSM parameter name and convert to lowercase
INSTANCE_NAME=$(echo "$INSTANCE_NAME" | sed 's/[^a-zA-Z0-9-]/-/g' | tr '[:upper:]' '[:lower:]')

# Update iSCSI initiator name
iscsi_initiator_name="iqn.2004-10.com.ubuntu:$INSTANCE_NAME"
echo "Setting iSCSI Initiator Name to $iscsi_initiator_name"
sudo sed -i "s|^InitiatorName=.*|InitiatorName=$iscsi_initiator_name|" /etc/iscsi/initiatorname.iscsi

# Restart iSCSI service to apply changes
sudo systemctl restart iscsid

# Save iSCSI Initiator Name to SSM Parameter Store
aws ssm put-parameter --name "$SSM_PARAMETER_PATH_PREFIX/$INSTANCE_NAME" \
                      --value "$iscsi_initiator_name" \
                      --type "String" \
                      --overwrite

echo "Custom iSCSI initiator name set successfully and saved to SSM: $iscsi_initiator_name"

# Create the /scripts directory and set permissions
echo "Creating /scripts directory..."
sudo mkdir -p /scripts
sudo chown ssm-user:ssm-user /scripts
sudo chmod 755 /scripts

# Download scripts from S3
echo "Downloading scripts from S3..."
aws s3 cp "s3://${s3_bucket_name}/${s3_key_create_iscsi_luns}" "/scripts/create_iscsi_luns.sh" --region "$region"
aws s3 cp "s3://${s3_bucket_name}/${s3_key_mount_iscsi_lun}" "/scripts/mount_iscsi_lun.sh" --region "$region"

# Ensure the downloaded scripts are executable
sudo chmod +x /scripts/create_iscsi_luns.sh
sudo chmod +x /scripts/mount_iscsi_lun.sh

echo "Scripts downloaded and permissions set."