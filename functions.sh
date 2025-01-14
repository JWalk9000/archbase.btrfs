#!/usr/bin/bash


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

# User selects a hostname (function).
set_hostname() {
  display_header
  read -rp "$(info_print "Enter a name (hostname) for this computer: ")" HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    warning_print "You need to enter a hostname, please try again."
    return 1
  fi
}

# Setting up a password for the root account (function).
set_root_password() {
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
  info_print "=> Refreshing locale list"
  sleep 1

  # Use the locale.gen file from the install image
  cp /etc/locale.gen /tmp/locale.gen

  info_print "=> Start typing to search for a locale, press Enter to select."
  sleep 1
  
  # Read the available locales into an array
  mapfile -t locales < <(grep -E '^[#]*[a-z]{2,}_[A-Z]{2,}' /tmp/locale.gen | sed 's/^#//' | awk '{print $1}')
  
  # Use fzf to select a locale
  selected_locale=$(printf "%s\n" "${locales[@]}" | fzf --prompt="Search: " --header="Locales available:")

  if [[ -n "$selected_locale" ]]; then
    echo "Selected locale: $selected_locale"
    LOCALE="$selected_locale"
  else
    warning_print "No locale selected. Please try again."
    return 1
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

# Choose a kernel to install (function).
choose_kernel() {
  display_header
  info_print "=> Choose a kernel to install:"
  choices_print "1" ") linux: (default) Vanilla kernel, with Arch Linux patches."
  choices_print "2" ") linux-lts: Long-term Support kernel."
  choices_print "3" ") linux-zen: Kernel with the desktop optimizations."
  choices_print "4" ") linux-hardened: a Security-focused kernel."
  select_print "1" "4" "Kernel choice" KERNEL_CHOICE
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

# Install user-specified packages (function).
user_packages() {
  display_header
  info_print "By default, in addition to the base system this installer will also install the following packages:
  - networkmanager
  - nano
  - git
  - openssh
  - pciutils
  - usbutils
  " 
  Yn_print "Did you create a userpkgs.txt file with optional packages to install?"
  read -rp "" USERPKGS_FILE
  if [[ "$USERPKGS_FILE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    while true; do
      info_print "=> Checking for userpkgs.txt at $RAW_GITHUB/$REPO/userpkgs.txt"
      sleep 1
      if curl --output /dev/null --silent --head --fail "$RAW_GITHUB/$REPO/userpkgs.txt"; then
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
      while true; do
        info_print "Enter the packages you would like to install, separated by a space:"
        read -rp "" USERPKGS
        info_print "I will now check that those packages are available to install."
        sleep 1
        VERIFIED_PKGS=""
        for PKG in $USERPKGS; do
          if ! pacman -Si "$PKG" > /dev/null; then
            warning_print "Package $PKG not found in the repositories."
            Yn_print "Would you like to change the spelling?"
            read -rp "" CHANGE_SPELLING
            if [[ "$CHANGE_SPELLING" =~ ^([yY][eE][sS]|[yY])$ ]]; then
              read -rp "Enter the correct package name: " FIXPKG
              if pacman -Si "$FIXPKG" > /dev/null; then
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
        USERPKGS=$VERIFIED_PKGS
        break
      done
    fi
  fi

  if [[ -n "$USERPKGS" ]]; then
    info_print "The following packages will be installed: $USERPKGS"
  else
    warning_print "No packages to install."
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
      INSTALL_GPU_DRIVERS="nvidia nvidia-utils"
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
# Post installation functions.. WIP
#
####################################################################################################



# Enable Auto-login for the user (function).
autologin_setup() {
  display_header
  Yn_print "Would you like to enable autologin for the $NEW_USER?"
  read -rp "" AUTOLOGIN_CHOICE
  if [[ "$AUTOLOGIN_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    AUTOLOGIN_CHOICE="true"
    info_print "=> Setting up autologin for the first boot"
  fi
}    
    
desktop_environment() {
  display_header
  echo -e "${BWARNING}[EXPERIMENTAL]${RESET}"
  Yn_print "Would you like to enable the desktop environment install script as a command?"
  read -rp "" DESKTOP_CHOICE
  if [[ "$DESKTOP_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    DESKTOP_CHOICE="true"    
  fi
}
