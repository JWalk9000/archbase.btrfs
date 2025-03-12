# ArchBase.Btrfs - Automated Arch Linux Installation with Btrfs

#WIP

## General Description and Goals

I created this set of scripts initially because I wanted to have a quick, repeatable, and stable way to have an Arch Linux base system to try out different desktop environments, configurations, and setups for my family on different hardware. It has since grown into almost a whole turnkey installation that not only give choices for preinstalling basic desktop environments, but also facilitates the use of community made configuration setup scripts. 

As the end of support for Windows 10 approaches, and with the consitently worse and worse behavior of Microsoft I am more determined than ever to select a daily driver linux for my family. What started as a few basic scripts to make partitioning, creating a user, base system install and setup faster is now a whole installer that almost anyone can use and customise to fit their needs.

ArchBase.Btrfs currently uses a preselcted partition plan, using BTRFS subvolumes for the root, home, and a .snapshots directories. Virtually everything else in the installation is easily customisable, either with the selections during the install, or in one of the 3 configuration files (userpkgs.txt, roles.yml, or gui_options.json). Using it as-is offers a base installation that includes the essentials to get up and running on most hardware quickly

I have done my best to make this user-friendly for newer linux users, while catering to advanced users who want control over their system setup.

## Features

### Current

- BTRFS file system, with root, home, and snapshots subvolumes.
- Install to either BIOS or EFI systems.
- Select your preferred Linux Kernel.
- Root and User Credential setup, and auto-login option.
- Optional GPU packages.
- Optional user defined package list, both premade and during the installer.
- Boot manager options for EFI systems. ( only bash is working right now, issues with BTRFS subvolumes).
- Base system packags and services configured via Yaml file.

### Future

- Convert userpkgs.txt to use yaml. 
- Make running it locally after cloning easier.
- Interactive partioning, and by extension, installing alongside another OS.
- Snapshot setup and scheduling.
- Standardization for importing and installing user DE dependancies and configurations.

### Known Issues

- Currently only grub works for a boot loader, because of this I have temporarily disabled displaying other options until I can fix this.(contribution welcome)

## Running As-Is

### Prerequisites
- A bootable Arch Linux install ISO, version 2025.01.01 or later. (It may work with earlier ISOs, but I had issues with expired certs for different things from the previous 2 releases)
- A stable internet connection.
- A target disk for installation (Currently uses the entire chosen target disk, all data will be erased).

### Running the Script As-Is

1. Run with Curl and Bash.
```
bash <(curl -s https://raw.githubusercontent.com/jwalk9000/archbase.btrfs/main/archsetup.sh)
```

2. Follow the prompts to complete the installation process. Once the base system is installed, and you have rebooted into you newly installed Arch Linux, the first-boot script can be run as a command ```firstBoot.sh```, allowing you to install your desired configuration and additional packages. These files can be removed thereafter.


## Forking and modifying

### Forking on GitHub

1. Click the "Fork" button on the top-right corner of the repository page.
2. Make modifications to your forked repository as needed.
     - modify the ```REPO``` variable to point to your repository details in both ```archsetup.sh``` and ```firstBoot.sh```
3. Then follow the above instructions with your username (and repo name if you changed it) in place of this one.

### (Future) Clone, Modify, then run locally

 - This is not implemented yet.


## General modifications

### Pre-Set Variable

In the ```archsetup.sh``` script you can preset some of the variables if you are going to be doing the same install over and over. I would highly recommend NOT putting passwords in that would be used for any sort of production environment or long term testing. 

#### Additional Services

~~Below the variables you can add services that need to be enabled, depending on what you add to the userpkgs.txt~~
Additional services that need to enabled can be added to the ```base_services``` array in the roles.yml file.

#### userpkgs.txt

In this file you can list packages that you would like to have installed during this initial setup, separated by spaces only. 

For example:
```
kate neofetch kitty htop sddm xfce
```

~~I would strongly suggest that if you are installing a DE from the gui_options.json that you dont install anything extra, not even the gpu drivers. The only exception to this might be sddm, as your greeter, some of the DE install scripts have it and skip installing if it is already on the system however most don't seem to include it. You can always leave it out and install and enable it after the fact if you choose to.~~ Not a concern anymore


## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, feel free to open an issue or submit a pull request.

## Acknowledgements

Special thanks to the Arch Linux community for their extensive documentation, Stephan Raabe(My-Linux-4-Work) who's setup scripts were the initial inspiration for me to start this project, and all others who openly share their setup scripts to be used and shared.

## License

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)