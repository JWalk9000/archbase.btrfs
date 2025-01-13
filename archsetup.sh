#!/usr/bin/bash
set -e

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"

source <(curl -s $RAW_GITHUB/$REPO/functions.sh)
source <(curl -s $RAW_GITHUB/$REPO/colors.sh)

# Install script dependencies
PKGDEPS=(
  "jq" 
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

HOSTNAME=""
ROOT_PASS=""
NEW_USER=""
USER_PASS=""
SUDO_GROUP=""

MICROCODE=""
KERNEL_PKG=""
LOCALE=""
TIMEZONE=""
AUTOLOGIN_CHOICE=""
DESKTOP_CHOICE=""
BOOTLOADER=""
INSTALL_DISK=""
INSTALL_GPU_DRIVERS=false
DESKTOP=false


# Display the header at the start
display_header

# Greet the user
greet_user
until display_warning; do : ; done

# Set hostname
until set_hostname; do : ; done

# Set root password
until set_root_password; do : ; done

# Create a new user
until create_new_user; do : ; done

# Select locale
until select_locale; do : ; done

# Select timezone
until select_timezone; do : ; done

# Choose a kernel to install
until choose_kernel; do : ; done

# Detect and install microcode
until microcode_detector; do : ; done

# Select additional packages to install
until user_packages; do : ; done

# offer to enable automatic loggin
until autologin_setup; do : ; done

# offer to enable Destop environment setup
until desktop_environment; do : ; done

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

# Install the base system and user-selected packages
install_message
info_print "=> Installing base system with $KERNEL_PKG and essential packages"
sleep 1
pacstrap /mnt base $KERNEL_PKG $MICROCODE linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager pciutils usbutils $USERPKGS
if $user_packages; then
  pacstrap /mnt $USERPKGS
fi

# Generate the fstab file
install_message
info_print "=> Generating the fstab file"
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system and configure it
info_print "=> Configuring the new system"
arch-chroot /mnt /bin/bash <<EOF
# Set the timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set the locale
echo "$LOCALE UTF-8" >> /etc/locale.gen
echo "LANG=$LOCALE" > /etc/locale.conf
locale-gen

# Set the hostname
echo "$HOSTNAME" > /etc/hostname
{
  echo "127.0.0.1       localhost"
  echo "::1             localhost"
  echo "127.0.1.1       $HOSTNAME.localdomain $HOSTNAME"
} >> /etc/hosts

# Set the root password
echo "root:$ROOT_PASS" | chpasswd

# Create the new user
if [ $SUDO_GROUP == "true" ]; then
  useradd -m -G wheel -s /bin/bash $NEW_USER
else
  useradd -m -s /bin/bash $NEW_USER
fi

echo "$NEW_USER:$USER_PASS" | chpasswd

# Enable essential services
systemctl enable NetworkManager
systemctl enable sshd

########################################
# Enable other services here if needed #
########################################

# Install the bootloader
if [ -d /sys/firmware/efi/efivars ]; then
  case "$BOOTLOADER" in
    "systemd-boot")
      bootctl --path=/boot install
      ;;
    "rEFInd")
      pacman -S --noconfirm refind
      refind-install
      mkrlconf --root /mnt --subvol @ --output /mnt/boot/refind_linux.conf
      ;;
    *)
      pacman -S --noconfirm grub
      grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
      grub-mkconfig -o /boot/grub/grub.cfg
      ;;
  esac
else
  pacman -S --noconfirm grub
  grub-install --target=i386-pc "$INSTALL_DISK"
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# Install a desktop environment scripts if selected
if [ $DESKTOP_CHOICE == "true" ]; then
    mkdir -p /home/$NEW_USER/firstBoot
    
    FB_FILES=(
      "firstBoot.sh"
      "gui_options.yml"
      "install_yay.sh"
      "disable-autologin.sh"

    )
    for FILE in "${FB_FILES[@]}"; do 
      curl -s "$RAW_GITHUB/$REPO/firstBoot/$FILE" | sed "s/user_placeholder/$NEW_USER/g" > /home/$NEW_USER/firstBoot/$FILE
      done

    for FILE in "${FB_FILES[@]}"; do
      chmod +x /home/$NEW_USER/firstBoot/$FILE
    done

    # Change ownership to the new user
    chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/firstBoot
    
    # Add the firstBoot scrip to the system path
    echo "export PATH=$PATH:/home/$NEW_USER/firstBoot" >> /home/$NEW_USER/.bashrc
fi

# Install GPU drivers if selected
if [ -n "$INSTALL_GPU_DRIVERS" ] && [ "$INSTALL_GPU_DRIVERS" != "false" ]; then
  pacman -S --noconfirm $INSTALL_GPU_DRIVERS
fi

# Enable automatic login for the new user
if [ $AUTOLOGIN_CHOICE == "true" ]; then
  mkdir -p /etc/systemd/system/getty@tty1.service.d
  {
    echo "[Service]" 
    echo "ExecStart=" 
    echo "ExecStart=-/usr/bin/agetty --autologin $NEW_USER --noclear %I \$TERM" 
  } > /etc/systemd/system/getty@tty1.service.d/override.conf
  systemctl daemon-reload

fi


EOF


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