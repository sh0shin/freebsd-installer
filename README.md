# FreeBSD Installer
FreeBSD Installer script with Ansible user and base packages.

**WARNING: NO PASSWORDS WILL BE SET! USE IT AT YOUR OWN RISK!**

## Usage
Boot into [mfsBSD](https://mfsbsd.vx.sk/)  
_Don't use the mini edition, the installer will fail!_

### Download
The `--no-verify-peer` flag is needed, `ca_root_nss` is not yet installed on mfsBSD.
```sh
fetch --no-verify-peer "https://raw.githubusercontent.com/sh0shin/freebsd-installer/master/freebsd-installer.sh"
```
### Modify to your needs
You should set the `ANSIBLE_SSH_KEYS` variable.
```sh
vi freebsd-installer.sh
```
Setup the hostname `BSD_HOSTNAME` variable or
```sh
hostname myfreebsdbox
```

### Execute
```sh
chmod +x freebsd-installer.sh
./freebsd-installer.sh
```

### Reboot
Finally reboot into your new FreeBSD system, and run Ansible afterwards.
```sh
reboot
```

## Packages
The following packages will be installed as a base set for Ansible:
```
python
dmidecode
ca_root_nss
sudo
firstboot-freebsd-update
firstboot-pkgs
```
If it's a VMware virtual-machine:
```
open-vm-tools-nox11
```

## Ansible user and sudo
This script creates the `ansible` user with uid/gid `1000`, no password, and the ssh-key(s) specified with the `ANSIBLE_SSH_KEYS` variable.
The ssh-key(s) will also be deployed for the `root` user!

The default sudoers rule:
```sudo
ansible     ALL=(ALL) NOPASSWD: ALL
%ansible    ALL=(ALL) NOPASSWD: ALL
```
