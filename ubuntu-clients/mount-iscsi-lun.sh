#!/bin/bash

# Log file location in the home directory
LOG_FILE="$HOME/iscsi_lun_mount.log"
MOUNT_POINT="/mnt/fsx_1"
MULTIPATH_ALIAS="iscsi_lun1"
PARTITION="/dev/mapper/${MULTIPATH_ALIAS}-part1"

# Function to log messages
log() {
    echo "$1" | sudo tee -a $LOG_FILE
}

# Ensure the log directory and file can be created
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Start logging
log "Script started at $(date)"

# Retrieve SERIAL_HEX and ISCSI_IP from SSM Parameter Store
PARAM_SERIAL_HEX="/fsx-ontap-poc/iscsi-lun/serial-hex"
PARAM_ISCSI_IP="/fsx-ontap-poc/iscsi-lun/iscsi-ip1"

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

# Step 1: Discover iSCSI targets
log "Discovering iSCSI targets on $ISCSI_IP..."
IQN=$(sudo iscsiadm --mode discovery --type sendtargets --portal "$ISCSI_IP" | awk '{print $2}' | head -n 1)

if [ -z "$IQN" ]; then
    log "Error: No IQN discovered at portal $ISCSI_IP."
    exit 1
fi

log "Discovered IQN: $IQN"

# Step 2: Update node to record the target
log "Establishing a record for target $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --op new
if [ $? -ne 0 ]; then
    log "Error: Failed to establish a record for the target node."
    exit 1
fi

# Step 3: Update number of sessions for the iSCSI target
log "Updating number of sessions for $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --op update -n node.session.nr_sessions -v 8

# Step 4: Log in to the iSCSI target
log "Logging into iSCSI target $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --login
if [ $? -ne 0 ]; then
    log "Error: Failed to log in to iSCSI target $IQN."
    exit 1
fi

# Step 5: Verify multipath status
log "Verifying multipath status..."
sudo multipath -ll | sudo tee -a $LOG_FILE

# Step 6: Append multipath configuration to /etc/multipath.conf
log "Checking for existing multipath configuration..."
if ! sudo grep -q -F "wwid 3600a0980$SERIAL_HEX" /etc/multipath.conf; then
    log "Appending multipath configuration..."
    echo -e "multipaths {\n    multipath {\n        wwid 3600a0980$SERIAL_HEX\n        alias $MULTIPATH_ALIAS\n    }\n}" | sudo tee -a /etc/multipath.conf > /dev/null
else
    log "Multipath entry already exists for alias $MULTIPATH_ALIAS."
fi

# Step 7: Restart multipathd service
log "Restarting multipathd service..."
sudo systemctl restart multipathd.service

# Step 8: Partition the disk automatically using fdisk
log "Partitioning the disk..."
(echo o; echo n; echo p; echo 1; echo ''; echo ''; echo w) | sudo fdisk /dev/mapper/$MULTIPATH_ALIAS

# Step 9: Create ext4 filesystem on the new partition
log "Creating ext4 filesystem..."
sudo mkfs.ext4 $PARTITION

# Step 10: Create the mount point directory
log "Creating mount point directory $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT

# Step 11: Mount the filesystem
log "Mounting the filesystem at $MOUNT_POINT..."
sudo mount -t ext4 $PARTITION $MOUNT_POINT

# Step 12: Change ownership of the mount point
log "Changing ownership of $MOUNT_POINT to ssm-user..."
sudo chown ssm-user:ssm-user $MOUNT_POINT

# End logging
log "Script completed at $(date)"
log "iSCSI LUN mounted, partitioned, filesystem created, mounted, and ownership set successfully."