
# Building a Custom Arch Linux ISO with Calamares

## Step 1: Install Required Packages
Install the necessary packages for building the ISO and Calamares:
```sh
    sudo pacman -S archiso calamares
```

## Step 2: Set Up the Build Environment
Create a working directory for the ISO build process:
```sh
    mkdir -p ~/iso-build/airootfs
    cd ~/iso-build
```

## Step 3: Copy the Base Files
Copy the default Arch ISO configuration files to your working directory:
```sh
    cp -r /usr/share/archiso/configs/releng/* .
```
## Step 4: Customize the ISO
Customize the 'airootfs' directory to include your installed system and configurations:
```sh
    rsync -a /mnt/ ~/iso-build/airootfs/
```

## Step 5: Configure Calamares
Edit the Calamares configuration files to match your system setup:
```sh
    nano ~/iso-build/airootfs/etc/calamares/settings.conf
```

## Step 6: Build the ISO
Use the 'build.sh' script provided by 'archiso' to build your custom ISO:
```sh
    ./build.sh -v
```

## Step 7: Test the ISO
Once the ISO is built, test it in a virtual machine to ensure everything works as expected:
```sh
    qemu-system-x86_64 -boot d -cdrom out/archlinux-*.iso -m 2048
```

## Step 8: Finalize and Distribute
After testing, you can distribute the ISO as needed.




# Additional Instructions for Calamares Configuration
---------------------------------------------------

## Modules Configuration:
```sh
    nano ~/iso-build/airootfs/etc/calamares/modules/*
```

## Locale and Keyboard:
```sh
    nano ~/iso-build/airootfs/etc/calamares/modules/locale.conf
    nano ~/iso-build/airootfs/etc/calamares/modules/keyboard.conf
```

## Partitioning:
```sh
    nano ~/iso-build/airootfs/etc/calamares/modules/partition.conf
```



