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

# Detect instance metadata
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

# Fetch instance name tag
INSTANCE_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)

if [ -z "$INSTANCE_NAME" ]; then
    log "Error: Failed to retrieve instance name from AWS"
    exit 1
fi

log "Running on instance: $INSTANCE_NAME"

# Check if necessary tools are installed
for cmd in iscsiadm multipath mkfs.ext4 fdisk; do
    if ! command -v $cmd &> /dev/null; then
        log "Error: $cmd is not installed."
        exit 1
    fi
done

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

# Discover and log in to iSCSI target
log "Discovering iSCSI targets on $ISCSI_IP..."
IQN=$(sudo iscsiadm --mode discovery --type sendtargets --portal "$ISCSI_IP" | awk '{print $2}' | head -n 1)

if [ -z "$IQN" ]; then
    log "Error: No IQN discovered at portal $ISCSI_IP."
    exit 1
fi

log "Discovered IQN: $IQN"

log "Establishing a record for target $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --op new
if [ $? -ne 0 ]; then
    log "Error: Failed to establish a record for the target node."
    exit 1
fi

log "Updating number of sessions for $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --op update -n node.session.nr_sessions -v 8

log "Logging into iSCSI target $IQN..."
sudo iscsiadm --mode node --targetname "$IQN" --portal "$ISCSI_IP" --login
if [ $? -ne 0 ]; then
    log "Error: Failed to log in to iSCSI target $IQN."
    exit 1
fi

# Execute full setup for first client
if [ "$INSTANCE_NAME" == "Ubuntu-Client-1" ]; then
    log "Running full setup for first client: $INSTANCE_NAME"

    # Verify multipath status
    log "Verifying multipath status..."
    sudo multipath -ll | sudo tee -a $LOG_FILE

    # Append multipath configuration
    log "Checking for existing multipath configuration..."
    if ! sudo grep -q -F "wwid 3600a0980$SERIAL_HEX" /etc/multipath.conf; then
        log "Appending multipath configuration..."
        echo -e "multipaths {\n    multipath {\n        wwid 3600a0980$SERIAL_HEX\n        alias $MULTIPATH_ALIAS\n    }\n}" | sudo tee -a /etc/multipath.conf > /dev/null
    else
        log "Multipath entry already exists for alias $MULTIPATH_ALIAS."
    fi

    # Restart multipathd service
    log "Restarting multipathd service..."
    sudo systemctl restart multipathd.service

    # Partition the disk
    log "Partitioning the disk..."
    (echo o; echo n; echo p; echo 1; echo ''; echo ''; echo w) | sudo fdisk /dev/mapper/$MULTIPATH_ALIAS

    # Create ext4 filesystem on the new partition
    log "Creating ext4 filesystem..."
    sudo mkfs.ext4 $PARTITION
fi

# Mount filesystem and set ownership (for all clients)
log "Ensuring mount point directory $MOUNT_POINT exists..."
sudo mkdir -p $MOUNT_POINT

log "Mounting the filesystem at $MOUNT_POINT..."
sudo mount -t ext4 $PARTITION $MOUNT_POINT

log "Changing ownership of $MOUNT_POINT to ssm-user..."
sudo chown ssm-user:ssm-user $MOUNT_POINT

# End logging
log "Script completed at $(date)"
log "iSCSI LUN successfully handled according to client role."