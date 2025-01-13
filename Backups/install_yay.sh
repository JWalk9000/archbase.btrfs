#!/usr/bin/bash
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