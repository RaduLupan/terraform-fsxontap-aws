#!/bin/bash

# ==============================================================================
# Script Name: mount_iscsi_lun.sh
#
# Description: This script automates the process of mounting an iSCSI LUN on a
#              specified mount point. It checks for active sessions, partitions
#              disks, creates filesystems, and mounts them, ensuring each step
#              is only executed if necessary, making the script idempotent.
#              The script now configures persistent settings to survive reboots.
#
# Usage: sudo ./mount_iscsi_lun.sh
#
# Requirements:
#   - iscsiadm, multipath, mkfs.ext4, fdisk installed
#   - AWS CLI configured to access SSM Parameter Store
#   - Run with superuser privileges
#
# Author: Radu Lupan - Assisted by OpenAI ChatGPT (gpt-4o)
# Date:   2025-03-07
# ==============================================================================

# Log file location in the /var/log/ directory
LOG_FILE="/var/log/mount_iscsi_lun.log"

# Initialize variables
ISCSI_INITIATOR_NAME=""
MULTIPATH_ALIAS=""
PARAM_SERIAL_HEX=""
MOUNT_POINT="/mnt/fsx_1"
MULTIPATH_DEVICE="/dev/mapper/${MULTIPATH_ALIAS}"
PARTITION="${MULTIPATH_DEVICE}-part1"
PARAM_ISCSI_IP="/fsxontap-poc/iscsi-network-ip"

# Function to log messages
log() {
    echo "$1" | sudo tee -a $LOG_FILE
}

# Ensure the log directory and file can be created
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Start logging
log "Script started at $(date)"

# Read the iSCSI Initiator Name from the file and assign it to a variable
ISCSI_INITIATOR_NAME=$(sudo grep -E '^InitiatorName=' /etc/iscsi/initiatorname.iscsi | awk -F= '{print $2}')

# Verify if the variable is assigned correctly
if [ -z "$ISCSI_INITIATOR_NAME" ]; then
    log "Error: Could not retrieve iSCSI Initiator Name."
    exit 1
else
    log "iSCSI Initiator Name: $ISCSI_INITIATOR_NAME"
fi

# Determine MULTIPATH_ALIAS and PARAM_SERIAL_HEX based on the initiator name. This will mount iscsi_lun_1 for client-1 and iscsi_lun_2 for client-2.
if [[ "$ISCSI_INITIATOR_NAME" == *"client-1"* ]]; then
    MULTIPATH_ALIAS="iscsi_lun_1"
    PARAM_SERIAL_HEX="/fsxontap-poc/iscsi-lun1-serial-hex"
else
    MULTIPATH_ALIAS="iscsi_lun_2"
    PARAM_SERIAL_HEX="/fsxontap-poc/iscsi-lun2-serial-hex"
fi

log "MULTIPATH_ALIAS set to: $MULTIPATH_ALIAS"
log "PARAM_SERIAL_HEX set to: $PARAM_SERIAL_HEX"

# Retrieve SERIAL_HEX and ISCSI_IP from SSM Parameter Store
SERIAL_HEX=$(aws ssm get-parameter --name "$PARAM_SERIAL_HEX" --query "Parameter.Value" --output text)
ISCSI_IP=$(aws ssm get-parameter --name "$PARAM_ISCSI_IP" --query "Parameter.Value" --output text)

# Validate retrieval
if [ -z "$SERIAL_HEX" ] || [ -z "$ISCSI_IP" ]; then
    log "Error: Failed to retrieve one or more parameters from SSM Parameter Store."
    exit 1
fi

# Check if necessary tools are installed
for cmd in iscsiadm multipath mkfs.ext4 fdisk; do
    if ! command -v $cmd &> /dev/null; then
        log "Error: $cmd is not installed."
        exit 1
    fi
done

# Step 1 & 2: Discover iSCSI targets and manage sessions
log "Discovering iSCSI targets on $ISCSI_IP..."
IQN=$(sudo iscsiadm --mode discovery --type sendtargets --portal "$ISCSI_IP" | awk '{print $2}' | head -n 1)
if [ -z "$IQN" ]; then
    log "Error: No IQN discovered at portal $ISCSI_IP."
    exit 1
fi
log "Discovered IQN: $IQN"

# Configure automatic iSCSI login
log "Setting iSCSI target $IQN to automatic login..."
sudo iscsiadm -m node --targetname "$IQN" --portal "$ISCSI_IP" --op update -n node.startup -v automatic

# Log out any existing sessions for the target
if iscsiadm -m session | grep -q "$IQN"; then
    log "Logging out existing iSCSI session for $IQN..."
    sudo iscsiadm -m node --targetname "$IQN" --portal "$ISCSI_IP" --logout || log "Warning: Failed to log out from existing iSCSI session."
fi

# Step 3: Ensure node sessions are configured
log "Updating number of sessions for $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --op update -n node.session.nr_sessions -v 8

# Step 4: Proceed with logging in to iSCSI target
log "Establishing record and logging into iSCSI target $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --login
if [ $? -ne 0 ]; then
    log "Error: Failed to log in to iSCSI target $IQN."
    exit 1
fi

# Step 5: Verify and refresh multipath status
log "Verifying multipath status and refreshing devices..."
sudo multipath -ll | sudo tee -a $LOG_FILE

# Step 6: Assign the block device a friendly name
log "Configuring multipath by assigning a friendly name..."
sudo tee /etc/multipath.conf >/dev/null <<EOF
defaults {
    user_friendly_names yes
    find_multipaths yes
    no_path_retry 6
}

multipaths {
    multipath {
        wwid "3600a0980$SERIAL_HEX"
        alias "$MULTIPATH_ALIAS"
    }
}
EOF

log "Restarting multipathd service..."
sudo systemctl restart multipathd

# Refresh multipath devices to apply the config
log "Refreshing multipath devices..."
sudo multipath -r

# Verify that the multipath alias is correctly recognized
if sudo multipath -ll | grep -q "$MULTIPATH_ALIAS"; then
    log "Multipath alias $MULTIPATH_ALIAS successfully configured."
else
    log "Error: Multipath alias $MULTIPATH_ALIAS not found."
    exit 1
fi

# Step 7: Check multipath configuration
if [ ! -e "$MULTIPATH_DEVICE" ]; then
    log "Error: Multipath device $MULTIPATH_DEVICE does not exist."
    exit 1
fi

# Step 8: Restart multipathd service at boot
log "Ensuring multipathd service starts on boot..."
sudo systemctl enable multipathd.service

# Step 9: Partition the disk if not already partitioned
if [ ! -e "$PARTITION" ]; then
    log "Partitioning the disk..."
    (echo o; echo n; echo p; echo 1; echo ''; echo ''; echo w) | sudo fdisk "$MULTIPATH_DEVICE"
else
    log "Partition $PARTITION already exists. Skipping partitioning."
fi

# Step 10: Create ext4 filesystem on the partition if it doesn't exist
if ! sudo blkid "$PARTITION" | grep -q "ext4"; then
    log "Creating ext4 filesystem..."
    sudo mkfs.ext4 "$PARTITION"
else
    log "Filesystem already exists on $PARTITION. Skipping filesystem creation."
fi

# Step 11: Create the mount point directory if it doesn't exist
log "Ensuring mount point directory $MOUNT_POINT exists..."
sudo mkdir -p "$MOUNT_POINT"

# Step 12: Add the filesystem to /etc/fstab for automatic mounting
log "Adding the filesystem to /etc/fstab for automatic mounting..."
UUID=$(sudo blkid -s UUID -o value "$PARTITION")
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults,_netdev 0 2" | sudo tee -a /etc/fstab
    log "Added $PARTITION to /etc/fstab for mounting at $MOUNT_POINT"
else
    log "Filesystem already configured in /etc/fstab."
fi

# Step 13: Mount the filesystem if not already mounted
if ! mount | grep -q "$MOUNT_POINT"; then
    log "Mounting the filesystem at $MOUNT_POINT..."
    sudo mount "$MOUNT_POINT"
else
    log "Filesystem already mounted at $MOUNT_POINT. Skipping mounting."
fi

# Step 14: Change ownership of the mount point
log "Changing ownership of $MOUNT_POINT to ssm-user..."
sudo chown ssm-user:ssm-user "$MOUNT_POINT"

# End logging
log "Script completed at $(date)"
log "iSCSI LUN mounted, partitioned, filesystem created, mounted, and ownership set successfully."