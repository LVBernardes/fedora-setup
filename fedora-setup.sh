#!/bin/bash

# Store script directory name full path to use later
script_dir_path=$(cd `dirname $0` && pwd -P)
echo "Setup script directory path: $script_dir_path"

# ----------------------------------------------------------------------------
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

# Storing USER and HOME variables for later configurations
user_selected=$1
home_selected="/home/${user_selected}"

# ----------------------------------------------------------------------------
#####
# Log setup
#####
# DATETIME=`date +"%Y%m%d_%H%M%S"`
# LOGDIR="/home/${USER}/"
# OUTPUT="${LOGDIR}/fedora_setup_output_${DATETIME}"
# OUTPUT_TIMING="${LOGDIR}/fedora_setup_output_timeline${DATETIME}"

export LOGDIR=$home_selected
export DATE=`date +"%Y%m%d"`
export DATETIME=`date +"%Y%m%d_%H%M%S"`

verbosity=2

### verbosity levels
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
ntf_lvl=4
inf_lvl=5
dbg_lvl=6
 
## esilent prints output even in silent mode
function esilent () { verb_lvl=$silent_lvl elog "$@" ;}
function enotify () { verb_lvl=$ntf_lvl elog "$@" ;}
function eok ()    { verb_lvl=$ntf_lvl elog "SUCCESS - $@" ;}
function ewarn ()  { verb_lvl=$wrn_lvl elog "${colylw}WARNING${colrst} - $@" ;}
function einfo ()  { verb_lvl=$inf_lvl elog "${colwht}INFO${colrst} ---- $@" ;}
function edebug () { verb_lvl=$dbg_lvl elog "${colgrn}DEBUG${colrst} --- $@" ;}
function eerror () { verb_lvl=$err_lvl elog "${colred}ERROR${colrst} --- $@" ;}
function ecrit ()  { verb_lvl=$crt_lvl elog "${colpur}FATAL${colrst} --- $@" ;}
function edumpvar () { for var in $@ ; do edebug "$var=${!var}" ; done }
function elog() {
    if [ $verbosity -ge $verb_lvl ]; then
        datestring=`date +"%Y-%m-%d %H:%M:%S"`
        echo -e "$datestring - $@"
    fi
}
 
ScriptName=`basename $0`
Job=`basename $0 .sh`"_log"
JobClass=`basename $0 .sh`
 
function Log_Open() {
    if [ $NO_JOB_LOGGING ] ; then
        einfo "Not logging to a logfile because -Z option specified." #(*)
    else
        [[ -d $LOGDIR/$JobClass ]] || mkdir -p $LOGDIR/$JobClass
        Pipe=${LOGDIR}/$JobClass/${Job}_${DATETIME}.pipe
        mkfifo -m 700 $Pipe
        LOGFILE=${LOGDIR}/$JobClass/${Job}_${DATETIME}.log
        exec 3>&1
        exec 2>&1
        tee ${LOGFILE} <$Pipe >&3 &
        teepid=$!
        exec 1>$Pipe
        PIPE_OPENED=1
        enotify Logging to $LOGFILE  # (*)
        [ $SUDO_USER ] && enotify "Sudo user: $SUDO_USER" #(*)
    fi
}
 
function Log_Close() {
    if [ ${PIPE_OPENED} ] ; then
        exec 1<&3
        sleep 0.2
        ps --pid $teepid >/dev/null
        if [ $? -eq 0 ] ; then
            # a wait $teepid whould be better but some
            # commands leave file descriptors open
            sleep 1
            kill  $teepid
        fi
        rm $Pipe
        unset PIPE_OPENED
    fi
}
 
OPTIND=1
while getopts ":Z" opt ; do
    case $opt in
        Z)
            NO_JOB_LOGGING="true"
            ;;
    esac
done

Log_Open

echo ""
echo "FEDORA-SETUP: Initializing setup process."
echo ""

# ----------------------------------------------------------------------------
#####
# First configs to kernel and DNF
#####

echo ""
echo "FEDORA-SETUP: Configuring kernel and SO."
echo ""

# Configuring DNF to be faster
tee -a /etc/dnf/dnf.conf > /dev/null <<EOF
fastestmirror=True
max_parallel_downloads=10
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

echo ""
echo "FEDORA-SETUP: Configuring kernel and SO finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Disable unnecessary repositories
#####

echo ""
echo "FEDORA-SETUP: Disabling unnecessary repositories."
echo ""

dnf config-manager --set-disabled phracek-PyCharm
dnf config-manager --set-disabled rpmfusion-nonfree-nvidia-driver
dnf config-manager --set-disabled rpmfusion-nonfree-steam

echo ""
echo "FEDORA-SETUP: Disabling unnecessary repositories finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Add aditional repositories to system list
#####

echo ""
echo "FEDORA-SETUP: Instaling and configuring additional repositories."
echo ""

# Nvidia drivers from Negativo17
dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo

# Visual Studio Code from Microsoft
rpm --import https://packages.microsoft.com/keys/microsoft.asc
tee /etc/yum.repos.d/vscode.repo > /dev/null <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
gpgcheck=1
EOF

# RPM Fusion Free
dnf install \
-y `# Do not ask for confirmation` \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm

# Plex Media Server
tee /etc/yum.repos.d/plex.repo > /dev/null <<EOF
[PlexRepo]
name=PlexRepo
baseurl=https://downloads.plex.tv/repo/rpm/x86_64/
enabled=1
gpgkey=https://downloads.plex.tv/plex-keys/PlexSign.key
gpgcheck=1
EOF

# Adoptium (Temurin Eclipse OpenJDK)
tee /etc/yum.repos.d/adoptium.repo > /dev/null <<EOF
[Adoptium]
name=Adoptium
baseurl=https://packages.adoptium.net/artifactory/rpm/fedora/\$releasever/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
EOF

# There was no available temurin jdk package for fedora 36 yet
dnf config-manager --set-disabled Adoptium

echo ""
echo "FEDORA-SETUP: Instaling and configuring additional repositories finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Force update the whole system to the latest and greatest
#####

echo ""
echo "FEDORA-SETUP: Updating cache and drivers and upgrading existent packages."
echo ""

dnf upgrade --best --allowerasing --refresh -y

# And also remove any packages without a source backing them
dnf distro-sync -y

# Update firmware e drivers
fwupdmgr get-devices
fwupdmgr refresh --force
fwupdmgr get-updates
fwupdmgr update

echo ""
echo "FEDORA-SETUP: Updating and upgrading existent packages and cache finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Install base packages and terminal applications from repositories
#####

echo ""
echo "FEDORA-SETUP: Installing base packages and terminal applications."
echo ""

dnf install \
-y `# Do not ask for confirmation` \
ansible `# SSH-based configuration management, deployment, and task execution system` \
ansible-collection-ansible-netcommon `# Ansible Network Collection for Common Cod` \
ansible-collection-ansible-posix `# Ansible Collection targeting POSIX and POSIX-ish platforms` \
ansible-collection-ansible-utils `# Ansible Network Collection for Common Code` \
ansible-core-doc `# Documentation for Ansible Bas` \
bat `# cat(1) clone with wings` \
curl `# A utility for getting files from remote servers (FTP, HTTP, and others)` \
dnf-plugins-core `# Core Plugins for DNF` \
exa `# Modern replacement for ls` \
exfatprogs `# Userspace utilities for exFAT filesystems` \
ffmpeg `# Adds Codec Support to Firefox, and in general` \
fuse `# File System in Userspace (FUSE) v2 utilities` \
fuse-common `# Common files for File System in Userspace (FUSE) v2 and v3` \
fuse-sshfs `# FUSE-Filesystem to access remote filesystems via SSH` \
gcc `# Various compilers (C, C++, Objective-C, ...)` \
gcc-c++ `# C++ support for GCC` \
git `# Fast Version Control System` \
gtkhash `# GTK+ utility for computing message digests or checksums` \
gvfs `# Backends for the gio framework in GLib` \
gvfs-fuse `# gnome<>fuse` \
gvfs-mtp `# gnome<>android` \
gvfs-nfs `# gnome<>ntfs` \
gvfs-smb `# gnome<>samba` \
htop `# Interactive CLI process monitor` \
httpie `# A Curl-like tool for humans` \
jq `# Command-line JSON processor` \
julia `# High-level, high-performance dynamic language for technical computing` \
libappindicator `# Application indicators library` \
lsd `# Ls command with a lot of pretty colors and some other stuff` \
kernel-devel `# Development package for building kernel modules to match the kernel` \
kernel-modules `# kernel modules to match the core kernel` \
meld `# Visual diff and merge tool` \
nano `# Because pressing i is too hard sometimes` \
neovim `# Vim-fork focused on extensibility and agility` \
nethogs `# Whats using all your traffic? Now you know!` \
NetworkManager-openvpn-gnome `# To enforce that its possible to import .ovpn files in the settings` \
nload `# A tool can monitor network traffic and bandwidth usage in real time` \
openssh-askpass `# Base Lib to let applications request ssh pass via gui` \
p7zip `# Very high compression ratio file archiver` \
p7zip-plugins `# Additional plugins for p7zip` \
pv `# A tool for monitoring the progress of data through a pipeline ( | )` \
python3 `# Python core library` \
python3-devel `# Python Development Gear` \
python3-neovim `# Python Neovim Libs` \
snapd `# A transactional software package manager. Analogous to Flatpak.` \
solaar `# Device manager for a wide range of Logitech devices` \
squashfuse `# FUSE filesystem to mount squashfs archives` \
texlive-scheme-full `# Texlive complete package` \
tlp `# Optimize laptop battery life` \
tlp-rdw `# Radio device wizard for TLP` \
tuned `# Tuned can optimize your performance according to metrics. tuned-adm profile powersave can help you on laptops, alot` \
tuned-gtk `# GTK GUI for tuned` \
tuned-switcher `# Simple utility to manipulate the Tuned service` \
tuned-utils `# Various tuned utilities` \
unar `# free rar decompression` \
unzip `# A utility for unpacking zip files` \
util-linux-user `# A utility with chsh program to change shell` \
vim-enhanced `# full vim` \
wget `# A utility for retrieving files using the HTTP or FTP protocols` \
zsh `# zshell installation in preparation for oh-my-zsh`


echo ""
echo "FEDORA-SETUP: Installing base packages and terminal applications finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Install applications and plugins from repositories
#####

echo ""
echo "FEDORA-SETUP: Installing applications."
echo ""

dnf install \
-y `# Do not ask for confirmation` \
blender `# 3D Software Powerhouse` \
calibre `# Ebook management` \
cockpit `# An awesome local and remote management tool` \
cockpit-navigator `# A File System Browser for Cockpit` \
cockpit-networkmanager `# Manage your network interfaces and edit your firewall with ease.` \
cockpit-packagekit `# See and apply updates to your system. Supports RPM and DEB based systems through PackageKit.` \
cockpit-podman `# Download, use, and manage containers in your browser. (Podman replaces Docker.)` \
cockpit-storaged `# Manage your system’s storage. Supports local partitions, encryption, NFS, RAID, iSCSI, and more.` \
code `# Visual Studio Code application` \
darktable `# Easy RAW Editor` \
dconf-editor `# Configuration editor for dconf` \
easyeffects `# Audio effects for PipeWire applications` \
filezilla `# S/FTP Access` \
flameshot `# Powerful and simple to use screenshot software` \
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
glances `# Nice CLI Monitor for your System` \
gmic-gimp \
google-chrome-stable `# Google Chrome` \
gparted `# Gnome Partition Editor` \
gwe `# System utility designed to provide information of NVIDIA card` \
inkscape `# Working with .svg files` \
krita `# Painting done right` \
libreoffice-draw `# LibreOffice Drawing Application` \
lm_sensors `# Hardware monitoring tools` \
lm_sensors-sensord `# Daemon that periodically logs sensor readings` \
plexmediaserver `# Plex organizes all of your personal media so you can easily access and enjoy it.` \
qbittorrent `# A bittorrent Client` \
rawtherapee `# Professional RAW Editor` \
texstudio `# A feature-rich editor for LaTeX documents` \
thunderbird `# Mozilla Thunderbird mail/newsgroup client` \
vlc `# The cross-platform open-source multimedia framework, player and server`


echo ""
echo "FEDORA-SETUP: Installing applications finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Install extensions, addons, fonts and themes from repositories
#####

echo ""
echo "FEDORA-SETUP: Installing extension, fonts and themes."
echo ""

# Fonts
dnf install \
-y `# Do not ask for confirmation` \
adobe-source-code-pro-fonts `# The most beautiful monospace font around` \
open-sans-fonts `# One of the best multipurpuse sans-serif font OpenType compliant` \
'mozilla-fira-*' `# A nice font family` \
'google-roboto*' \
fira-code-fonts

## Install recommended fonts (Nerd Fonts) for Powerlevel10k
mkdir -p /usr/share/fonts/meslo
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v2.2.2/Meslo.zip -O /tmp/Meslo.zip
unzip -q /tmp/Meslo.zip -d /usr/share/fonts/meslo
fc-cache -f
rm  /tmp/Meslo.zip

## Install patch (Nerd Fonts) JetBrains Mono
mkdir -p /usr/share/fonts/jetbrains-mono-fonts-all
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v2.2.2/JetBrainsMono.zip -O /tmp/JetBrainsMono.zip
unzip -q /tmp/JetBrainsMono.zip -d /usr/share/fonts/jetbrains-mono-fonts-all
fc-cache -f
rm  /tmp/JetBrainsMono.zip

# Extensions
dnf install \
-y `# Do not ask for confirmation` \
beesu `# Graphical wrapper for su` \
file-roller-nautilus `# More Archives supported in nautilus` \
gnome-extensions-app `# Manage GNOME Shell extensions` \
gnome-shell-extension-user-theme `# Enables theming the gnome shell` \
gnome-terminal-nautilus `# GNOME Terminal extension for Nautilus` \
gnome-tweaks `# Your central place to make gnome like you want` \
gtkhash-nautilus `# To get a file hash via GUI` \
nautilus-extensions `# What it says on the tin` \
nautilus-image-converter `# Image converter option in context menu` \
nautilus-python `# Python bindings for Nautilus` \
nautilus-search-tool `# Searh option in context menu`

# Themes
dnf install \
-y `# Do not ask for confirmation` \
arc-theme `# Flat theme with transparent elements` \
papirus-icon-theme `# Free and open source SVG icon theme based on Paper Icon Set` \
flat-remix-theme `# Pretty simple theme inspired on material design`


# Installing JetBrains Mono NerdFont
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/install_manual.sh)"

echo ""
echo "FEDORA-SETUP: Installing extension, fonts and themes finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Configure and use Flathub
#####

echo ""
echo "FEDORA-SETUP: Installing and configuring Flathub and applications."
echo ""

# Add Flathub repo to Flatpak remote list
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install applications from Flathub
sudo -E -u $user_selected bash <<EOF
flatpak install \
-y `# Do not ask for confirmation` \
flathub `# from flathub repo` \
org.gnome.FontManager `# Powerful markdown editor for the GNOME desktop.` \
com.github.fabiocolacio.marker `# A simple font management application for Gtk+ Desktop Environments` \
com.jgraph.drawio.desktop `# draw.io is the most flexible and privacy-focused of any production grade diagramming tool.` \
org.kde.okular `# One of the best PDF readers for Linux.` \
com.spotify.Client `# Spotify client.`

EOF

echo ""
echo "FEDORA-SETUP: Installing and configuring Flathub and applications finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Configure and use Snap and Snap Store Applications
#####

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap."
echo ""

# Create symlink to ensure proper functioning
ln -s /var/lib/snapd/snap /snap

# Install Snap Store
snap install snap-store

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap finished."
echo ""


# ----------------------------------------------------------------------------
#####
# Enable some of the goodies, but not all
# or set a more specific tuned profile
#####

echo ""
echo "FEDORA-SETUP: Enabling applications daemons."
echo ""

### Tuned activation
systemctl enable --now tuned

# Balanced:
sudo -E -u $user_selected tuned-adm profile balanced

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

# Opening cockpit service to firewall whitelist
firewall-cmd --add-service=cockpit --permanent

echo ""
echo "FEDORA-SETUP: Enabling applications daemons finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Installing Zotero
#####

echo ""
echo "FEDORA-SETUP: Installing Zotero."
echo ""

# Download tarball
wget -O "zotero.tar.bz2" "https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64" -o "/dev/null"

# Extract with diffente owner from archiving
tar -xf zotero.tar.bz2 --no-same-owner 

# Change extracted folder name
mv Zotero*/ zotero/

# Move folder
mv zotero/ /opt/

# Change ownership to specified user
chown -R $user_selected:$user_selected /opt/zotero/

# Clean root user folder from the downloaded tarball
rm -f zotero.tar.bz2

# Go to zotero folder to chance icon config
cd /opt/zotero

# Run launcher icon locator
bash /opt/zotero/set_launcher_icon
cd ~

# Create symlink to desktop launcher
ln -s /opt/zotero/zotero.desktop $home_selected/.local/share/applications/zotero.desktop

echo ""
echo "FEDORA-SETUP: Zotero successfully installed."
echo ""


# ----------------------------------------------------------------------------
#####
# Installing TeamViewer
#####

echo ""
echo "FEDORA-SETUP: Installing TeamViewer."
echo ""

# Download GPG key
wget "https://download.teamviewer.com/download/linux/signature/TeamViewer2017.asc" -o "/dev/null"

# Add GPG key
rpm --import TeamViewer2017.asc -y

# Download client
wget "https://download.teamviewer.com/download/linux/teamviewer.x86_64.rpm" -o "/dev/null"

# Install client
dnf install ./teamviewer.x86_64.rpm -y

# Remove downloaded files
rm -f TeamViewer2017.asc teamviewer.x86_64.rpm

echo ""
echo "FEDORA-SETUP: Teamviewer successfully installed."
echo ""


# ----------------------------------------------------------------------------
#####
# Installing LanguateTool
#####

echo ""
echo "FEDORA-SETUP: Installing LanguateTool Server."
echo ""

# Download tarball
wget -O "languagetool.zip" "https://languagetool.org/download/LanguageTool-stable.zip" -o "/dev/null"

# create an appropriate location
mkdir .bin/languagetool

# Extract
unzip -q languagetool.zip -d $home_selected/.bin/languagetool

# Change ownership to specified user
chown -R $user_selected:$user_selected $home_selected/.bin/languagetool

# Clean root user folder from the downloaded tarball
rm -f languagetool.zip

echo ""
echo "FEDORA-SETUP: LanguateTool Server successfully installed."
echo ""

# ----------------------------------------------------------------------------
#####
# AppImage Integrator
#####

echo ""
echo "FEDORA-SETUP: Installing and configuring AppImageLauncher integrator."
echo ""

# Download and install AppImageLauncher
sudo -E -u $user_selected wget -q -O "$home_selected/appimagelauncher.rpm" -o "/dev/null" \
"https://github.com$(curl -s $(curl -Ls -o /dev/null -w %{url_effective} https://github.com/TheAssassin/AppImageLauncher/releases/latest) | grep -Eoi '<a [^>]+>' | grep -Eo 'href="[^\"]+"' | grep -Eo '\/TheAssassin\/AppImageLauncher\/releases\/download\/\S*\/appimagelauncher\S*\.x86_64.rpm')"

dnf install -y "$home_selected/appimagelauncher.rpm"

# Configure AppImageLauncher
sudo -E -u $user_selected tee $home_selected/.config/appimagelauncher.cfg > /dev/null <<EOF
[AppImageLauncher]
ask_to_move = true
destination = $home_selected/.bin/appimagefiles
enable_daemon = true


[appimagelauncherd]
additional_directories_to_watch = $home_selected:$home_selected/Downloads
# monitor_mounted_filesystems = false
EOF

# Clean AppImageLauncher file
rm $home_selected/appimagelauncher.rpm

echo ""
echo "FEDORA-SETUP: Installing and configuring AppImageLauncher integrator finished."
echo ""

# ----------------------------------------------------------------------------
#####
# AppImage Applications
#####

echo ""
echo "FEDORA-SETUP: Installing and configuring AppImage applications."
echo ""

# Create folder to store AppImage files
mkdir $home_selected/.bin $home_selected/.bin/appimagefiles
chown -R $user_selected:$user_selected $home_selected/.bin

# Download and install Obsidian
wget -q -O "$home_selected/.bin/appimagefiles/obisidian.AppImage" -o "/dev/null" \
"$(curl -Ls https://obsidian.md/download | grep -Eo 'href="[^\"]+"' | grep -Eo '((http|https):\/\/github\.com\/obsidianmd\/obsidian-releases\/releases\/download\/\S*\/Obsidian-[0-9]*\.[0-9]*\.[0-9]*\.AppImage)')"
chown -R $user_selected:$user_selected $home_selected/.bin/appimagefiles/obisidian.AppImage

# Download and install JetBrains ToolBox
wget -q -O "/tmp/jetbrains-toolbox.tar.bz2" -o "/dev/null" "https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.26.2.13244.tar.gz"
tar -xf /tmp/jetbrains-toolbox.tar.bz2 --strip-components=1 -C $home_selected/.bin/appimagefiles/
chown -R $user_selected:$user_selected $home_selected/.bin/appimagefiles/jetbrains-toolbox
rm /tmp/jetbrains-toolbox.tar.bz2

# Download and install Insomnia Core
wget -q -O "$home_selected/.bin/appimagefiles/insomnia.AppImage" -o "/dev/null" \
https://github.com$(curl -Ls https://updates.insomnia.rest/downloads/release/latest\?app\=com.insomnia.app\&source\=website | grep -Eo 'href="[^\"]+"' | grep -Eo '\/Kong\/insomnia\/releases\/download\/\S*\/Insomnia.Core-[0-9]*\.[0-9]*\.[0-9]*\.AppImage')
chown -R $user_selected:$user_selected $home_selected/.bin/appimagefiles/insomnia.AppImage


echo ""
echo "FEDORA-SETUP: Installing and configuring AppImage applications finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Theming and GNOME Options
#####

echo ""
echo "FEDORA-SETUP: Configuring dconf settings."
echo ""

# This indexer is nice, but can be detrimental for laptop users battery life
sudo -E -u $user_selected bash <<EOC
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery false
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery-first-time false
gsettings set org.freedesktop.Tracker3.Miner.Files throttle 15
EOC

# Nautilus (File Manager) configuration
sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.nautilus.window-state sidebar-width 250
gsettings set org.gnome.nautilus.window-state maximized true
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard'
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.list-view default-column-order "['name','size','type','detailed_type','owner','group','permissions','where','date_modified','date_created','date_modified_with_time','date_accessed','recency','starred']"
gsettings set org.gnome.nautilus.list-view default-visible-columns "['name','size','type','detailed_type','date_modified','date_created','starred']"
EOC

# File Chooser configuration
sudo -E -u $user_selected bash <<EOC
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.Settings.FileChooser date-format 'with-time'
gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gtk.Settings.FileChooser type-format 'mime'
EOC

# Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)
sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell.extensions.user-theme name 'Flat-Remix-Blue-Dark-fullPanel'
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.interface gtk-theme 'Flat-Remix-GTK-Blue-Dark-Solid'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans 11'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans Medium 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono 10'
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Noto Sans Bold 11'
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'adaptive'
gsettings set org.gnome.desktop.peripherals.keyboard numlock-state true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl'), ('xkb', 'br')]"
gsettings set org.gnome.Weather locations "[<(uint32 2, <('São Paulo', 'SBMT', true, [(-0.41044326824509736, -0.8139052020289248)], [(-0.41073414481823473, -0.81361432545578749)])>)>]"
gsettings set org.gnome.GWeather temperature-unit 'centigrade'

EOC

# Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)
sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
gsettings set org.gnome.system.locale region 'pt_BR.UTF-8'
gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']"
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.mutter workspaces-only-on-primary true
gsettings set org.gnome.tweaks show-extensions-notice false
EOC

# Apps and UX configs for different Gnome Shell version equal or superior to 42
if [ "$(gnome-shell --version | cut -d" " -f3 | cut -d. -f1)" -ge 42 ]
then
    # Dark mode preference mode for compliant apps and extensions
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
EOC

    # File Chooser configuration (GTK4+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.gtk4.Settings.FileChooser date-format 'with-time'
gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden true
gsettings set org.gtk.gtk4.Settings.FileChooser type-format 'mime'
EOC

    # Text Editor configuration (gedit substitute in GNOME 42+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.TextEditor highlight-current-line true
gsettings set org.gnome.TextEditor indent-style 'space'
gsettings set org.gnome.TextEditor show-line-numbers true
gsettings set org.gnome.TextEditor show-map true
gsettings set org.gnome.TextEditor show-right-margin true
gsettings set org.gnome.TextEditor tab-width 4
EOC

    # Weather widget configuration (GTK4+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.GWeather4 temperature-unit 'centigrade'
EOC

fi

# GNOME Shell Default Extensions Activation
sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell enabled-extensions "['background-logo@fedorahosted.org', 'user-theme@gnome-shell-extensions.gcampax.github.com']"
EOC

echo ""
echo "FEDORA-SETUP: Configuring dconf settings finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Oh-My-Zsh, Powerlevel10k and LSD configuration
#####

echo ""
echo "FEDORA-SETUP: Installing and Configuring Oh-My-Zsh with Powerlevel10k."
echo ""

# Install oh-my-szh
ZSH=/usr/share/oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# # Add oh-my-zsh to /usr/share
# mv /root/.oh-my-zsh /usr/share
# mv /usr/share/.oh-my-zsh /usr/share/oh-my-zsh
mv /root/.zshrc /usr/share/oh-my-zsh
mv /usr/share/oh-my-zsh/.zshrc /usr/share/oh-my-zsh/zshrc

# # Modify zshrc to point to /usr/share/oh-my-zsh
# sed -i 's|export ZSH="$HOME/.oh-my-zsh"|export ZSH="\/usr\/share\/oh-my-zsh"|g' /usr/share/oh-my-zsh/zshrc

# Enable Autocorrection for zsh
sed -i 's/# ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/g' /usr/share/oh-my-zsh/zshrc

# Enable Autosuggestions and sintax highlighting plugins ofr zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-/usr/share/oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-/usr/share/oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(\n  git\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n)/' /usr/share/oh-my-zsh/zshrc
sed -i 's/plugins=(git)/plugins=(git)\nZSH_DISABLE_COMPFIX=true/' /usr/share/oh-my-zsh/zshrc

# Create a backup copy of original zshrc
cp /usr/share/oh-my-zsh/zshrc /usr/share/oh-my-zsh/zshrc.backup

## Install Powelevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-/usr/share/oh-my-zsh/custom}/themes/powerlevel10k

# Configure .zshrc file to use Powerlevel10k
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' /usr/share/oh-my-zsh/zshrc
tee -a /usr/share/oh-my-zsh/zshrc > /dev/null << 'EOI'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOI

sed -i '1i\
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.\
# Initialization code that may require console input (password prompts, [y/n]\
# confirmations, etc.) must go above this block; everything else may go below.\
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then\
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"\
fi\
' /usr/share/oh-my-zsh/zshrc

# Configure LSD alias over 'ls'
tee -a /usr/share/oh-my-zsh/zshrc > /dev/null << 'EOI'

# Configuration for LSD alias over LS
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree --depth'
alias lta='ls -la --tree --depth' 

EOI

# Create Symbolic Links to /etc/skel
sudo ln /usr/share/oh-my-zsh/zshrc /etc/skel/.zshrc

# Copy zshrc to $HOME for root and change default shell to ZSH
ln /usr/share/oh-my-zsh/zshrc /root/.zshrc
echo "$USER" | chsh -s /bin/zsh

# Copy zshrc to $HOME for user and change default shell to ZSH
ln /usr/share/oh-my-zsh/zshrc $home_selected/.zshrc
usermod --shell $(which zsh) $user_selected
chown -R $user_selected:$user_selected $home_selected/.zshrc

# Copy Powerlevel10k config file to both root and user home directories
if [ -f "$script_dir_path/p10k.zsh" ] 
then
    cp $script_dir_path/p10k.zsh /root/.p10k.zsh
    cp $script_dir_path/p10k.zsh $home_selected/.p10k.zsh
    chown -R $user_selected:$user_selected $home_selected/.p10k.zsh
fi 

# ----------------------------------------------------------------------------
#####
# Install and configure nvidia and CUDA drivers
#####

if [ -n "$(lspci | grep -E "NVIDIA|nvidia|Nvidia|NVidia")" ]
then
        echo ""
        echo "FEDORA-SETUP: Installing NVidia drivers."
        echo ""

        dnf install \
        -y `# Do not ask for confirmation` \
        nvidia-driver `# Basic NVidia drivers for amd64` \
        nvidia-driver-libs.i686 `#B asic NVidia drivers for x86` \
        nvidia-driver-cuda `# Basic CUDA drivers for amd64` \
        nvidia-settings `# NVidia control panel` \
        cuda-devel `# CUDA development packages` \
        cuda-cudnn `# CUDA development packages for deep neural networks`
	
	dnf config-manager --set-disabled fedora-nvidia

        echo ""
        echo "FEDORA-SETUP: Installing NVidia drivers finished."
        echo ""
fi

# ----------------------------------------------------------------------------
#####
# Configure and use Snap and Snap Store Applications
#####

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap."
echo ""

# Create symlink to ensure proper functioning
ln -s /var/lib/snapd/snap /snap

# Updating cache
snap refresh

# Install Snap Store
snap install snap-store

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap finished."
echo ""


# ----------------------------------------------------------------------------
#####
# Configure Gnome Terminal to work with Oh-my-zsh and Powerlevel10k
#####

sudo -E -u $user_selected bash <<-EOC
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" default-size-columns 160
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" default-size-rows 96
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" font 'MesloLGS Nerd Font Mono 11'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" use-system-font false
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" visible-name 'Oh-My-Zsh-P10k-Default'
gsettings set org.gnome.desktop.interface monospace-font-name 'MesloLGS Nerd Font Mono 10'
EOC

# ----------------------------------------------------------------------------
#####
# Ending setup process
#####

echo ""
echo "FEDORA-SETUP: Ending setup."
echo ""

# Restart
echo ""
echo "FEDORA-SETUP: Please, restart."
echo ""

Log_Close

chown -R $user_selected:$user_selected $LOGDIR/$JobClass
