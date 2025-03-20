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

### Future

- **Interactive Partitioning**: Support for custom partitioning and dual-boot setups.
- **Snapshot Management**: Automate snapshot creation and scheduling.
- **Improved Local Execution**: Simplify running the scripts locally after cloning the repository.

## Running the Script

### Prerequisites

- A bootable Arch Linux ISO (2025.01.01 or later is recommended).
- A stable internet connection.
- A target disk for installation (all data on the selected disk will be erased).

### Running the Script

1. Boot into the Arch Linux live environment.
2. Run the following command to start the installation:
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/jwalk9000/archbase.btrfs/main/archsetup.sh)
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
  user:
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
   git clone https://github.com/yourusername/archbase.btrfs.git
   ```
2. Navigate to the project directory and run the setup script:
   ```bash
   cd archbase.btrfs
   ./archsetup.sh
   ```

## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, feel free to open an issue or submit a pull request.

## Acknowledgements

Special thanks to the Arch Linux community for their extensive documentation and to all contributors who openly share their setup scripts.

## License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).