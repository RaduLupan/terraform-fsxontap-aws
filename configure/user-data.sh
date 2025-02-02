#!/bin/bash

# Variables
FSX_MGMT_IP="management_endpoint_ip"
FSX_USERNAME="fsxadmin"
FSX_PASSWORD="your_password"

SVM_NAME="svm_name"
VOL_NAME="vol_name"
LUN_NAME="lun_name"
LUN_SIZE="size"  # Example: 100g
OS_TYPE="linux"  # OS Type for LUN

IGROUP_NAME="igroup_name"
INITIATORS=("iqn.2004-10.com.ubuntu:client1" "iqn.2004-10.com.ubuntu:client2")  # List of initiators

# Install sshpass if not installed
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt update && sudo apt install -y sshpass
fi

# Execute commands over SSH
sshpass -p "$FSX_PASSWORD" ssh -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP <<EOF

# Create LUN
lun create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -size $LUN_SIZE -ostype $OS_TYPE -space-allocation enabled

# Create iGroup
lun igroup create -vserver $SVM_NAME -igroup $IGROUP_NAME -protocol iscsi -ostype linux

# Add multiple initiators to iGroup
$(for INITIATOR in "${INITIATORS[@]}"; do
    echo "lun igroup add -vserver $SVM_NAME -igroup $IGROUP_NAME -initiator $INITIATOR"
done)

# Map LUN to iGroup
lun mapping create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -igroup $IGROUP_NAME

EOF

# Verify LUN, iGroup, and Mapping
sshpass -p "$FSX_PASSWORD" ssh -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP <<EOF
lun show -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME
lun igroup show -vserver $SVM_NAME -igroup $IGROUP_NAME
lun mapping show -vserver $SVM_NAME
EOF
