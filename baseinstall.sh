#!/usr/bin/env bash
set -e


RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"

source $RAW_GITHUB/$REPO/functions.sh

# Install script dependencies
PKGDEPS=(
  "jq" 
  "fzf"
)

info_print "=> Installing script dependencies"
for PKG in "${PKGDEPS[@]}"; do
  if ! pacman -Qs "$PKG" > /dev/null ; then
    pacman -S --noconfirm "$PKG"
  fi
done

clear
tput cup 0 0
display_header
tput cup 14 0

# 0. Greet user and provide information about the script
until greet_user; do : ; done

# 1. List block devices and prompt user for target install disk
until target_disk; do : ; done

# 2. Check for mounted partitions and unmount them
until unmount_partitions "$INSTALL_DISK"; do : ; done

# 3. Check for existing partitions and prompt for confirmation to overwrite
until erase_partitions "$INSTALL_DISK"; do : ; done

# 5. Set system clock
info_print "=> Enabling network time synchronization"
timedatectl set-ntp true

# 6. Automated partitioning with fdisk
info_print "=> Creating GPT partition table and partitions on $INSTALL_DISK"
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
partprobe "$INSTALL_DISK"

# 7. Format the partitions
if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
  EFI_PART="${INSTALL_DISK}p1"
  BTRFS_PART="${INSTALL_DISK}p2"
else
  EFI_PART="${INSTALL_DISK}1"
  BTRFS_PART="${INSTALL_DISK}2"
fi

info_print "=> Formatting EFI partition as FAT32"
sleep 1
mkfs.fat -F 32 "$EFI_PART"

info_print "=> Formatting primary partition as Btrfs"
sleep 1
mkfs.btrfs -f "$BTRFS_PART"

# 8. Create and mount Btrfs subvolumes
info_print "=> Mounting $BTRFS_PART to /mnt"
sleep 1
mount "$BTRFS_PART" /mnt

info_print "=> Creating BTRFS subvolumes"
sleep 1
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
info_print "=> BTRFS subvolumes /@, /@home, and @/snapshots created"
sleep 1

info_print "=> Unmounting /mnt to re-mount subvolumes"
sleep 1
umount /mnt

info_print "=> Remounting subvolumes"
sleep 1
mount -o subvol=@ "$BTRFS_PART" /mnt
mkdir -p /mnt/home
mount -o subvol=@home "$BTRFS_PART" /mnt/home
mkdir -p /mnt/.snapshots
mount -o subvol=@snapshots "$BTRFS_PART" /mnt/.snapshots

# 9. Mount EFI partition
info_print "=> Mounting EFI partition at /mnt/boot"
sleep 1
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# 10. Install base system
info_print "=> Installing base system with $KERNEL_PKG and essential packages"
sleep 1
pacstrap /mnt base $KERNEL_PKG linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager pciutils usbutils

echo "=> Generating fstab file and chrooting into new system"
sleep 1
genfstab -U -p /mnt >> /mnt/etc/fstab

# 11. Download and execute chroot_setup.sh inside the chroot environment
arch-chroot /mnt /bin/bash -c "bash <(curl -s $RAW_GITHUB/$REPO/chrootSetup.sh)"

# 12. Unmount and reboot
display_header
echo "=> Unmounting new installation"
sleep 1.5
umount -R /mnt

display_header
echo "========================================================================"
echo "                 Base system installation complete."
echo "                           Next steps:"
echo " "
echo "                    1) Reboot into the new system."
echo "  2) The post-install script will run automatically on the first boot."
echo "========================================================================"

read -rp "Please remove the boot media and press [Enter] to reboot..."
reboot

