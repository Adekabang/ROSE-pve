#!/bin/bash

# VM Template Creation Script
# This script creates VM templates for various operating systems in Proxmox

# Configuration
ssh_keyfile="/root/.ssh/authorized_keys"
username="root"
password="password"
storage="local"
network="vmbr1"
cpu=1
memory=512
base_vmid=4001
timezone="Asia/Jakarta"
nameserver="10.0.1.1 1.1.1.1 8.8.8.8 2606:4700:4700::1001"

# Function to customize image
customize_image() {
    local file_name=$1
    local os_type=$2

    echo "Customizing image for $os_type"

    # Temporary copy from original
    cp ~/os-images/$file_name ~/ROSE-pve 

    case $os_type in
        "debian"|"ubuntu")
            virt-customize -a "$file_name" --install qemu-guest-agent,vim,wget
            virt-customize -a "$file_name" --run-command "systemctl enable qemu-guest-agent"
            virt-customize -a "$file_name" --timezone "$timezone"
            virt-customize -a "$file_name" --run-command "mv /etc/ssh/sshd_config.d/60-cloudimg-settings.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf.disable"
            ### Enable SSH access
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            ### Allow PasswordAuthentication
            virt-customize -a "$file_name" --run-command 'sed -i "/^#PasswordAuthentication[[:space:]]/cPasswordAuthentication yes" /etc/ssh/sshd_config && sed -i "/^PasswordAuthentication no/cPasswordAuthentication yes" /etc/ssh/sshd_config'
            ### Enable root SSH login
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "centos"|"rocky"|"alma")
            virt-customize -a "$file_name" --install vim,wget
            virt-customize -a "$file_name" --selinux-relabel --timezone $timezone
            virt-customize -a "$file_name" --run-command "mkdir -p /etc/ssh/sshd_config.d/ && touch /etc/ssh/sshd_config.d/01-allow-password-auth.conf "
            ### Enable SSH access
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            ### Allow PasswordAuthentication
            virt-customize -a "$file_name" --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            ### Enable root SSH login
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "centos8")
            ### Fix yum repository
            virt-customize -a "$file_name" --run-command "sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*"
            virt-customize -a "$file_name" --run-command "sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*"
            virt-customize -a "$file_name" --install vim,wget
            virt-customize -a "$file_name" --selinux-relabel --timezone $timezone
            virt-customize -a "$file_name" --run-command "mkdir -p /etc/ssh/sshd_config.d/ && touch /etc/ssh/sshd_config.d/01-allow-password-auth.conf "
            ### Enable SSH access
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            ### Allow PasswordAuthentication
            virt-customize -a "$file_name" --run-command 'sed -i "1iInclude /etc/ssh/sshd_config.d/*.conf" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            ### Enable root SSH login
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "rocky8"|"alma8")
            virt-customize -a "$file_name" --install vim,wget
            virt-customize -a "$file_name" --selinux-relabel --timezone $timezone
            virt-customize -a "$file_name" --run-command "mkdir -p /etc/ssh/sshd_config.d/ && touch /etc/ssh/sshd_config.d/01-allow-password-auth.conf "
            ### Enable SSH access
            virt-customize -a "$file_name" --run-command 'sed -i -e "s/^#Port 22/Port 22/" -e "s/^#AddressFamily any/AddressFamily any/" -e "s/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" -e "s/^#ListenAddress ::/ListenAddress ::/" /etc/ssh/sshd_config'
            ### Allow PasswordAuthentication
            virt-customize -a "$file_name" --run-command 'sed -i "1iInclude /etc/ssh/sshd_config.d/*.conf" /etc/ssh/sshd_config'
            virt-customize -a "$file_name" --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/01-allow-password-auth.conf"
            ### Enable root SSH login
            virt-customize -a "$file_name" --run-command 'sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
            ;;
        "freebsd")
            # FreeBSD uses a different package manager and might have different paths
            echo "FreeBSD. Skipping customization."
            ;;
        *)
            echo "Unknown OS type: $os_type. Skipping customization."
            ;;
    esac
}

# Function to create a template
create_template() {
    local vm_id=$1
    local vm_name=$2
    local file_name=$3
    local os_type=$4

    echo "Creating template $vm_name ($vm_id)"

    # Customize the image before creating the VM
    customize_image "$file_name" "$os_type"

    # Create new VM with basic configuration
    qm create $vm_id --name $vm_name --ostype l26 
    qm set $vm_id --net0 virtio,bridge=${network}
    qm set $vm_id --serial0 socket # --vga serial0
    qm set $vm_id --memory ${memory} --cores ${cpu} --cpu host
    qm set $vm_id --scsi0 ${storage}:0,import-from="$(pwd)/$file_name",discard=on,format=qcow2
    qm set $vm_id --boot order=scsi0 --scsihw virtio-scsi-single
    qm set $vm_id --agent enabled=1,fstrim_cloned_disks=1
    qm set $vm_id --ide2 ${storage}:cloudinit
    qm set $vm_id --ipconfig0 "ip6=auto,ip=dhcp"
    qm set $vm_id --sshkeys ${ssh_keyfile}
    qm set $vm_id --cipassword ${password}
    qm set $vm_id --ciuser ${username}
    qm set $vm_id --nameserver "${nameserver}"

    # Attempt to resize the disk to 15G
    qm disk resize $vm_id scsi0 15G || echo "Disk already larger than 15G or resize failed"

    # Convert to template
    qm template $vm_id

    echo "Template $vm_name created successfully"
    echo "------------------------------------"
}

find_next_available_vmid() {
    local start_id=$1
    local current_id=$start_id
    
    while qm status $current_id &>/dev/null; do
        ((current_id++))
    done
    
    echo $current_id
}

# Define OS templates
# Format: OS_Name, Template_Name, Image_URL, File_Name, OS_Type
declare -A os_templates=(
    ["Debian 10"]="temp-debian-10|https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2|debian-10-genericcloud-amd64.qcow2|debian"
    ["Debian 11"]="temp-debian-11|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2|debian-11-genericcloud-amd64.qcow2|debian"
    ["Debian 12"]="temp-debian-12|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2|debian-12-genericcloud-amd64.qcow2|debian"
    ["Ubuntu 20.04"]="temp-ubuntu-20-04|https://cloud-images.ubuntu.com/releases/20.04/release/ubuntu-20.04-server-cloudimg-amd64.img|ubuntu-20.04-server-cloudimg-amd64.img|ubuntu"
    ["Ubuntu 22.04"]="temp-ubuntu-22-04|https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img|ubuntu-22.04-server-cloudimg-amd64.img|ubuntu"
    ["Ubuntu 24.04"]="temp-ubuntu-24-04|https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img|ubuntu-24.04-server-cloudimg-amd64.img|ubuntu"
    ["CentOS Stream 8"]="temp-centos-8-stream|https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2|CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2|centos8"
    ["CentOS Stream 9"]="temp-centos-9-stream|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos"
    ["CentOS Stream 10"]="temp-centos-10-stream|https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2|CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2|centos"
    ["Rocky Linux 8"]="temp-rocky-linux-8-generic|https://mirror.nevacloud.com/rockylinux/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|rocky8"
    ["Rocky Linux 9"]="temp-rocky-linux-9-generic|https://mirror.nevacloud.com/rockylinux/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|rocky"
    ["Rocky Linux 10"]="temp-rocky-linux-10-generic|https://mirror.nevacloud.com/rockylinux/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2|Rocky-10-GenericCloud-Base.latest.x86_64.qcow2|rocky"
    ["AlmaLinux 8"]="temp-almalinux-8-generic|https://mirror.nevacloud.com/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|alma8"
    ["AlmaLinux 9"]="temp-almalinux-9-generic|https://mirror.nevacloud.com/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma"
    ["AlmaLinux 10"]="temp-almalinux-10-generic|https://mirror.nevacloud.com/almalinux/10/cloud/x86_64/images/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2|AlmaLinux-10-GenericCloud-latest.x86_64.qcow2|alma"
    ["FreeBSD 13.4 UFS"]="temp-freebsd-13-4-ufs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/13.4/2024-10-28/ufs/freebsd-13.4-ufs-2024-10-28.qcow2|freebsd-13.4-ufs-2024-10-28.qcow2|freebsd"
    ["FreeBSD 13.4 ZFS"]="temp-freebsd-13-4-zfs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/13.4/2024-10-28/zfs/freebsd-13.4-zfs-2024-10-28.qcow2|freebsd-13.4-zfs-2024-10-28.qcow2|freebsd"
    ["FreeBSD 14.2 UFS"]="temp-freebsd-14-2-ufs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/14.2/2024-12-08/ufs/freebsd-14.2-ufs-2024-12-08.qcow2|freebsd-14.2-ufs-2024-12-08.qcow2|freebsd"
    ["FreeBSD 14.2 ZFS"]="temp-freebsd-14-2-zfs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/14.2/2024-12-08/zfs/freebsd-14.2-zfs-2024-12-08.qcow2|freebsd-14.2-zfs-2024-12-08.qcow2|freebsd"
    # ["Windows Server 2019 Standard"]="temp-windows-server-2019-standard|https://os-cdn.virtfusion.net/windows/windows-server-2019-standard-virtfusion.qcow2|windows-server-2019-standard-virtfusion.qcow2|windows"
    # ["Windows Server 2022 Standard"]="temp-windows-server-2022-standard|https://os-cdn.virtfusion.net/windows/windows-server-2022-standard-virtfusion.qcow2|windows-server-2022-standard-virtfusion.qcow2|windows"
    # ["Windows Server 2025 Standard"]="temp-windows-server-2025-standard|https://os-cdn.virtfusion.net/windows/windows-server-2025-standard-virtfusion.qcow2|windows-server-2025-standard-virtfusion.qcow2|windows"
)

# Main loop to create templates
vmid=$base_vmid
for os_name in "${!os_templates[@]}"; do
    IFS='|' read -r template_name image_url file_name os_type <<< "${os_templates[$os_name]}"
    
    echo "Processing $os_name"
    
    # Find the next available VM ID
    vmid=$(find_next_available_vmid $vmid)
    echo "Using VM ID: $vmid"
    
    # Download image if not present
    if [[ ! -f "$file_name" ]]; then
        echo "Downloading $file_name"
        wget "$image_url" -O "$file_name"
    fi
    
    # Create template
    create_template $vmid "$template_name" "$file_name" "$os_type"
    
    ((vmid++))
done

echo "All templates created successfully!"
