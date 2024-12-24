#!/usr/bin/env bash
set -e

# 1. Localization
echo "=> Setting locale to en_US.UTF-8"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 2. Network configuration
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

# 3. Interactive bootloader installation
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

# 4. Root password
echo "=> Set root password"
passwd root

# 5. Interactive new user creation
read -rp "Enter new username: " NEW_USER
useradd -m -s /bin/bash "$NEW_USER"

read -rp "Should $NEW_USER have sudo privileges? (y/N): " SUDO_CHOICE
if [[ "$SUDO_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  usermod -aG wheel "$NEW_USER"
  echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

echo "=> Set password for $NEW_USER"
passwd "$NEW_USER"

# 6. Final instructions
echo "=> Done with post-install setup."
echo "=> You can now exit chroot, unmount, and reboot."
echo "=> (Optional) After reboot, install additional packages or run any custom scripts:"
echo "   bash <(curl -s 'https://YOUR_RAW_GITHUB_URL/custom_script.sh')"