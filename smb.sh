sudo bash -c 'cat > /tmp/install_smb.sh << "EOL"
#!/bin/bash

# Exit on any error
set -e

# Update package list
apt-get update

# Install Samba 
apt-get install -y samba samba-common-bin

# Backup original config
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

LOGGED_IN_USER=$(logname)

echo "The user logged in is: $LOGGED_IN_USER"


sed -i '/\[homes\]/,/\[/ s/^[[:space:]]*read only[[:space:]]*=[[:space:]]*yes/\tread only = no/' /etc/samba/smb.conf
sed -i '/\[homes\]/a\   valid users = %S\n   inherit permissions = yes' /etc/samba/smb.conf


systemctl restart smbd
systemctl restart nmbd

USER=$(logname)
sudo smbpasswd -a $USER

systemctl restart smbd
systemctl restart nmbd

# Enable Samba services to start on boot
systemctl enable smbd
systemctl enable nmbd

# Configure firewall if UFW is installed
if command -v ufw >/dev/null 2>&1; then
    ufw allow Samba
fi

echo "Samba installation complete!"
echo "Users can now connect using their system username and password"
IP_ADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname | awk '{print}')
USERNAME=$(logname)
echo "Samba is now configured. Connect using your current username and password."
echo "Your SMB URL is: smb://$IP_ADDR/$USERNAME"
echo "Your SMB URL is: smb://$HOSTNAME.local/$USERNAME"
EOL
chmod +x /tmp/install_smb.sh && /tmp/install_smb.sh && rm /tmp/install_smb.sh'