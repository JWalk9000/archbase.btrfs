#!/usr/bin/env bash
set -e

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"

wait 15

# Ensure yq is installed
pacman -S --noconfirm yq

# Function to display the header.
display_header() {
  clear
  echo -e "\033[0;32m"
  cat <<"EOF"

     __                     _  _      ___    ___    ___    ___  
     \ \  __      __  __ _ | || | __ / _ \  / _ \  / _ \  / _ \ 
      \ \ \ \ /\ / / / _` || || |/ /| (_) || | | || | | || | | |
   /\_/ /  \ V  V / | (_| || ||   <  \__, || |_| || |_| || |_| |
   \___/    \_/\_/   \__,_||_||_|\_\   /_/  \___/  \___/  \___/ 
                                                          
                       GUI Setup                              
         _____              _           _  _                      
         \_   \ _ __   ___ | |_   __ _ | || |  ___  _ __         
          / /\/| '_ \ / __|| __| / _` || || | / _ \| '__|        
       /\/ /_  | | | |\__ \| |_ | (_| || || ||  __/| |           
       \____/  |_| |_||___/ \__| \__,_||_||_| \___||_|     

EOF
  echo -e "\033[0m"
  echo -e "
  Welcome to the first boot setup script.
  This script will guide you through the setup process.
  "
}

# Display the header at the start
display_header

# Read GUI options from YAML file
GUI_OPTIONS_YAML="/home/$USER/firstBoot/gui_options.yml"
declare -A gui_options

while IFS= read -r line; do
  name=$(echo "$line" | yq e '.name' -)
  repo=$(echo "$line" | yq e '.repo' -)
  installer=$(echo "$line" | yq e '.installer' -)
  gui_options["$name"]="$repo $installer"
done < <(yq e -o=json '.[]' "$GUI_OPTIONS_YAML")

# Display GUI options
echo "Choose an optional GUI to install:"
PS3="Enter the number corresponding to your choice: "
options=("${!gui_options[@]}" "None")
select gui_choice in "${options[@]}"; do
  if [[ "$gui_choice" == "None" ]]; then
    read -rp "Would you like to install Yay (AUR helper)? (y/N): " INSTALL_YAY
    if [[ "$INSTALL_YAY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      bash <(curl -s "$RAW_GITHUB/$REPO/install_yay.sh")
    fi
    echo "Skipping GUI installation."
    break
  elif [[ -n "${gui_options[$gui_choice]}" ]]; then
    repo=$(echo "${gui_options[$gui_choice]}" | awk '{print $1}')
    installer=$(echo "${gui_options[$gui_choice]}" | awk '{print $2}')
    bash <(curl -s "$RAW_GITHUB/$REPO/install_yay.sh")
    echo "Installing $gui_choice..."
    git clone "$repo" /tmp/gui_repo
    bash /tmp/gui_repo/"$installer"
    break
  else
    echo "Invalid option. Please try again."
  fi
done

# Final steps
echo "First boot setup complete. The system will now reboot."
reboot