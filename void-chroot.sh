#! /bin/bash

# Hostname and time
echo "skylake" > /etc/hostname
ln -s /usr/share/zoneinfo/${timezone} /etc/localtime
hwclock --systohc --utc

# Locale
echo "${locale}.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
cat << EOF > /etc/locale.conf
LANG="${locale}.UTF-8"
LC_COLLATE=C
EOF
echo "KEYMAP=${kb_layout}" > /etc/vconsole.conf

# Set root password and change root shell to bash
passwd << EOD
${root_password}
${root_password}
EOD
usermod -s /bin/bash root

# Create user and add to groups
useradd -m -G audio,video,input,network,wheel void

# Set user password
passwd ${username} << EOD
${user_password}
${user_password}
EOD

# Enable sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/99_wheel

# Create fstab
UEFI_UUID=$(blkid -s UUID -o value /dev/"${disk}1")
ROOT_UUID=$(blkid -s UUID -o value /dev/"${disk}2")
sed -i '/tmpfs/d' /etc/fstab
cat << EOF >> /etc/fstab
UUID=${ROOT_UUID} / ext4 defaults 0 1
UUID=${UEFI_UUID} /boot vfat defaults,noatime 0 2
tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev,mode=1777 0 0
EOF

# Create swapfile
sudo fallocate -l 4G /swapfile
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile
cat << EOF >> /etc/fstab
/swapfile none swap sw 0 0
EOF

# Dracut config
echo -e "hostonly=yes\nhostonly_cmdline=yes" >> /etc/dracut.conf.d/00-hostonly.conf
echo "tmpdir=/tmp" >> /etc/dracut.conf.d/30-tmpfs.conf
dracut --regenerate-all --force --hostonly

# Grub bootloader
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
xbps-install -Sy grub-x86_64-efi
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="Void Linux"
xbps-install -y grub-terminus
cp /etc/default/grub /etc/default/grub.backup
cat << EOF  > /etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Void Linux"
GRUB_CMDLINE_LINUX_DEFAULT="${kernel_parameters}"
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE=3840x2160x32
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_FONT="/boot/grub/fonts/terminus32.pf2"
EOF
grub-mkconfig -o /boot/grub/grub.cfg

# Enable nonfree repo
xbps-install -y void-repo-nonfree

# Intel microcode, Xorg and nVidia driver
xbps-install -Sy intel-ucode xorg-minimal xorg-apps nvidia

# Essentials
xbps-install -y ntfs-3g polkit elogind rtkit

# Useful tools
xbps-install -y base-devel util-linux coreutils xtools xdg-utils curl nano vsv btop tree

# Pulseaudio
xbps-install -y alsa-{utils,firmware} apulse bluez{,-alsa} ffmpeg alsa-plugins{,-ffmpeg,-pulseaudio} pulseaudio pavucontrol

# Gstreamer
xbps-install -y gstreamer1 gst-libav gst-plugins-base1 gst-plugins-good1 gst-plugins-bad1 gst-plugins-ugly1

# Fonts
xbps-install -y fonts-roboto-ttf noto-fonts-ttf noto-fonts-ttf-extra noto-fonts-emoji noto-fonts-cjk

# Cinnamon desktop and apps
xbps-install -y cinnamon cinnamon-menus nemo nemo-fileroller

# Gnome apps
xbps-install -y gedit gnome-terminal eog eog-plugins gnome-disk-utility gnome-screenshot gnome-calculator gnome-keyring rhythmbox celluloid

# Software
xbps-install -y fontmanager firefox vscode

# Themes
xbps-install -y Adapta papirus-icon-theme breeze-amber-cursor-theme

# Syslog
xbps-install -y socklog-void
usermod -a -G socklog ${username}
ln -s /etc/sv/socklog-unix /etc/runit/runsvdir/default/
ln -s /etc/sv/nanoklogd /etc/runit/runsvdir/default/

# Time sync (NTP)
xbps-install -y chrony
ln -s /etc/sv/chronyd /etc/runit/runsvdir/default/

# Disable/enable services
sudo sv down acpid
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/

# Wifi setup
touch /etc/sv/dhcpcd/down
touch /etc/sv/wpa_supplicant/down
xbps-install -y iwd NetworkManager
cat << EOF >> /etc/NetworkManager/NetworkManager.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF
cat << EOF > /etc/iwd/main.conf
[General]
UseDefaultInterface=true
EOF
ln -s /etc/sv/iwd /etc/runit/runsvdir/default/
ln -s /etc/sv/NetworkManager /etc/runit/runsvdir/default/

# Nivida config
cat << EOF > /usr/share/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    BoardName      "GeForce GTX 1070"
    Option         "Coolbits" "4"
EndSection
EOF

# Xinitrc
cat << EOF > /home/${username}/.xinitrc
nvidia-settings -a '[gpu:0]/GPUFanControlState=1' -a '[fan:0]/GPUTargetFanSpeed=40' &
exec cinnamon-session
EOF

# Create user dirs
xbps-install -y xdg-user-dirs-gtk
xdg-user-dirs-update

# Reconfigure & finish
xbps-reconfigure -fa
rm void-chroot.sh && exit 0