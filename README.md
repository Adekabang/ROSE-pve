## Pre-Installation

```sh
apt update -y
apt install git vim -y
```

## Theme Installation
```
git clone https://github.com/Adekabang/ROSE-pve.git
cd ROSE-pve

cd theme-xxx
./changelogo.sh
```

## Create VM Template 
Available Template(s):
Debian
* Buster (10)
* Bullseye (11)
* Bookworm (12)

Ubuntu
* 20.04 (Focal Fossa)
* 22.04 (Jammy Jellyfish)
* 24.04 (Noble Numbat)

CentOS Stream
* Stream 8
* Stream 9

Rocky Linux
* 8 Generic (Green Obsidian)
* 9 Generic (Blue Onyx)

Alma Linux
* 8 Generic
* 9 Generic

FreeBSD
* 13.3 UFS
* 13.3 ZFS
* 14.0 UFS
* 14.0 ZFS
```
nohup ./create-template-id.sh &>template.log &
```

## Download VM Template 
```bash
nohup ./download-only.sh &>download.log &
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

## Add PAM User In Proxmox: In 3 Steps
In order to add the PAM user in Proxmox, we should execute mainly three steps, namely:

1. Firstly, create the user in OS. 
2. Secondly, add the OS user to Proxmox. 
3. Lastly, set the permission to the user. 


### 1. Creating the user in OS
In order to add the user, we need to run the below command:
```
adduser --shell /bin/bash <user>
usermod -aG sudo <user>
# optional to bypass sudo
echo "<user> ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
```

### 2. Adding OS user to Proxmox
In order to add a user to Proxmox, run the code:
```
pveum user add <user>@pam
pveum user list
```

### 3. Setting the permission/role to the user.
The user role is set by using the code:
```
pveum acl modify <PATH> --roles PVEAdmin --users <user>@pam
```

The default roles in Proxmox VE are as follows: Administrator, PVEAdmin, PVEVMAdmin, PVEVMUser, PVEUserAdmin, PVEDatastoreAdmin, PVEDatastoreUser, PVESysAdmin, PVEPoolAdmin, PVETemplateUser, and PVEAuditor. Additionally, there is a “NoAccess” role to forbid access.

### If sudo not exist
```
apt install sudo
```
