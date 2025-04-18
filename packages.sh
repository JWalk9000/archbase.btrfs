#!/usr/bin/env bash
set -e

# This is a script to allow users to install additional packages and enable services interactively during the installation process.
# This script will be called by the main script, archsetup.sh, if the user chooses to install additional packages and enable services during the installation process.

# Load required functions and variables
source /tmp/archbase/colors.sh
source /tmp/archbase/functions.sh

# Variables to store user inputs
USERPKGS=()
USER_SVCS=() # Define USER_SVCS array
ROLE_PKGS=() # Define ROLE_PKGS array
ROLE_SVCS=() # Define ROLE_SVCS array
VERIFIED_PKGS=()
SYSTEM_SVCS=() # This will hold the final consolidated list of services
SYSTEM_PKGS=() # This will hold the final consolidated list of packages
CURRENT_ROLE=""

# Load base packages and services from roles.yml initially
load_base_packages_services() {
  if [ -f "$ROLES_YAML" ]; then
      mapfile -t BASE_PKGS < <(yq -r '.base.packages[]?' "$ROLES_YAML")
      mapfile -t BASE_SVCS < <(yq -r '.base.services[]?' "$ROLES_YAML")
  else
      warning_print "Could not find roles.yml at $ROLES_YAML. Base packages/services will be empty."
  fi
}

# Function to load user packages and services from YAML file
load_user_packages() {
  if [ -f "$USER_YAML" ]; then
    mapfile -t USERPKGS < <(yq -r '.packages[]?' "$USER_YAML")
    mapfile -t USER_SVCS < <(yq -r '.services[]?' "$USER_YAML")
    info_print "Loaded user packages and services from $USER_YAML."
  else
    warning_print "No $USER_YAML file found. Starting with empty user lists."
    USERPKGS=()
    USER_SVCS=()
  fi
}

# Choose a role for the system (function).
choose_role() {
  display_header
  if [[ -n "$CURRENT_ROLE" ]]; then
    info_print "You have already selected the role: $CURRENT_ROLE."
    choices_print "1" ") Add another role's packages/services"
    choices_print "2" ") Switch to a different role (removes previous role's items)"
    select_print "1" "2" "Choose an option: " ROLE_ACTION
    case $ROLE_ACTION in
      1)
        info_print "Adding packages/services from another role."
        ;;
      2)
        info_print "Switching roles. Removing packages and services from the previous role: $CURRENT_ROLE."
        ROLE_PKGS=()
        ROLE_SVCS=()
        CURRENT_ROLE=""
        ;;
      *)
        warning_print "Invalid option. Returning to the menu."
        return
        ;;
    esac
  fi

  info_print "Below are some available system roles to choose from."
  choices_print "0" ") Skip/Custom"
  choices_print "1" ") Server ----------------- A basic server setup with some common services aiming at a similar experience to Ubuntu Server."
  choices_print "2" ") Desktop - XFCE --------- A lightweight desktop environment, similar layout to MS Windows 7."
  choices_print "3" ") Desktop - KDE Plasma --- A modern, feature-rich desktop environment, similar layout MS Windows 10/11."
  choices_print "4" ") Desktop - GNOME -------- A modern, feature-rich desktop environment, similar layout to macOS."
  choices_print "5" ") Desktop - Hyprland ----- A highly customizable dynamic tiling Wayland compositor keyboard-shortcut-driven."
  select_print "0" "5" "System role: " "SYSTEM_ROLE_CHOICE"
  local selected_role_name=""
  case $SYSTEM_ROLE_CHOICE in
    1) selected_role_name="server" ;;
    2) selected_role_name="xfce" ;;
    3) selected_role_name="kde" ;;
    4) selected_role_name="gnome" ;;
    5) selected_role_name="hypr" ;;
    *)
      info_print "Skipping role selection or choosing custom."
      return 0;;
  esac

  system_role "$selected_role_name"
  if [[ "$ROLE_ACTION" != "1" || -z "$CURRENT_ROLE" ]]; then
      CURRENT_ROLE="$selected_role_name"
  else
      CURRENT_ROLE+="/$selected_role_name"
  fi
  return 0
}

# Function to verify user packages
verify_packages() {
  VERIFIED_PKGS=()
  for PKG in "${USERPKGS[@]}"; do
    if pacman -Si "$PKG" > /dev/null; then
      VERIFIED_PKGS+=("$PKG")
    else
      warning_print "Package $PKG not found in the repositories."
      Yn_print "Would you like to change the spelling?"
      read -rp "" CHANGE_SPELLING
      if [[ "$CHANGE_SPELLING" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        read -rp "$(info_print "Enter the correct package name: ")" FIXPKG
        if pacman -Si "$FIXPKG" > /dev/null; then
          VERIFIED_PKGS+=("$FIXPKG")
        else
          warning_print "Package $FIXPKG not found in the repositories."
          Yn_print "Would you like to try again?"
          read -rp "" TRY_AGAIN
          if [[ "$TRY_AGAIN" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            continue
          else
            break
          fi
        fi
      else
        continue
      fi
    fi
  done
  USERPKGS=("${VERIFIED_PKGS[@]}")
}

# Function to add or remove packages
add_or_remove_packages() {
  while true; do
    display_header
    info_print "Current user-defined packages:"
    if [ ${#USERPKGS[@]} -eq 0 ]; then
        info_print "  (None)"
    else
        for PKG in "${USERPKGS[@]}"; do
          info_print "  - $PKG"
        done
    fi
    echo ""
    info_print "1) Add user packages"
    info_print "2) Remove user packages"
    info_print "3) Go back"
    select_print "1" "3" "Choose an option: " OPTION

    case $OPTION in
      1)
        read -rp "$(info_print "Enter additional packages to install (space-separated): ")" ADD_PKGS
        if [ -n "$ADD_PKGS" ]; then
          mapfile -t -O "${#USERPKGS[@]}" USERPKGS < <(echo "$ADD_PKGS" | tr ' ' '\n')
          verify_packages
          info_print "User packages updated."
        fi
        ;;
      2)
        read -rp "$(info_print "Enter packages to remove (space-separated): ")" REMOVE_PKGS
        if [ -n "$REMOVE_PKGS" ]; then
          local pkgs_to_remove=($REMOVE_PKGS)
          local updated_pkgs=()
          for pkg in "${USERPKGS[@]}"; do
            local remove=false
            for rem_pkg in "${pkgs_to_remove[@]}"; do
              if [[ "$pkg" == "$rem_pkg" ]]; then
                remove=true
                break
              fi
            done
            if ! $remove; then
              updated_pkgs+=("$pkg")
            fi
          done
          USERPKGS=("${updated_pkgs[@]}")
          info_print "User packages updated."
        fi
        ;;
      3) break ;;
      *) warning_print "Invalid option. Please try again." ;;
    esac
  done
}

# Function to add or remove services
add_or_remove_services() {
   while true; do
    display_header
    info_print "Current user-defined services:"
    if [ ${#USER_SVCS[@]} -eq 0 ]; then
        info_print "  (None)"
    else
        for SVC in "${USER_SVCS[@]}"; do
          info_print "  - $SVC"
        done
    fi
    echo ""
    info_print "1) Add user services"
    info_print "2) Remove user services"
    info_print "3) Go back"
    select_print "1" "3" "Choose an option: " OPTION

    case $OPTION in
      1)
        read -rp "$(info_print "Enter additional services to enable (space-separated): ")" ADD_SVCS
        if [ -n "$ADD_SVCS" ]; then
           mapfile -t -O "${#USER_SVCS[@]}" USER_SVCS < <(echo "$ADD_SVCS" | tr ' ' '\n')
           info_print "User services updated."
        fi
        ;;
      2)
        read -rp "$(info_print "Enter services to disable (space-separated): ")" REMOVE_SVCS
        if [ -n "$REMOVE_SVCS" ]; then
          local svcs_to_remove=($REMOVE_SVCS)
          local updated_svcs=()
          for svc in "${USER_SVCS[@]}"; do
            local remove=false
            for rem_svc in "${svcs_to_remove[@]}"; do
              if [[ "$svc" == "$rem_svc" ]]; then
                remove=true
                break
              fi
            done
            if ! $remove; then
              updated_svcs+=("$svc")
            fi
          done
          USER_SVCS=("${updated_svcs[@]}")
           info_print "User services updated."
        fi
        ;;
      3) break ;;
      *) warning_print "Invalid option. Please try again." ;;
    esac
  done
}

# Function to display packages
display_packages() {
  info_print "These are the packages that will be installed:"
  for PKG in "${SYSTEM_PKGS[@]}"; do
    info_print "  - $PKG"
  done
}

# Function to display services
display_services() {
  info_print "These are the services that will be enabled:"
  for SVC in "${SYSTEM_SVCS[@]}"; do
    info_print "  - $SVC"
  done
}

# Function to save user packages and services to YAML file
save_userpkgs() {
  # Ensure the file exists and has the correct structure
  if [ ! -f "$USER_YAML" ] || [ ! -s "$USER_YAML" ]; then
    echo -e "packages: []\nservices: []" > "$USER_YAML"
  fi
  info_print "Saving user-defined packages and services to $USER_YAML..."
  sleep 1.5
  yq -i -y '.packages = []' "$USER_YAML"
  sleep 1.5
  yq -i -y '.services = []' "$USER_YAML"
  sleep 1.5
  for PKG in "${SYSTEM_PKGS[@]}"; do
    yq -i -y '.packages += ["'$PKG'"]' "$USER_YAML"
    sleep 1.5
  done
  for SVC in "${SYSTEM_SVCS[@]}"; do
    yq -i -y '.services += ["'$SVC'"]' "$USER_YAML"
    sleep 1.5
  done
  info_print "User configuration saved."
  sleep 1.5
}

# Function to review packages and services
review_packages_and_services() {
  display_header
  info_print "Consolidating and reviewing packages and services..."
  package_lists
  echo ""
  info_print "Packages to be installed:"
  if [ ${#SYSTEM_PKGS[@]} -eq 0 ]; then
      info_print "  (None)"
  else
      for PKG in "${SYSTEM_PKGS[@]}"; do
        info_print "  - $PKG"
      done
  fi
  echo ""
  info_print "Services to be enabled:"
   if [ ${#SYSTEM_SVCS[@]} -eq 0 ]; then
      info_print "  (None)"
  else
      for SVC in "${SYSTEM_SVCS[@]}"; do
        info_print "  - $SVC"
      done
  fi
  echo ""
  read -rp "$(info_print "Press Enter to continue.")"
}

# Function to handle package and service selection
packages_and_services() {
  load_base_packages_services
  load_user_packages
  package_lists
  while true; do
    display_header
    info_print "Package and Service Management Menu:"
    choices_print "1" ") Choose role"
    choices_print "2" ") Load user packages"
    choices_print "3" ") Add or remove packages"
    choices_print "4" ") Add or remove services"
    choices_print "5" ") Review packages and services"
    choices_print "6" ") Save packages and services"
    choices_print "7" ") Continue"
    #choices_print "8" ") Go back"
    select_print "1" "7" "Choose an option: " OPTION

    case $OPTION in
      1) choose_role ;;
      2) load_user_packages ;;
      3) add_or_remove_packages ;;
      4) add_or_remove_services ;;
      5) review_packages_and_services ;;
      6) save_userpkgs ;;
      7)
        package_lists
        info_print "Package and service selection complete."
        break ;;
      8)
        Yn_print "Do you want to save your user package/service changes before going back?"
        read -rp "" SAVE_CHOICE
        if [[ "$SAVE_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            save_userpkgs
        fi
        return ;;
      *) warning_print "Invalid option. Please try again." ;;
    esac
  done
}

# Package and service lists for the role options
system_role() {
  local ROLE=$1
  info_print "Adding packages and services for role: $ROLE"
  local new_role_pkgs=()
  mapfile -t new_role_pkgs < <(yq -r ".roles.$ROLE.packages[]?" "$ROLES_YAML")
  for pkg in "${new_role_pkgs[@]}"; do
      local found=false
      for existing_pkg in "${ROLE_PKGS[@]}"; do
          if [[ "$existing_pkg" == "$pkg" ]]; then
              found=true
              break
          fi
      done
      if ! $found; then
          ROLE_PKGS+=("$pkg")
      fi
  done

  local new_role_svcs=()
  mapfile -t new_role_svcs < <(yq -r ".roles.$ROLE.services[]?" "$ROLES_YAML")
   for svc in "${new_role_svcs[@]}"; do
       local found=false
       for existing_svc in "${ROLE_SVCS[@]}"; do
           if [[ "$existing_svc" == "$svc" ]]; then
               found=true
               break
           fi
       done
       if ! $found; then
           ROLE_SVCS+=("$svc")
       fi
   done
}

# Consolidate all package lists and remove duplicates
package_lists() {
  # Combine all sources into temporary arrays
  # Ensure INSTALL_GPU_DRIVERS is treated as an array
  local all_pkgs+=("${BASE_PKGS[@]}" "${MICROCODE}" "${INSTALL_GPU_DRIVERS[@]}" "${KERNEL_PKG}" "${ROLE_PKGS[@]}" "${USERPKGS[@]}" "${SYSTEM_PKGS[@]}")
  local all_svcs+=("${BASE_SVCS[@]}" "${ROLE_SVCS[@]}" "${USER_SVCS[@]}" "${SYSTEM_SVCS[@]}")

  # Remove duplicates and assign to final variables
  mapfile -t SYSTEM_PKGS < <(printf "%s\n" "${all_pkgs[@]}" | grep -v '^\s*$' | sort -u)
  mapfile -t SYSTEM_SVCS < <(printf "%s\n" "${all_svcs[@]}" | grep -v '^\s*$' | sort -u)
  
}

