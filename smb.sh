#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Update package list and install samba
apt-get update
apt-get install -y samba

# Backup the original smb.conf with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cp /etc/samba/smb.conf "/etc/samba/smb.conf.backup_${TIMESTAMP}"

# Get logged in user more reliably
if [ -n "$SUDO_USER" ]; then
    LOGGED_IN_USER="$SUDO_USER"
elif [ -n "$LOGNAME" ]; then
    LOGGED_IN_USER="$LOGNAME"
else
    echo "Error: Could not determine the logged-in user"
    exit 1
fi

echo "The user logged in is: $LOGGED_IN_USER"

# Ensure the [homes] section exists and modify it
if ! grep -q "^\[homes\]" /etc/samba/smb.conf; then
    echo "Error: [homes] section not found in smb.conf"
    exit 1
fi

# Add settings to [homes] section more reliably
sed -i '/\[homes\]/,/\[/ {
    /inherit permissions/! s/\[homes\]/[homes]\n   inherit permissions = yes/
    /writable/! s/\[homes\]/[homes]\n   writable = yes/
}' /etc/samba/smb.conf

# Verify smb.conf syntax
testparm -s || {
    echo "Error: Invalid smb.conf configuration"
    exit 1
}

# Enable and start Samba services
systemctl enable smbd nmbd
systemctl restart smbd nmbd || {
    echo "Error: Failed to restart Samba services"
    exit 1
}

# Set up Samba password for the logged-in user
echo "Setting up Samba password for $LOGGED_IN_USER"
smbpasswd -a "$LOGGED_IN_USER"

# Configure firewall if UFW is present
if command -v ufw >/dev/null 2>&1; then
    ufw allow samba
fi

# Get network information more reliably
IP_ADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

echo "Samba configuration completed successfully!"
echo "A backup of your original configuration has been saved to: /etc/samba/smb.conf.backup_${TIMESTAMP}"
echo "Connect using these URLs:"
echo "smb://$IP_ADDR/$LOGGED_IN_USER"
echo "smb://$HOSTNAME.local/$LOGGED_IN_USER"
echo ""
echo "Important: Make sure your user has proper Unix permissions on their home directory:"
echo "sudo chmod 755 /home/$LOGGED_IN_USER"