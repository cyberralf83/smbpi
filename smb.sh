sudo bash -c 'cat > /tmp/install_smb.sh << "EOL"
#!/bin/bash

# Exit on any error
set -e

# Update package list
apt-get update

# Install Samba and required packages including PAM authentication
apt-get install -y samba samba-common-bin libpam-winbind

# Backup original config
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Create new Samba configuration
cat > /etc/samba/smb.conf << "EOF"
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = never
   dns proxy = no
   
   # Enable PAM authentication
   pam password change = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   
   # Use system users and passwords
   passdb backend = tdbsam
   obey pam restrictions = yes
   
   # Logging configuration
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   
   # Protocol configurations
   server min protocol = SMB2
   server max protocol = SMB3
   
   # Performance tuning
   socket options = TCP_NODELAY IPTOS_LOWDELAY
   read raw = yes
   write raw = yes
   
[homes]
   comment = Home Directories
   browseable = no
   read only = no
   create mask = 0666
   force create mode = 0666
   directory mask = 0777
   force directory mode = 0777
   valid users = %S
   inherit permissions = yes
EOF

# Restart Samba services
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
echo "Your SMB URL is: smb://$HOSTNAME.local"
echo "Your SMB URL is: smb://$IP_ADDR"
EOL
chmod +x /tmp/install_smb.sh && /tmp/install_smb.sh && rm /tmp/install_smb.sh'