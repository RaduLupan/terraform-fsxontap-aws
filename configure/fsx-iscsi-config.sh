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

# Consolidate SSH commands to reduce context issues
execute_command() {
    local COMMAND="$1"
    sshpass -p "$FSX_PASSWORD" ssh -T -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP "$COMMAND"
}

# Command block execution via SSH for setup tasks
execute_command <<EOF
    lun create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -size $LUN_SIZE -ostype $OS_TYPE -space-allocation enabled
    lun igroup create -vserver $SVM_NAME -igroup $IGROUP_NAME -protocol iscsi -ostype linux
$(for INITIATOR in "${INITIATORS[@]}"; do
    echo "    lun igroup add -vserver $SVM_NAME -igroup $IGROUP_NAME -initiator $INITIATOR"
done)
    lun mapping create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -igroup $IGROUP_NAME
EOF

# Verifying setup and storing logs
{
echo "LUN Serial-Hex:"
execute_command \
    "lun show -path /vol/$VOL_NAME/$LUN_NAME -vserver $SVM_NAME -fields serial-hex" | awk 'NR==3 {print $3}'

echo "iSCSI Network Interfaces:"
execute_command \
    "network interface show -vserver $SVM_NAME" | awk '/iscsi_1/ || /iscsi_2/ {print $2, $4}'

# Show iGroup and LUN mappings
echo "iGroup details:"
execute_command \
    "lun igroup show -vserver $SVM_NAME -igroup $IGROUP_NAME"

echo "LUN Mappings:"
execute_command \
    "lun mapping show -vserver $SVM_NAME"
} | tee -a "$LOG_FILE"