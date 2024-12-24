# Partition and install the base and dependencies.

### set the time.
```sh
timedatectl set-ntp true
```

## Partition the disk
```sh
fdisk /dev/sda
```

## Create a single partition for boot partition and single partition for Btrfs
### /dev/sda1 - 512M - boot partition
### /dev/sda2 - 100% - Btrfs partition
```sh
n
p
1

+512M

n
p
2


w

```

### Format the boot partition with ext4
```sh
mkfs.fat -F 32 /dev/sda1
```

### Format the partition with Btrfs
```sh
mkfs.btrfs /dev/sda2
```

### Mount the Btrfs filesystem
```sh
mount /dev/sda2 /mnt
```

### Create Btrfs subvolumes
```sh
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
```

### Unmount the Btrfs filesystem
```sh
umount /mnt
```

### Mount the subvolumes
```sh
mount -o subvol=@ /dev/sda2 /mnt
mkdir /mnt/home
mount -o subvol=@home /dev/sda2 /mnt/home
mkdir /mnt/.snapshots
mount -o subvol=@snapshots /dev/sda2 /mnt/.snapshots
```

### Mount the boot partition
```sh
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
```

### Install the base system and requirements. Can swap linux with linux-lts, linux-hardened, or linux-zen, or linux-rt.
```sh
pacstrap /mnt base linux-zen linux-firmware btrfs-progs base-devel git curl nano openssh networkmanager
```

### Generate an fstab file
```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

### Chroot into the new system
```sh
arch-chroot /mnt
```

### Set the time zone
```sh
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc
```

### Localization
```sh
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### Network configuration
```sh
echo "myhostname" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts

systemctl enable NetworkManager
systemctl enable sshd
```

### Set the root password
```sh
passwd root
```
### Set up user and permissions. Add user to the wheel group for sudo privileges, change username as needed.
```sh
useradd -m -G wheel -s /bin/bash tempuser
passwd tempuser
```

### (option) Install and configure the bootloader - GRUB
```sh
pacman -S grub
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

### (option) Install and configure the bootloader - systemd-boot
```sh
bootctl --path=/boot install
```

### (option) Install and configure the bootloader - rEFInd
```sh
pacman -S refind
refind-install
```


## Exit chroot and reboot
```sh
exit
umount -R /mnt
reboot
```

# After reboot and logged in with User

### Install Yay
```sh
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
```

### Install M4LW Hyprland
```sh
bash <(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh)
```

## follow onscreen prompts and reboot into new OS.
