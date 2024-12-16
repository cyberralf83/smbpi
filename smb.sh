#!/bin/bash

# Exit on error
set -e

# Update package list and install samba
apt-get update
apt-get install -y samba

# Backup the original smb.conf
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Get logged in user
LOGGED_IN_USER=$(logname)

echo "The user logged in is: $LOGGED_IN_USER"

# Find and modify the [homes] section to add inherit permissions and writable
sed -i '/\[homes\]/,/\[/ s/$/\n   inherit permissions = yes\n   writable = yes/' /etc/samba/smb.conf

# Restart samba to apply changes
systemctl restart smbd

# Set up Samba password for the logged-in user
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