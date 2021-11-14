#!/bin/bash

#####
# Check which user is running the script
#####

# Check if script was executed as ROOT
if ((${EUID:-0} || "$(id -u)")); then
   echo "ERROR: This script must be run as root." 
   exit 1
fi

# Check if a user is passed as parameter
if [ $# -eq 0 ]; then
    echo "ERROR: You need to inform a user as parameter to be used in GNOME and Applications configuration."
    echo "Example: sudo -E bash fedora-setup.sh user1"
    exit 1
fi

# Check if the user session environment variables were preserved
if [ -v $DBUS_SESSION_BUS_ADDRESS ]; then
	echo "ERROR: You need to run 'sudo -E' to preserve session environment variables."
	exit 1
fi

# Storing USER for later configurations
USER=$1


#####
# First configs to kernel and DNF
#####

# Configuring DNF to be faster
tee -a /etc/dnf/dnf.conf > /dev/null <<EOF
fastestmirror=True
deltarpm=True
EOF

# Some Kernel/Usability Improvements
tee -a /etc/sysctl.d/40-max-user-watches.conf > /dev/null <<EOF
fs.inotify.max_user_watches=524288
EOF

# Some Kernel/Usability Improvements
tee -a /etc/sysctl.d/99-network.conf > /dev/null  <<EOF
net.ipv4.ip_forward=0
net.ipv4.tcp_ecn=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

tee -a /etc/sysctl.d/99-swappiness.conf > /dev/null  <<EOF
vm.swappiness=1
EOF


#####
# Add aditional repositories to system list
#####

# Nvidia drivers from Negativo17
dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo

# Visual Studio Code from Microsoft
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

# RPM Fusion Free
dnf install \
-y `# Do not ask for confirmation` \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm


#####
# Force update the whole system to the latest and greatest
#####

dnf upgrade --best --allowerasing --refresh -y

# And also remove any packages without a source backing them
dnf distro-sync -y

#####
# Install base packages and terminal applications from repositories
#####

dnf install \
-y `# Do not ask for confirmation` \
kernel-modules `# kernel modules to match the core kernel` \
fuse `# File System in Userspace (FUSE) v2 utilities` \
squashfuse `# FUSE filesystem to mount squashfs archives` \
gcc `# Various compilers (C, C++, Objective-C, ...)` \
gcc-c++ `# C++ support for GCC` \
dnf-plugins-core `# Core Plugins for DNF` \
kernel-devel `# Development package for building kernel modules to match the kernel` \
git `# Fast Version Control System` \
jq `# Command-line JSON processor` \
curl `# A utility for getting files from remote servers (FTP, HTTP, and others)` \
wget `# A utility for retrieving files using the HTTP or FTP protocols` \
httpie `# A Curl-like tool for humans` \
unzip `# A utility for unpacking zip files` \
bat `# cat(1) clone with wings` \
exfat-utils `# Allows managing exfat (android sd cards and co)` \
ffmpeg `# Adds Codec Support to Firefox, and in general` \
fuse-exfat `# Allows mounting exfat` \
fuse-sshfs `# Allows mounting servers via sshfs` \
GREYCstoration-gimp \
gvfs-fuse `# gnome<>fuse` \
gvfs-mtp `# gnome<>android` \
gvfs-nfs `# gnome<>ntfs` \
gvfs-smb `# gnome<>samba` \
htop `# CLI process monitor` \
NetworkManager-openvpn-gnome `# To enforce that its possible to import .ovpn files in the settings` \
openssh-askpass `# Base Lib to let applications request ssh pass via gui` \
p7zip `# Very high compression ratio file archiver` \
p7zip-plugins `# Additional plugins for p7zip` \
pv `# pipe viewer - see what happens between the | with output | pv | receiver ` \
python3 `# Python core library` \
python3-devel `# Python Development Gear` \
python3-neovim `# Python Neovim Libs` \
tuned `# Tuned can optimize your performance according to metrics. tuned-adm profile powersave can help you on laptops, alot` \
unar `# free rar decompression` \
ansible `# Awesome to manage multiple machines or define states for systems` \
meld `# Quick Diff Tool` \
nano `# Because pressing i is too hard sometimes` \
neovim `# the better vim` \
nethogs `# Whats using all your traffic? Now you know!` \
nload `# Network Load Monitor` \
vim-enhanced `# full vim` \
solaar `# Device manager for a wide range of Logitech devices` \
java-latest-openjdk-devel `# OpenJDK latest version Development Environment` \
texlive-scheme-full `# Texlive complete package`

#####
# Install applications and plugins from repositories
#####

dnf install \
-y `# Do not ask for confirmation` \
vlc `# The cross-platform open-source multimedia framework, player and server` \
code `# Visual Studio Code application`
google-chrome-stable `# Google Chrome` \
flameshot `# Powerful and simple to use screenshot software` \
blender `# 3D Software Powerhouse` \
calibre `# Ebook management` \
darktable `# Easy RAW Editor` \
filezilla `# S/FTP Access` \
gimp `# The Image Editing Powerhouse - and its plugins` \
gimp-data-extras \
gimp-dbp \
gimp-dds-plugin \
gimp-elsamuko \
gimp-focusblur-plugin \
gimp-fourier-plugin \
gimpfx-foundry.noarch \
gimp-high-pass-filter \
gimp-layer-via-copy-cut \
gimp-lensfun \
gimp-lqr-plugin \
gimp-luminosity-masks \
gimp-paint-studio \
gimp-resynthesizer \
gimp-save-for-web \
gimp-wavelet-decompose \
gimp-wavelet-denoise-plugin \
gmic-gimp \
glances `# Nice Monitor for your System` \
inkscape  `# Working with .svg files` \
krita  `# Painting done right` \
lm_sensors `# Show your systems Temperature` \
rawtherapee `# Professional RAW Editor` \
qbittorrent `# Torrent Client` \
cockpit `# An awesome local and remote management tool` \
cockpit-bridge \
ulauncher `# Linux Application Launcher` \
thunderbird `# Mozilla Thunderbird mail/newsgroup client` \
texstudio `# A feature-rich editor for LaTeX documents`


#####
# Install extensions, addons, fonts and themes from repositories
#####

dnf install \
-y `# Do not ask for confirmation` \
adobe-source-code-pro-fonts `# The most beautiful monospace font around` \
'mozilla-fira-*' `# A nice font family` \
file-roller-nautilus `# More Archives supported in nautilus` \
nautilus-extensions `# What it says on the tin` \
nautilus-image-converter `# Image converter option in context menu` \
nautilus-search-tool `# Searh option in context menu` \
nautilus-open-terminal `# Open folder in terminal option in context menu` \
nautilus-gksu `# Open file as administrator option in context menu` \
gtkhash-nautilus `# To get a file hash via GUI` \
gnome-extensions-app `# Manage GNOME Shell extensions` \
gnome-tweaks `# Your central place to make gnome like you want` \
gnome-shell-extension-user-theme `# Enables theming the gnome shell` \
gnome-shell-extension-appindicator `# AppIndicator/KStatusNotifierItem support for GNOME Shell` \
gnome-shell-extension-sound-output-device-chooser `# GNOME Shell extension for selecting sound devices` \
gnome-shell-extension-common `# Files common to GNOME Shell Extensions` \
gnome-shell-extension-mediacontrols `# Show controls for the current playing media in the panel` \
gnome-shell-extension-caffeine `# Disable the screen saver and auto suspend in gnome shell` \
papirus-icon-theme `# A quite nice icon theme` \
arc-theme `# Flat theme with transparent elements`


#####
# Configure and use Flathub
#####

# Add Flathub repo to Flatpak remote list
sudo -E -u $USER flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install applications from Flathub
sudo -E -u $USER bash <<EOF
flatpak install \
-y `# Do not ask for confirmation` \
flathub `# from flathub repo`
org.gnome.FontManager `# Powerful markdown editor for the GNOME desktop.` \
com.github.fabiocolacio.marker `# A simple font management application for Gtk+ Desktop Environments`
EOF


#####
# Configure and use Snap
#####

# Install snapd
dnf install snapd

# Create symlink to ensure proper functioning
ln -s /var/lib/snapd/snap /snap

# Install Snap Store
snap install snap-store


#####
# Install and configure nvidia and CUDA drivers
#####

dnf install \
-y `# Do not ask for confirmation` \
nvidia-driver `# Basic NVidia drivers for amd64` \
nvidia-driver-libs.i686 `#B asic NVidia drivers for x86` \
nvidia-driver-cuda `# Basic CUDA drivers for amd64` \
nvidia-settings `# NVidia control panel` \
cuda-devel `# CUDA development packages` \
cuda-cudnn `# CUDA development packages for deep neural networks`


#####
# Enable some of the goodies, but not all
# or set a more specific tuned profile
#####

### Tuned activation
systemctl enable --now tuned

# Balanced:
tuned-adm profile balanced

# Performance:
#sudo tuned-adm profile desktop

# Virtual Machine Host:
#sudo tuned-adm profile virtual-host

# Virtual Machine Guest:
#sudo tuned-adm profile virtual-guest

# Battery Saving:
#sudo tuned-adm profile powersave

# Virtual Machines
systemctl enable --now libvirtd

### Cockpit activation
# Management of local/remote system(s) - available via http://localhost:9090
systemctl enable --now cockpit.socket


#####
# Installing Zotero
#####

# Download tarball
wget -O "zotero.tar.bz2" "https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64" -o "/dev/null"

# Extract with diffente owner from archiving
tar -xf zotero.tar.bz2 --no-same-owner 

# Change extracted folder name
mv Zotero*/ zotero/

# Move folder
mv zotero/ /opt/

# Change ownership to specified user
chown -R $USER:$USER /opt/zotero/

# Run launcher icon locator
bash /opt/zotero/set_launcher_icon

# Create symlink to desktop launcher
ln -s /opt/zotero/zotero.desktop /home/$USER/.local/share/applications/zotero.desktop

# Clean root user folder from the downloaded tarvball
rm -f zotero.tar.bz2


#####
# Theming and GNOME Options
#####

# This indexer is nice, but can be detrimental for laptop users battery life
sudo -E -u $USER bash <<EOF
gsettings set org.freedesktop.Tracker.Miner.Files index-on-battery false
gsettings set org.freedesktop.Tracker.Miner.Files index-on-battery-first-time false
gsettings set org.freedesktop.Tracker.Miner.Files throttle 15
EOF

# Nautilus (File Manager) Usability
sudo -E -u $USER bash <<EOF
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard'
gsettings set org.gnome.nautilus.preferences executable-text-activation 'ask'
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gnome.nautilus.list-view use-tree-view true
EOF

#Usability Improvements
sudo -E -u $USER bash <<EOF
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'adaptive'
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
EOF

