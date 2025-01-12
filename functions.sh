#!/usr/bin/env bash

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"

source <(curl -s $RAW_GITHUB/$REPO/colors.sh)

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
                                                                 
  ======================= ARCH LINUX BASED =====================
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
  "Welcome to my Arch Linux Base installation script.
  This script will streamline the installation process, creating a minimal Arch Linux system.
  
  ${WARNING}
  Please be aware that this script will use the entire selected disk for the installation.
  Ensure you have backed up any important data before proceeding.
  Please ensure you have a stable internet connection before proceeding.

EOL
  echo -e "${RESET}"
  echo -e "${INFO}Press ${INPUT}Enter${INFO} to continue...${RESET}"
  read -rp ""
}

# Display partition WARNING message (function).
partition_warning() {
  warning_bold "
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !! WARNING: This will destroy all data on the target disk. Proceed with  !!
    !! caution. If you are unsure, answer 'N' or Ctrl+C to abort this script. !!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  "
}

# List block devices and prompt user for target install disk (function).
target_disk() {
  display_header
  info_print "=== List of available block devices ==="
  lsblk -o NAME,SIZE,TYPE,MODEL
  info_print "======================================="
  local devices=($(lsblk -dn -o NAME))
  for i in "${!devices[@]}"; do
    input_print "$((i+1)). ${devices[$i]}"
  done
  input_print "Enter the number corresponding to the block device you want to install to:"
  read -rp "" choice
  INSTALL_DISK="/dev/${devices[$((choice-1))]}"
  echo ""
  Yn_print "You chose: $INSTALL_DISK, is this correct?"
  read -rp confirm
  if [[ "$confirm" =~ ^([nN][oO]?|[nN])$ ]]; then
    Yn_print "Do you want to select the disk again, "Nn" will exit this installer?"
    read -rp action
    if [[ "$action" =~ ^([yY])$ ]]; then
      target_disk
    else
      warning_print "Aborting installation."
      exit 1
    fi
  fi
}

# Check for existing partitions and prompt for confirmation to overwrite (function).
erase_partitions() {
  display_header
  if lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}(p?[0-9]+)"; then
    display_warning
    info_print "Warning: Existing partitions found on $INSTALL_DISK."
    yN_print "Do you want to overwrite the existing partitions? This will delete all data on the disk."
    read -rp OVERWRITE_CONFIRMATION
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

# Unmount partitions (function).
unmount_partitions() {
  display_header
  info_print "=> Checking for mounted partitions on $INSTALL_DISK"
  sleep 1
  while mount | grep "$INSTALL_DISK" >/dev/null; do
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

# Choose a kernel to install (function).
choose_kernel() {
  display_header
  info_print "=> Choose a kernel to install:"
  choices_print "1" ") linux: (default) Vanilla kernel, with Arch Linux patches."
  choices_print "2" ") linux-lts: Long-term Support kernel."
  choices_print "3" ") linux-zen: Kernel with the desktop optimizations."
  choices_print "4" ") linux-hardened: a Security-focused kernel."
  read -rp "${INFO}Kernel choice [1-4]: " KERNEL_CHOICE
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

# Setting up a password for the root account (function).
set_root_password() {
  display_header
  while true; do
    Echo -e "${INFO}Enter root password: ${RESET}"
    read -s -rp "" ROOT_PASS1
    echo
    if [[ -z "$ROOT_PASS1" ]]; then
        echo
        error_print "You need to enter a password for the root user, please try again."
        return 1
    fi
    read -s -rp "Confirm root password: " ROOT_PASS2
    echo
    if [ "$ROOT_PASS1" == "$ROOT_PASS2" ]; then
      echo "=> Setting root password"
      ROOT_PASS="$ROOT_PASS1"
      break
    else
      echo "Passwords do not match. Please try again."
      sleep 1.5
    fi
  done
}

# Setting up a username and password for the user account (function).
create_new_user() {
  display_header
  info_print "Enter new username (must be all lowercase):"
  read -rp NEW_USER
  yN_print "Should $NEW_USER have sudo privileges?" 
  read -rp SUDO_CHOICE
  if [[ "$SUDO_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    SUDO_GROUP="-G wheel "
  else
    SUDO_GROUP=""
  fi

  while true; do
    info_print "Enter password for $NEW_USER:"
    read -s -rp USER_PASS1
    echo
    info_print 
    read -s -rp "${INFO}Confirm password for $NEW_USER:  ${RESET}" USER_PASS2
    echo
    if [ "$USER_PASS1" == "$USER_PASS2" ]; then
      USER_PASS="$USER_PASS1"
      break
    else
      warning_print "Passwords do not match. Please try again."
      sleep 1.5
      return 1
    fi
  done
}

# User selects a hostname (function).
set_hostname() {
  display_header
  read -rp "${INFO}Enter hostname: ${RESET}" HOSTNAME
}

# User selects a locale (function).
select_locale() {
  info_print "=> Start typing to search for a locale, press Enter to select."
  
  # Read the available locales into an array
  mapfile -t locales < <(grep -E '^[a-z]{2,}_[A-Z]{2,}' /mnt/etc/locale.gen | awk '{print $1}')
  
  # Use fzf to select a locale
  selected_locale=$(printf "%s\n" "${locales[@]}" | fzf --prompt="Search: " --header="Locales available:")

  if [[ -n "$selected_locale" ]]; then
    echo "Selected locale: $selected_locale"
    LOCALE="$selected_locale"
  else
    echo "No locale selected."
  fi
}

# User selects a timezone (function).
select_timezone() {
  display_header
  info_print "=> Start typing to search for a timezone, press Enter to select."
  
  # Read the available timezones into an array
  mapfile -t timezones < <(timedatectl list-timezones)
  
  # Use fzf to select a timezone
  selected_timezone=$(printf "%s\n" "${timezones[@]}" | fzf --prompt="Search: " --header="Timezones available:")

  if [[ -n "$selected_timezone" ]]; then
    echo "Selected timezone: $selected_timezone"
    TIMEZONE="$selected_timezone"
  else
    echo "No timezone selected."
  fi
}

# Microcode detector (function).
microcode_detector () {
  display_header
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        MICROCODE="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        MICROCODE="intel-ucode"
    fi
}

# Detect and install GPU drivers (function).
gpu_drivers() {
  display_header
  info_print "=> Checking for a dedicated GPU"
  sleep 1
  if lspci | grep -i -E "VGA compatible controller|3D controller"; then
    display_header
    yN_print "Dedicated GPU detected. Would you like to install GPU drivers?"
    read -rp INSTALL_GPU
    if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      info_print "=> Installing GPU drivers (this may take a while)"
      sleep 1
      INSTALL_GPU_DRIVERS=true
    else
      info_print "=> Skipping GPU driver installation"
      sleep 1
    fi
  else
    info_print "No dedicated GPU detected."
    sleep 1
  fi
}

# Choose a bootloader to install (function).
choose_bootloader() {
  display_header
  echo "=> Choose a bootloader to install:"
  sleep 1.5
  echo "   1) GRUB"
  echo "   2) systemd-boot"
  echo "   3) rEFInd"
  read -rp "Enter your choice (1-3, default is 1): " BOOTLOADER_CHOICE
  case "$BOOTLOADER_CHOICE" in
    2)
      BOOTLOADER="systemd-boot"
      ;;
    3)
      BOOTLOADER="rEFInd"
      ;;
    *)
      BOOTLOADER="grub"
      ;;
  esac
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