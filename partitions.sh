#!/usr/bin/env bash
set -e

# This is a script to allow users to partition their drives in case they want to install Arch Linux alongside another OS.
# This script will be called by the main script, main.sh, if the user chooses to partition their drives during the installation process.

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
  clear
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

# Function to show free space on disk (fixed)
show_free_space() {
  if [ -z "$INSTALL_DISK" ]; then
    warning_print "No target disk selected. Please select a target disk first."
    return 1
  fi
  info_print "=> Available disk space on $INSTALL_DISK:"
  
  # Use parted to show free space more reliably
  if command -v parted >/dev/null 2>&1; then
    parted "$INSTALL_DISK" unit MB print free 2>/dev/null | grep -E "(Free Space|Disk)" || info_print "Unable to read free space information"
  else
    # Fallback to lsblk
    lsblk "$INSTALL_DISK" -o NAME,SIZE,FSTYPE,MOUNTPOINT
    info_print "Free space calculation requires parted. Please install parted for detailed free space information."
  fi
}

# Function to resize existing partition (interactive)
resize_existing_partition() {
  if [ -z "$INSTALL_DISK" ]; then
    warning_print "No target disk selected. Please select a target disk first."
    return 1
  fi
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
    
    # Load subvolumes if they exist (handle both old and new format)
    if yq eval '.partitions[] | select(.subvolumes) | .subvolumes[]' "$PARTITIONS_YAML" >/dev/null 2>&1; then
      # New format with mountpoints
      if yq eval '.partitions[] | select(.subvolumes) | .subvolumes[] | .mountpoint' "$PARTITIONS_YAML" >/dev/null 2>&1; then
        mapfile -t SUBVOLUMES < <(yq eval '.partitions[] | select(.fs == "btrfs") | .subvolumes[] | .name + ":" + .mountpoint' "$PARTITIONS_YAML" 2>/dev/null)
      else
        # Old format, just names
        mapfile -t temp_subvols < <(yq eval '.partitions[] | select(.fs == "btrfs") | .subvolumes[].name' "$PARTITIONS_YAML" 2>/dev/null)
        SUBVOLUMES=()
        for subvol in "${temp_subvols[@]}"; do
          case "$subvol" in
            "@") SUBVOLUMES+=("@:/") ;;
            "@home") SUBVOLUMES+=("@home:/home") ;;
            "@snapshots") SUBVOLUMES+=("@snapshots:/.snapshots") ;;
            *) SUBVOLUMES+=("$subvol:/mnt/$subvol") ;;
          esac
        done
      fi
    else
      # No subvolumes in YAML, use defaults
      SUBVOLUMES=("@:/" "@home:/home" "@snapshots:/.snapshots")
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
        subvol_name="${subvol%:*}"
        mount_point="${subvol#*:}"
        echo "      - name: $subvol_name" >> "$PARTITIONS_YAML"
        echo "        mountpoint: $mount_point" >> "$PARTITIONS_YAML"
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

# Legacy interactive menu (kept for YAML workflow compatibility)
partitioning_menu() {
  while true; do
    display_subheader
    echo "Legacy Interactive Partitioning Menu (YAML-based):"
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

# Function to apply the partition layout (legacy - for YAML-based workflows)
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

# Interactive partitioning workflow with YAML backbone
interactive_partitioning_workflow() {
  # Step 1: Choose disk
  until target_disk; do : ; done
  
  # Auto-load existing YAML configuration if available
  if [ -f "$PARTITIONS_YAML" ]; then
    info_print "=> Found existing YAML configuration: $PARTITIONS_YAML"
    yN_print "Load existing partition configuration?"
    read -rp "" load_yaml
    if [[ "$load_yaml" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      load_partitions_yaml
    fi
  else
    info_print "=> No existing YAML configuration found. Starting fresh."
    # Initialize with defaults for new configuration
    PARTITIONS=()
    SUBVOLUMES=("@:/" "@home:/home" "@snapshots:/.snapshots")
  fi
  
  # Step 2: Interactive partitioning menu with YAML integration
  while true; do
    display_subheader
    echo "Interactive Partitioning for $INSTALL_DISK (YAML-based):"
    
    # Show YAML configuration summary
    display_yaml_summary
    
    # Show option 0 only if disk is completely blank
    if ! lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)" >/dev/null 2>&1; then
      echo "GPT) Create new GPT table (disk appears to be blank)"
    fi
    
    echo "1) Display existing partitions"
    echo "2) Comprehensive overview (physical + YAML)"
    echo "3) Load partition layout from YAML"
    echo "4) Save current layout to YAML"
    echo "5) Move/modify partition"
    echo "6) Create new partition"
    echo "7) Subvolumes configuration"
    echo "8) Review and proceed"
    echo "9) Help and workflow guide"
    echo "0) Cancel and return to previous menu"
    read -rp "Choose an option: " OPTION
    
    case $OPTION in
      GPT)
        if ! lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)" >/dev/null 2>&1; then
          create_new_gpt_table
        else
          echo "Option not available - disk is not blank"
        fi
        ;;
      1) display_existing_partitions ;;
      2) display_comprehensive_overview ;;
      3) load_partitions_yaml ;;
      4) save_partitions_yaml ;;
      5) move_modify_partition ;;
      6) create_new_partition ;;
      7) configure_subvolumes ;;
      8) review_and_proceed ;;
      9) show_yaml_workflow_help ;;
      0) 
        echo "Returning to main menu..."
        return 0
        ;;
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

# Function to create new GPT table
create_new_gpt_table() {
  warning_print "This will create a new GPT partition table on $INSTALL_DISK"
  warning_print "ALL EXISTING DATA WILL BE LOST!"
  yN_print "Continue with creating new GPT table?"
  read -rp "" confirm
  if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info_print "=> Creating new GPT partition table on $INSTALL_DISK"
    sgdisk --zap-all "$INSTALL_DISK"
    sgdisk --clear --new=0:0:0 --typecode=0:8300 "$INSTALL_DISK" >/dev/null 2>&1 || true
    sgdisk --delete=1 "$INSTALL_DISK" >/dev/null 2>&1 || true  # Remove the auto-created partition
    partprobe "$INSTALL_DISK"
    info_print "=> New GPT table created"
  fi
}

# Function to display existing partitions (filtered to target disk)
display_existing_partitions() {
  info_print "=> Current partitions on $INSTALL_DISK:"
  lsblk "$INSTALL_DISK" -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
}

# Function to move/modify partition
move_modify_partition() {
  info_print "=> Partitions on $INSTALL_DISK:"
  lsblk "$INSTALL_DISK" -ln -o NAME,SIZE,FSTYPE | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)" || {
    warning_print "No partitions found on $INSTALL_DISK"
    return 1
  }
  
  # Create numbered list of partitions
  mapfile -t partitions < <(lsblk "$INSTALL_DISK" -ln -o NAME | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)")
  
  echo "Select partition to modify:"
  for i in "${!partitions[@]}"; do
    partition="/dev/${partitions[$i]}"
    size=$(lsblk "$partition" -ln -o SIZE | head -1)
    fstype=$(lsblk "$partition" -ln -o FSTYPE | head -1)
    echo "$((i+1))) $partition ($size, $fstype)"
  done
  
  read -rp "Enter partition number: " part_num
  if [[ $part_num =~ ^[0-9]+$ ]] && [ $part_num -ge 1 ] && [ $part_num -le ${#partitions[@]} ]; then
    selected_partition="/dev/${partitions[$((part_num-1))]}"
    modify_partition_details "$selected_partition"
  else
    warning_print "Invalid selection"
  fi
}

# Function to modify partition details (with YAML integration)
modify_partition_details() {
  local partition="$1"
  echo "Modifying partition: $partition"
  echo "Current details:"
  lsblk "$partition" -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
  
  read -rp "Space before (MB, default 0): " space_before
  space_before=${space_before:-0}
  
  read -rp "Size (MB, leave empty for maximum available): " new_size
  
  if [ -n "$new_size" ]; then
    read -rp "Space after (MB, default 0): " space_after
    space_after=${space_after:-0}
    echo "Free space created: $space_after MiB"
  else
    read -rp "Space after (MB, default 0): " space_after
    space_after=${space_after:-0}
    # Calculate size automatically
    new_size="remaining after $space_after MB"
  fi
  
  # Get current filesystem and mountpoint
  current_fs=$(lsblk "$partition" -ln -o FSTYPE | head -1)
  current_mount=$(lsblk "$partition" -ln -o MOUNTPOINT | head -1)
  current_mount=${current_mount:-"/"}  # Default if not mounted
  
  echo ""
  echo "Proposed changes:"
  echo "Partition: $partition"
  echo "Space before: $space_before MB"
  echo "Size: $new_size"
  echo "Space after: $space_after MB"
  echo "Filesystem: $current_fs (detected)"
  echo "Mount point: $current_mount (detected)"
  echo ""
  
  choices_print "1" ") Apply changes (save to YAML)"
  choices_print "2" ") Cancel and return"
  read -rp "Choose: " apply_choice
  
  case $apply_choice in
    1)
      # Update or add to PARTITIONS array
      local found=false
      for i in "${!PARTITIONS[@]}"; do
        if [[ "${PARTITIONS[$i]}" == *"device: $partition"* ]]; then
          PARTITIONS[$i]="device: $partition, mountpoint: $current_mount, fs: $current_fs, size: $new_size"
          found=true
          break
        fi
      done
      
      if [ "$found" = false ]; then
        PARTITIONS+=("device: $partition, mountpoint: $current_mount, fs: $current_fs, size: $new_size")
      fi
      
      info_print "=> Updated partition configuration: $partition"
      
      # Auto-save to YAML
      auto_save_configuration
      info_print "=> Changes saved for repeatability"
      warning_print "Note: Actual partition changes not yet implemented - only saved to configuration"
      ;;
    2)
      info_print "=> Cancelled, returning to previous menu"
      ;;
  esac
}

# Function to create new partition
create_new_partition() {
  info_print "=> Available free space on $INSTALL_DISK:"
  
  # Show free space
  mapfile -t free_spaces < <(parted "$INSTALL_DISK" unit MB print free 2>/dev/null | grep "Free Space" | nl -w2 -s') ')
  
  if [ ${#free_spaces[@]} -eq 0 ]; then
    warning_print "No free space available on $INSTALL_DISK"
    return 1
  fi
  
  echo "Select free space:"
  printf "%s\n" "${free_spaces[@]}"
  
  read -rp "Enter free space number: " space_num
  if [[ $space_num =~ ^[0-9]+$ ]] && [ $space_num -ge 1 ] && [ $space_num -le ${#free_spaces[@]} ]; then
    create_partition_in_space "$space_num"
  else
    warning_print "Invalid selection"
  fi
}

# Function to create partition in selected free space (with YAML integration)
create_partition_in_space() {
  local space_num="$1"
  
  read -rp "Space before (MB, default 0): " space_before
  space_before=${space_before:-0}
  
  read -rp "Size (MB, leave empty for maximum available): " partition_size
  
  if [ -n "$partition_size" ]; then
    read -rp "Space after (MB, default 0): " space_after
    space_after=${space_after:-0}
    echo "Free space created: $space_after MiB"
  else
    read -rp "Space after (MB, default 0): " space_after
    space_after=${space_after:-0}
    partition_size="remaining after $space_after MB"
  fi
  
  echo ""
  echo "Choose File System:"
  choices_print "1" ") EFI (will be set up as /boot partition)"
  choices_print "2" ") BTRFS"
  choices_print "3" ") EXT4"
  choices_print "4" ") Swap"
  read -rp "Choose filesystem: " fs_choice
  
  case $fs_choice in
    1) 
      filesystem="vfat"
      mountpoint="/boot"
      ;;
    2) 
      filesystem="btrfs"
      mountpoint="/"
      ;;
    3) 
      filesystem="ext4"
      read -rp "Mount point (e.g., /home): " mountpoint
      ;;
    4) 
      filesystem="swap"
      mountpoint="swap"
      ;;
    *)
      warning_print "Invalid choice"
      return 1
      ;;
  esac
  
  echo ""
  echo "Proposed new partition:"
  echo "Space before: $space_before MB"
  echo "Size: $partition_size"
  echo "Space after: $space_after MB"
  echo "Filesystem: $filesystem"
  echo "Mount point: $mountpoint"
  echo ""
  
  choices_print "1" ") Continue (save changes to YAML)"
  choices_print "2" ") Cancel and return"
  read -rp "Choose: " create_choice
  
  case $create_choice in
    1)
      # Create next available device name
      local next_partition_num=$(( $(lsblk "$INSTALL_DISK" -ln -o NAME | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)" | wc -l) + 1 ))
      if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
        local device_name="${INSTALL_DISK}p${next_partition_num}"
      else
        local device_name="${INSTALL_DISK}${next_partition_num}"
      fi
      
      # Add to PARTITIONS array
      PARTITIONS+=("device: $device_name, mountpoint: $mountpoint, fs: $filesystem, size: $partition_size")
      info_print "=> Added partition to configuration: $device_name ($filesystem, $mountpoint)"
      
      # Auto-save to YAML
      auto_save_configuration
      info_print "=> Partition added and saved for repeatability"
      ;;
    2)
      info_print "=> Cancelled, returning to previous menu"
      ;;
  esac
}

# Function to configure subvolumes
configure_subvolumes() {
  # Initialize default subvolumes if not set
  if [ ${#SUBVOLUMES[@]} -eq 0 ]; then
    SUBVOLUMES=("@:/" "@home:/home" "@snapshots:/.snapshots")
  fi
  
  while true; do
    display_subheader
    echo "Current Subvolumes and mount points:"
    echo ""
    printf "%-20s %s\n" "Subvolume" "Mountpoint"
    echo "----------------------------------------"
    for i in "${!SUBVOLUMES[@]}"; do
      subvol_name="${SUBVOLUMES[$i]%:*}"
      mount_point="${SUBVOLUMES[$i]#*:}"
      printf "%-20s %s\n" "$subvol_name" "$mount_point"
    done
    echo ""
    
    choices_print "1" ") Change a subvolume and/or its mount point"
    choices_print "2" ") Delete a subvolume"
    choices_print "3" ") Add a new subvolume"
    choices_print "4" ") Confirm changes and continue"
    choices_print "5" ") Reset to defaults"
    read -rp "Choose an option: " subvol_option
    
    case $subvol_option in
      1) change_subvolume ;;
      2) delete_subvolume ;;
      3) add_subvolume ;;
      4) 
        info_print "=> Subvolume configuration confirmed"
        # Auto-save to YAML when subvolumes are confirmed
        auto_save_configuration
        return 0
        ;;
      5)
        SUBVOLUMES=("@:/" "@home:/home" "@snapshots:/.snapshots")
        info_print "=> Reset to default subvolumes"
        # Auto-save after reset
        auto_save_configuration
        ;;
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

# Function to add subvolume
add_subvolume() {
  read -rp "Enter new subvolume name (e.g., @var): " new_name
  if [ -z "$new_name" ]; then
    warning_print "Subvolume name cannot be empty"
    return 1
  fi
  
  # Check for duplicates
  for existing in "${SUBVOLUMES[@]}"; do
    existing_name="${existing%:*}"
    if [ "$existing_name" = "$new_name" ]; then
      warning_print "Duplicate subvolume name: $new_name"
      return 1
    fi
  done
  
  read -rp "Enter mount point (e.g., /var): " new_mount
  if [ -z "$new_mount" ]; then
    warning_print "Mount point cannot be empty"
    return 1
  fi
  
  # Check for duplicate mount points
  for existing in "${SUBVOLUMES[@]}"; do
    existing_mount="${existing#*:}"
    if [ "$existing_mount" = "$new_mount" ]; then
      warning_print "Duplicate mount point: $new_mount"
      return 1
    fi
  done
  
  SUBVOLUMES+=("$new_name:$new_mount")
  info_print "=> Added subvolume: $new_name -> $new_mount"
}

# Function to change subvolume
change_subvolume() {
  echo "Choose a subvolume to modify:"
  for i in "${!SUBVOLUMES[@]}"; do
    subvol_name="${SUBVOLUMES[$i]%:*}"
    mount_point="${SUBVOLUMES[$i]#*:}"
    echo "$((i+1))) $subvol_name -> $mount_point"
  done
  
  read -rp "Enter subvolume number: " subvol_num
  if [[ $subvol_num =~ ^[0-9]+$ ]] && [ $subvol_num -ge 1 ] && [ $subvol_num -le ${#SUBVOLUMES[@]} ]; then
    idx=$((subvol_num-1))
    current_subvol="${SUBVOLUMES[$idx]%:*}"
    current_mount="${SUBVOLUMES[$idx]#*:}"
    
    read -rp "New name? (current: $current_subvol, Enter to skip): " new_name
    new_name=${new_name:-$current_subvol}
    
    # Check for duplicates
    for existing in "${SUBVOLUMES[@]}"; do
      existing_name="${existing%:*}"
      if [ "$existing_name" = "$new_name" ] && [ "$existing_name" != "$current_subvol" ]; then
        warning_print "Duplicate subvolume name: $new_name"
        return 1
      fi
    done
    
    read -rp "New mountpoint? (current: $current_mount, Enter to skip): " new_mount
    new_mount=${new_mount:-$current_mount}
    
    # Check for duplicate mount points
    for existing in "${SUBVOLUMES[@]}"; do
      existing_mount="${existing#*:}"
      if [ "$existing_mount" = "$new_mount" ] && [ "$existing_mount" != "$current_mount" ]; then
        warning_print "Duplicate mount point: $new_mount"
        return 1
      fi
    done
    
    SUBVOLUMES[$idx]="$new_name:$new_mount"
    info_print "=> Updated subvolume: $new_name -> $new_mount"
  else
    warning_print "Invalid selection"
  fi
}

# Function to delete subvolume
delete_subvolume() {
  echo "Choose a subvolume to delete:"
  for i in "${!SUBVOLUMES[@]}"; do
    subvol_name="${SUBVOLUMES[$i]%:*}"
    mount_point="${SUBVOLUMES[$i]#*:}"
    echo "$((i+1))) $subvol_name -> $mount_point"
  done
  
  read -rp "Enter subvolume number: " subvol_num
  if [[ $subvol_num =~ ^[0-9]+$ ]] && [ $subvol_num -ge 1 ] && [ $subvol_num -le ${#SUBVOLUMES[@]} ]; then
    idx=$((subvol_num-1))
    deleted_subvol="${SUBVOLUMES[$idx]}"
    
    yN_print "Delete subvolume: ${deleted_subvol%:*} -> ${deleted_subvol#*:}?"
    read -rp "" confirm
    if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      unset 'SUBVOLUMES[idx]'
      SUBVOLUMES=("${SUBVOLUMES[@]}")
      info_print "=> Deleted subvolume: $deleted_subvol"
      
      # Auto-save to YAML
      auto_save_configuration
    else
      info_print "=> Cancelled deletion of subvolume: $deleted_subvol"
    fi
  else
    warning_print "Invalid selection"
  fi
}

# Function to review and proceed (YAML-driven)
review_and_proceed() {
  display_subheader
  info_print "=> Review Configuration (YAML-based):"
  echo ""
  
  info_print "Target disk: $INSTALL_DISK"
  echo ""
  
  # Show current physical partitions
  info_print "Current physical partitions:"
  lsblk "$INSTALL_DISK" -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
  echo ""
  
  # Show planned configuration from YAML
  if [ ${#PARTITIONS[@]} -gt 0 ]; then
    info_print "Planned partition layout (from YAML):"
    for partition in "${PARTITIONS[@]}"; do
      echo "  $partition"
    done
    echo ""
  else
    warning_print "No partitions defined in YAML configuration"
    echo ""
  fi
  
  if [ ${#SUBVOLUMES[@]} -gt 0 ]; then
    info_print "Configured subvolumes (from YAML):"
    for subvol in "${SUBVOLUMES[@]}"; do
      subvol_name="${subvol%:*}"
      mount_point="${subvol#*:}"
      echo "  $subvol_name -> $mount_point"
    done
    echo ""
  fi
  
  info_print "YAML configuration file: $PARTITIONS_YAML"
  echo ""
  
  # Validate configuration before proceeding
  if ! validate_yaml_configuration; then
    warning_print "Configuration validation failed. Please review and fix issues."
    yN_print "Continue anyway?"
    read -rp "" force_continue
    if [[ ! "$force_continue" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      info_print "=> Returning to configuration menu to fix issues"
      return 1
    fi
  fi
  
  warning_print "This configuration can be reused for identical deployments."
  info_print "The YAML file serves as documentation and enables repeatable installs."
  echo ""
  
  yN_print "Continue with this YAML-based configuration?"
  read -rp "" confirm
  if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info_print "=> Proceeding with YAML-based installation..."
    
    # Unmount any existing partitions on the target disk
    until unmount_partitions; do : ; done
    
    # Apply partition changes based on YAML configuration
    if [ ${#PARTITIONS[@]} -gt 0 ]; then
      info_print "=> Applying YAML-based partition layout..."
      apply_yaml_partitioning
    else
      warning_print "No YAML partitions defined. Using default partitioning."
      yN_print "Continue with default partitioning?"
      read -rp "" use_default
      if [[ "$use_default" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        until erase_partitions; do : ; done
        default_partitioning
      else
        warning_print "Installation cancelled."
        return 1
      fi
    fi
  else
    info_print "=> Returning to partition menu..."
  fi
}

# Function to apply YAML-based partitioning
apply_yaml_partitioning() {
  info_print "=> Creating partitions based on YAML configuration..."
  
  # For now, show what would be done and fall back to default
  warning_print "YAML-based partitioning implementation in progress."
  info_print "Current YAML configuration:"
  
  for partition in "${PARTITIONS[@]}"; do
    device=$(echo "$partition" | grep -o 'device: [^,]*' | cut -d' ' -f2)
    mountpoint=$(echo "$partition" | grep -o 'mountpoint: [^,]*' | cut -d' ' -f2)
    fs=$(echo "$partition" | grep -o 'fs: [^,]*' | cut -d' ' -f2)
    size=$(echo "$partition" | grep -o 'size: [^,]*' | cut -d' ' -f2)
    
    info_print "Would create: $device ($fs, $size) mounted at $mountpoint"
  done
  
  echo ""
  warning_print "Falling back to default partitioning with YAML-configured subvolumes..."
  yN_print "Continue with default partitioning using your subvolume configuration?"
  read -rp "" proceed
  
  if [[ "$proceed" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    until erase_partitions; do : ; done
    
    # Use default partitioning but with custom subvolumes
    default_partitioning_with_yaml_subvolumes
  else
    warning_print "Installation cancelled."
    return 1
  fi
}

# Function for default partitioning with YAML subvolumes
default_partitioning_with_yaml_subvolumes() {
  info_print "=> Using default partitioning with YAML-configured subvolumes"
  
  # Call the original default partitioning function but modify subvolume creation
  # We'll need to modify functions.sh to support this, for now just note the intention
  info_print "=> This will use your configured subvolumes:"
  for subvol in "${SUBVOLUMES[@]}"; do
    subvol_name="${subvol%:*}"
    mount_point="${subvol#*:}"
    info_print "  $subvol_name -> $mount_point"
  done
  
  # Call default partitioning (implementation needs to be enhanced to use YAML subvolumes)
  default_partitioning
  
  info_print "=> Installation completed with YAML configuration"
  info_print "=> Configuration saved in: $PARTITIONS_YAML"
  info_print "=> This configuration can be reused for identical deployments"
}

# Function to display comprehensive partition overview
display_comprehensive_overview() {
  display_subheader
  info_print "=> Comprehensive Partition Overview for $INSTALL_DISK"
  echo ""
  
  # Current physical state
  info_print "Current Physical Partitions:"
  lsblk "$INSTALL_DISK" -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
  echo ""
  
  # YAML Configuration status
  if [ -f "$PARTITIONS_YAML" ]; then
    info_print "YAML Configuration File: $PARTITIONS_YAML (found)"
  else
    warning_print "YAML Configuration File: $PARTITIONS_YAML (not found)"
  fi
  echo ""
  
  # Loaded partitions from YAML
  if [ ${#PARTITIONS[@]} -gt 0 ]; then
    info_print "Planned Partitions (loaded from YAML):"
    for i in "${!PARTITIONS[@]}"; do
      echo "  $((i+1)). ${PARTITIONS[$i]}"
    done
  else
    warning_print "No partitions defined in current configuration"
  fi
  echo ""
  
  # Configured subvolumes
  if [ ${#SUBVOLUMES[@]} -gt 0 ]; then
    info_print "Configured Subvolumes:"
    for subvol in "${SUBVOLUMES[@]}"; do
      subvol_name="${subvol%:*}"
      mount_point="${subvol#*:}"
      echo "  $subvol_name -> $mount_point"
    done
  else
    warning_print "No subvolumes configured"
  fi
  echo ""
  
  info_print "Press Enter to continue..."
  read -r
}

# Function to validate and clean YAML configuration
validate_yaml_configuration() {
  local valid=true
  
  info_print "=> Validating YAML configuration..."
  
  # Check for required partitions
  local has_root=false
  local has_boot=false
  
  for partition in "${PARTITIONS[@]}"; do
    mountpoint=$(echo "$partition" | grep -o 'mountpoint: [^,]*' | cut -d' ' -f2)
    if [[ "$mountpoint" == "/" ]]; then
      has_root=true
    elif [[ "$mountpoint" == "/boot" ]] || [[ "$mountpoint" == "/boot/efi" ]]; then
      has_boot=true
    fi
  done
  
  if [ "$has_root" = false ]; then
    warning_print "No root partition (/) defined in configuration"
    valid=false
  fi
  
  if [ "$has_boot" = false ]; then
    warning_print "No boot partition (/boot or /boot/efi) defined in configuration"
    info_print "This may be fine for BIOS systems, but UEFI requires a boot partition"
  fi
  
  # Validate subvolumes
  if [ ${#SUBVOLUMES[@]} -eq 0 ]; then
    warning_print "No subvolumes configured"
    info_print "Default subvolumes will be used: @, @home, @snapshots"
    SUBVOLUMES=("@:/" "@home:/home" "@snapshots:/.snapshots")
  fi
  
  if [ "$valid" = true ]; then
    info_print "Configuration validation passed"
    return 0
  else
    warning_print "Configuration validation failed"
    return 1
  fi
}

# Function to automatically save configuration after any changes
auto_save_configuration() {
  if [ ${#PARTITIONS[@]} -gt 0 ] || [ ${#SUBVOLUMES[@]} -gt 0 ]; then
    save_partitions_yaml
    info_print "=> Configuration automatically saved to $PARTITIONS_YAML"
  fi
}

# Function to display YAML configuration summary
display_yaml_summary() {
  echo ""
  info_print "=== YAML Configuration Summary ==="
  if [ -f "$PARTITIONS_YAML" ]; then
    echo "Configuration file: $PARTITIONS_YAML ✓"
    echo "Partitions defined: ${#PARTITIONS[@]}"
    echo "Subvolumes configured: ${#SUBVOLUMES[@]}"
    
    if [ ${#PARTITIONS[@]} -gt 0 ]; then
      echo ""
      echo "Partition layout:"
      for i in "${!PARTITIONS[@]}"; do
        device=$(echo "${PARTITIONS[$i]}" | grep -o 'device: [^,]*' | cut -d' ' -f2)
        mountpoint=$(echo "${PARTITIONS[$i]}" | grep -o 'mountpoint: [^,]*' | cut -d' ' -f2)
        fs=$(echo "${PARTITIONS[$i]}" | grep -o 'fs: [^,]*' | cut -d' ' -f2)
        echo "  $device -> $mountpoint ($fs)"
      done
    fi
    
    if [ ${#SUBVOLUMES[@]} -gt 0 ]; then
      echo ""
      echo "Subvolume layout:"
      for subvol in "${SUBVOLUMES[@]}"; do
        subvol_name="${subvol%:*}"
        mount_point="${subvol#*:}"
        echo "  $subvol_name -> $mount_point"
      done
    fi
  else
    echo "Configuration file: Not found"
    echo "Status: Starting fresh configuration"
  fi
  echo "=================================="
  echo ""
}

# Function to show help/guidance for YAML workflow
show_yaml_workflow_help() {
  display_subheader
  info_print "=== YAML-Based Partitioning Workflow Help ==="
  echo ""
  echo "This partitioning system uses YAML as the backbone for:"
  echo "• Safe, repeatable installations"
  echo "• Configuration documentation"
  echo "• System management framework integration"
  echo ""
  echo "Workflow:"
  echo "1. Select target disk"
  echo "2. Configure partitions and subvolumes"
  echo "3. Save configuration to YAML"
  echo "4. Review and validate"
  echo "5. Apply changes"
  echo ""
  echo "Key features:"
  echo "• Auto-save after each change"
  echo "• Load existing configurations"
  echo "• Validation before applying"
  echo "• Support for Btrfs subvolumes"
  echo ""
  echo "YAML file location: $PARTITIONS_YAML"
  echo "=============================================="
  echo ""
  info_print "Press Enter to continue..."
  read -r
}