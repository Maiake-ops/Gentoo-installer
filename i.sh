#!/bin/bash
set -e

echo "[1/9] Partitioning disk..."
sgdisk -Z /dev/sda
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI"
sgdisk -n 2:0:+2G   -t 2:8200 -c 2:"SWAP"
sgdisk -n 3:0:0     -t 3:8300 -c 3:"ROOT"

echo "[2/9] Formatting..."
mkfs.vfat -F 32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 /dev/sda3

echo "[3/9] Mounting..."
mount /dev/sda3 /mnt/gentoo
mkdir /mnt/gentoo/boot
mount /dev/sda1 /mnt/gentoo/boot

echo "[4/9] Downloading Stage3..."
cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-openrc-latest.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

echo "[5/9] Chroot setup..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
cp /etc/resolv.conf /mnt/gentoo/etc/

cat <<'EOF' | chroot /mnt/gentoo /bin/bash
source /etc/profile
emerge-webrsync

# Binary packages
echo 'PORTAGE_BINHOST="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64"' >> /etc/portage/make.conf

# Timezone & Locale
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

# Kernel (precompiled)
emerge sys-kernel/gentoo-kernel-bin

# Hostname & Networking
echo "gentoo-vm" > /etc/hostname
emerge --noreplace net-misc/dhcpcd
rc-update add dhcpcd default

# Bootloader
emerge sys-boot/grub:2
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg

# Root password
echo "root:gentoo" | chpasswd
EOF

echo "[6/9] Cleaning..."
rm /mnt/gentoo/stage3-*.tar.xz

echo "[7/9] Unmounting..."
umount -R /mnt/gentoo

echo "[8/9] Done! Reboot and login as root/gentoo"
echo "[9/9] You can now shutdown the ISO in your VM and boot from disk."