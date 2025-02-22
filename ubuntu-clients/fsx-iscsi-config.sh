#!/bin/bash

# Variables - Replace these with your actual parameter names
PARAM_FSX_MGMT_IP="/fsx-ontap-poc/admin/management-ip"
PARAM_FSX_USERNAME="/fsx-ontap-poc/admin/management-user"
PARAM_FSX_PASSWORD="/fsx-ontap-poc/admin/management-pwd"
PARAM_INITIATOR_1="/fsx-ontap-poc/clients/iscsi-initiator-name/Ubuntu-Client-1"
PARAM_INITIATOR_2="/fsx-ontap-poc/clients/iscsi-initiator-name/Ubuntu-Client-2"

# Retrieve values from SSM Parameter Store
FSX_MGMT_IP=$(aws ssm get-parameter --name "$PARAM_FSX_MGMT_IP" --query "Parameter.Value" --output text)
FSX_USERNAME=$(aws ssm get-parameter --name "$PARAM_FSX_USERNAME" --query "Parameter.Value" --output text)
FSX_PASSWORD=$(aws ssm get-parameter --name "$PARAM_FSX_PASSWORD" --with-decryption --query "Parameter.Value" --output text)
INITIATOR_1=$(aws ssm get-parameter --name "$PARAM_INITIATOR_1" --query "Parameter.Value" --output text)
INITIATOR_2=$(aws ssm get-parameter --name "$PARAM_INITIATOR_2" --query "Parameter.Value" --output text)

# Check if all parameters were retrieved
if [ -z "$FSX_MGMT_IP" ] || [ -z "$FSX_USERNAME" ] || [ -z "$FSX_PASSWORD" ] || [ -z "$INITIATOR_1" ] || [ -z "$INITIATOR_2" ]; then
    echo "Failed to retrieve one or more parameters from SSM Parameter Store."
    exit 1
fi

SVM_NAME="svm01"
VOL_NAME="iscsi_volume2"
LUN_NAME="lun_1"
LUN_SIZE="295279001600"  # Size in bytes for the LUN, example 275GB LUN will be 295279001600 bytes (275*1024*1024*1024)
IGROUP_NAME="igroup_1"
INITIATORS=("$INITIATOR_1" "$INITIATOR_2")  # List of initiators from SSM
OS_TYPE="linux"  # OS Type for LUN

LOG_FILE="$HOME/fsx_iscsi.log"

# Install sshpass if not installed
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt update && sudo apt install -y sshpass
fi

# Function to run commands via SSH
run_ssh_command() {
    local COMMAND="$1"
    OUTPUT=$(sshpass -p "$FSX_PASSWORD" ssh -T -o StrictHostKeyChecking=no $FSX_USERNAME@$FSX_MGMT_IP "$COMMAND" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Command failed: $COMMAND"
        echo "Error: $OUTPUT"
        exit 1
    fi
    echo "$OUTPUT"
}

# Begin logging
echo "Starting script at $(date)" | tee -a "$LOG_FILE"

# Create the LUN
echo "Creating LUN..." | tee -a "$LOG_FILE"
run_ssh_command "lun create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -size $LUN_SIZE -ostype $OS_TYPE -space-allocation enabled" | tee -a "$LOG_FILE"

# Create iGroup
echo "Creating iGroup..." | tee -a "$LOG_FILE"
run_ssh_command "lun igroup create -vserver $SVM_NAME -igroup $IGROUP_NAME -protocol iscsi -ostype linux" | tee -a "$LOG_FILE"

# Add each initiator to the iGroup
for INITIATOR in "${INITIATORS[@]}"; do
    echo "Adding initiator $INITIATOR to iGroup $IGROUP_NAME..." | tee -a "$LOG_FILE"
    run_ssh_command "lun igroup add -vserver $SVM_NAME -igroup $IGROUP_NAME -initiator $INITIATOR" | tee -a "$LOG_FILE"
done

# Map the LUN to the iGroup
echo "Mapping the LUN to the iGroup..." | tee -a "$LOG_FILE"
run_ssh_command "lun mapping create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -igroup $IGROUP_NAME" | tee -a "$LOG_FILE"

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

echo "Script completed at $(date)" | tee -a "$LOG_FILE"