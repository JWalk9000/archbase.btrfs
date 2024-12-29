#!/usr/bin/env bash
set -e

# Prompt the new user to log in
echo "Please log in as the new user to install Yay."
read -rp "Enter the new username: " NEW_USER

# Switch to the new user's home directory
sudo -u "$NEW_USER" bash << 'EOF'
cd ~

# Install Yay
echo "=> Installing Yay"
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

echo "Yay installation complete."
EOF