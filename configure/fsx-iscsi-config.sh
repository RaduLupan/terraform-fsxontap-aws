#!/bin/bash

# Variables
FSX_MGMT_IP="198.19.255.155"
FSX_USERNAME="fsxadmin"
FSX_PASSWORD="MyTestEfEsEx2025!"

SVM_NAME="svm01"
VOL_NAME="iscsi_volume2"
LUN_NAME="lun_1"
LUN_SIZE="295279001600"  # Size in bytes for the LUN, example 275GB LUN will be 295279001600 bytes (275*1024*1024*1024)
IGROUP_NAME="igroup_1"
INITIATORS=("iqn.2004-10.com.ubuntu:Ubuntu-Client-1" "iqn.2004-10.com.ubuntu:Ubuntu-Client-2")  # List of initiators
OS_TYPE="linux"  # OS Type for LUN

LOG_FILE="$HOME/fsx_iscsi.log"  # Change log file location to home directory

# Install sshpass if not installed
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt update && sudo apt install -y sshpass
fi

# Function to run commands via SSH
run_ssh_command() {
    local COMMAND="$1"
    sshpass -p "$FSX_PASSWORD" ssh -T -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP "$COMMAND"
}

# Create the LUN
run_ssh_command "lun create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -size $LUN_SIZE -ostype $OS_TYPE -space-allocation enabled"

# Create iGroup
run_ssh_command "lun igroup create -vserver $SVM_NAME -igroup $IGROUP_NAME -protocol iscsi -ostype linux"

# Add each initiator to the iGroup
for INITIATOR in "${INITIATORS[@]}"; do
    run_ssh_command "lun igroup add -vserver $SVM_NAME -igroup $IGROUP_NAME -initiator $INITIATOR"
done

# Map the LUN to the iGroup
run_ssh_command "lun mapping create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -igroup $IGROUP_NAME"

# Verify and log
{
    echo "LUN Details:"
    run_ssh_command "lun show -path /vol/$VOL_NAME/$LUN_NAME -vserver $SVM_NAME -fields state,mapped,serial-hex"

    echo "iSCSI Network Interfaces:"
    run_ssh_command "network interface show -vserver $SVM_NAME"

    echo "iGroup Details:"
    run_ssh_command "lun igroup show -vserver $SVM_NAME -igroup $IGROUP_NAME"

    echo "LUN Mappings:"
    run_ssh_command "lun mapping show -vserver $SVM_NAME"
} | tee -a "$LOG_FILE"