#!/usr/bin/env bash
set -e

# This is a script to allow users to partition their drives in case they want to install Arch Linux alongside another OS.
# This script will be called by the main script, main.sh, if the user chooses to partition their drives during the installation process.

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

# Path to YAML layout file (default)
PARTITIONS_YAML="roles/partitions.yml"

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

# Function to load partition layout from YAML
load_partitions_yaml() {
  if [ -f "$PARTITIONS_YAML" ]; then
    info_print "Loading partition layout from $PARTITIONS_YAML..."
    mapfile -t PARTITIONS < <(yq -r '.partitions[] | "device: " + .device + ", mountpoint: " + .mountpoint + ", fs: " + .fs + ", size: " + .size' "$PARTITIONS_YAML")
    info_print "Loaded $((${#PARTITIONS[@]})) partitions from YAML."
  else
    warning_print "No $PARTITIONS_YAML file found. Starting with empty partition list."
    PARTITIONS=()
  fi
}

# Function to save partition layout to YAML
save_partitions_yaml() {
  info_print "Saving partition layout to $PARTITIONS_YAML..."
  echo "partitions:" > "$PARTITIONS_YAML"
  for entry in "${PARTITIONS[@]}"; do
    device=$(echo "$entry" | grep -o 'device: [^,]*' | cut -d' ' -f2)
    mountpoint=$(echo "$entry" | grep -o 'mountpoint: [^,]*' | cut -d' ' -f2)
    fs=$(echo "$entry" | grep -o 'fs: [^,]*' | cut -d' ' -f2)
    size=$(echo "$entry" | grep -o 'size: [^,]*' | cut -d' ' -f2)
    echo "  - device: $device" >> "$PARTITIONS_YAML"
    echo "    mountpoint: $mountpoint" >> "$PARTITIONS_YAML"
    echo "    fs: $fs" >> "$PARTITIONS_YAML"
    echo "    size: $size" >> "$PARTITIONS_YAML"
  done
  info_print "Partition layout saved."
}

# Improved interactive menu
partitioning_menu() {
  while true; do
    display_subheader
    echo "Interactive Partitioning Menu:"
    echo "1) Display current partitions (lsblk)"
    echo "2) Load partition layout from YAML"
    echo "3) Save current layout to YAML"
    echo "4) Add/Edit a partition entry"
    echo "5) Remove a partition entry"
    echo "6) Resize a partition (interactive)"
    echo "7) List/Edit Btrfs subvolumes"
    echo "8) Bootloader options"
    echo "9) Confirm and exit menu"
    echo "0) Exit without saving"
    read -rp "Choose an option: " OPTION

    case $OPTION in
      1) display_partitions ;;
      2) load_partitions_yaml ;;
      3) save_partitions_yaml ;;
      4)
        read -rp "Device (e.g., /dev/sda2): " device
        read -rp "Mountpoint (e.g., /): " mountpoint
        read -rp "Filesystem (e.g., btrfs): " fs
        read -rp "Size (e.g., 40G): " size
        PARTITIONS+=("device: $device, mountpoint: $mountpoint, fs: $fs, size: $size")
        ;;
      5)
        echo "Current partition entries:"
        for i in "${!PARTITIONS[@]}"; do
          echo "$i) ${PARTITIONS[$i]}"
        done
        read -rp "Enter the number to remove: " idx
        unset 'PARTITIONS[idx]'
        PARTITIONS=(${PARTITIONS[@]})
        ;;
      6)
        echo "Current partition entries:"
        for i in "${!PARTITIONS[@]}"; do
          echo "$i) ${PARTITIONS[$i]}"
        done
        read -rp "Enter the number to resize: " idx
        read -rp "Enter new size (e.g., 50G): " newsize
        PARTITIONS[$idx]=$(echo "${PARTITIONS[$idx]}" | sed "s/size: [^,]*/size: $newsize/")
        ;;
      7)
        echo "Btrfs subvolumes editing is not yet implemented in this menu."
        ;;
      8)
        echo "Bootloader options editing is not yet implemented in this menu."
        ;;
      9)
        echo "Exiting interactive partitioning menu."
        break
        ;;
      0)
        echo "Exiting without saving."
        exit 0
        ;;
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

choice_partitioning() {
  while true; do
    display_subheader
    echo "Choose partitioning method:"
    echo "1) Manual partitioning"
    echo "2) Automatic partitioning (YAML layout)"
    echo "3) Exit