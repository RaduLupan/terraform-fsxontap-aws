#!/bin/bash
# ==============================================================================
# Script Name: user_data_script.sh
#
# Description: This script is used in AWS EC2 user-data to automate the setup and
#              configuration of a Linux instance for iSCSI connectivity and script
#              deployment. The script performs the following operations:
#                - Installs AWS CLI, open-iscsi, and multipath tools.
#                - Configures iSCSI settings and initiator names.
#                - Downloads specified scripts from an S3 bucket to /scripts.
#                - Logs actions to a file accessible by both ubuntu and ssm-user.
#
# Usage: This script is typically run as part of EC2 instance initialization,
#        injected by Terraform. Ensure all required variables are provided through
#        Terraform's template_file mechanism.
#
# Injected Variables:
#   - region: The AWS region of the S3 bucket.
#   - s3_bucket_name: The name of the S3 bucket containing scripts.
#   - s3_key_create_iscsi_luns: S3 key for the create_iscsi_luns script.
#   - s3_key_mount_iscsi_lun: S3 key for the mount_iscsi_lun script.
#
# Log File: /var/log/user_data_script.log
#
# Prerequisites:
#   - AWS CLI installed and configured for S3 access.
#   - Network access to the S3 bucket in the specified region.
#   - Correct IAM role assigned to the EC2 instance for S3 access.
#
# Author: Radu Lupan assisted by OpenAI ChatGPT (gpt-4o)
# Date:   2025-03-05
# ==============================================================================

set -e

# Log file location
LOG_FILE="/var/log/user_data_script.log"

# Function to log messages
log() {
    echo "$1" | tee -a $LOG_FILE
}

# Log and exit if an error occurs, capturing the failing line
trap 'log "Error occurred at line $LINENO: $BASH_COMMAND"; exit 1' ERR

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

# Log the injected variables for verification
log "Injected variables via Terraform:"
log "Region: $region"
log "S3 Bucket Name: $s3_bucket_name"
log "S3 Key for Create iSCSI LUNs: $s3_key_create_iscsi_luns"
log "S3 Key for Mount iSCSI LUN: $s3_key_mount_iscsi_lun"

# Validate that essential variables are set
if [ -z "$region" ] || [ -z "$s3_bucket_name" ] || [ -z "$s3_key_create_iscsi_luns" ] || [ -z "$s3_key_mount_iscsi_lun" ]; then
    log "Error: One or more injected variables are empty."
    exit 1
fi

# Variables
AWS_CLI_ZIP_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
NODE_SESSION_TIMEOUT=5

# Define the SSM parameter path prefix
SSM_PARAMETER_PATH_PREFIX="/fsxontap-poc/iscsi-initiator-name"

log "Updating package lists..."
apt update -y

log "Installing AWS CLI v2..."
apt install unzip -y
curl "$AWS_CLI_ZIP_URL" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

log "Installing open-iscsi package..."
apt install open-iscsi -y

log "Setting replacement timeout in /etc/iscsi/iscsid.conf..."
sed -i "s/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = $NODE_SESSION_TIMEOUT/" /etc/iscsi/iscsid.conf
grep -q "node.session.timeo.replacement_timeout" /etc/iscsi/iscsid.conf || echo "node.session.timeo.replacement_timeout = $NODE_SESSION_TIMEOUT" | tee -a /etc/iscsi/iscsid.conf
cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout

log "Enabling and starting iSCSI service..."
systemctl enable --now iscsid
systemctl is-active iscsid

log "Installing multipath tools..."
apt install multipath-tools multipath-tools-boot -y

log "Creating and configuring /etc/multipath.conf..."
tee /etc/multipath.conf > /dev/null <<EOF
defaults {
    user_friendly_names yes
    find_multipaths yes
    no_path_retry 6   
}
EOF

log "Enabling and starting multipath service..."
systemctl enable --now multipathd
systemctl restart multipathd
systemctl is-active multipathd

log "Fetching instance metadata..."
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

log "Retrieving Name tag from AWS..."
INSTANCE_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)

if [ -z "$INSTANCE_NAME" ]; then
    INSTANCE_NAME="Ubuntu-Client"
fi

INSTANCE_NAME=$(echo "$INSTANCE_NAME" | sed 's/[^a-zA-Z0-9-]/-/g' | tr '[:upper:]' '[:lower:]')

log "Updating iSCSI Initiator Name to iqn.2004-10.com.ubuntu:$INSTANCE_NAME..."
sed -i "s|^InitiatorName=.*|InitiatorName=iqn.2004-10.com.ubuntu:$INSTANCE_NAME|" /etc/iscsi/initiatorname.iscsi
systemctl restart iscsid

log "Saving iSCSI Initiator Name to SSM Parameter Store..."
aws ssm put-parameter --name "$SSM_PARAMETER_PATH_PREFIX/$INSTANCE_NAME" \
                      --value "iqn.2004-10.com.ubuntu:$INSTANCE_NAME" \
                      --type "String" \
                      --overwrite

log "Creating /scripts directory and setting permissions..."

mkdir -p /scripts

# Check if ssm-user exists
if id -u ssm-user &>/dev/null; then
    chown ssm-user:ssm-user /scripts
    chmod 755 /scripts
else
    log "Warning: ssm-user does not exist, assuming default permissions for /scripts."
    chmod 755 /scripts
fi

log "Downloading scripts from S3..."
aws s3 cp "s3://${s3_bucket_name}/${s3_key_create_iscsi_luns}" "/scripts/create_iscsi_luns.sh" --region "$region"
aws s3 cp "s3://${s3_bucket_name}/${s3_key_mount_iscsi_lun}" "/scripts/mount_iscsi_lun.sh" --region "$region"

log "Ensuring the downloaded scripts are executable..."
chmod +x /scripts/create_iscsi_luns.sh
chmod +x /scripts/mount_iscsi_lun.sh

log "Script completed successfully."