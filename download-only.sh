#!/bin/bash

# Set the directory for storing OS images
IMAGE_DIR="~/os-images"

# Create the directory if it doesn't exist
mkdir -p "$IMAGE_DIR"

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
    ["Rocky Linux 8"]="temp-rocky-linux-8-generic|https://mirror.nevacloud.com/rockylinux/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|rocky8"
    ["Rocky Linux 9"]="temp-rocky-linux-9-generic|https://mirror.nevacloud.com/rockylinux/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|rocky"
    ["AlmaLinux 8"]="temp-almalinux-8-generic|https://mirror.nevacloud.com/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|alma8"
    ["AlmaLinux 9"]="temp-almalinux-9-generic|https://mirror.nevacloud.com/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma"
    # ["FreeBSD 13.3 UFS"]="temp-freebsd-13-3-ufs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/13.3/2024-05-06/ufs/freebsd-13.3-ufs-2024-05-06.qcow2|freebsd-13.3-ufs-2024-05-06.qcow2|freebsd"
    # ["FreeBSD 13.3 ZFS"]="temp-freebsd-13-3-zfs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/13.3/2024-05-06/zfs/freebsd-13.3-zfs-2024-05-06.qcow2|freebsd-13.3-zfs-2024-05-06.qcow2|freebsd"
    # ["FreeBSD 14.0 UFS"]="temp-freebsd-14-0-ufs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/14.0/2024-05-04/ufs/freebsd-14.0-ufs-2024-05-04.qcow2|freebsd-14.0-ufs-2024-05-04.qcow2|freebsd"
    # ["FreeBSD 14.0 ZFS"]="temp-freebsd-14-0-zfs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/14.0/2024-05-06/zfs/freebsd-14.0-zfs-2024-05-06.qcow2|freebsd-14.0-zfs-2024-05-06.qcow2|freebsd"
    ["FreeBSD 13.4 UFS"]="temp-freebsd-13-4-ufs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/13.4/2024-10-28/ufs/freebsd-13.4-ufs-2024-10-28.qcow2|freebsd-13.4-ufs-2024-10-28.qcow2|freebsd"
    ["FreeBSD 13.4 ZFS"]="temp-freebsd-13-4-zfs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/13.4/2024-10-28/zfs/freebsd-13.4-zfs-2024-10-28.qcow2|freebsd-13.4-zfs-2024-10-28.qcow2|freebsd"
    ["FreeBSD 14.2 UFS"]="temp-freebsd-14-2-ufs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/14.2/2024-12-08/ufs/freebsd-14.2-ufs-2024-12-08.qcow2|freebsd-14.2-ufs-2024-12-08.qcow2|freebsd"
    ["FreeBSD 14.2 ZFS"]="temp-freebsd-14-2-zfs|https://object-storage.public.mtl1.vexxhost.net/swift/v1/1dbafeefbd4f4c80864414a441e72dd2/bsd-cloud-image.org/images/freebsd/14.2/2024-12-08/zfs/freebsd-14.2-zfs-2024-12-08.qcow2|freebsd-14.2-zfs-2024-12-08.qcow2|freebsd"
)

# Function to download images
download_images() {
    for os_name in "${!os_templates[@]}"; do
        IFS='|' read -r _ image_url file_name _ <<< "${os_templates[$os_name]}"
        
        echo "Processing $os_name"
        
        # Full path to the image file
        full_path="$IMAGE_DIR/$file_name"
        
        # Download image if not present
        if [[ ! -f "$full_path" ]]; then
            echo "Downloading $file_name to $IMAGE_DIR"
            wget "$image_url" -O "$full_path"
            if [ $? -eq 0 ]; then
                echo "Successfully downloaded $file_name"
            else
                echo "Failed to download $file_name"
                # Remove the partially downloaded file if the download failed
                rm -f "$full_path"
            fi
        else
            echo "$file_name already exists in $IMAGE_DIR. Skipping download."
        fi
        
        echo "------------------------------------"
    done
}

# Run the download function
download_images

echo "All images processed. Check the '$IMAGE_DIR' folder for downloaded images."
