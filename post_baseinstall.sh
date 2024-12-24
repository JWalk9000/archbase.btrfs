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

# 3. Install pciutils and detect NVIDIA GPU
echo "=> Installing pciutils"
pacman -S pciutils

echo "=> Detecting NVIDIA GPU"
if lspci | grep -i nvidia; then
  read -rp "NVIDIA GPU detected. Would you like to install GPU drivers? (y/N): " INSTALL_GPU
  if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "=> Installing GPU drivers"
    bash <(curl -s 'https://YOUR_RAW_GITHUB_URL/install_gpu.sh')
  fi
else
  echo "No NVIDIA GPU detected."
fi

# 4. Interactive bootloader installation
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

# 5. Root password
echo "=> Set root password"
passwd root

# 6. Interactive new user creation
read -rp "Enter new username: " NEW_USER
useradd -m -s /bin/bash "$NEW_USER"

read -rp "Should $NEW_USER have sudo privileges? (y/N): " SUDO_CHOICE
if [[ "$SUDO_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  usermod -aG wheel "$NEW_USER"
  echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

echo "=> Set password for $NEW_USER"
passwd "$NEW_USER"

# 7. Optional GUI installation
declare -A gui_options=(
  ["ML4W Hyperland-Full"]="bash <(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh)"
  ["ML4W Hyperland-Starter"]="bash <(curl -s https://raw.githubusercontent.com/mylinuxforwork/hyprland-starter/main/setup.sh)"
)

echo "=> Choose an optional GUI to install:"
select gui_choice in "${!gui_options[@]}" "None"; do
  if [[ "$gui_choice" == "None" ]]; then
    read -rp "Would you like to install Yay (AUR helper)? (y/N): " INSTALL_YAY
    if [[ "$INSTALL_YAY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "=> Installing Yay"
      pacman -S --needed git base-devel
      git clone https://aur.archlinux.org/yay.git
      cd yay
      sudo -u nobody bash -c 'cd yay && makepkg -si --noconfirm'
      cd ..
      rm -rf yay
    fi
    echo "=> Skipping GUI installation."
    break
  elif [[ -n "${gui_options[$gui_choice]}" ]]; then
    echo "=> Installing Yay"
    pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u nobody bash -c 'cd yay && makepkg -si --noconfirm'
    cd ..
    rm -rf yay
    echo "=> Installing $gui_choice"
    eval "${gui_options[$gui_choice]}"
    break
  else
    echo "Invalid choice. Please try again."
  fi
done

# 8. Final instructions
echo "=> Done with post-install setup."
echo "=> You can now exit chroot, unmount, and reboot."
echo "=> (Optional) After reboot, install additional packages or run any custom scripts:"
echo "   bash <(curl -s 'https://YOUR_RAW_GITHUB_URL/custom_script.sh')"

# 9. Reboot option
read -rp "Reboot now? (y/N): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "=> Exiting chroot, unmounting /mnt, and rebooting..."
  exit
  umount -R /mnt
  reboot
else
  echo "=> Reboot skipped. You can reboot manually later."
fi