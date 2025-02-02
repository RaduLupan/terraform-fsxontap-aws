#!/bin/bash

# Update package lists
sudo apt update -y

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
sudo apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Install open-iscsi package
sudo apt install open-iscsi -y

# Set replacement timeout for faster failover in /etc/iscsi/iscsid.conf
sudo sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 5/' /etc/iscsi/iscsid.conf
grep -q "node.session.timeo.replacement_timeout" /etc/iscsi/iscsid.conf || echo "node.session.timeo.replacement_timeout = 5" | sudo tee -a /etc/iscsi/iscsid.conf
sudo cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout

# Enable and start iSCSI service
sudo systemctl enable --now iscsid

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

# Use IMDSv2 to fetch instance metadata
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

# Get the Name tag from AWS
INSTANCE_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)

# If the instance has no Name tag, set a default value
if [ -z "$INSTANCE_NAME" ]; then
    INSTANCE_NAME="Ubuntu-Client"
fi

# Update iSCSI initiator name
echo "Setting iSCSI Initiator Name to iqn.2004-10.com.ubuntu:$INSTANCE_NAME"
sudo sed -i "s|^InitiatorName=.*|InitiatorName=iqn.2004-10.com.ubuntu:$INSTANCE_NAME|" /etc/iscsi/initiatorname.iscsi

# Restart iSCSI service to apply changes
sudo systemctl restart iscsid

echo "Custom iSCSI initiator name set successfully: iqn.2004-10.com.ubuntu:$INSTANCE_NAME"
