#!/usr/bin/env bash
set -e

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/refs/heads/main"

# Function to display the header.
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

# Ensure jq is installed
pacman -S --noconfirm jq

# Read GUI options from JSON file
GUI_OPTIONS_JSON="/$RAW_GITHUB/$REPO/gui_options.json"
declare -A gui_options

while IFS= read -r line; do
  name=$(echo "$line" | jq -r '.name')
  repo=$(echo "$line" | jq -r '.repo')
  installer=$(echo "$line" | jq -r '.installer')
  gui_options["$name"]="$repo $installer"
done < <(jq -c '.[]' "$GUI_OPTIONS_JSON")

echo "=> Choose an optional GUI to install:"
select gui_choice in "${!gui_options[@]}" "None"; do
  if [[ "$gui_choice" == "None" ]]; then
    read -rp "Would you like to install Yay (AUR helper)? (y/N): " INSTALL_YAY
    if [[ "$INSTALL_YAY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      bash <(curl -s "$RAW_GITHUB/$REPO/install_yay.sh")
    fi
    echo "=> Skipping GUI installation."
    break
  elif [[ -n "${gui_options[$gui_choice]}" ]]; then
    repo=$(echo "${gui_options[$gui_choice]}" | awk '{print $1}')
    installer=$(echo "${gui_options[$gui_choice]}" | awk '{print $2}')
    bash <(curl -s "$RAW_GITHUB/$REPO/install_yay.sh")
    echo "=> Installing $gui_choice"
    git clone "$repo" /tmp/gui_repo
    bash /tmp/gui_repo/"$installer"
    break
  else
    echo "Invalid option. Please try again."
  fi
done

# Final steps
echo "=> First boot setup complete. Rebooting..."
reboot