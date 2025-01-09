#!/usr/bin/env bash
set -e

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"

# Ensure yq and dialog are installed
pacman -S --noconfirm yq dialog

# Function to display the header.
display_header() {
  dialog --title "Welcome" --msgbox "\n   __                    _      ___    ___    ___    ___  
   \ \ __      __  __ _ | | __ / _ \  / _ \  / _ \  / _ \ 
    \ \\ \ /\ / / / _\` || |/ /| (_) || | | || | | || | | |
 /\_/ / \ V  V / | (_| ||   <  \__, || |_| || |_| || |_| |
 \___/   \_/\_/   \__,_||_|\_\   /_/  \___/  \___/  \___/ 
                                                          
   _____              _           _  _                      
   \_   \ _ __   ___ | |_   __ _ | || |  ___  _ __         
    / /\/| '_ \ / __|| __| / _\` || || | / _ \| '__|        
 /\/ /_  | | | |\__ \| |_ | (_| || || ||  __/| |           
 \____/  |_| |_||___/ \__| \__,_||_||_| \___||_|     

\nWelcome to the first boot setup script.\n\nThis script will guide you through the setup process." 20 70
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

# Prepare options for dialog
options=()
for key in "${!gui_options[@]}"; do
  options+=("$key" "")
done
options+=("None" "")

# Display GUI options using dialog
gui_choice=$(dialog --title "Choose GUI" --menu "Choose an optional GUI to install:" 15 50 8 "${options[@]}" 3>&1 1>&2 2>&3 3>&-)

clear

if [[ "$gui_choice" == "None" ]]; then
  dialog --title "Install Yay" --yesno "Would you like to install Yay (AUR helper)?" 7 50
  response=$?
  if [[ $response -eq 0 ]]; then
    bash <(curl -s "$RAW_GITHUB/$REPO/install_yay.sh")
  fi
  dialog --msgbox "Skipping GUI installation." 5 40
else
  repo=$(echo "${gui_options[$gui_choice]}" | awk '{print $1}')
  installer=$(echo "${gui_options[$gui_choice]}" | awk '{print $2}')
  bash <(curl -s "$RAW_GITHUB/$REPO/install_yay.sh")
  dialog --infobox "Installing $gui_choice..." 5 40
  git clone "$repo" /tmp/gui_repo
  bash /tmp/gui_repo/"$installer"
fi

# Final steps
dialog --msgbox "First boot setup complete. The system will now reboot." 7 50
reboot