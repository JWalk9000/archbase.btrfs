#!/usr/bin/env bash
set -e

# Define colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display the header
display_header() {
  clear
  echo -e "${GREEN}"
  cat <<"EOF"
   ____         __       ____       
  /  _/__  ___ / /____ _/ / /__ ____
 _/ // _ \(_-</ __/ _ `/ / / -_) __/
/___/_//_/___/\__/\_,_/_/_/\__/_/   
EOF
  echo -e "${NC}"
}

# Display the header at the start
display_header

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/refs/heads/main"

# 1. List block devices and prompt user for target install disk
display_header
echo "=== List of available block devices ==="
lsblk -o NAME,SIZE,TYPE,MODEL
echo "======================================="
read -rp "Enter the block device you want to install to (e.g. sda or nvme0n1): " INSTALL_DISK

# 2. Confirm the user choice
display_header
INSTALL_DISK="/dev/$INSTALL_DISK"
echo "You chose: $INSTALL_DISK"
read -rp "Press [Enter] to continue or Ctrl+C to abort..."

# 3. Check for mounted partitions and unmount them
if mount | grep "$INSTALL_DISK"; then
  echo "=> Unmounting mounted partitions on $INSTALL_DISK"
  for PART in $(lsblk -ln -o NAME,MOUNTPOINT "$INSTALL_DISK" | awk '$2 != "" {print $1}'); do
    umount "/dev/$PART"
  done
fi

# 4. Check for existing partitions and prompt for confirmation to overwrite
if lsblk "$INSTALL_DISK" | grep -q part; then
  display_header
  echo "Warning: Existing partitions found on $INSTALL_DISK."
  read -rp "Do you want to overwrite the existing partitions? This will delete all data on the disk. (y/N): " OVERWRITE_CONFIRMATION
  if [[ "$OVERWRITE_CONFIRMATION" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "=> Removing existing partitions on $INSTALL_DISK"
    for PART in $(lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}p?[0-9]+$"); do
      wipefs -a "/dev/$PART" || true
    done
    echo "=> Deleting existing partitions on $INSTALL_DISK"
    for PART in $(lsblk -ln -o NAME "$INSTALL_DISK" | grep -E "^${INSTALL_DISK#/dev/}p?[0-9]+$"); do
      echo "d" | fdisk "$INSTALL_DISK"
    done
    echo "w" | fdisk "$INSTALL_DISK"
    partprobe "$INSTALL_DISK"
  else
    echo "Aborting installation."
    exit 1
  fi
fi

# 5. Set system clock
echo "=> Enabling network time synchronization"
timedatectl set-ntp true

# 6. Automated partitioning with fdisk
echo "=> Creating GPT partition table and partitions on $INSTALL_DISK"
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

# 7. Format the partitions
if [[ "$INSTALL_DISK" == *"nvme"* ]]; then
  EFI_PART="${INSTALL_DISK}p1"
  BTRFS_PART="${INSTALL_DISK}p2"
else
  EFI_PART="${INSTALL_DISK}1"
  BTRFS_PART="${INSTALL_DISK}2"
fi

echo "=> Formatting EFI partition as FAT32"
mkfs.fat -F 32 "$EFI_PART"

echo "=> Formatting primary partition as Btrfs"
mkfs.btrfs -f "$BTRFS_PART"

# 8. Create and mount Btrfs subvolumes
echo "=> Mounting $BTRFS_PART to /mnt"
mount "$BTRFS_PART" /mnt

echo "=> Creating subvolumes"
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

echo "=> Unmounting /mnt to re-mount subvolumes"
umount /mnt

echo "=> Remounting subvolumes"
mount -o subvol=@ "$BTRFS_PART" /mnt
mkdir -p /mnt/home
mount -o subvol=@home "$BTRFS_PART" /mnt/home
mkdir -p /mnt/.snapshots
mount -o subvol=@snapshots "$BTRFS_PART" /mnt/.snapshots

# 9. Mount EFI partition
echo "=> Mounting EFI partition at /mnt/boot"
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# 10. Install base system
echo "=> Installing base system with linux-zen kernel and essential packages"
pacstrap /mnt base linux-zen linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager

echo "=> Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# 11. Chroot into the new system and set up hostname, root password, user, bootloader, and GPU drivers
arch-chroot /mnt /bin/bash <<EOF
set -e

# Define colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display the header
display_header() {
  clear
  echo -e "${GREEN}"
  cat <<"EOH"
   ____         __       ____       
  /  _/__  ___ / /____ _/ / /__ ____
 _/ // _ \(_-</ __/ _ `/ / / -_) __/
/___/_//_/___/\__/\_,_/_/_/\__/_/   
EOH
  echo -e "${NC}"
}

# Display the header at the start
display_header

# 1. Localization
display_header
echo "=> Setting locale to en_US.UTF-8"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 2. Network configuration
display_header
read -rp "Enter hostname: " HOSTNAME
echo "=> Configuring hostname and /etc/hosts"
echo "$HOSTNAME" > /etc/hostname
{
  echo "127.0.0.1       localhost"
  echo "::1             localhost"
  echo "127.0.1.1       $HOSTNAME.localdomain $HOSTNAME"
} >> /etc/hosts

# Enable essential services
echo "=> Enabling NetworkManager and SSH"
systemctl enable NetworkManager
systemctl enable sshd

# 3. Root password
display_header
echo "=> Set root password"
passwd root

# 4. Interactive new user creation
display_header
read -rp "Enter new username: " NEW_USER
useradd -m -s /bin/bash "$NEW_USER"

read -rp "Should $NEW_USER have sudo privileges? (y/N): " SUDO_CHOICE
if [[ "$SUDO_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  usermod -aG wheel "$NEW_USER"
  echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

echo "=> Set password for $NEW_USER"
passwd "$NEW_USER"

# 5. Install pciutils and detect dedicated GPU
display_header
echo "=> Installing pciutils"
pacman -S pciutils

echo "=> Detecting dedicated GPU"
if lspci | grep -i -E "VGA compatible controller|3D controller"; then
  display_header
  read -rp "Dedicated GPU detected. Would you like to install GPU drivers? (y/N): " INSTALL_GPU
  if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "=> Installing GPU drivers"
    bash <(curl -s "$RAW_GITHUB/$REPO/install_gpu.sh")
  fi
else
  echo "No dedicated GPU detected."
fi

# 6. Interactive bootloader installation
display_header
echo "=> Choose a bootloader to install:"
echo "   1) GRUB"
echo "   2) systemd-boot"
echo "   3) rEFInd"
read -rp "Enter your choice (1-3, default is 1): " BOOTLOADER_CHOICE

case "$BOOTLOADER_CHOICE" in
  2)
    echo "=> Installing systemd-boot"
    bootctl --path=/boot install
    ;;
  3)
    echo "=> Installing rEFInd"
    pacman -S refind
    refind-install
    ;;
  *)
    echo "=> Installing GRUB (default)"
    pacman -S grub
    if [ -d /sys/firmware/efi ]; then
      echo "=> Detected EFI system"
      pacman -S efibootmgr
      grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
      echo "=> Detected BIOS/MBR system"
      grub-install --target=i386-pc /dev/sda
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac

# 7. Create systemd service for first boot script
display_header
echo "=> Creating systemd service for first boot script"
cat <<EOL > /etc/systemd/system/firstboot.service
[Unit]
Description=First Boot Script
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'bash <(curl -s "$RAW_GITHUB/$REPO/post_baseinstall.sh")'
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOL

systemctl enable firstboot.service

EOF

# 12. Instructions to proceed
echo "========================================================="
echo "Base system installation complete."
echo "Next steps:"
echo "  1) Reboot into the new system."
echo "  2) The post-install script will run automatically on the first boot."
echo "========================================================="

# 13. Reboot option
display_header
read -rp "Reboot now? (y/N): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "=> Exiting chroot, unmounting /mnt, and rebooting..."
  umount -R /mnt
  reboot
else
  echo "=> Reboot skipped. You can reboot manually later."
fi