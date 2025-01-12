#!/usr/bin/env bash
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


#list of variables
KERNEL_PKG=""
MICROCODE=""
ROOT_PASS=""
NEW_USER=""
USER_PASS=""
HOSTNAME=""
LOCALE=""
TIMEZONE=""
INSTALL_DISK=""
BOOTLOADER=""
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

# Choose a kernel to install
until choose_kernel; do : ; done

# Select locale
until select_locale; do : ; done

# Select timezone
until select_timezone; do : ; done

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
start_installation

# Partition the disk
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
info_print "=> Mounting EFI partition at /mnt/boot"
sleep 1
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# Install the base system
install_message
info_print "=> Installing base system with $KERNEL_PKG and essential packages"
sleep 1
pacstrap /mnt base $KERNEL_PKG $MICROCODE linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager pciutils usbutils

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
useradd -m -s /bin/bash $SUDO_GROUP "$NEW_USER"
echo "$NEW_USER:$USER_PASS" | chpasswd

# Enable essential services
systemctl enable NetworkManager
systemctl enable sshd

# Install the bootloader
case "$BOOTLOADER" in
  "systemd-boot")
    bootctl --path=/boot install
    ;;
  "rEFInd")
    pacman -S --noconfirm refind
    refind-install
    ;;
  *)
    pacman -S --noconfirm grub
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac

# Install GPU drivers if selected
if [ "$INSTALL_GPU_DRIVERS" = true ]; then
  pacman -S --noconfirm nvidia nvidia-utils
fi
EOF

# Unmount the partitions
info_print "=> Unmounting the partitions"
umount -R /mnt

# Reboot the system
info_print "=> Installation complete. Rebooting the system."
reboot