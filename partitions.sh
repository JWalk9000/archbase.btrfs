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

if ! command -v yq &> /dev/null; then
  info_print "Installing yq for YAML processing..."
  pacman -Sy yq --noconfirm
fi

if ! command -v os-prober &> /dev/null; then
  info_print "Installing os-prober for OS detection..."
  pacman -Sy os-prober --noconfirm
fi

# Variables to store user inputs
PARTITIONS=()
SUBVOLUMES=()
BOOTLOADER_SETUP=()

# Path to YAML layout file (default)
PARTITIONS_YAML="$LOCALREPO/roles/partitions.yml"

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

# Function to detect existing operating systems
detect_existing_os() {
  info_print "=> Detecting existing operating systems..."
  if command -v os-prober >/dev/null 2>&1; then
    os-prober 2>/dev/null || true
  fi
  
  info_print "=> Current partition layout:"
  lsblk -f | grep -E "(ntfs|fat32|ext4|vfat|btrfs)" || info_print "No obvious OS partitions detected"
  
  info_print "=> EFI boot partitions:"
  lsblk -f | grep -i "vfat" | grep -E "(boot|efi)" || info_print "No EFI partitions detected"
}

# Function to show free space on disk
show_free_space() {
  info_print "=> Available disk space on $INSTALL_DISK:"
  parted "$INSTALL_DISK" print free 2>/dev/null | grep "Free Space" || info_print "No free space information available"
}

# Function to resize existing partition (interactive)
resize_existing_partition() {
  info_print "=> Current partitions on $INSTALL_DISK:"
  lsblk "$INSTALL_DISK"
  echo ""
  read -rp "Enter the partition to resize (e.g., /dev/sda1): " partition
  read -rp "Enter new size (e.g., 50G, or +10G to add 10G): " new_size
  
  warning_print "This will resize $partition to $new_size"
  yN_print "Continue with resize? This may cause data loss!"
  read -rp "" confirm
  if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info_print "=> Resizing $partition to $new_size..."
    # Use parted to resize (this is a basic implementation)
    parted "$INSTALL_DISK" resizepart "${partition##*[^0-9]}" "$new_size" || warning_print "Resize failed"
    partprobe "$INSTALL_DISK"
    info_print "=> Resize complete. Please verify the result."
    lsblk "$INSTALL_DISK"
  fi
}

# Function to manage Btrfs subvolumes
manage_btrfs_subvolumes() {
  info_print "=> Current Btrfs subvolume configuration:"
  if [ ${#SUBVOLUMES[@]} -eq 0 ]; then
    SUBVOLUMES=("@" "@home" "@snapshots")
    info_print "Using default subvolumes: @, @home, @snapshots"
  fi
  
  for subvol in "${SUBVOLUMES[@]}"; do
    echo "   $subvol"
  done
  
  echo ""
  choices_print "1" ") Add a subvolume"
  choices_print "2" ") Remove a subvolume"
  choices_print "3" ") Reset to defaults"
  choices_print "4" ") Back to main menu"
  read -rp "Choose an option: " subvol_choice
  
  case $subvol_choice in
    1)
      read -rp "Enter subvolume name (e.g., @var): " new_subvol
      SUBVOLUMES+=("$new_subvol")
      info_print "Added subvolume: $new_subvol"
      ;;
    2)
      echo "Current subvolumes:"
      for i in "${!SUBVOLUMES[@]}"; do
        echo "$i) ${SUBVOLUMES[$i]}"
      done
      read -rp "Enter number to remove: " idx
      if [[ $idx =~ ^[0-9]+$ ]] && [ $idx -lt ${#SUBVOLUMES[@]} ]; then
        removed="${SUBVOLUMES[$idx]}"
        unset 'SUBVOLUMES[idx]'
        SUBVOLUMES=("${SUBVOLUMES[@]}")
        info_print "Removed subvolume: $removed"
      fi
      ;;
    3)
      SUBVOLUMES=("@" "@home" "@snapshots")
      info_print "Reset to default subvolumes"
      ;;
    4)
      return
      ;;
  esac
}

# Function to configure bootloader options
configure_bootloader() {
  info_print "=> Bootloader configuration:"
  echo ""
  choices_print "1" ") Use existing EFI partition"
  choices_print "2" ") Create new EFI partition"
  choices_print "3" ") BIOS/Legacy boot setup"
  choices_print "4" ") Back to main menu"
  read -rp "Choose bootloader setup: " boot_choice
  
  case $boot_choice in
    1)
      info_print "=> Available EFI partitions:"
      lsblk -f | grep -i "vfat" || info_print "No EFI partitions found"
      read -rp "Enter EFI partition to use (e.g., /dev/sda1): " efi_part
      BOOTLOADER_SETUP=("type:efi" "partition:$efi_part" "action:use_existing")
      ;;
    2)
      read -rp "Enter size for new EFI partition (e.g., 512M): " efi_size
      BOOTLOADER_SETUP=("type:efi" "size:$efi_size" "action:create_new")
      ;;
    3)
      BOOTLOADER_SETUP=("type:bios" "action:install_to_mbr")
      ;;
    4)
      return
      ;;
  esac
  
  info_print "=> Bootloader configuration saved"
}

# Enhanced YAML loading with better error handling
load_partitions_yaml() {
  if [ -f "$PARTITIONS_YAML" ]; then
    info_print "Loading partition layout from $PARTITIONS_YAML..."
    
    # Check if YAML is valid
    if ! yq eval '.' "$PARTITIONS_YAML" >/dev/null 2>&1; then
      warning_print "Invalid YAML file: $PARTITIONS_YAML"
      return 1
    fi
    
    # Load partitions
    mapfile -t PARTITIONS < <(yq eval '.partitions[] | "device: " + .device + ", mountpoint: " + .mountpoint + ", fs: " + .fs + ", size: " + .size' "$PARTITIONS_YAML" 2>/dev/null)
    
    # Load subvolumes if they exist
    if yq eval '.partitions[] | select(.subvolumes) | .subvolumes[]' "$PARTITIONS_YAML" >/dev/null 2>&1; then
      mapfile -t SUBVOLUMES < <(yq eval '.partitions[] | select(.fs == "btrfs") | .subvolumes[].name' "$PARTITIONS_YAML" 2>/dev/null)
    fi
    
    info_print "Loaded ${#PARTITIONS[@]} partitions and ${#SUBVOLUMES[@]} subvolumes from YAML."
  else
    warning_print "No $PARTITIONS_YAML file found. Starting with empty partition list."
    PARTITIONS=()
    SUBVOLUMES=("@" "@home" "@snapshots")  # Set defaults
  fi
}

# Enhanced YAML saving with subvolumes and bootloader info
save_partitions_yaml() {
  info_print "Saving partition layout to $PARTITIONS_YAML..."
  
  # Create YAML header
  echo "# Arch Linux Partition Layout Configuration" > "$PARTITIONS_YAML"
  echo "# Generated on $(date)" >> "$PARTITIONS_YAML"
  echo "" >> "$PARTITIONS_YAML"
  echo "partitions:" >> "$PARTITIONS_YAML"
  
  for entry in "${PARTITIONS[@]}"; do
    device=$(echo "$entry" | grep -o 'device: [^,]*' | cut -d' ' -f2)
    mountpoint=$(echo "$entry" | grep -o 'mountpoint: [^,]*' | cut -d' ' -f2)
    fs=$(echo "$entry" | grep -o 'fs: [^,]*' | cut -d' ' -f2)
    size=$(echo "$entry" | grep -o 'size: [^,]*' | cut -d' ' -f2)
    
    echo "  - device: $device" >> "$PARTITIONS_YAML"
    echo "    mountpoint: $mountpoint" >> "$PARTITIONS_YAML"
    echo "    fs: $fs" >> "$PARTITIONS_YAML"
    echo "    size: $size" >> "$PARTITIONS_YAML"
    
    # Add subvolumes for btrfs partitions
    if [[ "$fs" == "btrfs" ]] && [[ "$mountpoint" == "/" ]] && [ ${#SUBVOLUMES[@]} -gt 0 ]; then
      echo "    subvolumes:" >> "$PARTITIONS_YAML"
      for subvol in "${SUBVOLUMES[@]}"; do
        echo "      - name: $subvol" >> "$PARTITIONS_YAML"
      done
    fi
    
    # Add bootloader info for boot partitions
    if [[ "$mountpoint" == "/boot"* ]] && [ ${#BOOTLOADER_SETUP[@]} -gt 0 ]; then
      for boot_setting in "${BOOTLOADER_SETUP[@]}"; do
        if [[ "$boot_setting" == "type:"* ]]; then
          bootloader_type=${boot_setting#type:}
          echo "    bootloader: $bootloader_type" >> "$PARTITIONS_YAML"
        fi
      done
    fi
  done
  
  info_print "Partition layout saved to $PARTITIONS_YAML"
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
        manage_btrfs_subvolumes
        ;;
      8)
        configure_bootloader
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

# Function to apply the partition layout
apply_partition_layout() {
  if [ ${#PARTITIONS[@]} -eq 0 ]; then
    warning_print "No partitions defined. Please add partitions first."
    return 1
  fi
  
  info_print "=> Applying partition layout..."
  warning_print "This will modify your disk. Continue?"
  yN_print "Apply the partition layout to $INSTALL_DISK?"
  read -rp "" confirm
  if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # TODO: Implement actual partitioning based on PARTITIONS array
    info_print "=> Partition layout application is not yet fully implemented."
    info_print "=> Current planned partitions:"
    for partition in "${PARTITIONS[@]}"; do
      echo "   $partition"
    done
    
    # For now, fall back to default partitioning
    warning_print "Falling back to default partitioning for now..."
    default_partitioning
  fi
}

# Main partitioning choice function
choice_partitioning() {
  while true; do
    display_subheader
    echo "Choose partitioning method:"
    echo "1) Use interactive partitioning menu"
    echo "2) Detect existing OS and show options"
    echo "3) Show disk free space"
    echo "4) Resize existing partition"
    echo "5) Apply partition layout"
    echo "0) Return to main menu"
    read -rp "Choose an option: " choice
    
    case $choice in
      1) partitioning_menu ;;
      2) detect_existing_os ;;
      3) show_free_space ;;
      4) resize_existing_partition ;;
      5) apply_partition_layout ;;
      0) return 0 ;;
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

# Main entry point for interactive partitioning
main() {
  # Install required tools if not present
  if ! command -v yq &> /dev/null; then
    info_print "Installing yq for YAML processing..."
    pacman -Sy yq --noconfirm
  fi
  
  if ! command -v os-prober &> /dev/null; then
    info_print "Installing os-prober for OS detection..."
    pacman -Sy os-prober --noconfirm
  fi
  
  choice_partitioning
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi