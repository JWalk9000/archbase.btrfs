#!/bin/bash

# Text color variables.
WARNING='\e[0;31m' # Red
BWARNING='\e[1;31m' # Bright Red
BANNER='\e[0;32m' # Green
INFO='\e[0;33m' # Yellow
BINFO='\e[1;33m' # Bright Yellow
INPUT='\e[0;34m' # Blue
RESET='\e[0m' # No Color

# Information text color function.
info_print() {
  echo -e "${INFO}$1${RESET}"
}

# Error/Warning text color function.
warning_print() {
  echo -e "${WARNING}$1${RESET}"
}

warning_bold() {
  echo -e "${BWARNING}$1${RESET}"
}

# User input choices text color function.
input_print() {
  echo -e "${INPUT}$1${RESET}"
}

# banner text color function.
banner_print() {
  echo -e "${BANNER}$1${RESET}"
}

# formating for user input choices.
choices_print() {
  echo -e "${INPUT}$1${INFO}$2${RESET}"
}

#  Display a Message with Y/N options
Yn_print() {
  echo -e "${INFO}$1(${INPUT}Y${INFO}/${INPUT}n${INFO}): ${RESET}"
}

yN_print() {
  echo -e "${INFO}$1(${INPUT}y${INFO}/${INPUT}N${INFO}): ${RESET}"
}