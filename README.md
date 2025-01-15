# ArchBase.Btrfs - Automated Arch Linux Installation with Btrfs

#WIP

## General Description and Goals

I created this set of scripts because I wanted to have a quick, repeatable, and stable way to have an Arch Linux base system to try out different Desktop Environments, on different hardware, leveraging community made DE setups. As the end of support for Windows 10 approaches, and with the consitently worse and worse behavior of Microsoft I am more determined than ever to select a daily driver linux for and my family. What began as of a couple simple scripts to do everything with no user input has now grown to essentially being a whole installer that almost anyone can use and customise

ArchBase.Btrfs is a set of bash scripts designed to automate the installation of Arch Linux with a focus on using the Btrfs file system. This project aims to streamline the setup process while providing flexibility for customization to suit individual preferences. It offers a base installation that includes the essentials and provides a guided first-boot script to install a desktop environment and additional packages.

Whether you're looking to use this script as-is, fork it for personal use, or modify it locally, ArchBase.Btrfs is designed to be user-friendly while catering to advanced users who want control over their system setup.

## Features

    - BTRFS file system, with root, home, and snapshots subvolumes.
    - Install to either BIOS or EFI systems.
    - Select your preferred Linux Kernel.
    - Root and User Credential setup, and auto-login option.
    - Optional GPU packages.
    - Optional user define package list, both premade and during the installer.
    - Boot manager options for EFI systems. ( only bash is working right now, issues with BTRFS subvolumes)

## Running As-Is

### Prerequisites
- A bootable Arch Linux install ISO, version 2025.01.01 or later. (It may work with earlier ISOs, but I had issues with expired certs for different things from the previous 2 releases)
- A stable internet connection.
- A target disk for installation (Currently uses the entire target disk, all data will be erased).

### Running the Script As-Is

1. Run with Curl and Bash.
```
bash <(curl -s https://raw.githubusercontent.com/jwalk9000/archbase.btrfs/main/archsetup.sh)
```

2. Follow the prompts to complete the installation process. Once the base system is installed, and you have rebooted into you newly installed Arch Linux, the first-boot script can be run as a command (firstBoot.sh), allowing you to install your desired desktop environment and additional packages. These files can be removed thereafter.


## Forking and modifying

### Forking on GitHub

1. Click the "Fork" button on the top-right corner of the repository page.
2. Make modifications to your forked repository as needed.
     - modify the ```REPO``` variable to point to your repository details in both ```archsetup.sh``` and ```firstBoot.sh```
3. Then folow the above instructions with your username (and repo name if you changed it) in place of mine.

### (Future) Clone, Modify, then run locally
 - This is not implemented yet.



## General modifications

### Pre-Set Variable

In the ```archsetup.sh``` script you can preset some of the variables if you are going to be doing the same install over and over. I would highly recommend NOT putting passwords in that would be used for any sort of production environment or long term testing. 

### Additional Services

Below the variables you can add services that need to be enabled, depending on what you add to the userpkgs.txt

### userpkgs.txt

In this file you can list packages that you would like to have installed during this initial setup, separated by spaces only. 

For example:
```
kate neofetch kitty htop sddm xfce
```

I would strongly suggest that if you are installing a DE from the gui_options.json that you dont install anything extra, not even the gpu drivers. The only exception to this might be sddm, as your greeter, some of the DE install scripts have it and skip installing if it is already on the system however most don't seem to include it. You can always leave it out and install and enable it after the fact if you choose to.