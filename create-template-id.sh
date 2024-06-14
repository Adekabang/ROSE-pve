#!/bin/bash

#Create template
#args:
# vm_id
# vm_name
# file name in the current directory
function create_template() {
    #Print all of the configuration
    echo "Creating template $2 ($1)"

    #Create new VM 
    #Feel free to change any of these to your liking
    qm create $1 --name $2 --ostype l26 
    #Set networking to default bridge
    qm set $1 --net0 virtio,bridge=${network}
    #Set display to serial
    qm set $1 --serial0 socket --vga serial0
    #Set memory, cpu, type defaults
    #If you are in a cluster, you might need to change cpu type
    qm set $1 --memory ${memory} --cores ${cpu} --cpu host
    #Set boot device to new file
    qm set $1 --scsi0 ${storage}:0,import-from="$(pwd)/$3",discard=on,format=qcow2
    #Set scsi hardware as default boot disk using virtio scsi single
    qm set $1 --boot order=scsi0 --scsihw virtio-scsi-single
    #Enable Qemu guest agent in case the guest has it available
    qm set $1 --agent enabled=1,fstrim_cloned_disks=1
    #Add cloud-init device
    qm set $1 --ide2 ${storage}:cloudinit
    #Set CI ip config
    #IP6 = auto means SLAAC (a reliable default with no bad effects on non-IPv6 networks)
    #IP = DHCP means what it says, so leave that out entirely on non-IPv4 networks to avoid DHCP delays
    qm set $1 --ipconfig0 "ip6=auto,ip=dhcp"
    #Import the ssh keyfile
    qm set $1 --sshkeys ${ssh_keyfile}
    #If you want to do password-based auth instaed
    #Then use this option and comment out the line above
    qm set $1 --cipassword ${password}
    #Add the user
    qm set $1 --ciuser ${username}
    #Resize the disk to 25G, a reasonable minimum. You can expand it more later.
    #If the disk is already bigger than 25G, this will fail, and that is okay.
    qm disk resize $1 scsi0 25G
    #Make it a template
    qm template $1

    #Remove file when done
    # rm $3

    echo ""
    echo "#######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######  #######"
    echo ""
}


#Path to your ssh authorized_keys file
#Alternatively, use /etc/pve/priv/authorized_keys if you are already authorized
#on the Proxmox system
export ssh_keyfile=/root/.ssh/authorized_keys
#Username to create on VM template
export username=root
#Set password on VM template
export password=password

#Name of your storage
export storage=local

#Name of your network interface
export network=vmbr1

#Set CPU and memory on VM template
export cpu=2
export memory=2048

#The images that I've found premade
#Feel free to add your own

## Debian
#Buster (10)
test -f $(pwd)/debian-10-genericcloud-amd64.qcow2 || wget "https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2"
create_template 3001 "temp-debian-10" "debian-10-genericcloud-amd64.qcow2"
#Bullseye (11)
test -f $(pwd)/debian-11-genericcloud-amd64.qcow2 || wget "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
create_template 3002 "temp-debian-11" "debian-11-genericcloud-amd64.qcow2" 
#Bookworm (12)
test -f $(pwd)/debian-12-genericcloud-amd64.qcow2 || wget "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
create_template 3003 "temp-debian-12" "debian-12-genericcloud-amd64.qcow2"

## Ubuntu
#20.04 (Focal Fossa)
test -f $(pwd)/ubuntu-20.04-server-cloudimg-amd64.img || wget "https://cloud-images.ubuntu.com/releases/20.04/release/ubuntu-20.04-server-cloudimg-amd64.img"
create_template 3011 "temp-ubuntu-20-04" "ubuntu-20.04-server-cloudimg-amd64.img" 
#22.04 (Jammy Jellyfish)
test -f $(pwd)/ubuntu-22.04-server-cloudimg-amd64.img || wget "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
create_template 3012 "temp-ubuntu-22-04" "ubuntu-22.04-server-cloudimg-amd64.img" 
#24.04 (Noble Numbat)
test -f $(pwd)/ubuntu-24.04-server-cloudimg-amd64.img || wget "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
create_template 3013 "temp-ubuntu-24-04" "ubuntu-24.04-server-cloudimg-amd64.img" 


## CentOS Stream
#Stream 8
test -f $(pwd)/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2 || wget https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2
create_template 3031 "temp-centos-8-stream" "CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
#Stream 9
test -f $(pwd)/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 || wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
create_template 3032 "temp-centos-9-stream" "CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"

## Rocky Linux
#8 Generic (Green Obsidian)
test -f $(pwd)/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2 || wget https://mirror.nevacloud.com/rockylinux/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2
create_template 3041 "temp-rocky-linux-8-generic" "Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
#9 Generic (Blue Onyx)
test -f $(pwd)/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 || wget https://mirror.nevacloud.com/rockylinux/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
create_template 3042 "temp-rocky-linux-9-generic" "Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"

## Alma Linux
#8 Generic 
test -f $(pwd)/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2 || wget https://mirror.nevacloud.com/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2
create_template 3051 "temp-almalinux-8-generic" "AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
#9 Generic
test -f $(pwd)/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 || wget https://mirror.nevacloud.com/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
create_template 3052 "temp-almalinux-9-generic" "AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"

## FreeBSD
#13.3
test -f $(pwd)/FreeBSD-13.3-RELEASE-amd64.qcow2 || (wget https://mirror.nevacloud.com/freebsd/releases/VM-IMAGES/13.3-RELEASE/amd64/Latest/FreeBSD-13.3-RELEASE-amd64.qcow2.xz && xz -d FreeBSD-13.3-RELEASE-amd64.qcow2.xz)
create_template 3061 "temp-freebsd-13-3" "FreeBSD-13.3-RELEASE-amd64.qcow2"
#14.0
test -f $(pwd)/FreeBSD-14.0-RELEASE-amd64.qcow2 || (wget https://mirror.nevacloud.com/freebsd/releases/VM-IMAGES/14.0-RELEASE/amd64/Latest/FreeBSD-14.0-RELEASE-amd64.qcow2.xz && xz -d FreeBSD-14.0-RELEASE-amd64.qcow2.xz)
create_template 3062 "temp-freebsd-14-0" "FreeBSD-14.0-RELEASE-amd64.qcow2"
#14.0 ZFS
test -f $(pwd)/FreeBSD-14.0-RELEASE-amd64-zfs.qcow2 || (wget https://mirror.nevacloud.com/freebsd/releases/VM-IMAGES/14.0-RELEASE/amd64/Latest/FreeBSD-14.0-RELEASE-amd64-zfs.qcow2.xz && xz -d FreeBSD-14.0-RELEASE-amd64.qcow2.xz)
create_template 3063 "temp-freebsd-14-0-zfs" "FreeBSD-14.0-RELEASE-amd64-zfs.qcow2"