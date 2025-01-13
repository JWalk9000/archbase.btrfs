#!/usr/bin/env bash

RAW_GITHUB="https://raw.githubusercontent.com"
REPO="jwalk9000/archbase.btrfs/main"

source <(curl -s $RAW_GITHUB/$REPO/functions.sh)
source <(curl -s $RAW_GITHUB/$REPO/colors.sh)

user=""
NEW_USER=$user

# Install a desktop environment scripts if selected

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
  
# Add the firstBoot script to the system path
echo "export PATH=\$PATH:/home/$NEW_USER/firstBoot" >> /home/$NEW_USER/.bashrc
