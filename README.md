# ArchBase.Btrfs - Automated Arch Linux Installation with Btrfs

## General Description and Goals

I created this set of scripts initially because I wanted to have a quick, repeatable, and stable way to have an Arch Linux base system to try out different desktop environments, configurations, and setups for my family on different hardware. It has since grown into almost a whole turnkey installation that not only gives choices for preinstalling basic desktop environments, but also facilitates the use of community made configuration setup scripts.

As the end of support for Windows 10 approaches, and with the consitently worse and worse behavior of Microsoft I am more determined than ever to select a daily driver linux for my family. What started as a few basic scripts to make partitioning, creating a user, base system install and setup faster is now a whole installer that almost anyone can use and customise to fit their needs.

ArchBase.Btrfs currently uses a preselected partition plan with Btrfs subvolumes for `root`, `home`, and `.snapshots`. Most other aspects of the installation are customizable through interactive prompts or configuration files (`userpkgs.yml`, `roles.yml`, and `gui_options.json`).

I have done my best to make this user-friendly for newer linux users, while catering to advanced users who want control over their system setup.

## Features

### Current

- **Btrfs File System**: Automatically creates subvolumes for `root`, `home`, and `.snapshots`.
- **Bootloader Support**: Installs GRUB for both BIOS and EFI systems.
- **Kernel Selection**: Choose from `linux`, `linux-lts`, `linux-zen`, or `linux-hardened`.
- **User and Root Setup**: Configure root and user credentials with optional auto-login.
- **GPU Drivers**: Detects and installs drivers for NVIDIA, AMD, or Intel GPUs.
- **Custom Packages**: Install additional packages defined in `userpkgs.yml` or interactively during installation.
- **Role-Based Configuration**: Predefined roles (e.g., server, desktop environments) with associated packages and services.
- **Post-Installation Scripts**: Optional first-boot scripts for further customization.
- **Local Execution**: Checks for local files, clones the repo into `/tmp` if not already there.
- **Script review Verification**: Set the local variable to true so that the script will be able to continue. This is to Protect you and me. I may remove this later.

### Future

- **Interactive Partitioning**: ✅ **IN PROGRESS** - Support for custom partitioning and dual-boot setups.
  - ✅ YAML-based partition layout configuration
  - ✅ Interactive menu for partition management
  - ✅ Load/save partition layouts
  - 🚧 OS detection and dual-boot setup
  - 🚧 Automatic partition resizing
  - 🚧 Custom Btrfs subvolume management
- **Snapshot Management**: Automate snapshot creation and scheduling.

## Recent Changes and Improvements

- **Improved Package and Service Management:**
  - Added a package and service selection menu to make it more streamlined and customizable. 
  - The review process includes a package verification step, allowing you to check for typos or missing packages before continuing.
  - Saving user package and service selections added, making it easier to ensure your changes are not lost, and your selections are reproducible
  - The scripts now use a single-layer YAML structure for `userpkgs.yml` (see below for the new format).
  - Using arrays instead of strings for package and service lists now.

- **Improved Local Execution:** 
  - `archsetup.sh` now clones the installer and runs it locally if its not being launched locally. This means that you can clone it locally and make changes before running it, like using a custom `userpkgs.yml`.

- **Bug Fixes and Reliability:**
  - Implemented a few locations where steps are delayed are echoed to better catch errors.

## Running the Script

### Prerequisites

- A bootable Arch Linux ISO (2025.01.01 or later is recommended).
- A stable internet connection.
- A target disk for installation (all data on the selected disk will be erased).

### Running the Script

1. Boot into the Arch Linux live environment.
2. Run the following command to start the installation:
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/jwalk9000/archbase.btrfs/dev/archsetup.sh)
   ```
3. Follow the prompts to complete the installation process.

### Post-Installation

After rebooting into the newly installed system, you can run the first-boot script to install additional configurations:
```bash
firstBoot.sh
```

## Configuration Files

### `userpkgs.yml`

This file allows you to define additional packages and services to be installed during the setup. Example:
```yml
packages:
  - neofetch
  - htop
  - sddm
  - hyprland
services:
  - sddm
```

### `roles.yml`

Defines roles (e.g., server, desktop environments) with associated packages and services. Example:
```yml
roles:
  server:
    packages:
      - zsh
      - rsync
      - nginx
    services:
      - nginx
  kde:
    packages:
      - plasma
      - kde-applications
    services:
      - sddm
```

### `gui_options.json`

Defines optional GUI setup scripts for first-boot customization. Example:
```json
[
  {
    "name": "ML4W Hyperland-Full (AMD GPU ONLY!!)",
    "repo": "https://github.com/mylinuxforwork/dotfiles",
    "installer": "setup-arch.sh"
  }
]
```

## Forking and Modifying

### Forking on GitHub

1. Click the "Fork" button on the repository page.
2. Modify the `REPO` variable in `archsetup.sh` and `firstBoot.sh` to point to your forked repository.
3. Run the script as described above.

### Local Execution

To run the scripts locally after cloning the repository:
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/archbase.btrfs.git /tmp/archbase
   ```
2. Execute the setup script:
   ```bash
   exec /tmp/archbase/archsetup.sh
   ```

## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, feel free to open an issue or submit a pull request.

## Acknowledgements

Special thanks to the Arch Linux community for their extensive documentation and to all contributors who openly share their setup scripts.

## License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).