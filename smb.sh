#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verbose mode flag
VERBOSE=${VERBOSE:-false}

# Log function
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Progress indicator
progress() {
    echo -e "${GREEN}▶${NC} $1"
}

# 1. Root/sudo verification
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root or with sudo"
    echo "Please run: sudo $0"
    exit 1
fi

log_success "Running with root privileges"

# 7. User validation
USER=$(logname 2>/dev/null || echo $SUDO_USER)
if [ -z "$USER" ]; then
    log_error "Could not determine user. Please set USER environment variable."
    exit 1
fi

if ! id "$USER" &>/dev/null; then
    log_error "User '$USER' does not exist on this system"
    exit 1
fi

log_success "Validated user: $USER"

# 4. Raspberry Pi detection (optional, warns if not detected)
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model)
    if [[ "$MODEL" == *"Raspberry Pi"* ]]; then
        log_success "Detected: $MODEL"
    else
        log_warning "Not running on Raspberry Pi. Detected: $MODEL"
        log_warning "Script will continue but may not work as expected."
    fi
else
    log_warning "Could not detect device model. Assuming Raspberry Pi."
fi

# 12. Disk space check (need at least 100MB free)
REQUIRED_SPACE=102400  # 100MB in KB
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    log_error "Insufficient disk space. Need at least 100MB free."
    log_error "Available: $(($AVAILABLE_SPACE / 1024))MB, Required: $(($REQUIRED_SPACE / 1024))MB"
    exit 1
fi

log_success "Disk space check passed ($(($AVAILABLE_SPACE / 1024))MB available)"

progress "Setting up Samba for user: $USER"

# 3 & 15. Error handling and cleanup on failure
INSTALL_FAILED=false
BACKUP_FILE=""

cleanup_on_failure() {
    if [ "$INSTALL_FAILED" = true ]; then
        log_error "Installation failed. Performing cleanup..."

        # Restore backup if it exists
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
            log "Restoring backup configuration..."
            cp "$BACKUP_FILE" /etc/samba/smb.conf
        fi

        log_error "Cleanup complete. Please check the errors above."
        exit 1
    fi
}

trap cleanup_on_failure EXIT

# Update package list and install samba
progress "Installing Samba..."
log_verbose "Updating package list..."

if ! apt-get update; then
    log_error "Failed to update package list"
    INSTALL_FAILED=true
    exit 1
fi

log_verbose "Installing Samba package..."

if ! apt-get install -y samba; then
    log_error "Failed to install Samba"
    INSTALL_FAILED=true
    exit 1
fi

log_success "Samba installed successfully"

# 13. Backup management with timestamps
progress "Backing up Samba configuration..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/etc/samba/smb.conf.backup_${TIMESTAMP}"

if [ -f /etc/samba/smb.conf ]; then
    cp /etc/samba/smb.conf "$BACKUP_FILE"
    log_success "Configuration backed up to: $BACKUP_FILE"

    # Also create/update the .bak file for easy reference
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
else
    log_warning "No existing smb.conf found. Fresh installation."
fi

# 8. Idempotent configuration - Configure the [homes] share with read/write access
progress "Configuring Samba share for home directory..."

# Check if [homes] section already exists
if grep -q "^\[homes\]" /etc/samba/smb.conf; then
    log "Existing [homes] section found. Removing it for clean configuration..."
    # Remove existing [homes] section if present
    sed -i '/^\[homes\]/,/^\[/{ /^\[homes\]/!{ /^\[/!d; }; }' /etc/samba/smb.conf
    sed -i '/^\[homes\]/d' /etc/samba/smb.conf
fi

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

log_success "Samba configuration updated"

# 14. Configuration validation
progress "Validating Samba configuration..."
if ! testparm -s /etc/samba/smb.conf > /dev/null 2>&1; then
    log_error "Samba configuration validation failed!"
    log_error "Restoring previous configuration..."
    INSTALL_FAILED=true
    exit 1
fi

log_success "Configuration validated successfully"

# Set Samba password
progress "Setting Samba password for user: $USER"
if [ -n "$SMB_PASSWORD" ]; then
    # Non-interactive mode with password from environment variable
    log "Using password from SMB_PASSWORD environment variable..."
    if ! (echo "$SMB_PASSWORD"; echo "$SMB_PASSWORD") | smbpasswd -a $USER > /dev/null 2>&1; then
        log_error "Failed to set Samba password"
        INSTALL_FAILED=true
        exit 1
    fi
    log_success "Samba password set successfully"
else
    # Interactive mode - prompt for password
    log "Please enter a password for SMB access..."
    if ! smbpasswd -a $USER; then
        log_error "Failed to set Samba password"
        INSTALL_FAILED=true
        exit 1
    fi
    log_success "Samba password set successfully"
fi

# 2. Enable services to start on boot
progress "Enabling Samba services to start on boot..."
if ! systemctl enable smbd; then
    log_error "Failed to enable smbd service"
    INSTALL_FAILED=true
    exit 1
fi

if ! systemctl enable nmbd; then
    log_error "Failed to enable nmbd service"
    INSTALL_FAILED=true
    exit 1
fi

log_success "Samba services enabled for auto-start"

# Restart samba to apply changes
progress "Restarting Samba services..."
if ! systemctl restart smbd; then
    log_error "Failed to restart smbd service"
    INSTALL_FAILED=true
    exit 1
fi

if ! systemctl restart nmbd; then
    log_error "Failed to restart nmbd service"
    INSTALL_FAILED=true
    exit 1
fi

log_success "Samba services restarted"

# 6. Service verification
progress "Verifying Samba services are running..."
sleep 2  # Give services a moment to fully start

if ! systemctl is-active --quiet smbd; then
    log_error "smbd service is not running!"
    systemctl status smbd --no-pager
    INSTALL_FAILED=true
    exit 1
fi

if ! systemctl is-active --quiet nmbd; then
    log_error "nmbd service is not running!"
    systemctl status nmbd --no-pager
    INSTALL_FAILED=true
    exit 1
fi

log_success "All Samba services are running"

# 5. Firewall handling
progress "Checking firewall configuration..."
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | grep -i "status:" | awk '{print $2}')
    if [ "$UFW_STATUS" = "active" ]; then
        log "UFW firewall is active. Configuring rules for Samba..."

        # Allow Samba through firewall
        ufw allow samba > /dev/null 2>&1 || {
            log_warning "Failed to add samba rule. Trying individual ports..."
            ufw allow 139/tcp > /dev/null 2>&1
            ufw allow 445/tcp > /dev/null 2>&1
            ufw allow 137/udp > /dev/null 2>&1
            ufw allow 138/udp > /dev/null 2>&1
        }

        log_success "Firewall configured for Samba"
    else
        log_verbose "UFW firewall is not active"
    fi
else
    log_verbose "UFW not installed, skipping firewall configuration"
fi

# 9. Better network detection
progress "Detecting network configuration..."

# Try to get IP address with retries (network might not be fully up)
MAX_RETRIES=3
RETRY_COUNT=0
IP_ADDR=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ -z "$IP_ADDR" ]; do
    IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$IP_ADDR" ]; then
        log_verbose "Waiting for network... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

HOSTNAME=$(hostname 2>/dev/null || echo "unknown")

# Mark installation as successful
INSTALL_FAILED=false

# Print final summary
echo ""
echo "=========================================="
log_success "Samba installation complete!"
echo "=========================================="
echo ""
echo "  User: ${GREEN}$USER${NC}"
echo ""

if [ -n "$IP_ADDR" ]; then
    echo "  ${BLUE}Connection URLs:${NC}"
    echo "    • smb://$IP_ADDR/$USER"
    echo "    • smb://$HOSTNAME.local/$USER"
    echo ""
    echo "  ${BLUE}Windows:${NC} \\\\$IP_ADDR\\$USER"
else
    log_warning "Could not detect IP address"
    echo "  ${BLUE}Connection URL:${NC}"
    echo "    • smb://$HOSTNAME.local/$USER"
fi

echo ""
echo "  ${GREEN}✓${NC} Read/write access to home directory"
echo "  ${GREEN}✓${NC} Services enabled to start on boot"
echo "  ${GREEN}✓${NC} Configuration backed up to:"
echo "    $BACKUP_FILE"
echo ""
echo "=========================================="
echo ""

log_verbose "Installation log complete" 