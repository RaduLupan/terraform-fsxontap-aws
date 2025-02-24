#!/bin/bash

# Variables - Replace these with your actual parameter names
PARAM_FSX_MGMT_IP="/fsxontap-poc/management-endpoint-ip"
PARAM_FSX_USERNAME="/fsxontap-poc/management-user"
PARAM_FSX_PASSWORD="/fsxontap-poc/management-password"
PARAM_INITIATOR_1="/fsxontap-poc/iscsi-initiator-name/ubuntu-client-1"
PARAM_INITIATOR_2="/fsxontap-poc/iscsi-initiator-name/ubuntu-client-2"

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

VOL1_NAME="iscsi_volume1"
LUN1_NAME="lun_1"
LUN1_SIZE="161061273600"  # Size in bytes for the LUN, example 150GB LUN will be 161061273600 bytes (150*1024*1024*1024)

VOL2_NAME="iscsi_volume2"
LUN2_NAME="lun_2"
LUN2_SIZE="161061273600"  # Size in bytes for the LUN, example 150GB LUN will be 161061273600 bytes (150*1024*1024*1024)

IGROUP1_NAME="igroup_1"
IGROUP2_NAME="igroup_2"

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

# Create the LUNs
echo "Creating LUN 1..." | tee -a "$LOG_FILE"
run_ssh_command "lun create -vserver $SVM_NAME -path /vol/$VOL1_NAME/$LUN1_NAME -size $LUN1_SIZE -ostype $OS_TYPE -space-allocation enabled" | tee -a "$LOG_FILE"

echo "Creating LUN 2..." | tee -a "$LOG_FILE"
run_ssh_command "lun create -vserver $SVM_NAME -path /vol/$VOL2_NAME/$LUN2_NAME -size $LUN2_SIZE -ostype $OS_TYPE -space-allocation enabled" | tee -a "$LOG_FILE"

# Create iGroups
echo "Creating iGroup 1..." | tee -a "$LOG_FILE"
run_ssh_command "lun igroup create -vserver $SVM_NAME -igroup $IGROUP1_NAME -protocol iscsi -ostype linux" | tee -a "$LOG_FILE"

echo "Creating iGroup 2..." | tee -a "$LOG_FILE"
run_ssh_command "lun igroup create -vserver $SVM_NAME -igroup $IGROUP2_NAME -protocol iscsi -ostype linux" | tee -a "$LOG_FILE"

# Add initiators to their respective iGroups
echo "Adding initiator $INITIATOR_1 to iGroup $IGROUP1_NAME..." | tee -a "$LOG_FILE"
run_ssh_command "lun igroup add -vserver $SVM_NAME -igroup $IGROUP1_NAME -initiator $INITIATOR_1" | tee -a "$LOG_FILE"

echo "Adding initiator $INITIATOR_2 to iGroup $IGROUP2_NAME..." | tee -a "$LOG_FILE"
run_ssh_command "lun igroup add -vserver $SVM_NAME -igroup $IGROUP2_NAME -initiator $INITIATOR_2" | tee -a "$LOG_FILE"

# Map the LUNs to their respective iGroups
echo "Mapping LUN 1 to iGroup 1..." | tee -a "$LOG_FILE"
run_ssh_command "lun mapping create -vserver $SVM_NAME -path /vol/$VOL1_NAME/$LUN1_NAME -igroup $IGROUP1_NAME" | tee -a "$LOG_FILE"

echo "Mapping LUN 2 to iGroup 2..." | tee -a "$LOG_FILE"
run_ssh_command "lun mapping create -vserver $SVM_NAME -path /vol/$VOL2_NAME/$LUN2_NAME -igroup $IGROUP2_NAME" | tee -a "$LOG_FILE"


# Verify and log
{
    echo "LUN 1 Details:"
    run_ssh_command "lun show -path /vol/$VOL1_NAME/$LUN1_NAME -vserver $SVM_NAME -fields state,mapped,serial-hex"
    
    echo "LUN 2 Details:"
    run_ssh_command "lun show -path /vol/$VOL2_NAME/$LUN2_NAME -vserver $SVM_NAME -fields state,mapped,serial-hex"

    echo "iSCSI Network Interfaces:"
    run_ssh_command "network interface show -vserver $SVM_NAME"

    echo "iGroup 1 Details:"
    run_ssh_command "lun igroup show -vserver $SVM_NAME -igroup $IGROUP1_NAME"

    echo "iGroup 2 Details:"
    run_ssh_command "lun igroup show -vserver $SVM_NAME -igroup $IGROUP2_NAME"

    echo "LUN Mappings:"
    run_ssh_command "lun mapping show -vserver $SVM_NAME"
} | tee -a "$LOG_FILE"

echo "Script completed at $(date)" | tee -a "$LOG_FILE"