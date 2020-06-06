#!/bin/sh
#

# environment
export TERM=vt100

export BSD_HOSTNAME="`hostname -f`"
export BSD_MIRROR="http://ftp2.de.freebsd.org"

export BSD_ARCH="`uname -m`"
export BSD_RELEASE="`uname -r`"

export ANSIBLE_SSH_KEYS="
...
"

export BSDINSTALL_DISTDIR="/tmp"
export BSDINSTALL_DISTSITE="${BSD_MIRROR}/pub/FreeBSD/releases/${BSD_ARCH}/${BSD_RELEASE}"
export DISTRIBUTIONS="kernel.txz base.txz"

export ZFSBOOT_POOL_NAME="z0"
export ZFSBOOT_BEROOT_NAME="ROOT"
export ZFSBOOT_BOOTFS_NAME="root"
export ZFSBOOT_SWAPFS_NAME="swap"

export ZFSBOOT_DISKS="da0" #`sysctl -n kern.disks | awk '{print $1}'`" # First Disk!
export ZFSBOOT_SWAP_SIZE="0"
export ZFSBOOT_SWAP_ZVOL_SIZE="1G"

export ZFSBOOT_VDEV_TYPE="stripe"
export ZFSBOOT_FORCE_4K_SECTORS="1"
export ZFSBOOT_PARTITION_SCHEME="GPT + Active"
export ZFSBOOT_BOOT_TYPE="BIOS"
export ZFSBOOT_CONFIRM_LAYOUT="0"
export ZFSBOOT_DATASETS="
  /$ZFSBOOT_BEROOT_NAME                       mountpoint=none
  /$ZFSBOOT_BEROOT_NAME/$ZFSBOOT_BOOTFS_NAME  mountpoint=/
"

export VM_GUEST="`sysctl -n kern.vm_guest`"

export LOCAL_PACKAGES="lang/python sysutils/dmidecode security/ca_root_nss security/sudo sysutils/firstboot-freebsd-update sysutils/firstboot-pkgs"
export LOCAL_PACKAGES_VMWARE="emulators/open-vm-tools-nox11"
export LOCAL_PACKAGES_NUTANIX=""
export LOCAL_PACKAGES_KVM=""

# ---

# generate installerconfig
cat << EOF > /etc/installerconfig
export nonInteractive="YES"

export BSDINSTALL_DISTDIR="$BSDINSTALL_DISTDIR"
export BSDINSTALL_DISTSITE="$BSDINSTALL_DISTSITE"
export DISTRIBUTIONS="$DISTRIBUTIONS"

export ZFSBOOT_POOL_NAME="$ZFSBOOT_POOL_NAME"
export ZFSBOOT_BEROOT_NAME="$ZFSBOOT_BEROOT_NAME"
export ZFSBOOT_BOOTFS_NAME="$ZFSBOOT_BOOTFS_NAME"
export ZFSBOOT_SWAPFS_NAME="$ZFSBOOT_SWAPFS_NAME"

export ZFSBOOT_DISKS="$ZFSBOOT_DISKS"
export ZFSBOOT_SWAP_SIZE="$ZFSBOOT_SWAP_SIZE"
export ZFSBOOT_SWAP_ZVOL_SIZE="$ZFSBOOT_SWAP_ZVOL_SIZE"

export ZFSBOOT_VDEV_TYPE="$ZFSBOOT_VDEV_TYPE"
export ZFSBOOT_FORCE_4K_SECTORS="$ZFSBOOT_FORCE_4K_SECTORS"
export ZFSBOOT_PARTITION_SCHEME="$ZFSBOOT_PARTITION_SCHEME"
export ZFSBOOT_BOOT_TYPE="$ZFSBOOT_BOOT_TYPE"
export ZFSBOOT_CONFIRM_LAYOUT="$ZFSBOOT_CONFIRM_LAYOUT"
export ZFSBOOT_DATASETS="$ZFSBOOT_DATASETS"

export VM_GUEST="$VM_GUEST"

export LOCAL_PACKAGES="$LOCAL_PACKAGES"
export LOCAL_PACKAGES_VMWARE="$LOCAL_PACKAGES_VMWARE"
export LOCAL_PACKAGES_NUTANIX="$LOCAL_PACKAGES_NUTANIX"
export LOCAL_PACKAGES_KVM="$LOCAL_PACKAGES_KVM"

export ANSIBLE_SSH_KEYS="$ANSIBLE_SSH_KEYS"

#!/bin/sh

# boot
echo '-P' >/boot.config

# loader
cat << IEOF > /boot/loader.conf
autoboot_delay=5
kern.geom.label.disk_ident.enable=0
kern.geom.label.gptid.enable=0
zfs_load="YES"
IEOF

# rc
cat << IEOF > /etc/rc.conf
hostname="${BSD_HOSTNAME}"
ifconfig_DEFAULT="dhcp inet6 accept_rtadv"
zfs_enable="YES"

# clean
cleanvar_enable="YES"
clear_tmp_X="NO"
clear_tmp_enable="YES"

# ntp
ntpd_enable="YES"
ntpdate_enable="YES"

# sendmail
sendmail_enable="NONE"

# sshd
sshd_enable="YES"
sshd_ecdsa_enable="NO"

# firstboot
#growfs_enable="YES" # breaks ZFS
firstboot_freebsd_update_enable="YES"
#firstboot_pkgs_enable="YES"
#firstboot_pkgs_list="awscli"
IEOF

# sysctl (clean)
sed -i~ '/vfs.*/d' /etc/sysctl.conf

# timezone
tzsetup UTC

# repo latest
mkdir -p /usr/local/etc/pkg/repos
echo 'FreeBSD: { url: "pkg+http://pkg.freebsd.org/\${ABI}/latest" }' > /usr/local/etc/pkg/repos/FreeBSD.conf

# packages
export ASSUME_ALWAYS_YES="YES" # pkg
pkg bootstrap
pkg update -f
pkg install ${LOCAL_PACKAGES}

## vm packages
test "${VM_GUEST}" = 'vmware' && pkg install ${LOCAL_PACKAGES_VMWARE}
test "${VM_GUEST}" = 'nutanix' && pkg install ${LOCAL_PACKAGES_NUTANIX}
test "${VM_GUEST}" = 'kvm' && pkg install ${LOCAL_PACKAGES_KVM}

## cleanup
pkg clean -qya

# ansible user & ssh keys
pw group add -n ansible -g 1000
pw user add -n ansible -u 1000 -c "Ansible" -g ansible -m -M 0700 -h -

## root
mkdir -m0700 /root/.ssh
cat << IEOF > /root/.ssh/authorized_keys
${ANSIBLE_SSH_KEYS}
IEOF
chmod 0400 /root/.ssh/authorized_keys
chown -R root:wheel /root/.ssh

## ansible
mkdir -m0700 /home/ansible/.ssh
cat << IEOF > /home/ansible/.ssh/authorized_keys
${ANSIBLE_SSH_KEYS}
IEOF
chmod 0400 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh

## sudo
cat << IEOF > /usr/local/etc/sudoers.d/00ansible
# Ansible
#

ansible     ALL=(ALL) NOPASSWD: ALL
%ansible    ALL=(ALL) NOPASSWD: ALL

# vim: set syn=sudoers sw=4 ts=4 et :
# eof
IEOF
chmod 0440 /usr/local/etc/sudoers.d/00ansible

## ssh config
echo 'PermitRootLogin prohibit-password' >> /etc/ssh/sshd_config

# ntp
service ntpd onefetch

# firstboot
touch /firstboot

# post
zfs set mountpoint=none ${ZFSBOOT_POOL_NAME}
#zfs set mountpoint=legacy ${ZFSBOOT_POOL_NAME}/${ZFSBOOT_BEROOT_NAME}/${ZFSBOOT_BOOTFS_NAME}
zfs set compression=lz4 ${ZFSBOOT_POOL_NAME}
zfs set atime=off ${ZFSBOOT_POOL_NAME}
zfs set aclmode=passthrough ${ZFSBOOT_POOL_NAME}
zfs set aclinherit=passthrough ${ZFSBOOT_POOL_NAME}
zfs create -s -o compression=off -o sync=disabled -o org.freebsd:swap=on -V ${ZFSBOOT_SWAP_ZVOL_SIZE} ${ZFSBOOT_POOL_NAME}/${ZFSBOOT_BEROOT_NAME}/${ZFSBOOT_SWAPFS_NAME}
rmdir /${ZFSBOOT_POOL_NAME}
EOF

# install
bsdinstall distfetch
bsdinstall script /etc/installerconfig

# zfs legacy
#zpool import -N ${ZFSBOOT_POOL_NAME}
#zfs set mountpoint=legacy ${ZFSBOOT_POOL_NAME}/${ZFSBOOT_BEROOT_NAME}/${ZFSBOOT_BOOTFS_NAME}
#zpool export ${ZFSBOOT_POOL_NAME}

# reboot
#reboot

# vim: set syn=sh sw=2 ts=2 et :
# eof
