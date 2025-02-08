#!/usr/bin/env bash
set -e

# This is a script to allow users to partition their drives in case they want to install Arch Linux alongside another OS.
# This script will be called by the main script, archsetup.sh, if the user chooses to partition their drives during the installation process.

# Ensure INSTALL_DISK is set
if [ -z "$INSTALL_DISK" ]; then
  echo "INSTALL_DISK is not set. Please set the INSTALL_DISK variable before running this script."
  exit 1
fi

# Install required packages if not installed.
if ! pacman -Qs parted > /dev/null; then
  pacman -Sy parted --noconfirm
fi

# Variables to store user inputs
PARTITIONS=()
SUBVOLUMES=()
BOOTLOADER_SETUP=()

# Custom partioning subheader
display_subheader() {
  info_print "
    +-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+-+-+
    |C|U|S|T|O|M| |P|A|R|T|I|T|I|O|N|S|
    +-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+-+-+
    "
}

# Function to display the current partitions
display_partitions() {
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
}

# Function to create a new partition
create_partition() {
  read -rp "Enter the partition size (e.g., +20G): " SIZE
  read -rp "Enter the partition type (e.g., primary): " TYPE
  PARTITIONS+=("parted $INSTALL_DISK mkpart $TYPE btrfs 0% $SIZE")
}

# Function to remove a partition
remove_partition() {
  read -rp "Enter the partition number to remove: " PART_NUM
  PARTITIONS+=("parted $INSTALL_DISK rm $PART_NUM")
}

# Function to resize a partition
resize_partition() {
  read -rp "Enter the partition number to resize: " PART_NUM
  read -rp "Enter the new size (e.g., +10G): " SIZE
  PARTITIONS+=("parted $INSTALL_DISK resizepart $PART_NUM $SIZE")
}

# Function to create Btrfs subvolumes
create_subvolumes() {
  read -rp "Enter the mount point (e.g., /mnt): " MOUNT_POINT
  SUBVOLUMES+=("mkdir -p $MOUNT_POINT")
  SUBVOLUMES+=("mount -o subvol=@ $INSTALL_DISK $MOUNT_POINT")
  SUBVOLUMES+=("btrfs subvolume create $MOUNT_POINT/@home")
  SUBVOLUMES+=("btrfs subvolume create $MOUNT_POINT/@snapshots")
  SUBVOLUMES+=("btrfs subvolume create $MOUNT_POINT/@var_log")
  SUBVOLUMES+=("umount $MOUNT_POINT")
}

# Function to set up the boot partition and bootloader
setup_bootloader() {
  read -rp "Enter the device for the boot partition (e.g., /dev/sda1): " BOOT_DEVICE
  read -rp "Enter the mount point for the boot partition (e.g., /mnt/boot): " BOOT_MOUNT
  BOOTLOADER_SETUP+=("mkdir -p $BOOT_MOUNT")
  BOOTLOADER_SETUP+=("mount $BOOT_DEVICE $BOOT_MOUNT")
  BOOTLOADER_SETUP+=("pacman -Sy grub --noconfirm")
  BOOTLOADER_SETUP+=("grub-install --target=x86_64-efi --efi-directory=$BOOT_MOUNT --bootloader-id=GRUB")
  BOOTLOADER_SETUP+=("grub-mkconfig -o $BOOT_MOUNT/grub/grub.cfg")
}

# Function to execute the actions
execute_actions() {
  for action in "${PARTITIONS[@]}"; do
    echo "Executing: $action"
    eval "$action"
  done

  for action in "${SUBVOLUMES[@]}"; do
    echo "Executing: $action"
    eval "$action"
  done

  for action in "${BOOTLOADER_SETUP[@]}"; do
    echo "Executing: $action"
    eval "$action"
  done
}

# Main menu
while true; do
  echo "Custom Partitioning Menu:"
  echo "1) Display current partitions"
  echo "2) Create a new partition"
  echo "3) Remove a partition"
  echo "4) Resize a partition"
  echo "5) Create Btrfs subvolumes"
  echo "6) Set up bootloader"
  echo "7) Confirm and execute actions"
  echo "8) Exit"
  read -rp "Choose an option: " OPTION

  case $OPTION in
    1) display_partitions ;;
    2) create_partition ;;
    3) remove_partition ;;
    4) resize_partition ;;
    5) create_subvolumes ;;
    6) setup_bootloader ;;
    7)
      echo "Summary of actions to be performed:"
      echo "Partitions:"
      for action in "${PARTITIONS[@]}"; do
        echo "- $action"
      done
      echo "Subvolumes:"
      for action in "${SUBVOLUMES[@]}"; do
        echo "- $action"
      done
      echo "Bootloader setup:"
      for action in "${BOOTLOADER_SETUP[@]}"; do
        echo "- $action"
      done
      read -rp "Do you want to proceed with these actions? (y/N): " CONFIRM
      if [[ "$CONFIRM" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        execute_actions
        exit 0
      else
        echo "Actions canceled."
      fi
      ;;
    8) exit 0 ;;
    *) echo "Invalid option. Please try again." ;;
  esac
done