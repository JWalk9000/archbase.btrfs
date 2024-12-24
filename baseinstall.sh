#!/usr/bin/env bash
set -e

# 1. List block devices and prompt user for target install disk
clear
echo "=== List of available block devices ==="
lsblk -o NAME,SIZE,TYPE,MODEL
echo "======================================="
read -rp "Enter the block device you want to install to (e.g. /dev/sda): " INSTALL_DISK

# 2. Confirm the user choice
echo "You chose: $INSTALL_DISK"
read -rp "Press [Enter] to continue or Ctrl+C to abort..."

# 3. Set system clock
echo "=> Enabling network time synchronization"
timedatectl set-ntp true

# 4. Automated partitioning with GPT
echo "=> Creating GPT partition table and partitions on $INSTALL_DISK"
parted -s "$INSTALL_DISK" mklabel gpt
parted -s "$INSTALL_DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$INSTALL_DISK" set 1 esp on
parted -s "$INSTALL_DISK" mkpart primary btrfs 512MiB 100%

# 5. Format the partitions
echo "=> Formatting EFI partition as FAT32"
mkfs.fat -F32 "${INSTALL_DISK}1"

echo "=> Formatting primary partition as Btrfs"
mkfs.btrfs "${INSTALL_DISK}2"

# 6. Create and mount Btrfs subvolumes
echo "=> Mounting ${INSTALL_DISK}2 to /mnt"
mount "${INSTALL_DISK}2" /mnt

echo "=> Creating subvolumes"
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

echo "=> Unmounting /mnt to re-mount subvolumes"
umount /mnt

echo "=> Remounting subvolumes"
mount -o subvol=@ "${INSTALL_DISK}2" /mnt
mkdir -p /mnt/home
mount -o subvol=@home "${INSTALL_DISK}2" /mnt/home
mkdir -p /mnt/.snapshots
mount -o subvol=@snapshots "${INSTALL_DISK}2" /mnt/.snapshots

# 7. Mount EFI partition
echo "=> Mounting EFI partition at /mnt/boot"
mkdir -p /mnt/boot
mount "${INSTALL_DISK}1" /mnt/boot

# 8. Install base system
echo "=> Installing base system with linux-zen kernel and essential packages"
pacstrap /mnt base linux-zen linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager

echo "=> Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# 9. Instructions to proceed
echo "========================================================="
echo "Base system installation complete."
echo "Next steps:"
echo "  1) arch-chroot /mnt"
echo "  2) Inside the chroot, set time with:"
echo "     ln -sf /usr/share/zoneinfo/Region/City /etc/localtime"
echo "     hwclock --systohc"
echo "  3) (Optional) Run additional setup:"
echo "     bash <(curl -s 'https://YOUR_RAW_GITHUB_URL/post_install.sh')"
echo "  4) Install and configure your preferred bootloader (e.g., GRUB, systemd-boot, or rEFInd)."
echo "  5) Exit chroot, unmount, and reboot."
echo "========================================================="