#!/usr/bin/bash


####################################################################################################
#
# header and message functions
#
####################################################################################################
# Function to display the header.
display_header() {
  clear
  tput cup 0 0  
  echo -e "${BANNER}"
  cat <<"EOF"
                                                                 
     __                     _  _      ___    ___    ___    ___   
     \ \  __      __  __ _ | || | __ / _ \  / _ \  / _ \  / _ \  
      \ \ \ \ /\ / / / _` || || |/ /| (_) || | | || | | || | | | 
   /\_/ /  \ V  V / | (_| || ||   <  \__, || |_| || |_| || |_| | 
   \___/    \_/\_/   \__,_||_||_|\_\   /_/  \___/  \___/  \___/  
                                                                 
  ======================= ARCH LINUX BASE ======================
         _____              _           _  _                      
         \_   \ _ __   ___ | |_   __ _ | || |  ___  _ __         
          / /\/| '_ \ / __|| __| / _` || || | / _ \| '__|        
       /\/ /_  | | | |\__ \| |_ | (_| || || ||  __/| |           
       \____/  |_| |_||___/ \__| \__,_||_||_| \___||_|           
EOF
  echo -e "${RESET}"
  tput cup 15 0
}

# Function to greet user, and provide information about the script
greet_user() {
  echo -e "${INFO}"
  cat << EOL
  Welcome to my Arch Linux Base installation script.
  This script will streamline the installation process, creating a minimal Arch Linux system.
  After entering your choices it will create a boot partition, and a system partition using Btrfs 
  and Btrfs sudirectories for the 'home', 'root', and '.snapshots' subdirectories before 
  installing the base system.
  
EOL
}

# Display warning message.
display_warning() {
  echo -e "${WARNING}
  Please be aware that this script will use the entire selected disk for the installation.
  Ensure you have backed up any important data before proceeding.
  Please ensure you have a stable internet connection before proceeding."

  echo -e "${RESET}"
  read -rp "$(echo -e ${INFO}Press ${INPUT}Enter${INFO} to proceed, ${INPUT}CTRL+C${INFO} to abort...${RESET})"
}

# Display partition WARNING message (function).
partition_warning() {
  warning_bold "
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !! WARNING: This will destroy all data on the target disk. Proceed with   !!
    !! caution. If you are unsure, answer 'N' or Ctrl+C to abort this script. !!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  "
}

# Start the installation process (function).
install_message() {
  display_header
  info_print ""
  info_print " Time to sit back and relax, maybe go grab a coffee, this will take a while."
  info_print ""
  tput cup 20 0 
  sleep 1
}




####################################################################################################
#
# system configuration functions
#
####################################################################################################

# User selects a hostname (function).
select_hostname() {
  display_header
  read -rp "$(info_print "Enter a name (hostname) for this computer: ")" HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    warning_print "You need to enter a hostname, please try again."
    return 1
  fi
}

# Setting up a password for the root account (function).
select_root_password() {
  display_header
  while true; do
    read -s -rp "$(echo -e ${INFO}Enter a password for root: ${RESET})" ROOT_PASS1
    echo ""
    if [[ -z "$ROOT_PASS1" ]]; then
        warning_print "You need to enter a password for the root user, please try again."
        sleep 2
        return 1
    fi
    read -s -rp "$(echo -e ${INFO}Confirm the password for root: ${RESET})" ROOT_PASS2
    echo ""
    if [ "$ROOT_PASS1" == "$ROOT_PASS2" ]; then
      ROOT_PASS="$ROOT_PASS1"
      break
    else
      warning_print "Passwords do not match. Please try again."
      sleep 2
      return 1
    fi
  done
}

# Setting up a username and password for the user account (function).
create_new_user() {
  display_header
  read -rp "$(info_print "Enter new username (must be all lowercase):")" NEW_USER
  echo ""
  if [[ -z "$NEW_USER" ]]; then
    warning_print "You need to enter a username, please try again."
    sleep 2
    return 1
  fi
  read -rp "$(yN_print "Should ${NEW_USER} have sudo privileges?")" SUDO_CHOICE
  echo ""
  if [[ "$SUDO_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    SUDO_GROUP="true"
  else
    SUDO_GROUP=""
  fi

  while true; do
    read -s -rp "$(info_print "Enter password for ${NEW_USER}: ")" USER_PASS1
    echo ""
    if [[ -z "$USER_PASS1" ]]; then
      warning_print "You need to enter a password for the new user, please try again."
      sleep 2
      continue
    fi
    read -s -rp "$(info_print "Confirm password for ${NEW_USER}: ")" USER_PASS2
    echo ""
    if [ "$USER_PASS1" == "$USER_PASS2" ]; then
      USER_PASS="$USER_PASS1"
      break
    else
      warning_print "Passwords do not match. Please try again."
      sleep 2
    fi
  done
}

select_locale() {
  display_header
  echo ""
  info_print "=> Refreshing locale list"
  local INSTRUCTIONS="
  => Start typing and/or use 'up' and 'down' arrows to search for a locale, this uses fuzzy find. 
     For instance: 'enust' to find 'en_US.UTF-8' ( US English with support for UTF-8 character set).
  
     Press Enter to select once you have found the desired locale.
     
     Locales available:"
  
  # Use the locale.gen file from the install image
  cp /etc/locale.gen /tmp/locale.gen
  
  # Read the available locales into an array
  mapfile -t locales < <(grep -E '^[#]*[a-z]{2,}_[A-Z]{2,}' /tmp/locale.gen | sed 's/^#//' | awk '{print $1}')
  
  # Use fzf to select a locale
  selected_locale=$(printf "%s\n" "${locales[@]}" | fzf --prompt="Search: " --header="$INSTRUCTIONS")

  if [[ -n "$selected_locale" ]]; then
    info_print "Selected locale: $selected_locale"
    LOCALE="$selected_locale"
  else
    warning_print "No locale selected. Please try again."
    return 1
  fi
}

# User selects a timezone (function).
select_timezone() {
  display_header
  local INSTRUCTIONS="
  => Start typing and/or use 'up' and 'down' arrows to search for a timezone, this uses fuzzy find. 
     For instance: 'eulo' to find 'Europe/London', or 'cace' to fine 'Canada/Central'.
  
     Press Enter to select once you have found the desired locale.
     
     Timezones available:"

  # Read the available timezones into an array
  mapfile -t timezones < <(timedatectl list-timezones)
  
  # Use fzf to select a timezone
  selected_timezone=$(printf "%s\n" "${timezones[@]}" | fzf --prompt="Search: " --header="$INSTRUCTIONS")

  if [[ -n "$selected_timezone" ]]; then
    info_print "Selected timezone: $selected_timezone"
    TIMEZONE="$selected_timezone"
  else
    warning_print "No timezone selected."
  fi
}

# Choose a kernel to install (function).
choose_kernel() {
  display_header
  info_print "=> Choose a kernel to install:"
  choices_print "1" ") linux: (default) Vanilla kernel, with Arch Linux patches."
  choices_print "2" ") linux-lts: Long-term Support kernel."
  choices_print "3" ") linux-zen: Kernel with the desktop optimizations."
  choices_print "4" ") linux-hardened: a Security-focused kernel."
  select_print "1" "4" "Kernel choice: " KERNEL_CHOICE
  case $KERNEL_CHOICE in
    1)
      KERNEL_PKG="linux"
      return 0;;
    2)
      KERNEL_PKG="linux-lts"
      return 0;;
    3)
      KERNEL_PKG="linux-zen"
      return 0;;
    4)
      KERNEL_PKG="linux-hardened"
      return 0;;
    *)
      KERNEL_PKG="linux"
      return 0;;
  esac
}

# Check if system is running in a virtual machine (function).
detect_vm() {
  info_print "=> Detecting whether the system is running in a virtual machine"
  sleep 1.5
  VIRT_TYPE=$(systemd-detect-virt)
  case "$VIRT_TYPE" in
    "oracle")
      info_print "Running in a VirtualBox virtual machine. Installing VirtualBox guest utilities."
      sleep 1.5
      BASE_PKGS+=$(yq eval -r ".virt.oracle.packages[]" $YAML_FILE | tr '\n' ' ')
      ENABLE_SVCS+=$(yq eval -r ".virt.oracle.services[]" $YAML_FILE | tr '\n' ' ')
      ;;
    "vmware")
      info_print "Running in a VMware virtual machine. Installing VMware guest utilities."
      sleep 1.5
      BASE_PKGS+=$(yq eval -r ".virt.vmware.packages[]" $YAML_FILE | tr '\n' ' ')
      ENABLE_SVCS+=$(yq eval -r ".virt.vmware.services[]" $YAML_FILE | tr '\n' ' ')
      ;;
    "kvm")
      info_print "Running in a KVM or QEMU virtual machine. Installing QEMU guest utilities." 
      sleep 1.5
      BASE_PKGS+=$(yq eval -r ".virt.kvm.packages[]" $YAML_FILE | tr '\n' ' ')
      ENABLE_SVCS+=$(yq eval -r ".virt.kvm.services[]" $YAML_FILE | tr '\n' ' ')
      ;;
    "microsoft")
      info_print "Running in a Hyper-V virtual machine. Installing Hyper-V guest utilities."
      sleep 1.5
      BASE_PKGS+=$(yq eval -r ".virt.microsoft.packages[]" $YAML_FILE | tr '\n' ' ')
      ENABLE_SVCS+=$(yq eval -r ".virt.microsoft.services[]" $YAML_FILE | tr '\n' ' ')
      ;;
    "xen")
      info_print "Running in a Xen virtual machine. Installing Xen guest utilities."
      sleep 1.5
      BASE_PKGS+=$(yq eval -r ".virt.xen.packages[]" $YAML_FILE | tr '\n' ' ')
      ENABLE_SVCS+=$(yq eval -r ".virt.xen.services[]" $YAML_FILE | tr '\n' ' ')
      ;;
    "none" | "")
      echo "Not running in a virtual machine."
      sleep 1.5
      ;;
    *)
      echo "Unknown virtualization type: $VIRT_TYPE, no additional packages will be installed."
      sleep 1.5
      ;;
  esac
}

# Package and service lists for the role options
system_role() {
  local ROLE=$1
  ROLE_PKGS=$(yq -r ".roles.$ROLE.packages[]" $YAML_FILE | tr '\n' ' ')
  ENABLE_SVCS+=$(yq -r ".roles.$ROLE.services[]" $YAML_FILE | tr '\n' ' ') 
}

# Choose a role for the system (function).
choose_role() {
  display_header
  info_print "Below are some available system roles to choose from. If you created a userpkgs.txt file, you can skip this step or select a role as well. 
  I suggest choosing to install Hyperland if you intend on using the fistBoot.sh script to install a hyperland configuration.
  "
  info_print "=> Select a role:"
  choices_print "0" ") Skip/Custom"
  choices_print "1" ") Server ----------------- A basic server setup with some common services aiming at a similar experience to Ubuntu Server."
  choices_print "2" ") Desktop - XFCE --------- A lightweight desktop environment, similar layout to MS Windows 7."
  choices_print "3" ") Desktop - KDE Plasma --- A modern, feature-rich desktop environment, similar layout MS Windows 10/11."
  choices_print "4" ") Desktop - GNOME -------- A modern, feature-rich desktop environment, similar layout to macOS."
  choices_print "5" ") Desktop - Hyprland ----- A highly customizable dynamic tiling Wayland compositor keyboard-shortcut-driven."
  select_print "0" "5" "System role: " "SYSTEM_ROLE"
  case $SYSTEM_ROLE in
    1)
      system_role server
      return 0;;
    2)
      system_role xfce
      return 0;;
    3)
      system_role kde
      return 0;;
    4)
      system_role gnome
      return 0;;
    5)
      system_role hypr
      return 0;;
    *)
      ROLE_PKGS=""
      return 0;;
  esac
  
}

# Consolidate all package lists (function).
package_lists() {
  BASE_PKGS+=$(yq -r '.base.packages[]' $YAML_FILE | tr '\n' ' ')
  SYSTEM_PKGS="$BASE_PKGS $MICROCODE $INSTALL_GPU_DRIVERS $KERNEL_PKG $ROLE_PKGS $USERPKGS"
  SYSTEM_PKGS=$(echo $SYSTEM_PKGS | tr -s ' ')
  ENABLE_SVCS+=$(yq -r ".base.services[]" $YAML_FILE | tr '\n' ' ')
}

# Install user-specified packages (function).
verify_packages() {
  VERIFIED_PKGS=""
  for PKG in $USERPKGS; do
    if ! pacman -Si "$PKG" > /dev\null; then
      warning_print "Package $PKG not found in the repositories."
      Yn_print "Would you like to change the spelling?"
      read -rp "" CHANGE_SPELLING
      if [[ "$CHANGE_SPELLING" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        read -rp "Enter the correct package name: " FIXPKG
        if pacman -Si "$FIXPKG" > /dev\null; then
          VERIFIED_PKGS="$VERIFIED_PKGS $FIXPKG"
        else
          warning_print "Package $FIXPKG not found in the repositories."
          Yn_print "Would you like to try again?"
          read -rp "" TRY_AGAIN
          if [[ "$TRY_AGAIN" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            continue
          else
            break
          fi
        fi
      else
        continue
      fi
    else
      VERIFIED_PKGS="$VERIFIED_PKGS $PKG"
    fi
  done
}

user_packages() {
  display_header
  info_print "By default, in addition to the base system this installer will also install the following packages:"
  for PKG in "${BASE_PKGS[@]}"; do
    info_print "  - $PKG"
  done

  Yn_print "Did you create a userpkgs.txt file with optional packages to install?"
  read -rp "" USERPKGS_FILE
  if [[ "$USERPKGS_FILE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    while true; do
      info_print "=> Checking for userpkgs.txt at $RAW_GITHUB/$REPO/userpkgs.txt"
      sleep 1
      if curl --output /dev\null --silent --head --fail "$RAW_GITHUB/$REPO/userpkgs.txt"; then
        info_print "=> User's packages list will be installed to the system."
        USERPKGS=$(curl -s "$RAW_GITHUB/$REPO/userpkgs.txt")
        break
      else
        warning_print "No userpkgs.txt file found at $RAW_GITHUB/$REPO/userpkgs.txt."
        Yn_print "Would you like to try again? Check the file name and location before proceeding."
        read -rp "" TRY_AGAIN
        if [[ "$TRY_AGAIN" =~ ^([nN][oO]?|[nN])$ ]]; then
          break
        fi
      fi
    done
  fi

  if [[ -z "$USERPKGS" ]]; then
    Yn_print "Would you like to enter the packages manually as a space-separated list?"
    read -rp "" ENTER_MANUALLY
    if [[ "$ENTER_MANUALLY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      info_print "Enter the packages you would like to install, separated by a space:"
      read -rp "" USERPKGS
      info_print "I will now check that those packages are available to install."
      sleep 1
      verify_packages
      USERPKGS=$VERIFIED_PKGS
    fi
  fi

  if [[ -n "$USERPKGS" ]]; then
    info_print "The following packages will be installed: $USERPKGS"
  else
    warning_print "No packages to install."
  fi
}

# Enable Auto-login for the user (function).
autologin_choice() {
  display_header
  Yn_print "Would you like to enable autologin for the $NEW_USER?"
  read -rp "" AUTOLOGIN_CHOICE
  if [[ "$AUTOLOGIN_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    AUTOLOGIN_CHOICE="true"
    info_print "=> Setting up autologin for the first boot"
  fi
}    

# Microcode detector (function).
microcode_detector () {
  display_header
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        MICROCODE="amd-ucode"
        sleep 2
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        MICROCODE="intel-ucode"
        sleep 2
    fi
}

# Detect and install GPU drivers (function).
gpu_drivers() {
  display_header
  info_print "=> Checking for a dedicated GPU"
  sleep 1.5

  # Check for NVIDIA GPU
  if lspci | grep -i "NVIDIA" | grep -i "VGA compatible controller"; then
    display_header
    yN_print "NVIDIA GPU detected. Would you like to install NVIDIA drivers?"
    read -rp "" INSTALL_GPU
    if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      INSTALL_GPU_DRIVERS=("nvidia-dkms" "nvidia-utils" "nvidia-settings" "lib32-nvidia-utils" "egl-wayland")
    else
      info_print "=> Skipping NVIDIA driver installation"
      INSTALL_GPU_DRIVERS=""
      sleep 1.5
    fi
  # Check for AMD GPU
  elif lspci | grep -i "AMD/ATI" | grep -i "VGA compatible controller"; then
    display_header
    yN_print "AMD GPU detected. Would you like to install AMD drivers?"
    read -rp "" INSTALL_GPU
    if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      INSTALL_GPU_DRIVERS="xf86-video-amdgpu"
    else
      info_print "=> Skipping AMD driver installation"
      INSTALL_GPU_DRIVERS=""
      sleep 1.5
    fi
  # Check for Intel GPU
  elif lspci | grep -i "Intel Corporation" | grep -i "VGA compatible controller"; then
    display_header
    yN_print "Intel GPU detected. Would you like to install Intel drivers?"
    read -rp "" INSTALL_GPU
    if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      INSTALL_GPU_DRIVERS="xf86-video-intel"
    else
      info_print "=> Skipping Intel driver installation"
      INSTALL_GPU_DRIVERS=""
      sleep 1.5
    fi
  else
    info_print "No dedicated GPU detected."
    INSTALL_GPU_DRIVERS=""
    sleep 1.5
  fi
}

# Choose a bootloader to install (function).
choose_bootloader() {
  display_header
  if [ -d /sys/firmware/efi/efivars ]; then
    EFIBOOTMGR="efibootmgr"
    info_print "=> EFI system detected. Choose a bootloader to install:"
    choices_print " * 1)"" GRUB"
    choices_print "   2)"" systemd-boot"
    #choices_print "   3)"" rEFInd"
    select_print "1" "3" "Bootloader" "BOOTLOADER_CHOICE"
    case "$BOOTLOADER_CHOICE" in
      2)
        BOOTLOADER="systemd-boot"
        ;;
      #3)
      #  BOOTLOADER="rEFInd"
      #  ;;
      *)
        BOOTLOADER="grub"
        ;;
    esac
  else
    info_print "=> BIOS system detected. GRUB bootloader will be installed:"
    sleep 2
    BOOTLOADER="grub"
  fi
}

# List block devices and prompt user for target install disk (function).
target_disk() {
  display_header
  info_print "=== List of available block devices ==="
  lsblk -o NAME,SIZE,TYPE,MODEL
  info_print "======================================="
  local devices=($(lsblk -dn -o NAME))
  for i in "${!devices[@]}"; do
    choices_print "$((i+1))." "${devices[$i]}"
  done
  read -rp "$(info_print "Enter the number corresponding to the block device you want to install to: ")" choice
  INSTALL_DISK="/dev/${devices[$((choice-1))]}"
  echo ""
  Yn_print "You chose: $INSTALL_DISK, is this correct?"
  read -rp "" confirm
  if [[ "$confirm" =~ ^([nN][oO]?|[nN])$ ]]; then
    Yn_print "Do you want to select the disk again, "Nn" will exit this installer?"
    read -rp "" action
    if [[ "$action" =~ ^([yY])$ ]]; then
      target_disk
    else
      warning_print "Aborting installation."
      exit 1
    fi
  fi
}

# Unmount partitions (function).
unmount_partitions() {
  display_header
  info_print "=> Checking for mounted partitions on $INSTALL_DISK"
  sleep 1
  while mount | grep "$INSTALL_DISK" >/dev\null; do
    # Get the shortest (root-most) mount point for the disk
    local mount_point=$(lsblk -ln -o MOUNTPOINT "$INSTALL_DISK" | grep -v '^$' | sort | head -n 1)
    if [[ -z "$mount_point" ]]; then
      info_print "No more mount points found for $INSTALL_DISK"
      break
    fi
    info_print "Unmounting $mount_point"
    umount -R "$mount_point" || echo "Failed to unmount $mount_point"
    sleep 1
  done
  info_print "=> All mount points unmounted on $INSTALL_DISK"
  sleep 1
}

# Check for existing partitions and prompt for confirmation to overwrite (function).
erase_partitions() {
  display_header
  if lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)"; then
    partition_warning
    info_print "Warning: Existing partitions found on $INSTALL_DISK."
    yN_print "Do you want to overwrite the existing partitions? This will delete all data on the disk."
    read -rp "" OVERWRITE_CONFIRMATION
    if [[ "$OVERWRITE_CONFIRMATION" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      info_print "=> Removing existing partitions on $INSTALL_DISK"
      sgdisk --zap-all "$INSTALL_DISK"
      partprobe "$INSTALL_DISK"
      info_print "=> Existing partitions removed"
    else
      warning_print "Aborting installation."
      exit 1
    fi
  else
    info_print "No existing partitions found on $INSTALL_DISK"
  fi
}

partitioning() {
  install_message
  # Partition the disk
  if [ -d /sys/firmware/efi/efivars ]; then
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

    # Format the partitions
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
  else
    (
    echo o # Create a new empty DOS partition table
    echo n # Add a new partition
    echo p # Primary partition
    echo 1 # Partition number
    echo   # First sector (Accept default: 1MiB)
    echo   # Last sector (Accept default: varies)
    echo a # Make partition bootable
    echo 1 # Partition number
    echo w # Write changes
    ) | fdisk "$INSTALL_DISK"
    partprobe "$INSTALL_DISK"

    # Format the partitions
    if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
      BTRFS_PART="${INSTALL_DISK}p1"
    else
      BTRFS_PART="${INSTALL_DISK}1"
    fi
  fi

  info_print "=> Formatting primary partition as Btrfs"
  sleep 1
  mkfs.btrfs -f "$BTRFS_PART"

  # Create and mount Btrfs subvolumes
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

  # Mount EFI partition
  if [ -d /sys/firmware/efi/efivars ]; then
    info_print "=> Mounting EFI partition at /mnt/boot"
    sleep 1
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
  fi
}


####################################################################################################
#
# Installation functions
#
####################################################################################################

install_base_system() {
  install_message
  info_print "These are the packages that will be installed:"
  for PKG in $SYSTEM_PKGS; do
    info_print "  - $PKG"
  done  
  read -rp "$(echo -e ${INFO}Press ${INPUT}Enter${INFO} to proceed, ${INPUT}CTRL+C${INFO} to abort...${RESET})"
      echo ""
      info_print "These are the Services that will be Enabled:"
  for SVC in $ENABLE_SVCS; do
    info_print "  - $SVC"
  done  
  read -rp "$(echo -e ${INFO}Press ${INPUT}Enter${INFO} to proceed, ${INPUT}CTRL+C${INFO} to abort...${RESET})"
  info_print "=> Installing base system with selected role or custom packages"
  sleep 2
  pacstrap /mnt $SYSTEM_PKGS
}

set_timezone() {
  install_message
  info_print "=> Setting the timezone"
  sleep 1
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
  arch-chroot /mnt hwclock --systohc
}

set_locale() {
  install_message
  info_print "=> Setting the locale"
  sleep 1
  arch-chroot /mnt bash -c "echo \"$LOCALE UTF-8\" >> /etc/locale.gen"
  arch-chroot /mnt bash -c "echo \"LANG=$LOCALE\" > /etc/locale.conf"
  arch-chroot /mnt locale-gen
}

set_hostname() {
  install_message
  info_print "=> Setting the hostname"
  sleep 1
  arch-chroot /mnt bash -c "echo \"$HOSTNAME\" > /etc/hostname"
  arch-chroot /mnt bash -c "{
    echo \"127.0.0.1       localhost\"
    echo \"::1             localhost\"
    echo \"127.0.1.1       $HOSTNAME.localdomain $HOSTNAME\"
  } >> /etc/hosts"
}

set_root_password() {
  install_message
  sleep 1
  info_print "=> Setting the root password"
  sleep 1.25
  arch-chroot /mnt bash -c "echo \"root:$ROOT_PASS\" | chpasswd"
}

setup_new_user() {
  install_message
  info_print "=> Creating $NEW_USER's profile"
  sleep 1.25
  if [ "$SUDO_GROUP" == "true" ]; then
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash $NEW_USER
    arch-chroot /mnt bash -c "echo \"$NEW_USER ALL=(ALL) ALL\" > /etc/sudoers.d/$NEW_USER"
  else
    arch-chroot /mnt useradd -m -s /bin/bash $NEW_USER
  fi
  arch-chroot /mnt bash -c "echo \"$NEW_USER:$USER_PASS\" | chpasswd"
}

# Install the bootloader (function).
install_bootloader() {
  install_message
  info_print "=> Installing the bootloader"
  sleep 1
  if [ -d /sys/firmware/efi/efivars ]; then
    case "$BOOTLOADER" in
      "systemd-boot")
        pacman -S --noconfirm systemd-boot efibootmgr
        arch-chroot /mnt /bin/bash <<EOF
        bootctl --path=/boot install
EOF
        ;;
      "rEFInd")
        arch-chroot /mnt /bin/bash <<EOF
        pacman -S --noconfirm refind efibootmgr
        refind-install
        mkrlconf --root / --subvol @ --output /boot/refind_linux.conf
EOF
        ;;
      *)
        arch-chroot /mnt /bin/bash <<EOF
         pacman -S --noconfirm grub efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
EOF
        ;;
    esac
  else
    arch-chroot /mnt /bin/bash <<EOF
    pacman -S --noconfirm grub
    grub-install --target=i386-pc "$INSTALL_DISK"
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
  fi
}

# Enable services (function).
enable_services() {
  install_message
  local SERVICES=("${ENABLE_SVCS[@]}")
  mount --bind /sys /mnt/sys
  mount --bind /proc /mnt/proc
  mount --bind /dev /mnt/dev
  for SVC in $SERVICES; do
    arch-chroot /mnt systemctl enable "$SVC" && info_print "=> $SVC service enabled" || warning_print "=> $SVC service not enabled"
    sleep 1.5
  done
}

####################################################################################################
#
# Post installation functions.. WIP
#
####################################################################################################

    
# Offer post installation scripts (function).
desktop_scripts() {
  display_header
  echo -e "${BWARNING}[EXPERIMENTAL]${RESET}"
  Yn_print "Would you like to enable the custom desktop environment install script as a command?"
  read -rp "" DESKTOP_CHOICE
  if [[ "$DESKTOP_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    DESKTOP_CHOICE="true"    
  fi
}

# Install post installation scripts (function).
post_install_scripts() {
  mkdir -p /mnt/home/$NEW_USER/firstBoot
  info_print "=> Installing firstBoot scripts"
  sleep 1
  FB_FILES=(
    "firstBoot.sh"
    "gui_options.json"
  )
  info_print "=> Downloading and installing firstBoot scripts"
  sleep 1.25
  for FILE in "${FB_FILES[@]}"; do 
    curl -s "$RAW_GITHUB/$REPO/firstBoot/$FILE" | sed "s/user_placeholder/$NEW_USER/g" > /mnt/home/$NEW_USER/firstBoot/$FILE
    done
    info_print "=> Setting permissions for firstBoot scripts"
    sleep 1.25
  for FILE in "${FB_FILES[@]}"; do
    chmod +x /mnt/home/$NEW_USER/firstBoot/$FILE
  done
  info_print "=> checking that the firstBoot directory was populated"
  ls -l /mnt/home/$NEW_USER/firstBoot
  sleep 3

  # Change ownership to the new user
  arch-chroot /mnt chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/firstBoot

  
  # Add the firstBoot script to the system path
  echo "export PATH=\$PATH:/home/$NEW_USER/firstBoot" >> /mnt/home/$NEW_USER/.bashrc
}