# smbpi
Automated SMB/Samba installation for Raspberry Pi

Automatically installs and configures Samba with read/write access to your home directory.

## Quick Install (One-Liner)

For **headless SSH setup**, run this single command:

```bash
curl -fsSL https://raw.githubusercontent.com/cyberralf83/smbpi/main/smb.sh | sudo bash
```

This will:
- Install Samba
- Configure read/write access to your home folder
- Prompt you to set a password

## Fully Automated Install (Non-Interactive)

For **completely headless** setup without any prompts:

```bash
export SMB_PASSWORD="your_secure_password"
curl -fsSL https://raw.githubusercontent.com/cyberralf83/smbpi/main/smb.sh | sudo -E bash
```

Replace `your_secure_password` with your desired SMB password.

## Manual Install

If you prefer to clone the repository first:

```bash
git clone https://github.com/cyberralf83/smbpi
cd smbpi
chmod +x smb.sh
sudo ./smb.sh
```

Or for non-interactive mode:

```bash
git clone https://github.com/cyberralf83/smbpi
cd smbpi
chmod +x smb.sh
export SMB_PASSWORD="your_secure_password"
sudo -E ./smb.sh
```

## After Installation

Connect to your Raspberry Pi share using:
- Windows: `\\<pi-ip-address>\<username>` or `\\<hostname>.local\<username>`
- Mac/Linux: `smb://<pi-ip-address>/<username>` or `smb://<hostname>.local/<username>`

Use your Raspberry Pi username and the SMB password you set during installation.
