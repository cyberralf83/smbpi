#!/bin/bash

# Exit on error
set -e

# Update package list and install samba
apt-get update
apt-get install -y samba

# Backup the original smb.conf
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Add configuration to share the home directories
LOGGED_IN_USER=$(logname)

echo "The user logged in is: $LOGGED_IN_USER"

# Restart samba to apply changes
systemctl restart smbd

# Prompt the user to set a Samba password for their user
USER=$(logname)
sudo smbpasswd -a $USER

# Restart samba to apply changes
systemctl restart smbd

# Print network info and SMB URL
IP_ADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname | awk '{print}')
USERNAME=$(logname)
echo "Samba is now configured. Connect using your current username and password."
echo "Your SMB URL is: smb://$IP_ADDR/$USERNAME"
echo "Your SMB URL is: smb://$HOSTNAME.local/$USERNAME"
echo "Next Step: sudo nano /etc/samba/smb.conf to make [homes] read only = no,"
echo" create mask = 0750, directory mask = 0750 then systemctl restart smbd" 