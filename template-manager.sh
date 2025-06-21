#!/bin/bash

# Template Manager Script
# This script manages VM templates for various operating systems in Proxmox

# Default Configuration
CONFIG_FILE="config.conf"
TEMPLATES_FILE="os-templates.json"
IMAGE_DIR="images"
WORK_DIR="work"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
elif [ -f "config.conf.example" ]; then
    echo "No $CONFIG_FILE found. You can copy config.conf.example to $CONFIG_FILE and modify it."
fi

# Default Proxmox Configuration (can be overridden in config.conf)
: ${SSH_KEYFILE:="/root/.ssh/authorized_keys"}  # Path to SSH authorized keys
: ${USERNAME:="root"}                           # Default template user
: ${PASSWORD:="password"}                       # Default template password
: ${STORAGE:="local"}                          # Storage location for templates
: ${NETWORK:="vmbr1"}                          # Network bridge
: ${CPU:=1}                                    # Number of CPU cores
: ${MEMORY:=512}                               # Memory in MB
: ${BASE_VMID:=4001}                          # Starting VMID for templates
: ${TIMEZONE:="Asia/Jakarta"}                  # Default timezone
: ${NAMESERVER:="1.1.1.1 8.8.8.8 2606:4700:4700::1001"}  # DNS servers

# Required commands
REQUIRED_COMMANDS="jq wget virt-customize"

# Function to check required commands
check_requirements() {
    local missing_commands=()
    local missing_packages=()
    
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
            case "$cmd" in
                "jq")
                    missing_packages+=("jq")
                    ;;
                "wget")
                    missing_packages+=("wget")
                    ;;
                "virt-customize")
                    missing_packages+=("libguestfs-tools")
                    ;;
            esac
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        echo "Error: Required commands are missing: ${missing_commands[*]}"
        echo "Please install the following packages:"
        printf '%s\n' "${missing_packages[@]}"
        exit 1
    fi
}

# Function to ensure we're in the script's directory
ensure_script_dir() {
    # Get the directory where the script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$script_dir"
    
    # Create necessary directories
    mkdir -p "$IMAGE_DIR" "$WORK_DIR"
}

# Function to list available templates
list_templates() {
    echo "Available Templates"
    echo "=================="
    echo
    
    # Function to print a separator line
    print_separator() {
        printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    }
    
    # Function to print OS family header
    print_os_header() {
        local os=$1
        echo "${os^} Templates:"
        print_separator
        printf "%-15s %-25s %s\n" "VERSION" "NAME" "TEMPLATE ID"
        print_separator
    }
    
    # Process each OS family
    for os in $(jq -r 'keys[]' "$TEMPLATES_FILE" | sort); do
        echo
        print_os_header "$os"
        
        # Get and sort versions for this OS
        versions=$(jq -r --arg os "$os" '.[$os] | keys[]' "$TEMPLATES_FILE" | sort -V)
        
        # Print each version's details
        while IFS= read -r version; do
            name=$(jq -r --arg os "$os" --arg ver "$version" '.[$os][$ver].name' "$TEMPLATES_FILE")
            template=$(jq -r --arg os "$os" --arg ver "$version" '.[$os][$ver].template_name' "$TEMPLATES_FILE")
            printf "%-15s %-25s %s\n" "$version" "$name" "$template"
        done <<< "$versions"
    done
    echo
}

# Function to download a specific template
download_template() {
    local os_type=$1
    local version=$2
    
    # Get template information
    local template_info=$(jq -r --arg os "$os_type" --arg ver "$version" '.[$os][$ver]' "$TEMPLATES_FILE")
    
    if [ "$template_info" = "null" ]; then
        echo "Error: Template not found for $os_type version $version"
        return 1
    fi
    
    local url=$(echo "$template_info" | jq -r '.url')
    local filename=$(echo "$template_info" | jq -r '.filename')
    local name=$(echo "$template_info" | jq -r '.name')
    
    echo "Downloading $name..."
    echo "URL: $url"
    echo "Filename: $filename"
    
    if [ -f "$IMAGE_DIR/$filename" ]; then
        echo "Image already exists. Skipping download."
        return 0
    fi
    
    wget "$url" -O "$IMAGE_DIR/$filename"
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $filename"
    else
        echo "Failed to download $filename"
        rm -f "$IMAGE_DIR/$filename"
        return 1
    fi
}

# Function to customize image
customize_image() {
    local file_name=$1
    local os_type=$2

    echo "Customizing image for $os_type"

    case $os_type in
        "debian"|"ubuntu")
            virt-customize -a "$file_name" --install qemu-guest-agent,vim,wget
            virt-customize -a "$file_name" --run-command "systemctl enable qemu-guest-agent"
            virt-customize -a "$file_name" --timezone "$TIMEZONE"
            virt-customize -a "$file_name" --run-command "mv /etc/ssh/sshd_config.d/60-cloudimg-settings.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf.disable"
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command 'sed -i "/^#PasswordAuthentication[[:space:]]/cPasswordAuthentication yes" /etc/ssh/sshd_config && sed -i "/^PasswordAuthentication no/cPasswordAuthentication yes" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "centos"|"rocky"|"alma")
            virt-customize -a "$file_name" --install vim,wget
            virt-customize -a "$file_name" --selinux-relabel --timezone $TIMEZONE
            virt-customize -a "$file_name" --run-command "mkdir -p /etc/ssh/sshd_config.d/ && touch /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "centos8")
            virt-customize -a "$file_name" --run-command "sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*"
            virt-customize -a "$file_name" --run-command "sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*"
            virt-customize -a "$file_name" --install vim,wget
            virt-customize -a "$file_name" --selinux-relabel --timezone $TIMEZONE
            virt-customize -a "$file_name" --run-command "mkdir -p /etc/ssh/sshd_config.d/ && touch /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command 'sed -i "1iInclude /etc/ssh/sshd_config.d/*.conf" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "rocky8"|"alma8")
            virt-customize -a "$file_name" --install vim,wget
            virt-customize -a "$file_name" --selinux-relabel --timezone $TIMEZONE
            virt-customize -a "$file_name" --run-command "mkdir -p /etc/ssh/sshd_config.d/ && touch /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command 'sed -i "1iInclude /etc/ssh/sshd_config.d/*.conf" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "freebsd")
            echo "FreeBSD. Skipping customization."
            ;;
        *)
            echo "Unknown OS type: $os_type. Skipping customization."
            ;;
    esac
}

# Function to find next available VMID
find_next_available_vmid() {
    local start_id=$1
    local current_id=$start_id
    
    while qm status $current_id &>/dev/null; do
        ((current_id++))
    done
    
    echo $current_id
}

# Function to ensure image exists
ensure_image_exists() {
    local os_type=$1
    local version=$2
    
    # Get template information
    local template_info=$(jq -r --arg os "$os_type" --arg ver "$version" '.[$os][$ver]' "$TEMPLATES_FILE")
    
    if [ "$template_info" = "null" ]; then
        echo "Error: Template not found for $os_type version $version"
        return 1
    fi
    
    local filename=$(echo "$template_info" | jq -r '.filename')
    
    if [ ! -f "$IMAGE_DIR/$filename" ]; then
        echo "Image not found. Downloading first..."
        download_template "$os_type" "$version"
        if [ $? -ne 0 ]; then
            echo "Failed to download required image."
            return 1
        fi
    fi
    
    return 0
}

# Function to download all templates
download_all() {
    local failed=()
    local total=0
    local success=0
    
    echo "Downloading all templates..."
    echo
    
    # Process each OS and version
    while IFS=$'\t' read -r os version; do
        ((total++))
        echo "Downloading $os $version..."
        if download_template "$os" "$version"; then
            ((success++))
            echo "✓ Successfully downloaded $os $version"
        else
            failed+=("$os $version")
            echo "✗ Failed to download $os $version"
        fi
        echo
    done < <(jq -r 'to_entries[] | .key as $os | .value | to_entries[] | .key as $ver | [$os, $ver] | @tsv' "$TEMPLATES_FILE")
    
    echo "Download Summary:"
    echo "----------------"
    echo "Total templates: $total"
    echo "Successfully downloaded: $success"
    echo "Failed: ${#failed[@]}"
    
    if [ ${#failed[@]} -gt 0 ]; then
        echo
        echo "Failed templates:"
        printf '%s\n' "${failed[@]}"
        return 1
    fi
    
    return 0
}

# Function to create all templates
create_all() {
    local failed=()
    local total=0
    local success=0
    
    echo "Creating all templates..."
    echo
    
    # Process each OS and version
    while IFS=$'\t' read -r os version; do
        ((total++))
        echo "Creating template for $os $version..."
        if create_template "$os" "$version"; then
            ((success++))
            echo "✓ Successfully created template for $os $version"
        else
            failed+=("$os $version")
            echo "✗ Failed to create template for $os $version"
        fi
        echo
    done < <(jq -r 'to_entries[] | .key as $os | .value | to_entries[] | .key as $ver | [$os, $ver] | @tsv' "$TEMPLATES_FILE")
    
    echo "Creation Summary:"
    echo "----------------"
    echo "Total templates: $total"
    echo "Successfully created: $success"
    echo "Failed: ${#failed[@]}"
    
    if [ ${#failed[@]} -gt 0 ]; then
        echo
        echo "Failed templates:"
        printf '%s\n' "${failed[@]}"
        return 1
    fi
    
    return 0
}

# Function to create template
create_template() {
    local os_type=$1
    local version=$2
    
    # Ensure image exists
    ensure_image_exists "$os_type" "$version" || return 1
    
    # Get template information
    local template_info=$(jq -r --arg os "$os_type" --arg ver "$version" '.[$os][$ver]' "$TEMPLATES_FILE")
    
    if [ "$template_info" = "null" ]; then
        echo "Error: Template not found for $os_type version $version"
        return 1
    fi
    
    local template_name=$(echo "$template_info" | jq -r '.template_name')
    local filename=$(echo "$template_info" | jq -r '.filename')
    local os_type_internal=$(echo "$template_info" | jq -r '.os_type')
    
    # Find next available VMID
    local vmid=$(find_next_available_vmid $BASE_VMID)
    echo "Using VM ID: $vmid"
    
    # Copy image to work directory
    cp "$IMAGE_DIR/$filename" "$WORK_DIR/"
    cd "$WORK_DIR"
    
    # Customize and create template
    customize_image "$filename" "$os_type_internal"
    
    # Create new VM with basic configuration
    qm create $vmid --name $template_name --ostype l26 
    qm set $vmid --net0 virtio,bridge=${NETWORK}
    qm set $vmid --serial0 socket
    qm set $vmid --memory ${MEMORY} --cores ${CPU} --cpu host
    qm set $vmid --scsi0 ${STORAGE}:0,import-from="$(pwd)/$filename",discard=on,format=qcow2
    qm set $vmid --boot order=scsi0 --scsihw virtio-scsi-single
    qm set $vmid --agent enabled=1,fstrim_cloned_disks=1
    qm set $vmid --ide2 ${STORAGE}:cloudinit
    qm set $vmid --ipconfig0 "ip6=auto,ip=dhcp"
    qm set $vmid --sshkeys "${SSH_KEYFILE}"
    qm set $vmid --cipassword "${PASSWORD}"
    qm set $vmid --ciuser "${USERNAME}"
    qm set $vmid --nameserver "${NAMESERVER}"
    
    # Attempt to resize the disk
    qm disk resize $vmid scsi0 15G || echo "Disk already larger than 15G or resize failed"
    
    # Convert to template
    qm template $vmid
    
    echo "Template $template_name created successfully with VMID $vmid"
    
    # Cleanup
    cd ..
    rm -f "$WORK_DIR/$filename"
    
    return 0
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND [ARGS...]

Commands:
    list                            List all available templates
    download OS VERSION             Download a specific template
    download-all                    Download all available templates
    create OS VERSION              Create a template
    create-all                     Create templates for all downloaded images
    help                           Show this help message

Options:
    --config FILE                  Use alternative config file (default: config.conf)
    --templates FILE              Use alternative templates file (default: os-templates.json)

Examples:
    $0 list
    $0 download debian 12
    $0 download-all
    $0 create ubuntu 22.04
    $0 create-all

Directory Structure:
    ./images/   - Stores downloaded OS images
    ./work/     - Temporary working directory for template creation
    
Configuration Files:
    config.conf       - Main configuration file (optional)
    config.conf.example - Example configuration file with documentation
    os-templates.json  - Template definitions

Configuration Options (can be set in config.conf):
    SSH_KEYFILE  - Path to SSH authorized keys (default: /root/.ssh/authorized_keys)
    USERNAME     - Default template user (default: root)
    PASSWORD     - Default template password (default: password)
    STORAGE      - Storage location for templates (default: local)
    NETWORK      - Network bridge (default: vmbr1)
    CPU          - Number of CPU cores (default: 1)
    MEMORY       - Memory in MB (default: 512)
    BASE_VMID    - Starting VMID for templates (default: 4001)
    TIMEZONE     - Default timezone (default: Asia/Jakarta)
    NAMESERVER   - DNS servers (default: 1.1.1.1 8.8.8.8 2606:4700:4700::1001)

For detailed configuration options, copy config.conf.example to config.conf and modify as needed.

EOF
}

# Main script logic
main() {
    # Check requirements first
    check_requirements
    
    # Ensure we're in the script directory and setup folders
    ensure_script_dir
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --templates)
                TEMPLATES_FILE="$2"
                shift 2
                ;;
            list)
                list_templates
                exit 0
                ;;
            download)
                if [ $# -lt 3 ]; then
                    echo "Error: download command requires OS and VERSION arguments"
                    show_help
                    exit 1
                fi
                download_template "$2" "$3"
                exit $?
                ;;
            download-all)
                download_all
                exit $?
                ;;
            create)
                if [ $# -lt 3 ]; then
                    echo "Error: create command requires OS and VERSION arguments"
                    show_help
                    exit 1
                fi
                create_template "$2" "$3"
                exit $?
                ;;
            create-all)
                create_all
                exit $?
                ;;
            help|--help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown command or option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # If no command provided, show help
    show_help
}

# Run main function with all arguments
main "$@" 
