#!/bin/bash

# Variables
FSX_MGMT_IP="198.19.255.155"
FSX_USERNAME="fsxadmin"
FSX_PASSWORD="MyTestEfEsEx2025!"

SVM_NAME="svm01"
VOL_NAME="iscsi_volume2"
LUN_NAME="lun_1"
LUN_SIZE="295279001600"  # Size in bytes for the LUN, example 275GB LUN will be 295279001600 bytes (275*1024*1024*1024)
OS_TYPE="linux"  # OS Type for LUN

IGROUP_NAME="igroup_1"
INITIATORS=("iqn.2004-10.com.ubuntu:Ubuntu-Client-1" "iqn.2004-10.com.ubuntu:Ubuntu-Client-2")  # List of initiators
LOG_FILE="$HOME/fsx_iscsi.log"  # Change log file location to home directory

# Install sshpass if not installed
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt update && sudo apt install -y sshpass
fi

# Execute commands over SSH
sshpass -p "$FSX_PASSWORD" ssh -t -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP <<EOF

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

# Verify LUN, iGroup, Mapping, and extract serial-hex + iSCSI IPs and save this locally
{
echo "LUN Serial-Hex:"
sshpass -p "$FSX_PASSWORD" ssh -t -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP \
"lun show -path /vol/$VOL_NAME/$LUN_NAME -vserver $SVM_NAME -fields serial-hex" | awk 'NR==3 {print $3}'

echo "iSCSI Network Interfaces:"
sshpass -p "$FSX_PASSWORD" ssh -t -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP \
"network interface show -vserver $SVM_NAME" | awk '/iscsi_1/ || /iscsi_2/ {print $2, $4}'

# Show iGroup and LUN mappings
sshpass -p "$FSX_PASSWORD" ssh -t -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP \
"lun igroup show -vserver $SVM_NAME -igroup $IGROUP_NAME"

sshpass -p "$FSX_PASSWORD" ssh -t -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP \
"lun mapping show -vserver $SVM_NAME"

} | tee -a "$LOG_FILE"