#!/usr/bin/env bash
set -e


RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"


# Define colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display the header
display_header() {
  clear
  echo -e "${GREEN}"
  cat <<"EOF"
   __                    _      ___    ___    ___    ___  
   \ \ __      __  __ _ | | __ / _ \  / _ \  / _ \  / _ \ 
    \ \\ \ /\ / / / _` || |/ /| (_) || | | || | | || | | |
 /\_/ / \ V  V / | (_| ||   <  \__, || |_| || |_| || |_| |
 \___/   \_/\_/   \__,_||_|\_\   /_/  \___/  \___/  \___/ 
                                                          
   _____              _           _  _                      
   \_   \ _ __   ___ | |_   __ _ | || |  ___  _ __         
    / /\/| '_ \ / __|| __| / _` || || | / _ \| '__|        
 /\/ /_  | | | |\__ \| |_ | (_| || || ||  __/| |           
 \____/  |_| |_||___/ \__| \__,_||_||_| \___||_|     

EOF
  echo -e "${NC}"
}

# Display the header at the start
display_header

# 1. Localization
display_header
echo "=> Setting locale to en_US.UTF-8"
sleep 1.5
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 2. Network configuration
display_header
read -rp "Enter hostname: " HOSTNAME
echo "=> Configuring hostname and /etc/hosts"
sleep 1.5
echo "$HOSTNAME" > /etc/hostname
{
  echo "127.0.0.1       localhost"
  echo "::1             localhost"
  echo "127.0.1.1       $HOSTNAME.localdomain $HOSTNAME"
} >> /etc/hosts

# Enable essential services
display_header
echo "=> Enabling Network and SSH"
sleep 1

systemctl enable NetworkManager
#systemctl enable netctl
systemctl enable sshd

# 3. Root password
display_header
read -rp "Would you like to set a root password? (y/N): " ROOT_PASS
if [[ "$ROOT_PASS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "=> Set root password, leave blank for no root password"
  passwd root
else
  echo "=> Skipping root password setup"
  sleep 1.5
fi

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
sleep 1.5
passwd "$NEW_USER"

# 5. Detect dedicated GPU
display_header
echo "=> Detecting dedicated GPU"
sleep 1.5
if lspci | grep -i -E "VGA compatible controller|3D controller"; then
  display_header
  read -rp "Dedicated GPU detected. Would you like to install GPU drivers? (y/N): " INSTALL_GPU
  if [[ "$INSTALL_GPU" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "=> Installing GPU drivers"
    sleep 1.5
    bash <(curl -s "$RAW_GITHUB/$REPO/install_gpu.sh")
  fi
else
  echo "No dedicated GPU detected."
  sleep 1.5
fi

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

# 8. Create systemd service for first boot script
display_header
echo "=> Creating systemd service to start the firstBoot script"
sleep 1.5

# Create the fetch_and_run.sh script 
cat << 'EOF' > /home/$NEW_USER/fetch_and_run.sh 
#!/bin/bash 

# Fetch and run the remote script 
bash <(curl -s "$RAW_GITHUB/$REPO/firstBoot.sh")
EOF

# Make the script executable 
chmod +x /home/$NEW_USER/fetch_and_run.sh

# Create the systemd service
cat <<EOL > /etc/systemd/system/firstboot.service
[Unit]
Description=First Boot Script
After=network.target

[Service]
Type=oneshot
ExecStart=/home/$NEW_USER/fetch_and_run.sh
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

# 10. Create a script to disable autologin after the first boot
cat <<'EOF' > /home/$NEW_USER/disable-autologin.sh
#!/usr/bin/env bash
rm /etc/systemd/system/getty@tty1.service.d/override.conf
systemctl daemon-reload
systemctl restart getty@tty1
systemctl disable disable-autologin.service
EOF
chmod +x /usr/local/bin/disable-autologin.sh

# 11. Create a systemd service to run the disable-autologin script after the first boot
cat <<EOL > /etc/systemd/system/disable-autologin.service
[Unit]
Description=Disable autologin after the first boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/home/$NEW_USER/disable-autologin.sh

[Install]
WantedBy=multi-user.target
EOL

systemctl enable disable-autologin.service

# 12. Exit chroot, unmount /mnt, and reboot
display_header
echo "========================================================="
echo "Base system installation complete."
echo "Next steps:"
echo "  1) Reboot into the new system."
echo "  2) The post-install script will run automatically on the first boot."
echo "========================================================="

echo "=> Exiting chroot environment"
sleep 1.5
exit
