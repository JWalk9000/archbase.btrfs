# ArchBase.Btrfs - Automated Arch Linux Installation with Btrfs

## General Description and Goals

I created this set of scripts because I wanted to have a quick, repeatable, and stable way to have an Arch Linux base system to try out different Desktop Environments, on different hardware, leveraging community made DE setups. As the end of support for Windows 10 approaches, and with the consitently worse and worse behavior of Microsoft I am more determined than ever to select a daily driver linux for and my family. What began as of a couple simple scripts to do everything with no user input has now grown to essentially being a whole installer that almost anyone can use and customise

ArchBase.Btrfs is a set of bash scripts designed to automate the installation of Arch Linux with a focus on using the Btrfs file system. This project aims to streamline the setup process while providing flexibility for customization to suit individual preferences. It offers a base installation that includes the essentials and provides a guided first-boot script to install a desktop environment and additional packages.

Whether you're looking to use this script as-is, fork it for personal use, or modify it locally, ArchBase.Btrfs is designed to be user-friendly while catering to advanced users who want control over their system setup.

## Features

ArchBase.Btrfs is a set of bash scripts designed to automate the installation of Arch Linux with a focus on using the Btrfs file system. This project aims to streamline the setup process while providing flexibility for customization to suit individual preferences. It offers a base installation that includes the essentials and provides a guided first-boot script to install a desktop environment and additional packages.

Whether you're looking to use this script as-is, fork it for personal use, or modify it locally, ArchBase.Btrfs is designed to be user-friendly while catering to advanced users who want control over their system setup.

## Running As-Is

### Prerequisites
    - A bootable Arch Linux install ISO, version 2025.01.01 or later.
    - A stable internet connection.
    - A target disk for installation (all data on this disk will be erased).

### Running the Script As-Is

1. Run with Curl and Bash (recommended).
```
bash <(curl -s https://raw.githubusercontent.com/jwalk9000/archbase.btrfs/main/archsetup.sh)
```

2. Clone the repository to the target machine and run locally.
```
git clone https://github.com/JWalk9000/archbase.btrfs.git && cd archbase.btrfs

./archsetup.sh
```

3. Follow the prompts to complete the installation process. Once the base system is installed, the first-boot script can be run as a command, allowing you to install your desired desktop environment and additional packages.


## Forking and/or modifying



