#!/usr/bin/env bash
set -e

# 1. List block devices and prompt user for target install disk
clear
echo "=== List of available block devices ==="
lsblk -o NAME,SIZE,TYPE,MODEL
echo "======================================="
read -rp "Enter the block device you want to install to (e.g. /dev/sda or /dev/nvme0n1): " INSTALL_DISK

# 2. Confirm the user choice
echo "You chose: $INSTALL_DISK"
read -rp "Press [Enter] to continue or Ctrl+C to abort..."

# 3. Check for existing partitions and prompt for confirmation to overwrite
FORCE_FLAG=""
if lsblk "$INSTALL_DISK" | grep -q part; then
  echo "Warning: Existing partitions found on $INSTALL_DISK."
  read -rp "Do you want to overwrite the existing partitions? This will delete all data on the disk. (y/N): " OVERWRITE_CONFIRMATION
  if [[ "$OVERWRITE_CONFIRMATION" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    FORCE_FLAG="-f"
    echo "=> Removing existing partitions on $INSTALL_DISK"
    wipefs -a "$INSTALL_DISK"
    sgdisk -Z "$INSTALL_DISK"
  else
    echo "Aborting installation."
    exit 1
  fi
fi

# 4. Set system clock
echo "=> Enabling network time synchronization"
timedatectl set-ntp true

# 5. Automated partitioning with fdisk
echo "=> Creating GPT partition table and partitions on $INSTALL_DISK"
(
echo g # Create a new empty GPT partition table
echo n # Add a new partition
echo 1 # Partition number
echo   # First sector (Accept default: 1MiB)
echo +512M # Last sector (Accept default: varies)
echo t # Change partition type
echo 1 # EFI System
echo n # Add a new partition
echo 2 # Partition number
echo   # First sector (Accept default: varies)
echo   # Last sector (Accept default: varies)
echo w # Write changes
) | fdisk "$INSTALL_DISK"

# 6. Format the partitions
if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
  EFI_PART="${INSTALL_DISK}p1"
  BTRFS_PART="${INSTALL_DISK}p2"
else
  EFI_PART="${INSTALL_DISK}1"
  BTRFS_PART="${INSTALL_DISK}2"
fi

echo "=> Formatting EFI partition as FAT32"
mkfs.fat -F32 "$EFI_PART" $FORCE_FLAG

echo "=> Formatting primary partition as Btrfs"
mkfs.btrfs "$BTRFS_PART" $FORCE_FLAG

# 7. Create and mount Btrfs subvolumes
echo "=> Mounting $BTRFS_PART to /mnt"
mount "$BTRFS_PART" /mnt

echo "=> Creating subvolumes"
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

echo "=> Unmounting /mnt to re-mount subvolumes"
umount /mnt

echo "=> Remounting subvolumes"
mount -o subvol=@ "$BTRFS_PART" /mnt
mkdir -p /mnt/home
mount -o subvol=@home "$BTRFS_PART" /mnt/home
mkdir -p /mnt/.snapshots
mount -o subvol=@snapshots "$BTRFS_PART" /mnt/.snapshots

# 8. Mount EFI partition
echo "=> Mounting EFI partition at /mnt/boot"
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# 9. Install base system
echo "=> Installing base system with linux-zen kernel and essential packages"
pacstrap /mnt base linux-zen linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager

echo "=> Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# 10. Instructions to proceed
echo "========================================================="
echo "Base system installation complete."
echo "Next steps:"
echo "  1) arch-chroot /mnt"
echo "  2) Inside the chroot, set time with:"
echo "     ln -sf /usr/share/zoneinfo/Region/City /etc/localtime"
echo "     hwclock --systohc"
echo "  3) (Optional) Run additional setup:"
echo "     bash <(curl -s 'https://raw.githubusercontent.com/JWalk9000/archbase.btrfs/refs/heads/main/post_baseinstall.sh')"
echo "  4) Install and configure your preferred bootloader (e.g., GRUB, systemd-boot, or rEFInd)."
echo "  5) Exit chroot, unmount, and reboot."
echo "========================================================="

# 11. Option to automatically arch-chroot and run post_baseinstall.sh
read -rp "Would you like to automatically arch-chroot and run the post_baseinstall.sh script? (y/N): " CHROOT_CHOICE
if [[ "$CHROOT_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  arch-chroot /mnt /bin/bash -c "
    ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
    hwclock --systohc
    bash <(curl -s 'https://raw.githubusercontent.com/JWalk9000/archbase.btrfs/refs/heads/main/post_baseinstall.sh')
  "
fi