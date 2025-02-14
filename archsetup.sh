#!/usr/bin/bash
set -e

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/dev"

#LOCALREPO=""    # <-- set this to the path of the local repo if you are using locally. DO NOT INCLUDE THE ROOT '/'.
#if [ $LOCALREPO != "" ]; then  # WIP - this is not yet implemented.
#  RAW_GITHUB=""
#  REPO=$LOCALREPO 

source <(curl -s $RAW_GITHUB/$REPO/functions.sh)
source <(curl -s $RAW_GITHUB/$REPO/colors.sh)

curl -s $RAW_GITHUB/$REPO/roles/roles.yml -o /tmp/roles.yml
YAML_FILE="/tmp/roles.yml"


# Install script dependencies
PKGDEPS=(
  "jq"
  "yq" 
  "fzf"
)

pacman -Sy

info_print "=> Installing script dependencies"
for PKG in "${PKGDEPS[@]}"; do
  if ! pacman -Qs "$PKG" > /dev/null ; then
    pacman -S --noconfirm "$PKG"
  fi
done

#####################################################
# Script variables -- some of these can be pre-set  #
# and the respective prompts can be skipped by      #
# commenting them out with a #.                     #
#                                                   #
# Note: It is not recommended to preset Credentials #
# in a script                                       #
#                                                   #
#####################################################

HOSTNAME=""                 # Example: "archbase"
ROOT_PASS=""
NEW_USER=""                 # All lowercase, for example: "john"
USER_PASS=""
SUDO_GROUP=""               # 'true' or blank
LOCALE=""                   # Example: "en_US.UTF-8"
TIMEZONE=""                 # Example: "America/New_York"
BOOTLOADER="grub"           # 'grub' 'systemd-boot' or 'rEFInd'


BASE_PKGS=""                # package list for the base system                
ROLE_PKGS=""                # package list for the selected role
MICROCODE=""                # 'intel-ucode' 'amd-ucode' or blank
KERNEL_PKG=""               # on of: 'linux' 'linux-lts' 'linux-hardened' 'linux-zen'
INSTALL_DISK=""             # Example: "/dev/sda"
INSTALL_GPU_DRIVERS=""      # 'true' or blank
DESKTOP_CHOICE=""           # 'true' or blank 
AUTOLOGIN_CHOICE=""         # 'true' or blank


########################################
# Enable other services here if needed #
########################################
ENABLE_SVCS=(
  ""
  #"sddm"   # example exra service
)



# Display the header at the start
display_header

# Greet the user
greet_user
until display_warning; do : ; done

# Set hostname
until select_hostname; do : ; done

# Set root password
until select_root_password; do : ; done

# Create a new user
until create_new_user; do : ; done

# Select locale
until select_locale; do : ; done

# Select timezone
until select_timezone; do : ; done

# Choose a kernel to install
until choose_kernel; do : ; done

# Select system role
until choose_role; do : ; done

# Select additional packages to install
until user_packages; do : ; done

# offer to enable automatic loggin
until autologin_choice; do : ; done

# offer to enable Destop environment setup
until desktop_scripts; do : ; done

# Detect and install microcode
until microcode_detector; do : ; done

# Detect and install GPU drivers
until gpu_drivers; do : ; done

# Choose a bootloader to install
until choose_bootloader; do : ; done

# Select target disk
until target_disk; do : ; done

# Unmount any existing partitions on the target disk
until unmount_partitions; do : ; done

# Erase existing partitions on the target disk
until erase_partitions; do : ; done

# Start the installation process
install_message

# create the partitions and filesystems
until partitioning; do : ; done


# Install the base system and user-selected packages
until detect_vm; do : ; done
until package_lists; do : ; done
until install_base_system; do : ; done


# Generate the fstab file
install_message
info_print "=> Generating the fstab file"
sleep 1
genfstab -U /mnt >> /mnt/etc/fstab

# Export the configuration variables
export HOSTNAME
export ROOT_PASS
export NEW_USER
export USER_PASS
export SUDO_GROUP
export LOCALE
export TIMEZONE
export BOOTLOADER
export INSTALL_DISK

# Configure the new system
display_header
install_message
info_print "=> Configuring the new system"
sleep 1.5

until set_timezone; do : ; done
until set_locale; do : ; done
until set_hostname; do : ; done
until set_root_password; do : ; done
until setup_new_user; do : ; done
until enable_services; do : ; done
until install_bootloader; do : ; done


#Install a desktop environment scripts if selected
if [ $DESKTOP_CHOICE == "true" ]; then
  post_install_scripts
else
  info_print "=> Post install scripts not selected."
  sleep 1
fi

# Enable automatic login for the new user
if [ $AUTOLOGIN_CHOICE == "true" ]; then
  mkdir -p /mnt/etc/systemd/system/getty@tty1.service.d
  cat <<EOL > /mnt/etc/systemd/system/getty@tty1.service.d/override.conf
  [Service]
  ExecStart= 
  ExecStart=-/usr/bin/agetty --autologin $NEW_USER --noclear %I \$TERM
EOL
fi

# Unmount the partitions
display_header
info_print "=> Unmounting new installation"
sleep 1.5
umount -R /mnt

display_header
info_print "============================================================================"
info_print "                 Base system installation complete."
info_print "                           Next steps:"
info_print " "
info_print "                    1) Reboot into the new system."
info_print "  2) If you chose to install a desktop you can run ${INPUT}firstBoot${INFO} once logged in."
info_print "============================================================================"

read -rp "Please remove the boot media and press [Enter] to reboot..."
reboot
