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
   
     __                     _  _      ___    ___    ___    ___  
     \ \  __      __  __ _ | || | __ / _ \  / _ \  / _ \  / _ \ 
      \ \ \ \ /\ / / / _` || || |/ /| (_) || | | || | | || | | |
   /\_/ /  \ V  V / | (_| || ||   <  \__, || |_| || |_| || |_| |
   \___/    \_/\_/   \__,_||_||_|\_\   /_/  \___/  \___/  \___/ 
                                                          
                 GPU Driver Installation                                
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

echo "=> Detecting GPU..."

if lspci | grep -i nvidia; then
  echo "NVIDIA GPU detected. Installing NVIDIA drivers..."
  if ! pacman -S --noconfirm nvidia nvidia-utils nvidia-settings; then
    echo "Error installing NVIDIA drivers. Skipping GPU driver installation."
  fi
elif lspci | grep -i amd; then
  echo "AMD GPU detected. Installing AMD drivers..."
  if ! pacman -S --noconfirm xf86-video-amdgpu; then
    echo "Error installing AMD drivers. Skipping GPU driver installation."
  fi
elif lspci | grep -i intel; then
  echo "Intel GPU detected. Installing Intel drivers..."
  if ! pacman -S --noconfirm xf86-video-intel; then
    echo "Error installing Intel drivers. Skipping GPU driver installation."
  fi
else
  echo "No supported GPU detected or GPU not recognized. Skipping GPU driver installation."
fi

echo "=> GPU driver installation complete."