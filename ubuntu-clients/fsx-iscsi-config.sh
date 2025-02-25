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
LUN1_SIZE="161061273600"  # Size in bytes for the LUN, example 150GB

VOL2_NAME="iscsi_volume2"
LUN2_NAME="lun_2"
LUN2_SIZE="161061273600"  # Size in bytes for the LUN, example 150GB

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
    else
        echo "$OUTPUT"
    fi
}

# Function to check if resource exists
resource_exists() {
    local RESOURCE_TYPE="$1"
    local RESOURCE_IDENTIFIER="$2"
    run_ssh_command "$RESOURCE_TYPE show -vserver $SVM_NAME | grep -q '$RESOURCE_IDENTIFIER'"
}

# Begin logging
echo "Starting script at $(date)" | tee -a "$LOG_FILE"

# Create the LUN if it doesn't exist
create_lun() {
    local VOL_NAME="$1"
    local LUN_NAME="$2"
    local LUN_SIZE="$3"
    if resource_exists lun "/vol/$VOL_NAME/$LUN_NAME"; then
        echo "LUN $LUN_NAME already exists. Skipping creation." | tee -a "$LOG_FILE"
    else
        echo "Creating LUN $LUN_NAME..." | tee -a "$LOG_FILE"
        run_ssh_command "lun create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -size $LUN_SIZE -ostype $OS_TYPE -space-allocation enabled" | tee -a "$LOG_FILE"
    fi
}

# Create iGroup if it doesn't exist
create_igroup() {
    local IGROUP_NAME="$1"
    if resource_exists "lun igroup" "$IGROUP_NAME"; then
        echo "iGroup $IGROUP_NAME already exists. Skipping creation." | tee -a "$LOG_FILE"
    else
        echo "Creating iGroup $IGROUP_NAME..." | tee -a "$LOG_FILE"
        run_ssh_command "lun igroup create -vserver $SVM_NAME -igroup $IGROUP_NAME -protocol iscsi -ostype linux" | tee -a "$LOG_FILE"
    fi
}

# Add initiator if it doesn't exist
add_initiator() {
    local IGROUP_NAME="$1"
    local INITIATOR="$2"
    if run_ssh_command "lun igroup show -vserver $SVM_NAME -igroup $IGROUP_NAME | grep -q '$INITIATOR'"; then
        echo "Initiator $INITIATOR already exists in $IGROUP_NAME. Skipping addition." | tee -a "$LOG_FILE"
    else
        echo "Adding initiator $INITIATOR to $IGROUP_NAME..." | tee -a "$LOG_FILE"
        run_ssh_command "lun igroup add -vserver $SVM_NAME -igroup $IGROUP_NAME -initiator $INITIATOR" | tee -a "$LOG_FILE"
    fi
}

# Map the LUN to the iGroup if not already mapped
map_lun() {
    local VOL_NAME="$1"
    local LUN_NAME="$2"
    local IGROUP_NAME="$3"
    if run_ssh_command "lun mapping show -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME" | grep -q "$IGROUP_NAME"; then
        echo "LUN $LUN_NAME is already mapped to $IGROUP_NAME. Skipping mapping." | tee -a "$LOG_FILE"
    else
        echo "Mapping LUN $LUN_NAME to $IGROUP_NAME..." | tee -a "$LOG_FILE"
        run_ssh_command "lun mapping create -vserver $SVM_NAME -path /vol/$VOL_NAME/$LUN_NAME -igroup $IGROUP_NAME" | tee -a "$LOG_FILE"
    fi
}

# Execute functions
create_lun "$VOL1_NAME" "$LUN1_NAME" "$LUN1_SIZE"
create_lun "$VOL2_NAME" "$LUN2_NAME" "$LUN2_SIZE"
create_igroup "$IGROUP1_NAME"
create_igroup "$IGROUP2_NAME"
add_initiator "$IGROUP1_NAME" "$INITIATOR_1"
add_initiator "$IGROUP2_NAME" "$INITIATOR_2"
map_lun "$VOL1_NAME" "$LUN1_NAME" "$IGROUP1_NAME"
map_lun "$VOL2_NAME" "$LUN2_NAME" "$IGROUP2_NAME"

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