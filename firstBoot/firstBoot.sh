#!/usr/bin/env bash
set -e

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"
TMPLOCALREPO=/home/$USER/firstBoot/gui_repo

# Ensure TMPLOCALREPO is removed if the script exits for any reason.
trap 'rm -rf "$TMPLOCALREPO"' EXIT  # <-- comment this out for debugging.

source <(curl -s $RAW_GITHUB/$REPO/functions.sh)
source <(curl -s $RAW_GITHUB/$REPO/colors.sh)

USER=$(whoami)
export USER

# Ask for sudo privileges
if [ "$EUID" -ne 0 ]; then
  info_print "This script requires sudo privileges. Please enter your password."
  sudo -v
fi

# Check If Yay is installed
if ! pacman -Qs yay > /dev/null ; then
  IS_YA=0
else
  IS_YA=1 
fi

# Install Yay AUR helper(function)
install_yay() {
  info_print "=> Installing Yay"
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
  info_print "Yay installation complete."
}

#disable autologin (function)
disable_autologin() {
  info_print "=> Disabling autologin"
  sudo rm /etc/systemd/system/getty@tty1.service.d/override.conf
  sudo systemctl daemon-reload
  sudo systemctl restart getty@tty1
  sudo systemctl disable disable-autologin.service
  info_print "Autologin has been disabled."
}

PKGDEPS=(
  "jq" 
  "fzf"
)
sudo pacman -Sy

info_print "=> Installing script dependencies"
for PKG in "${PKGDEPS[@]}"; do
  if ! sudo pacman -Qs "$PKG" > /dev/null ; then
    sudo pacman -S --noconfirm "$PKG"
  fi
done


# Display the header, warning and greeting at the start
display_header
info_print "Welcome to the first boot setup script. This script will guide you through the setup process."
echo ""
banner_print "This is the First Boot Setup, where you can install optional GUI setups from a prepopulated .json file. 
These are not my scripts, however I do plan on adding my own here too. I will do my best to pre-vet 
these scripts, however, it is always in your best interest to know and understand any script before running it."
echo ""
warning_print "Please be aware that these scripts are not mine, and I cannot guarantee their safety. Procede with caution."
echo ""


# Check for the GUI options JSON file locally, if not available, download it
GUI_OPTIONS_JSON="/home/$USER/firstBoot/gui_options.json"
if [ ! -f "$GUI_OPTIONS_JSON" ]; then
  info_print "=> Downloading gui_options.json from the repository"
  curl -s "$RAW_GITHUB/$REPO/firstBoot/gui_options.json" -o "$GUI_OPTIONS_JSON"
fi

# Read GUI options from JSON file
declare -A gui_options

while IFS= read -r line; do
  name=$(echo "$line" | jq -r '.name')
  repo=$(echo "$line" | jq -r '.repo')
  installer=$(echo "$line" | jq -r '.installer')
  gui_options["$name"]="$repo $installer"
done < <(jq -c '.[]' "$GUI_OPTIONS_JSON")

# Display GUI options
echo "Choose an optional GUI to install:"
PS3="Enter the number corresponding to your choice: "
options=("${!gui_options[@]}" "None")
select gui_choice in "${options[@]}"; do
  if [[ "$gui_choice" == "None" ]]; then
    if [ $IS_YA -eq 0 ]; then
      read -rp "Would you like to install Yay (AUR helper)? (y/N): " INSTALL_YAY
      if [[ "$INSTALL_YAY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        install_yay
      fi    
    fi  
    info_print "Skipping GUI installation."
    break
  elif [[ -n "${gui_options[$gui_choice]}" ]]; then
    repo=$(echo "${gui_options[$gui_choice]}" | awk '{print $1}')
    installer=$(echo "${gui_options[$gui_choice]}" | awk '{print $2}')
    if [ $IS_YA -eq 0 ]; then
      install_yay
    fi
    display_header
    info_print "Yay has been installed."
    echo ""
    info_print "Installing $gui_choice..."
    git clone "$repo" $TMPLOCALREPO
    bash $TMPLOCALREPO/"$installer"
    break
  else
    info_print "Invalid option. Please try again."
  fi
done

# Final steps
Yn_print "Would you like to dissable auto login now?"
read -rp "" AUTOLOGIN_CHOICE
if [ $AUTOLOGIN_CHOICE == "y" ]; then
  disable_autologin
fi

Yn_print "firstBoot setup complete. woudl you like to reboot now?"
read -rp "" REBOOT_CHOICE
if [ $REBOOT_CHOICE == "y" ]; then
  reboot
fi
