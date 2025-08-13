#!/bin/bash
set -e

echo "[1/8] Partitioning disk..."
sgdisk -Z /dev/sda
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI"
sgdisk -n 2:0:+2G   -t 2:8200 -c 2:"SWAP"
sgdisk -n 3:0:0     -t 3:8300 -c 3:"ROOT"

echo "[2/8] Formatting..."
mkfs.vfat -F 32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 /dev/sda3

echo "[3/8] Mounting..."
mount /dev/sda3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount /dev/sda1 /mnt/gentoo/boot

echo "[4/8] Downloading Stage3..."
cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-openrc-latest.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

echo "[5/8] Chroot setup..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
cp /etc/resolv.conf /mnt/gentoo/etc/

chroot /mnt/gentoo /bin/bash <<'EOF'
source /etc/profile

# Binary packages only
echo 'PORTAGE_BINHOST="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64"' >> /etc/portage/make.conf

# Timezone & locale
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

# Minimal network
emerge --noreplace net-misc/dhcpcd
rc-update add dhcpcd default

# Hostname
echo "gentoo-vm" > /etc/hostname

# Prebuilt kernel
emerge sys-kernel/gentoo-kernel-bin

# Root password
echo "root:gentoo" | chpasswd

# Install Xorg
emerge --noreplace x11-base/xorg-drivers x11-base/xorg-server x11-base/xorg-apps

# Install KDE Plasma and SDDM (login manager)
emerge --noreplace kde-plasma/plasma-meta kde-apps/kde-applications-meta x11-misc/sddm
rc-update add sddm default

EOF

echo "[6/8] Cleaning..."
rm /mnt/gentoo/stage3-*.tar.xz

echo "[7/8] Unmounting..."
umount -R /mnt/gentoo

echo "[8/8] Finished!"
echo "Gentoo with KDE Plasma is installed. Boot the VM disk and SDDM should start Plasma."