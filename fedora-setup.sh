#!/bin/bash

# Store script directory name full path to use later
script_dir_path=$(cd `dirname $0` && pwd -P)
echo "Setup script directory path: $script_dir_path"

# ----------------------------------------------------------------------------
#####
# Check which user is running the script
#####


print_usage() {
  printf "Usage: ..."
}


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

# Check for nvidia drivers installation flag
install_nvidia_drivers=''
while getopts 'n' flag; do
  case "${flag}" in
    n) install_nvidia_drivers='true' ;;
    *) print_usage
        echo "Invalid flag or argument."
        exit 1 ;;
  esac
done

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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# First configs to kernel and DNF
#####

echo "-----------------------------------------------------------------------"
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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Disable unnecessary repositories
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Disabling unnecessary repositories."
echo ""

dnf config-manager --set-disabled phracek-PyCharm
dnf config-manager --set-disabled rpmfusion-nonfree-nvidia-driver
dnf config-manager --set-disabled rpmfusion-nonfree-steam

echo ""
echo "FEDORA-SETUP: Disabling unnecessary repositories finished."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Add aditional repositories to system list
#####

echo "-----------------------------------------------------------------------"
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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Force update the whole system to the latest and greatest
#####

echo "-----------------------------------------------------------------------"
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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Install base packages and terminal applications from repositories
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing base packages and terminal applications."
echo ""

dnf install \
--allowerasing `# Replace conflicting packages` \
--skip-broken `# Skip uninstallable packages` \
-y `# Do not ask for confirmation` \
akmods `# Automatic kmods build and install tool (used for building nvidia driver kernel modules)` \
ansible `# SSH-based configuration management, deployment, and task execution system` \
ansible-collection-ansible-netcommon `# Ansible Network Collection for Common Cod` \
ansible-collection-ansible-posix `# Ansible Collection targeting POSIX and POSIX-ish platforms` \
ansible-collection-ansible-utils `# Ansible Network Collection for Common Code` \
ansible-core-doc `# Documentation for Ansible Bas` \
bat `# cat(1) clone with wings` \
ca-certificates`# The Mozilla CA root certificate bundle` \
curl `# A utility for getting files from remote servers (FTP, HTTP, and others)` \
dnf-plugins-core `# Core Plugins for DNF` \
exa `# Modern replacement for ls` \
exfatprogs `# Userspace utilities for exFAT filesystems` \
ffmpeg `# Adds Codec Support to Firefox, and in general` \
fuse `# File System in Userspace (FUSE) v2 utilities` \
fuse-common `# Common files for File System in Userspace (FUSE) v2 and v3` \
fuse-sshfs `# FUSE-Filesystem to access remote filesystems via SSH` \
fzf `# A command-line fuzzy finder written in Go` \
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
kmodtool `# Tool for building kmod packages (used for building nvidia driver kernel modules)` \
julia `# High-level, high-performance dynamic language for technical computing` \
libappindicator `# Application indicators library` \
lsd `# Ls command with a lot of pretty colors and some other stuff` \
kernel-devel `# Development package for building kernel modules to match the kernel` \
kernel-modules `# kernel modules to match the core kernel` \
meld `# Visual diff and merge tool` \
mokutil `# Tool to manage UEFI Secure Boot MoK Keys (used for signing nvidia driver or other kernel modules)` \
nano `# Because pressing i is too hard sometimes` \
neovim `# Vim-fork focused on extensibility and agility` \
nethogs `# Whats using all your traffic? Now you know!` \
NetworkManager-openvpn-gnome `# To enforce that its possible to import .ovpn files in the settings` \
nload `# A tool can monitor network traffic and bandwidth usage in real time` \
openssh-askpass `# Base Lib to let applications request ssh pass via gui` \
openssl `# Utilities from the general purpose cryptography library with TLS implementation` \
p7zip `# Very high compression ratio file archiver` \
p7zip-plugins `# Additional plugins for p7zip` \
pv `# A tool for monitoring the progress of data through a pipeline ( | )` \
python3 `# Python core library` \
python3-devel `# Python Development Gear` \
python3-neovim `# Python Neovim Libs` \
ripgrep `# Line oriented search tool | used with FZF` \
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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Install applications and plugins from repositories
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing applications."
echo ""

dnf install \
--allowerasing `# Replace conflicting packages` \
--skip-broken `# Skip uninstallable packages` \
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
darktable-tools-noise.x86_64 `# The noise profiling tools to support new cameras` \
dconf-editor `# Configuration editor for dconf` \
easyeffects `# Audio effects for PipeWire applications` \
filezilla `# S/FTP Access` \
flameshot `# Powerful and simple to use screenshot software` \
gimp `# The Image Editing Powerhouse - and its plugins` \
gimp-data-extras \
gimp-dds-plugin \
gimp-elsamuko \
gimp-fourier-plugin \
gimpfx-foundry \
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
echo "-----------------------------------------------------------------------"
echo ""


# ----------------------------------------------------------------------------
#####
# IInstalling packages to be used by pyenv for build python from source.
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing packages to be used by pyenv for build python from source."
echo 

dnf install \
--allowerasing `# Replace conflicting packages` \
--skip-broken `# Skip uninstallable packages` \
-y `# Do not ask for confirmation` \
make `# A GNU tool which simplifies the build process for users` \
gcc `# Various compilers (C, C++, Objective-C, ...)` \
patch `# Utility for modifying/upgrading files` \
zlib-devel `# Header files and libraries for Zlib development` \
bzip2 `# File compression utility` \
bzip2-devel `# Libraries and header files for apps which will use bzip2` \
readline-devel `# Files needed to develop programs which use the readline library` \
sqlite `# Library that implements an embeddable SQL database engine` \
sqlite-devel `# Development tools for the sqlite3 embeddable SQL database engine` \
openssl-devel `# Files for development of applications which will use OpenSSL` \
tk-devel `# Tk graphical toolkit development files` \
libffi-devel `# Development files for libffi` \
xz-devel `# Devel libraries & headers for liblzma` \
libuuid-devel `# Universally unique ID library` \
gdbm-libs `# Libraries files for gdbm` \
libnsl2 `# Public client interface library for NIS(YP) and NIS+`

echo ""
echo "FEDORA-SETUP: Installing packages to be used by pyenv for build python from source finished."
echo "-----------------------------------------------------------------------"
echo ""


# ----------------------------------------------------------------------------
#####
# Install extensions, addons, fonts and themes from repositories
#####

echo "-----------------------------------------------------------------------"
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
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/Meslo.zip -O /tmp/Meslo.zip
unzip -q /tmp/Meslo.zip -d /usr/share/fonts/meslo
fc-cache -f
rm  /tmp/Meslo.zip

## Install patch (Nerd Fonts) JetBrains Mono
mkdir -p /usr/share/fonts/jetbrains-mono-fonts-all
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip -O /tmp/JetBrainsMono.zip
unzip -q /tmp/JetBrainsMono.zip -d /usr/share/fonts/jetbrains-mono-fonts-all
fc-cache -f
rm  /tmp/JetBrainsMono.zip

# Extensions
dnf install \
--allowerasing `# Replace conflicting packages` \
--skip-broken `# Skip uninstallable packages` \
-y `# Do not ask for confirmation` \
beesu `# Graphical wrapper for su` \
file-roller-nautilus `# More Archives supported in nautilus` \
gnome-extensions-app `# Manage GNOME Shell extensions` \
gnome-shell-extension-user-theme `# Enables theming the gnome shell` \
gnome-terminal-nautilus `# GNOME Terminal extension for Nautilus` \
gnome-tweaks `# Your central place to make gnome like you want` \

# Themes
sudo dnf copr enable -y daniruiz/flat-remix
dnf install \
--allowerasing `# Replace conflicting packages` \
--skip-broken `# Skip uninstallable packages` \
-y `# Do not ask for confirmation` \
arc-theme `# Flat theme with transparent elements` \
papirus-icon-theme `# Free and open source SVG icon theme based on Paper Icon Set` \
flat-remix-theme `# Pretty simple theme inspired on material design`

echo ""
echo "FEDORA-SETUP: Installing extension, fonts and themes finished."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Configure and use Flathub
#####

echo "-----------------------------------------------------------------------"
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
echo "-----------------------------------------------------------------------"
echo ""


# ----------------------------------------------------------------------------
#####
# Enable some of the goodies, but not all
# or set a more specific tuned profile
#####

echo "-----------------------------------------------------------------------"
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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Installing Zotero
#####

echo "-----------------------------------------------------------------------"
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
echo "-----------------------------------------------------------------------"
echo ""


# ----------------------------------------------------------------------------
#####
# Installing TeamViewer
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing TeamViewer."
echo ""

# Download GPG key
wget -o "/dev/null" -O "TeamViewer_Linux_PubKey.asc" "https://linux.teamviewer.com/pubkey/currentkey.asc"

# Add GPG key
rpm --import TeamViewer_Linux_PubKey.asc

# Download client
wget -o "/dev/null" "https://download.teamviewer.com/download/linux/teamviewer.x86_64.rpm" 

# Install client
dnf install ./teamviewer.x86_64.rpm -y

# Remove downloaded files
rm -f TeamViewer_Linux_PubKey.asc teamviewer.x86_64.rpm

echo ""
echo "FEDORA-SETUP: Teamviewer successfully installed."
echo "-----------------------------------------------------------------------"
echo ""


# ----------------------------------------------------------------------------
#####
# Installing LanguateTool
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing LanguateTool Server."
echo ""

# Download tarball
wget -O "languagetool.zip" "https://languagetool.org/download/LanguageTool-stable.zip" -o "/dev/null"

# create an appropriate location
mkdir -p $home_selected/.bin
mkdir -p $home_selected/.bin/languagetool

# Extract
unzip -q languagetool.zip -d $home_selected/.bin/languagetool

# Change ownership to specified user
chown -R $user_selected:$user_selected $home_selected/.bin/languagetool

# Clean root user folder from the downloaded tarball
rm -f languagetool.zip

echo ""
echo "FEDORA-SETUP: LanguateTool Server successfully installed."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# AppImage Integrator
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing and configuring AppImageLauncher integrator."
echo ""

# Download and install AppImageLauncher
# sudo -E -u $user_selected wget -q -O "$home_selected/appimagelauncher.rpm" -o "/dev/null" \
# "https://github.com$(curl -s $(curl -Ls -o /dev/null -w %{url_effective} https://github.com/TheAssassin/AppImageLauncher/releases/latest) | grep -Eoi '<a [^>]+>' | grep -Eo 'href="[^\"]+"' | grep -Eo '/TheAssassin/AppImageLauncher/releases/download/\S*/appimagelauncher\S*\.x86_64.rpm')"

sudo -E -u $user_selected wget -q -O "$home_selected/appimagelauncher.rpm" -o "/dev/null" \
"$(wget -q -O - 'https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest' | jq -r '.assets[] | select(.name | test("appimagelauncher.*\\.x86_64\\.rpm")).browser_download_url')"

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
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# AppImage Applications
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing and configuring AppImage applications."
echo ""

# Create folder to store AppImage files
mkdir -p $home_selected/.bin $home_selected/.bin/appimagefiles
chown -R $user_selected:$user_selected $home_selected/.bin

# Download and install Obsidian
{
wget -q -O "$home_selected/.bin/appimagefiles/obisidian.AppImage" -o "/dev/null" \
"$(wget -q -O - 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest' | jq -r '.assets[] | select(.name | test("Obsidian-\\d*\\.\\d*\\.\\d*\\.AppImage")).browser_download_url')"
chown -R $user_selected:$user_selected $home_selected/.bin/appimagefiles/obisidian.AppImage

echo ""
echo "FEDORA-SETUP: Successfully downloaded and placed Obsidian ImageApp."
echo ""
} || {
echo ""
echo "FEDORA-SETUP: Failed to download and place Obsidian ImageApp."
echo ""
}

# Download and install JetBrains ToolBox
{
wget -q -O "/tmp/jetbrains-toolbox.tar.bz2" -o "/dev/null" "https://download-cdn.jetbrains.com/toolbox/jetbrains-toolbox-2.0.4.17212.tar.gz"
tar -xf /tmp/jetbrains-toolbox.tar.bz2 --strip-components=1 -C $home_selected/.bin/appimagefiles/
chown -R $user_selected:$user_selected $home_selected/.bin/appimagefiles/jetbrains-toolbox
rm /tmp/jetbrains-toolbox.tar.bz2

echo ""
echo "FEDORA-SETUP: Successfully downloaded and placed JeBrains ToolBox ImageApp."
echo ""
} || {
echo ""
echo "FEDORA-SETUP: Failed to download and place JeBrains ToolBox ImageApp."
echo ""
}


# Download and install Insomnia Core
{

sudo -E -u $user_selected bash <<-EOC
wget -q -O "insomnia.AppImage" -o "/dev/null" \
$(wget -q -O - 'https://api.github.com/repos/Kong/Insomnia/releases' | jq -r --arg version "${"$(curl -Ls -o /dev/null -w %{url_effective} https://updates.insomnia.rest/downloads/release/latest\?app\=com.insomnia.app\&source\=website)"##*/}" '.[] | select(.tag_name == $version) | .assets[] | select(.name | endswith(".AppImage")).browser_download_url')
EOC
mv ./insomnia.AppImage $home_selected/.bin/appimagefiles/insomnia.AppImage
chown -R $user_selected:$user_selected $home_selected/.bin/appimagefiles/insomnia.AppImage

echo ""
echo "FEDORA-SETUP: Successfully downloaded and placed JeBrains ToolBox ImageApp."
echo ""
} || {
echo ""
echo "FEDORA-SETUP: Failed to download and place JeBrains ToolBox ImageApp."
echo ""
}




echo ""
echo "FEDORA-SETUP: Installing and configuring AppImage applications finished."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Theming and GNOME Options
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Configuring dconf settings."
echo ""

# This indexer is nice, but can be detrimental for laptop users battery life
sudo -E -u $user_selected bash <<EOC
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery false
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery-first-time false
gsettings set org.freedesktop.Tracker3.Miner.Files throttle 15
EOC

# Nautilus (File Manager) configuration
{

# gsettings set org.gnome.nautilus.window-state sidebar-width 250

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.nautilus.window-state maximized true
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard'
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.list-view default-column-order "['name','size','type','detailed_type','owner','group','permissions','where','date_modified','date_created','date_modified_with_time','date_accessed','recency','starred']"
gsettings set org.gnome.nautilus.list-view default-visible-columns "['name','size','type','detailed_type','date_modified','date_created','starred']"
EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured Nautilus (File Manager)."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Nautilus (File Manager)."
echo ""

}


# File Chooser configuration
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.Settings.FileChooser date-format 'with-time'
gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gtk.Settings.FileChooser type-format 'mime'
EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured File Chooser."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure File Chooser."
echo ""

}

# Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)
{

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
gsettings set org.gnome.shell.weather locations "[<(uint32 2, <('São Paulo', 'SBMT', true, [(-0.41044326824509736, -0.8139052020289248)], [(-0.41073414481823473, -0.81361432545578749)])>)>]"
gsettings set org.gnome.GWeather temperature-unit 'centigrade'

EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)."
echo ""

}




# Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
gsettings set org.gnome.system.locale region 'pt_BR.UTF-8'
gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']"
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.mutter workspaces-only-on-primary true
gsettings set org.gnome.tweaks show-extensions-notice false
EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)."
echo ""

}

# Apps and UX configs for different Gnome Shell version equal or superior to 42
{

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
gsettings set org.gnome.TextEditor right-margin-position 120
EOC

    # Weather widget configuration (GTK4+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.GWeather4 temperature-unit 'centigrade'
EOC

mkdir -p /$home_selected/.config/gtk-4.0
cp -r /usr/share/themes/Flat-Remix-LibAdwaita-Blue-Dark-Solid/* /$home_selected/.config/gtk-4.0/
chown -R $user_selected:$user_selected $home_selected/.config/gtk-4.0/*

fi

echo ""
echo "FEDORA-SETUP: Succesfully configured GNOME Shell 43+ specifics."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure GNOME Shell 43+ specifics)."
echo ""

}

# GNOME Shell Default Extensions Activation
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell enabled-extensions "['user-theme@gnome-shell-extensions.gcampax.github.com', 'appindicatorsupport@rgcjonas.gmail.com']"

gsettings set org.gnome.shell disabled-extensions "['background-logo@fedorahosted.org']"
EOC

echo ""
echo "FEDORA-SETUP: Succesfully activated built-in GNOME shell extensions."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to activated built-in GNOME shell extensions."
echo ""

}


echo ""
echo "FEDORA-SETUP: Configuring dconf settings finished."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Oh-My-Zsh, Powerlevel10k and LSD configuration
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing and Configuring Oh-My-Zsh with Powerlevel10k."
echo ""

{

# Install oh-my-szh
export ZSH="/usr/share/oh-my-zsh"
sh -c "$(curl -fSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# # Add oh-my-zsh to /usr/share
# mv /root/.oh-my-zsh /usr/share
# mv /usr/share/.oh-my-zsh /usr/share/oh-my-zsh
# mv /root/.zshrc /usr/share/oh-my-zsh
# mv /usr/share/oh-my-zsh/.zshrc /usr/share/oh-my-zsh/zshrc

if [ -f  "/root/.zshrc" ] 
then
    mv /root/.zshrc /usr/share/oh-my-zsh
    mv /usr/share/oh-my-zsh/.zshrc /usr/share/oh-my-zsh/zshrc
else
    mv "${home_selected}"/.zshrc /usr/share/oh-my-zsh
    mv /usr/share/oh-my-zsh/.zshrc /usr/share/oh-my-zsh/zshrc
fi 

# # Modify zshrc to point to /usr/share/oh-my-zsh
# sed -i 's|export ZSH="$HOME/.oh-my-zsh"|export ZSH="\/usr\/share\/oh-my-zsh"|g' /usr/share/oh-my-zsh/zshrc

# Activate update reminder
sed -i "s/# zstyle ':omz:update' mode reminder  # just remind me to update when it's time/zstyle ':omz:update' mode reminder  # just remind me to update when it's time/" /usr/share/oh-my-zsh/zshrc

# Enable Autocorrection for zsh
sed -i 's/# ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/g' /usr/share/oh-my-zsh/zshrc

# Enable Autosuggestions, sintax highlighting and fzf plugins for zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-/usr/share/oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-/usr/share/oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(git)\nZSH_DISABLE_COMPFIX=true/' /usr/share/oh-my-zsh/zshrc
sed -i 's/plugins=(git)/plugins=(\n  git\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n  fzf\n)/' /usr/share/oh-my-zsh/zshrc


# Create a backup copy of original zshrc
cp /usr/share/oh-my-zsh/zshrc /usr/share/oh-my-zsh/zshrc.backup

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

# Configure FZF
tee -a /usr/share/oh-my-zsh/zshrc > /dev/null << 'EOI'

# ZFZ configuration
export FZF_BASE="$(which fzf)/.fzf"
export FZF_DEFAULT_COMMAND='rg --hidden --no-ignore --files -g "!.git/"'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

EOI

# other aliases
tee -a /usr/share/oh-my-zsh/zshrc > /dev/null << 'EOI'

# General aliases
alias python=python3
alias gs="git status"
alias fp="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"

EOI

# add user .local/bin and /bin to PATH
tee -a /usr/share/oh-my-zsh/zshrc > /dev/null << 'EOI'

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.bin" ] ; then
    PATH="$HOME/.bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

EOI

# Create Symbolic Links to /etc/skel
sudo ln -s /usr/share/oh-my-zsh/zshrc /etc/skel/.zshrc

# Copy zshrc to $HOME for root and change default shell to ZSH
ln -s /usr/share/oh-my-zsh/zshrc /root/.zshrc
echo "$USER" | chsh -s /bin/zsh

# Copy zshrc to $HOME for user and change default shell to ZSH
ln -s /usr/share/oh-my-zsh/zshrc ${home_selected}/.zshrc
usermod --shell $(which zsh) $user_selected
chown -R $user_selected:$user_selected ${home_selected}/.zshrc
chown -R $user_selected:$user_selected /usr/share/oh-my-zsh

echo ""
echo "FEDORA-SETUP: Succesfully installed Oh-My-Zsh."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to install Oh-My-Zsh."
echo ""

}

{
## Install Powelevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-/usr/share/oh-my-zsh/custom}/themes/powerlevel10k

echo ""
echo "FEDORA-SETUP: Succesfully installed Powerlevel10k."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to install Powerlevel10k."
echo ""

}

{
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

# Copy Powerlevel10k config file to both root and user home directories
if [ -f "$script_dir_path/p10k.zsh" ] 
then
    cp $script_dir_path/p10k.zsh /root/.p10k.zsh
    cp $script_dir_path/p10k.zsh $home_selected/.p10k.zsh
    chown -R $user_selected:$user_selected $home_selected/.p10k.zsh
fi 

echo ""
echo "FEDORA-SETUP: Succesfully configured Powerlevel10k."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Powerlevel10k."
echo ""

}

echo
echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing pyenv."
echo 

export PYENV_ROOT=${home_selected}/.pyenv
curl -s https://pyenv.run | bash


tee -a /usr/share/oh-my-zsh/zshrc ${home_selected}/.profile ${home_selected}/.zprofile ${home_selected}/.bashrc > /dev/null << 'EOI'


# Configuration for pyenv
if [ -d "$HOME/.pyenv" ] ; then
    export PYENV_ROOT="$HOME/.pyenv"
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi
EOI

chown -R $user_selected:$user_selected ${home_selected}/.pyenv
chown -R $user_selected:$user_selected ${home_selected}/.profile
chown -R $user_selected:$user_selected ${home_selected}/.zprofile

echo 
echo "FEDORA-SETUP: Installing pyenv finished."
echo "-----------------------------------------------------------------------"


echo ""
echo "FEDORA-SETUP: Installing and Configuring Oh-My-Zsh with Powerlevel10k finished."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Install and configure nvidia and CUDA drivers
#####

if [ -n "$(lspci | grep -E "NVIDIA|nvidia|Nvidia|NVidia")" ] && [[ -n "$install_nvidia_drivers" ]]
then
        echo "-----------------------------------------------------------------------"
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
        echo "-----------------------------------------------------------------------"
        echo ""
fi

# ----------------------------------------------------------------------------
#####
# Configure and use Snap and Snap Store Applications
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Installing and configuring Snap."
echo ""

# Create symlink to ensure proper functioning
ln -s /var/lib/snapd/snap /snap

# Updating cache
snap refresh

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap finished."
echo "-----------------------------------------------------------------------"
echo ""


# ----------------------------------------------------------------------------
#####
# Configure Gnome Terminal to work with Oh-my-zsh and Powerlevel10k
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Configure Gnome Terminal to work with Oh-my-zsh and Powerlevel10k."
echo ""

sudo -E -u $user_selected bash <<-EOC
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" default-size-columns 160
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" default-size-rows 96
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" font 'MesloLGS Nerd Font Mono 11'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" use-system-font false
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" visible-name 'Oh-My-Zsh-P10k-Default'
gsettings set org.gnome.desktop.interface monospace-font-name 'MesloLGS Nerd Font Mono 10'
EOC

echo ""
echo "FEDORA-SETUP: Configure Gnome Terminal to work with Oh-my-zsh and Powerlevel10k finished."
echo "-----------------------------------------------------------------------"
echo ""

# ----------------------------------------------------------------------------
#####
# Ending setup process
#####

echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Ending setup."
echo "-----------------------------------------------------------------------"
echo ""

# Restart
echo "-----------------------------------------------------------------------"
echo "FEDORA-SETUP: Please, restart."
echo "-----------------------------------------------------------------------"
echo ""

Log_Close

chown -R $user_selected:$user_selected $LOGDIR/$JobClass

# Script end