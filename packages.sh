#!/usr/bin/env bash
set -e

# This is a script to allow users to install additional packages and enable services interactively during the installation process.
# This script will be called by the main script, archsetup.sh, if the user chooses to install additional packages and enable services during the installation process.

# Load required functions and variables
source /tmp/archbase/colors.sh
source /tmp/archbase/functions.sh

# Variables to store user inputs
USERPKGS=()
VERIFIED_PKGS=()
ENABLE_SVCS=()

# Function to load user packages from YAML file
load_user_packages() {
  if [ -f "./roles/userpkgs.yml" ]; then
    USERPKGS=$(yq eval '.packages.user[]' ./roles/userpkgs.yml)
  else
    warning_print "No userpkgs.yml file found."
  fi
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
        read -rp "Enter the correct package name: " FIXPKG
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
    echo "Current packages:"
    for PKG in "${USERPKGS[@]}"; do
      echo "  - $PKG"
    done
    echo "1) Add packages"
    echo "2) Remove packages"
    echo "3) Go back"
    read -rp "Choose an option: " OPTION

    case $OPTION in
      1)
        read -rp "Enter additional packages to install (space-separated): " ADD_PKGS
        if [ -n "$ADD_PKGS" ]; then
          USERPKGS+=($ADD_PKGS)
          verify_packages
        fi
        ;;
      2)
        read -rp "Enter packages to remove (space-separated): " REMOVE_PKGS
        if [ -n "$REMOVE_PKGS" ]; then
          for PKG in $REMOVE_PKGS; do
            USERPKGS=("${USERPKGS[@]/$PKG}")
          done
          verify_packages
        fi
        ;;
      3) break ;;
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

# Function to add or remove services
add_or_remove_services() {
  while true; do
    echo "Current services:"
    for SVC in "${ENABLE_SVCS[@]}"; do
      echo "  - $SVC"
    done
    echo "1) Add services"
    echo "2) Remove services"
    echo "3) Go back"
    read -rp "Choose an option: " OPTION

    case $OPTION in
      1)
        read -rp "Enter additional services to enable (space-separated): " ADD_SVCS
        if [ -n "$ADD_SVCS" ]; then
          ENABLE_SVCS+=($ADD_SVCS)
        fi
        ;;
      2)
        read -rp "Enter services to disable (space-separated): " REMOVE_SVCS
        if [ -n "$REMOVE_SVCS" ]; then
          for SVC in $REMOVE_SVCS; do
            ENABLE_SVCS=("${ENABLE_SVCS[@]/$SVC}")
          done
        fi
        ;;
      3) break ;;
      *) echo "Invalid option. Please try again." ;;
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
  while true; do
    echo "Package and Service Management Menu:"
    echo "1) Choose role"
    echo "2) Load user packages"
    echo "3) Add or remove packages"
    echo "4) Add or remove services"
    echo "5) Review packages and services"
    echo "6) Save packages and services"
    echo "7) Continue"
    echo "8) Go back"
    read -rp "Choose an option: " OPTION

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
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

# Call the main function
packages_and_services