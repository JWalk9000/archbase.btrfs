#!/usr/bin/env bash
set -e

# This is a script to allow users to install additional packages and enable services interactively during the installation process.
# This script will be called by the main script, archsetup.sh, if the user chooses to install additional packages and enable services during the installation process.

# Load required functions and variables
source /tmp/archbase/colors.sh
source /tmp/archbase/functions.sh
sourch /tmp/archbase/roles/

# Variables to store user inputs
USERPKGS=()
VERIFIED_PKGS=()
ENABLE_SVCS=()
ROLES_YAML="./roles/roles.yml"
USER_YAML="./roles/userpkgs.yml"
CURRENT_ROLE=""

# Function to load user packages from YAML file
load_user_packages() {
  if [ -f "./roles/userpkgs.yml" ]; then
    USERPKGS=$(yq eval '.packages.user[]' ./roles/userpkgs.yml)
  else
    warning_print "No userpkgs.yml file found."
  fi
}

# Choose a role for the system (function).
choose_role() {
  display_header
  if [[ -n "$CURRENT_ROLE" ]]; then
    info_print "You have already selected the role: $CURRENT_ROLE."
    choices_print "1" ") Add another role"
    choices_print "2" ") Switch to a different role"
    select_print "1" "2" "Choose an option: " ROLE_ACTION
    case $ROLE_ACTION in
      1)
        info_print "Adding another role."
        ;;
      2)
        info_print "Switching roles. Removing packages and services from the current role: $CURRENT_ROLE."
        ROLE_PKGS=("${ROLE_PKGS[@]/$(yq -r ".roles.$CURRENT_ROLE.packages[]" $ROLES_YAML | tr '\n' ' ')}")
        ENABLE_SVCS=("${ENABLE_SVCS[@]/$(yq -r ".roles.$CURRENT_ROLE.services[]" $ROLES_YAML | tr '\n' ' ')}")
        CURRENT_ROLE=""
        ;;
      *)
        warning_print "Invalid option. Returning to the menu."
        return
        ;;
    esac
  fi

  info_print "Below are some available system roles to choose from. If you created a userpkgs.txt file, you can skip this step or select a role as well."
  info_print "I suggest choosing to install Hyperland if you intend on using the firstBoot.sh script to install a Hyperland configuration."
  echo ""
  info_print "=> Select a role:"
  choices_print "0" ") Skip/Custom"
  choices_print "1" ") Server ----------------- A basic server setup with some common services aiming at a similar experience to Ubuntu Server."
  choices_print "2" ") Desktop - XFCE --------- A lightweight desktop environment, similar layout to MS Windows 7."
  choices_print "3" ") Desktop - KDE Plasma --- A modern, feature-rich desktop environment, similar layout MS Windows 10/11."
  choices_print "4" ") Desktop - GNOME -------- A modern, feature-rich desktop environment, similar layout to macOS."
  choices_print "5" ") Desktop - Hyprland ----- A highly customizable dynamic tiling Wayland compositor keyboard-shortcut-driven."
  select_print "0" "5" "System role: " "SYSTEM_ROLE"
  case $SYSTEM_ROLE in
    1)
      system_role server
      CURRENT_ROLE="server"
      return 0;;
    2)
      system_role xfce
      CURRENT_ROLE="xfce"
      return 0;;
    3)
      system_role kde
      CURRENT_ROLE="kde"
      return 0;;
    4)
      system_role gnome
      CURRENT_ROLE="gnome"
      return 0;;
    5)
      system_role hypr
      CURRENT_ROLE="hypr"
      return 0;;
    *)
      ROLE_PKGS=""
      return 0;;
  esac
}

# Function to verify user packages
verify_packages() {
  VERIFIED_PKGS=()
  for PKG in $USERPKGS; do
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
}

# Function to add or remove packages
add_or_remove_packages() {
  while true; do
    display_header
    info_print "Current packages:"
    for PKG in "${USERPKGS[@]}"; do
      info_print "  - $PKG"
    done
    echo ""
    info_print "1) Add packages"
    info_print "2) Remove packages"
    info_print "3) Go back"
    select_print "1" "3" "Choose an option: " OPTION

    case $OPTION in
      1)
        read -rp "$(info_print "Enter additional packages to install (space-separated): ")" ADD_PKGS
        if [ -n "$ADD_PKGS" ]; then
          USERPKGS+=($ADD_PKGS)
          verify_packages
        fi
        ;;
      2)
        read -rp "$(info_print "Enter packages to remove (space-separated): ")" REMOVE_PKGS
        if [ -n "$REMOVE_PKGS" ]; then
          for PKG in $REMOVE_PKGS; do
            USERPKGS=("${USERPKGS[@]/$PKG}")
          done
          verify_packages
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
    info_print "Current services:"
    for SVC in "${ENABLE_SVCS[@]}"; do
      info_print "  - $SVC"
    done
    echo ""
    info_print "1) Add services"
    info_print "2) Remove services"
    info_print "3) Go back"
    select_print "1" "3" "Choose an option: " OPTION

    case $OPTION in
      1)
        read -rp "$(info_print "Enter additional services to enable (space-separated): ")" ADD_SVCS
        if [ -n "$ADD_SVCS" ]; then
          ENABLE_SVCS+=($ADD_SVCS)
        fi
        ;;
      2)
        read -rp "$(info_print "Enter services to disable (space-separated): ")" REMOVE_SVCS
        if [ -n "$REMOVE_SVCS" ]; then
          for SVC in $REMOVE_SVCS; do
            ENABLE_SVCS=("${ENABLE_SVCS[@]/$SVC}")
          done
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
  for PKG in "${VERIFIED_PKGS[@]}"; do
    info_print "  - $PKG"
  done
}

# Function to display services
display_services() {
  info_print "These are the services that will be enabled:"
  for SVC in "${ENABLE_SVCS[@]}"; do
    info_print "  - $SVC"
  done
}

# Function to save user packages and services to YAML file
save_userpkgs() {
  yq eval -i '.packages.user = []' ./roles/userpkgs.yml
  for PKG in "${VERIFIED_PKGS[@]}"; do
    yq eval -i '.packages.user += ["'$PKG'"]' ./roles/userpkgs.yml
  done

  yq eval -i '.services.user = []' ./roles/userpkgs.yml
  for SVC in "${ENABLE_SVCS[@]}"; do
    yq eval -i '.services.user += ["'$SVC'"]' ./roles/userpkgs.yml
  done
}

# Function to handle package and service selection
packages_and_services() {
  display_header
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
    choices_print "8" ") Go back"
    select_print "1" "8" "Choose an option: " OPTION

    case $OPTION in
      1) choose_role ;;
      2) load_user_packages ;;
      3) add_or_remove_packages ;;
      4) add_or_remove_services ;;
      5)
        display_packages
        display_services
        ;;
      6) save_userpkgs ;;
      7) break ;;
      8) return ;;
      *) warning_print "Invalid option. Please try again." ;;
    esac
  done
}

# Package and service lists for the role options
system_role() {
  local ROLE=$1
  ROLE_PKGS+=($(yq -r ".roles.$ROLE.packages[]" $ROLES_YAML | tr '\n' ' '))
  ENABLE_SVCS+=($(yq -r ".roles.$ROLE.services[]" $ROLES_YAML | tr '\n' ' '))
}

# Consolidate all package lists and remove duplicates
package_lists() {
  BASE_PKGS+=($(yq -r '.base.packages[]' $ROLES_YAML | tr '\n' ' '))
  SYSTEM_PKGS=("${BASE_PKGS[@]}" "${MICROCODE}" "${INSTALL_GPU_DRIVERS}" "${KERNEL_PKG}" "${ROLE_PKGS[@]}" "${USERPKGS[@]}")
  SYSTEM_PKGS=($(echo "${SYSTEM_PKGS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')) # Remove duplicates
  ENABLE_SVCS=($(echo "${ENABLE_SVCS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')) # Remove duplicates
}

