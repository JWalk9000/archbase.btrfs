#!/usr/bin/env bash
set -e


RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"



# 1. Localization
until select_locale; do : ; done

# 2. Network configuration
until set_hostname; do : ; done

# Enable essential services
info_print "=> Enabling Network and SSH"
sleep 1
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable sshd

# 3. Root password
until set_root_password; do : ; done

# 4. New user creation
until create_new_user; do : ; done

# 5. Detect dedicated GPU
until gpu_drivers; do : ; done

# 6. Interactive bootloader installation
display_header
echo "=> Choose a bootloader to install:"
sleep 1.5
echo "   1) GRUB"
echo "   2) systemd-boot"
echo "   3) rEFInd"
read -rp "Enter your choice (1-3, default is 1): " BOOTLOADER_CHOICE

case "$BOOTLOADER_CHOICE" in
  2)
    echo "=> Installing systemd-boot"
    sleep 1.5
    bootctl --path=/boot install
    ;;
  3)
    echo "=> Installing rEFInd"
    sleep 1.5
    pacman -S --noconfirm refind
    echo "=> Creating rEFInd configuration"
    cat <<EOL > /boot/refind_linux.conf
"Boot with defaults" "root=UUID=$(blkid -s UUID -o value $BTRFS_PART) rootflags=subvol=@ rw add_efi_memmap initrd=/boot/initramfs-linux-zen.img"
EOL
    refind-install
    ;;
  *)
    echo "=> Installing GRUB (default)"
    sleep 1.5
    pacman -S --noconfirm grub
    if [ -d /sys/firmware/efi ]; then
      echo "=> Detected EFI system"
      sleep 1.5
      pacman -S --noconfirm efibootmgr
      grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
      echo "=> Detected BIOS/MBR system"
      sleep 1.5
      grub-install --target=i386-pc /dev/sda
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac

# 7. Install optional packages from userpkgs.txt
display_header
echo "=> Checking for userpkgs.txt"
sleep 1.5
if curl --output /dev/null --silent --head --fail "$RAW_GITHUB/$REPO/userpkgs.txt"; then
  echo "=> Downloading and installing optional packages from userpkgs.txt"
  sleep 1.5
  curl -s "$RAW_GITHUB/$REPO/userpkgs.txt" -o /tmp/userpkgs.txt
  pacman -S --needed --noconfirm - < /tmp/userpkgs.txt
else
  echo "No userpkgs.txt file found at $RAW_GITHUB/$REPO/userpkgs.txt. Skipping optional package installation."
  sleep 1.5
fi

# 8. Setup firstBoot experience
display_header
echo "=> Preparing to install a Desktop Environment on the first boot"
sleep 1.5

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

# Create the systemd service
cat <<EOL > /etc/systemd/system/firstboot.service
[Unit]
Description=First Boot Script
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /home/$NEW_USER/firstBoot/firstBoot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOL

systemctl enable firstboot.service

# 9. Set up autologin for the first boot
display_header
echo "=> Setting up autologin for the first boot"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOL > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $NEW_USER --noclear %I \$TERM
EOL

systemctl daemon-reload

# 12. Exit chroot, unmount /mnt, and reboot
display_header
echo "=> Exiting chroot environment"
sleep 1.5
exit
