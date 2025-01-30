#!/bin/bash

# Capture the serial_hex as the first argument
SERIAL_HEX=$1
# Capture the iSCSI portal IP as the second argument
ISCSI_IP=$2
# Log file location
LOG_FILE="/var/log/iscsi_lun_mount.log"

# Start logging
echo "Script started at $(date)" | sudo tee -a $LOG_FILE

# Step 1: Discover iSCSI targets
echo "Discovering iSCSI targets..." | sudo tee -a $LOG_FILE
IQN=$(sudo iscsiadm --mode discovery --op update --type sendtargets --portal "$ISCSI_IP" | awk '{print $2}')
echo "Discovered IQN: $IQN" | sudo tee -a $LOG_FILE

# Step 2: Update number of sessions for the iSCSI target
echo "Updating number of sessions for $IQN..." | sudo tee -a $LOG_FILE
sudo iscsiadm --mode node -T "$IQN" --op update -n node.session.nr_sessions -v 8 | sudo tee -a $LOG_FILE

# Step 3: Log in to the iSCSI target
echo "Logging into iSCSI target $IQN..." | sudo tee -a $LOG_FILE
sudo iscsiadm --mode node -T "$IQN" --login | sudo tee -a $LOG_FILE

# Step 4: (Optional) Verify multipath status
echo "Verifying multipath status..." | sudo tee -a $LOG_FILE
sudo multipath -ll | sudo tee -a $LOG_FILE

# Step 5: Append multipath configuration to /etc/multipath.conf
echo "Appending multipath configuration..." | sudo tee -a $LOG_FILE
echo "multipaths {
    multipath {
        wwid 3600a0980$SERIAL_HEX
        alias iscsi_lun1
    }
}" | sudo tee -a /etc/multipath.conf > /dev/null

# Step 6: Restart multipathd service
echo "Restarting multipathd service..." | sudo tee -a $LOG_FILE
sudo systemctl restart multipathd.service | sudo tee -a $LOG_FILE

# Step 7: Partition the disk automatically using fdisk
echo "Partitioning the disk..." | sudo tee -a $LOG_FILE
echo -e "o\nn\np\n1\n\n\nw" | sudo fdisk /dev/mapper/iscsi_lun1 | sudo tee -a $LOG_FILE

# Step 8: Create ext4 filesystem on the new partition
echo "Creating ext4 filesystem on /dev/mapper/iscsi_lun1-part1..." | sudo tee -a $LOG_FILE
sudo mkfs.ext4 /dev/mapper/iscsi_lun1-part1 | sudo tee -a $LOG_FILE

# Step 9: Create the mount point directory
echo "Creating mount point directory /mnt/fsx_1..." | sudo tee -a $LOG_FILE
sudo mkdir /mnt/fsx_1 | sudo tee -a $LOG_FILE

# Step 10: Mount the filesystem
echo "Mounting the filesystem..." | sudo tee -a $LOG_FILE
sudo mount -t ext4 /dev/mapper/iscsi_lun1-part1 /mnt/fsx_1 | sudo tee -a $LOG_FILE

# Step 11: Change ownership of the mount point
echo "Changing ownership of /mnt/fsx_1 to ssm-user..." | sudo tee -a $LOG_FILE
sudo chown ssm-user:ssm-user /mnt/fsx_1 | sudo tee -a $LOG_FILE

# End logging
echo "Script completed at $(date)" | sudo tee -a $LOG_FILE
echo "iSCSI LUN mounted, partitioned, filesystem created, mounted, and ownership set successfully." | sudo tee -a $LOG_FILE
