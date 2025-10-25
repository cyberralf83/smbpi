#!/bin/bash

# Exit on error
set -e

# Get the current user
USER=$(logname)
echo "Setting up Samba for user: $USER"

# Update package list and install samba
echo "Installing Samba..."
apt-get update
apt-get install -y samba

# Backup the original smb.conf if not already backed up
if [ ! -f /etc/samba/smb.conf.bak ]; then
    echo "Backing up original smb.conf..."
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

# Configure the [homes] share with read/write access
# This keeps the system defaults but adds/updates the homes section
echo "Configuring Samba share for home directory..."

# Remove existing [homes] section if present
sed -i '/^\[homes\]/,/^\[/{ /^\[homes\]/!{ /^\[/!d; }; }' /etc/samba/smb.conf
sed -i '/^\[homes\]/d' /etc/samba/smb.conf

# Append the homes configuration to the end of the file
cat >> /etc/samba/smb.conf << EOF

[homes]
   comment = Home Directories
   browseable = no
   read only = no
   create mask = 0750
   directory mask = 0750
   valid users = %S
EOF

echo "Samba configuration updated."

# Prompt the user to set a Samba password
echo "Setting Samba password for user: $USER"
smbpasswd -a $USER

# Restart samba to apply changes
echo "Restarting Samba service..."
systemctl restart smbd
systemctl restart nmbd

# Print network info and SMB URL
IP_ADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
echo ""
echo "=========================================="
echo "Samba installation complete!"
echo "=========================================="
echo "Connect using username: $USER"
echo "SMB URL: smb://$IP_ADDR/$USER"
echo "SMB URL: smb://$HOSTNAME.local/$USER"
echo ""
echo "You now have read/write access to your home directory."
echo "==========================================" 