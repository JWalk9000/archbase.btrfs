#!/usr/bin/env bash
set -e


RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"


# Define colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display the header.
display_header() {
  clear
  echo -e "${GREEN}"
  cat <<"EOF"
   ____         __       ____       
  /  _/__  ___ / /____ _/ / /__ ____
 _/ // _ \(_-</ __/ _ `/ / / -_) __/
/___/_//_/___/\__/\_,_/_/_/\__/_/  


EOF
  echo -e "${NC}"
}

# Function to list block devices and prompt user for target install disk.
target_disk() {
  display_header
  echo "=== List of available block devices ==="
  lsblk -o NAME,SIZE,TYPE,MODEL
  echo "======================================="
  local devices=($(lsblk -dn -o NAME))
  for i in "${!devices[@]}"; do
    echo "$((i+1)). ${devices[$i]}"
  done
  read -rp "Enter the number corresponding to the block device you want to install to: " choice
  INSTALL_DISK="/dev/${devices[$((choice-1))]}"
  echo ""
  read -rp "You chose: $INSTALL_DISK, is this correct? (Y/n): " confirm
  if [[ "$confirm" =~ ^([nN][oO]?|[nN])$ ]]; then
    read -rp "Do you want to select the disk again, "Nn" will exit the installer? (Y/n): " action
    if [[ "$action" =~ ^([yY])$ ]]; then
      target_disk
      fi
    else
      echo "Aborting installation."
      exit 1
    fi
  fi
}



# 1. List block devices and prompt user for target install disk
target_disk


# 2. Check for mounted partitions and unmount them
display_header
if mount | grep "$INSTALL_DISK"; then
  echo "=> Unmounting mounted partitions on $INSTALL_DISK"
  sleep 1.5
  for PART in $(lsblk -ln -o NAME,MOUNTPOINT "$INSTALL_DISK" | awk '$2 != "" {print $1}'); do
    umount "/dev/$PART"
  done
fi

# 4. Check for existing partitions and prompt for confirmation to overwrite
if lsblk "$INSTALL_DISK" | grep -q part; then
  display_header
  echo "Warning: Existing partitions found on $INSTALL_DISK."
  read -rp "Do you want to overwrite the existing partitions? This will delete all data on the disk. (y/N): " OVERWRITE_CONFIRMATION
  if [[ "$OVERWRITE_CONFIRMATION" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "=> Removing existing partitions on $INSTALL_DISK"
    for PART in $(lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}p?[0-9]+$"); do
      wipefs -a "/dev/$PART" || true
    done
    echo "=> Deleting existing partitions on $INSTALL_DISK"
    for PART in $(lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}p?[0-9]+$"); do
      echo "d" | fdisk "$INSTALL_DISK"
    done
    echo "w" | fdisk "$INSTALL_DISK"
    partprobe "$INSTALL_DISK"
  else
    echo "Aborting installation."
    exit 1
  fi
fi

# 5. Set system clock
echo "=> Enabling network time synchronization"
timedatectl set-ntp true

# 6. Automated partitioning with fdisk
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
partprobe "$INSTALL_DISK"

# 7. Format the partitions
if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
  EFI_PART="${INSTALL_DISK}p1"
  BTRFS_PART="${INSTALL_DISK}p2"
else
  EFI_PART="${INSTALL_DISK}1"
  BTRFS_PART="${INSTALL_DISK}2"
fi

echo "=> Formatting EFI partition as FAT32"
mkfs.fat -F 32 "$EFI_PART"

echo "=> Formatting primary partition as Btrfs"
mkfs.btrfs -f "$BTRFS_PART"

# 8. Create and mount Btrfs subvolumes
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

# 9. Mount EFI partition
echo "=> Mounting EFI partition at /mnt/boot"
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# 10. Install base system
echo "=> Installing base system with linux-zen kernel and essential packages"
pacstrap /mnt base linux-zen linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager pciutils usbutils

echo "=> Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# 11. Download and execute chroot_setup.sh inside the chroot environment
arch-chroot /mnt /bin/bash -c "curl -s $RAW_GITHUB/$REPO/chroot_setup.sh | bash"

# 12. Unmount and reboot
display_header
echo "=> Unmounting new installation"
sleep 1.5
umount -R /mnt

display_header
read -rp "Remove the boot media and press [Enter] to reboot..."
reboot