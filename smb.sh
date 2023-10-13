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

echo "[$LOGGED_IN_USER]
   comment = Home Directories
   browseable = no
   path = /home/$LOGGED_IN_USER/
   read only = no
   create mask = 0700
   directory mask = 0700
   valid users = %S" >> /etc/samba/smb.conf

# Restart samba to apply changes
systemctl restart smbd

# Prompt the user to set a Samba password for their user
USER=$(logname)
sudo smbpasswd -a $USER

# Print network info and SMB URL
IP_ADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname | awk '{print}')
USERNAME=$(logname)
echo "Samba is now configured. Connect using your current username and password."
echo "Your SMB URL is: smb://$IP_ADDR/$USERNAME"
echo "Your SMB URL is: smb://$HOSTNAME.local/$USERNAME"


