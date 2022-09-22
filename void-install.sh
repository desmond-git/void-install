#! /bin/bash

# Variables
export disk="sda"
wifi_ssid=""
wifi_password=""
export kb_layout="sv-latin1"
export root_password=""
export username=""
export user_password=""
export locale="en_US"
export timezone="Europe/Stockholm"
export kernel_parameters="console=tty2 loglevel=3"

# Check if system is being installed to the correct disk
lsblk -o NAME,FSTYPE,LABEL,MOUNTPOINTS /dev/${disk}
read -p "Press ENTER to install to above disk or CTRL+C to abort." key

# Set keyboard layout
loadkeys ${kb_layout}

# Connect to wifi
nmcli device wifi connect ${wifi_ssid} password ${wifi_password}

# Partition the disk
sgdisk -Z /dev/${disk}
sgdisk -n 0:0:+512MiB -t 1:ef00 -c 1:"EFI System Partition" /dev/${disk}
sgdisk -n 0:0:0 -t 2:8300 -c 2:"Linux" /dev/${disk}
mkfs.fat -n ESP -F 32 /dev/"${disk}1"
yes | mkfs.ext4 -L VoidLinux /dev/"${disk}2"

# Mount partitions
mount /dev/"${disk}2" /mnt
mount --mkdir /dev/"${disk}1" /mnt/boot

# Prepare Chroot
ARCH=x86_64
REPO=https://repo-default.voidlinux.org/current
XBPS_ARCH=$ARCH xbps-install -Suvy xbps
yes | XBPS_ARCH=$ARCH xbps-install -Suvy -r /mnt -R "$REPO" base-system
for dir in sys dev proc; do mount --rbind /$dir /mnt/$dir; mount --make-rslave /mnt/$dir; done
cp -L /etc/resolv.conf /mnt/etc/
cp void-chroot.sh /mnt/
PS1='(chroot) # ' chroot /mnt/ /bin/bash /void-chroot.sh
