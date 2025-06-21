# ROSE-pve: Proxmox VE Enhancement Tools

A collection of tools for Proxmox VE administration, featuring a powerful template manager and customization utilities.

## Features

### Template Manager
- Download and create VM templates from cloud images
- Support for multiple operating systems:
  - Debian (10 Buster, 11 Bullseye, 12 Bookworm)
  - Ubuntu (20.04 Focal Fossa, 22.04 Jammy Jellyfish, 24.04 Noble Numbat)
  - CentOS Stream (8, 9, 10)
  - Rocky Linux (8 Green Obsidian, 9 Blue Onyx, 10)
  - AlmaLinux (8, 9, 10)
  - FreeBSD (13.4, 14.2 with UFS/ZFS options)
  - Windows Server (2019, 2022, 2025) Standard editions
- Cloud-init/Cloudbase-Init support for all templates
- Group operations (download/create all templates for an OS)
- Indonesian mirror support for faster downloads
- Customizable configuration
- Detailed progress tracking and error reporting

### Customization Tools
- Proxmox theme customization
- Subscription message removal
- Repository configuration for no-subscription usage
- Storage management utilities

## Pre-Installation Requirements

1. Update system and install required packages:
```bash
apt update -y
apt install git vim libguestfs-tools jq wget sudo -y
```

2. Clone the repository:
```bash
git clone https://github.com/Adekabang/ROSE-pve.git
cd ROSE-pve
```

## Template Manager Usage

### Basic Setup

1. Make the script executable:
```bash
chmod +x template-manager.sh
```

2. Configure your settings (optional):
```bash
cp config.conf.example config.conf
vim config.conf
```

### Available Commands

```bash
# List all available templates
./template-manager.sh list

# List templates for a specific OS
./template-manager.sh list debian

# Show available OS groups
./template-manager.sh groups

# Download a specific template
./template-manager.sh download debian 12

# Create a template
./template-manager.sh create ubuntu 22.04

# Download all templates for an OS
./template-manager.sh download-group debian

# Create all templates for an OS
./template-manager.sh create-group ubuntu

# Use Indonesian mirrors
./template-manager.sh --templates os-templates-id.json download debian 12
```

### Background Operations

Run template operations in the background and save logs:

```bash
# Download templates in background
nohup ./template-manager.sh download-all &>download.log &

# Create templates in background
nohup ./template-manager.sh create-all &>template.log &

# Download specific OS group in background
nohup ./template-manager.sh download-group debian &>debian-download.log &

# Create specific OS group in background
nohup ./template-manager.sh create-group ubuntu &>ubuntu-template.log &

# Check progress
tail -f download.log    # Monitor download progress
tail -f template.log    # Monitor template creation progress
```

You can check the process status using:
```bash
jobs            # List background jobs
ps aux | grep template-manager.sh    # Find running template manager processes
```

### Configuration Options

Edit `config.conf` to customize your template settings:

```bash
# SSH and Authentication
SSH_KEYFILE="/root/.ssh/authorized_keys"  # Path to SSH authorized keys
USERNAME="root"                           # Default template user
PASSWORD="password"                       # Default template password

# Proxmox Settings
STORAGE="local"                          # Storage location for templates
NETWORK="vmbr1"                          # Network bridge
CPU=1                                    # Number of CPU cores
MEMORY=512                               # Memory in MB
BASE_VMID=4001                          # Starting VMID for templates

# System Settings
TIMEZONE="Asia/Jakarta"                  # Default timezone
NAMESERVER="1.1.1.1 8.8.8.8"            # DNS servers
```

## Theme Customization

Apply custom themes to your Proxmox interface:
```bash
cd theme-xxx
./changelogo.sh
```

## System Administration

### Remove Subscription Message and Update Repository
For Debian 11 & 12 based PVE:
```bash
./no-subs-repo.sh
./remove-subs-message.sh
```

### Storage Management

To remove local-lvm and expand local storage:

1. Remove local-lvm from the Datacenter storage configuration
2. Execute:
```bash
lvremove /dev/pve/data
lvresize -l +100%FREE /dev/pve/root
resize2fs /dev/mapper/pve-root
```

### User Management

#### Adding PAM Users

1. Create OS user:
```bash
adduser --shell /bin/bash <user>
usermod -aG sudo <user>
# Optional: Configure passwordless sudo
echo "<user> ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
```

2. Add user to Proxmox:
```bash
pveum user add <user>@pam
pveum user list
```

3. Set permissions:
```bash
pveum acl modify <PATH> --roles PVEAdmin --users <user>@pam
```

Available Roles:
- Administrator
- PVEAdmin
- PVEVMAdmin
- PVEVMUser
- PVEUserAdmin
- PVEDatastoreAdmin
- PVEDatastoreUser
- PVESysAdmin
- PVEPoolAdmin
- PVETemplateUser
- PVEAuditor
- NoAccess (to forbid access)

## Directory Structure

```
.
├── template-manager.sh      # Template management script
├── os-templates.json        # Global mirror templates
├── os-templates-id.json     # Indonesian mirror templates
├── config.conf.example      # Example configuration
├── config.conf             # Your custom configuration (optional)
├── images/                 # Downloaded images directory
├── work/                   # Temporary working directory
├── theme-xxx/              # Theme customization files
└── scripts/                # Administration utilities
```

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

### Template Management

List and manage existing templates in your Proxmox system:

```bash
# List all existing templates in Proxmox
./template-manager.sh list-existing

# Remove a specific template (will prompt for confirmation)
./template-manager.sh remove 4001

# Remove multiple templates at once
./template-manager.sh remove-multiple 4001 4002 4003
```

The `list-existing` command shows:
- Template VMID
- Template Name
- Memory allocation
- CPU cores

When removing templates:
- Confirmation is required for safety
- Templates are verified before removal
- Summary of successful/failed removals is provided
- Only actual templates can be removed (VMs are protected)

### Background Operations
