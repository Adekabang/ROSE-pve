#!/usr/bin/env bash

# backup /etc/apt/sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak

mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak

cp /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.bak

OS_VERSION_ID=$(cat /etc/os-release | egrep "VERSION_ID" | cut -d = -f 2 | tr -d '"')

if [[ $OS_VERSION_ID -eq 12 ]]; then
    cat /etc/os-release | egrep "PRETTY_NAME" | cut -d = -f 2 | tr -d '"'

    # change sources.list
cat << EOF > /etc/apt/sources.list
    deb http://ftp.debian.org/debian bookworm main contrib
    deb http://ftp.debian.org/debian bookworm-updates main contrib

    # Proxmox VE pve-no-subscription repository provided by proxmox.com,
    # NOT recommended for production use
    deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription

    # security updates
    deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
    echo "CHANGE OS SOURCE LIST - DONE"

cat << EOF > /etc/apt/sources.list.d/ceph.list
    deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
EOF
    echo "CHANGE CEPH SOURCE LIST - DONE"

elif [[ $OS_VERSION_ID -eq 11 ]]; then
    cat /etc/os-release | egrep "PRETTY_NAME" | cut -d = -f 2 | tr -d '"'

    # change sources.list
cat << EOF > /etc/apt/sources.list
    deb http://ftp.debian.org/debian buster main contrib
    deb http://ftp.debian.org/debian buster-updates main contrib

    # Proxmox VE pve-no-subscription repository provided by proxmox.com,
    # NOT recommended for production use
    deb http://download.proxmox.com/debian/pve buster pve-no-subscription

    # security updates
    deb http://security.debian.org/debian-security buster-security main contrib                                                                    
EOF
    echo "CHANGE OS SOURCE LIST - DONE"
fi

echo ""
echo "you can do update now"
echo "=========="
echo "apt update"
echo "apt dist-upgrade"
echo "=========="
