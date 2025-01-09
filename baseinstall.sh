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
   __                    _      ___    ___    ___    ___  
   \ \ __      __  __ _ | | __ / _ \  / _ \  / _ \  / _ \ 
    \ \\ \ /\ / / / _` || |/ /| (_) || | | || | | || | | |
 /\_/ / \ V  V / | (_| ||   <  \__, || |_| || |_| || |_| |
 \___/   \_/\_/   \__,_||_|\_\   /_/  \___/  \___/  \___/ 
                                                          
   _____              _           _  _                      
   \_   \ _ __   ___ | |_   __ _ | || |  ___  _ __         
    / /\/| '_ \ / __|| __| / _` || || | / _ \| '__|        
 /\/ /_  | | | |\__ \| |_ | (_| || || ||  __/| |           
 \____/  |_| |_||___/ \__| \__,_||_||_| \___||_|     

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
echo "=> Checking for mounted partitions on $INSTALL_DISK"
sleep 1
if mount | grep "$INSTALL_DISK"; then
  echo "=> Unmounting mounted partitions on $INSTALL_DISK"
  sleep 1
  for MOUNT_POINT in $(lsblk -ln -o MOUNTPOINT "$INSTALL_DISK" | grep -v '^$' | sort -r); do
    echo "Unmounting $MOUNT_POINT"
    umount -R "$MOUNT_POINT" || echo "Failed to unmount $MOUNT_POINT"
    sleep 1
  done
  echo "=> All mount points unmounted"
  sleep 1
else
  echo "No mounted partitions found on $INSTALL_DISK"
  sleep 1
fi

# 3. Ensure partitions are unmounted and reload partition table
echo "=> Ensuring all partitions are unmounted and reloading partition table"
sleep 1
for PART in $(lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}[0-9]+"); do
  umount "/dev/$PART" || true
done
partprobe "$INSTALL_DISK"
sleep 1



# 4. Check for existing partitions and prompt for confirmation to overwrite
if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
  if lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}p[0-9]+"; then
    display_header
    echo "Warning: Existing partitions found on $INSTALL_DISK."
    read -rp "Do you want to overwrite the existing partitions? This will delete all data on the disk. (y/N): " OVERWRITE_CONFIRMATION
    if [[ "$OVERWRITE_CONFIRMATION" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "=> Removing existing partitions on $INSTALL_DISK"
      sgdisk --zap-all "$INSTALL_DISK"
      partprobe "$INSTALL_DISK"
      echo "=> Existing partitions removed"
    else
      echo "Aborting installation."
      exit 1
    fi
  fi
else
  if lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}[0-9]+"; then
    display_header
    echo "Warning: Existing partitions found on $INSTALL_DISK."
    read -rp "Do you want to overwrite the existing partitions? This will delete all data on the disk. (y/N): " OVERWRITE_CONFIRMATION
    if [[ "$OVERWRITE_CONFIRMATION" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "=> Removing existing partitions on $INSTALL_DISK"
      sgdisk --zap-all "$INSTALL_DISK"
      partprobe "$INSTALL_DISK"
      echo "=> Existing partitions removed"
    else
      echo "Aborting installation."
      exit 1
    fi
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
sleep 1.5
mkfs.fat -F 32 "$EFI_PART"

echo "=> Formatting primary partition as Btrfs"
sleep 1.5
mkfs.btrfs -f "$BTRFS_PART"

# 8. Create and mount Btrfs subvolumes
echo "=> Mounting $BTRFS_PART to /mnt"
sleep 1.5
mount "$BTRFS_PART" /mnt

echo "=> Creating BTRFS subvolumes"
sleep 1.5
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
echo "=> BTRFS subvolumes /@, /@home, and @/snapshots created"
sleep 1.5

echo "=> Unmounting /mnt to re-mount subvolumes"
sleep 1.5
umount /mnt

echo "=> Remounting subvolumes"
sleep 1.5
mount -o subvol=@ "$BTRFS_PART" /mnt
mkdir -p /mnt/home
mount -o subvol=@home "$BTRFS_PART" /mnt/home
mkdir -p /mnt/.snapshots
mount -o subvol=@snapshots "$BTRFS_PART" /mnt/.snapshots

# 9. Mount EFI partition
echo "=> Mounting EFI partition at /mnt/boot"
sleep 1.5
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# 10. Install base system
echo "=> Installing base system with linux-zen kernel and essential packages"
sleep 1.5
pacstrap /mnt base linux-zen linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager pciutils usbutils

echo "=> Generating fstab file and chrooting into new system"
sleep 1.5
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

