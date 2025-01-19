#!/bin/bash

sudo apt update -y

# Install the open-iscsi package
sudo apt install open-iscsi -y

# To facilitate a faster response when automatically failing over between file servers when using multipath, 
# set the replacement timeout value in the /etc/iscsi/iscsid.conf file to a value of 5 instead of using the default value of 120.
sudo sed -i 's/node.session.timeo.replacement_timeout = .*/node.session.timeo.replacement_timeout = 5/' /etc/iscsi/iscsid.conf
sudo cat /etc/iscsi/iscsid.conf | grep node.session.timeo.replacement_timeout

# Start the iSCSI service
sudo service iscsid start

# Install multi-path packages
sudo apt install multipath-tools multipath-tools-boot -y

# Create new config file
sudo touch /etc/multipath.conf

# Add the following lines to the /etc/multipath.conf file. 
# Refer to the multipath.conf man page (man multipath.conf) for a complete list of available options and their descriptions.
sudo cat <<EOF | sudo tee /etc/multipath.conf
defaults {
    user_friendly_names yes
    find_multipaths yes
    no_path_retry 6   
}
EOF

# Start and enable the multipath serviceStart and enable the multipath service
sudo systemctl start multipathd
sudo systemctl enable multipathd