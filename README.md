## Pre-Installation

```sh
apt update -y
apt install git vim -y
```

## Theme Installation
```
git clone https://github.com/Adekabang/RISS-pve.git
cd RISS-pve

cd theme-xxx
./changelogo.sh
```

## Create VM Template 
Available Template(s):
Debian
* Buster (10)
* Bullseye (11)
* Bookworm (12)
* Sid (Unstable)

Ubuntu
* 20.04 (Focal Fossa)
* 22.04 (Jammy Jellyfish)
* 23.04 (Lunar Lobster) - daily builds

Fedora 
* 37
* 38

CentOS Stream
* Stream 8
* Stream 9 (daily)

Rocky Linux
* 8 Generic (Green Obsidian)
* 9 Generic (Blue Onyx)

FreeBSD
* 13.2 ZFS
* 12.4 ZFS
```
./create-template.sh
```

## Remove Subscription Message and Change Repo to No Subscription
Tested on Debian 11 & 12 based PVE
```
./no-subs-repo.sh
./remove-subs-message.sh
```

## Remove local-lvm and expand local storage

- Remove local-lvm from the storage configuration of the Datacenter
- Execute the following commands on the node's shell:
```
lvremove /dev/pve/data
lvresize -l +100%FREE /dev/pve/root
resize2fs /dev/mapper/pve-root
```
