#!/bin/bash

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
kernel-modules `# kernel modules to match the core kernel` \
fuse `# File System in Userspace (FUSE) v2 utilities` \
fuse-common `# Common files for File System in Userspace (FUSE) v2 and v3` \
fuse-sshfs `# FUSE-Filesystem to access remote filesystems via SSH` \
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
gtkhash `# GTK+ utility for computing message digests or checksums` \
exfatprogs `# Userspace utilities for exFAT filesystems` \
ffmpeg `# Adds Codec Support to Firefox, and in general` \
gvfs `# Backends for the gio framework in GLib` \
gvfs-fuse `# gnome<>fuse` \
gvfs-mtp `# gnome<>android` \
gvfs-nfs `# gnome<>ntfs` \
gvfs-smb `# gnome<>samba` \
htop `# Interactive CLI process monitor` \
NetworkManager-openvpn-gnome `# To enforce that its possible to import .ovpn files in the settings` \
openssh-askpass `# Base Lib to let applications request ssh pass via gui` \
p7zip `# Very high compression ratio file archiver` \
p7zip-plugins `# Additional plugins for p7zip` \
pv `# A tool for monitoring the progress of data through a pipeline ( | )` \
python3 `# Python core library` \
python3-devel `# Python Development Gear` \
python3-neovim `# Python Neovim Libs` \
tuned `# Tuned can optimize your performance according to metrics. tuned-adm profile powersave can help you on laptops, alot` \
tuned-gtk `# GTK GUI for tuned` \
tuned-switcher `# Simple utility to manipulate the Tuned service` \
tuned-utils `# Various tuned utilities` \
unar `# free rar decompression` \
ansible `# SSH-based configuration management, deployment, and task execution system` \
ansible-core-doc `# Documentation for Ansible Bas` \
ansible-collection-ansible-netcommon `# Ansible Network Collection for Common Cod` \
ansible-collection-ansible-posix `# Ansible Collection targeting POSIX and POSIX-ish platforms` \
ansible-collection-ansible-utils `# Ansible Network Collection for Common Code` \
meld `# Visual diff and merge tool` \
nano `# Because pressing i is too hard sometimes` \
neovim `# Vim-fork focused on extensibility and agility` \
nethogs `# Whats using all your traffic? Now you know!` \
nload `# A tool can monitor network traffic and bandwidth usage in real time` \
vim-enhanced `# full vim` \
solaar `# Device manager for a wide range of Logitech devices` \
java-latest-openjdk-devel `# OpenJDK latest version Development Environment` \
texlive-scheme-full `# Texlive complete package`

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
vlc `# The cross-platform open-source multimedia framework, player and server` \
code `# Visual Studio Code application` \
google-chrome-stable `# Google Chrome` \
flameshot `# Powerful and simple to use screenshot software` \
blender `# 3D Software Powerhouse` \
calibre `# Ebook management` \
darktable `# Easy RAW Editor` \
dconf-editor `# Configuration editor for dconf` \
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
glances `# Nice CLI Monitor for your System` \
inkscape  `# Working with .svg files` \
krita  `# Painting done right` \
lm_sensors `# Hardware monitoring tools` \
lm_sensors-sensord `# Daemon that periodically logs sensor readings` \
rawtherapee `# Professional RAW Editor` \
qbittorrent `# A bittorrent Client` \
cockpit `# An awesome local and remote management tool` \
cockpit-navigator `# A File System Browser for Cockpit` \
cockpit-storaged `# Manage your system’s storage. Supports local partitions, encryption, NFS, RAID, iSCSI, and more.` \
cockpit-networkmanager `# Manage your network interfaces and edit your firewall with ease.` \
cockpit-packagekit `# See and apply updates to your system. Supports RPM and DEB based systems through PackageKit.` \
cockpit-podman `# Download, use, and manage containers in your browser. (Podman replaces Docker.)` \
ulauncher `# Linux Application Launcher` \
thunderbird `# Mozilla Thunderbird mail/newsgroup client` \
texstudio `# A feature-rich editor for LaTeX documents` \
plexmediaserver `# Plex organizes all of your personal media so you can easily access and enjoy it.`

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

dnf install \
-y `# Do not ask for confirmation` \
adobe-source-code-pro-fonts `# The most beautiful monospace font around` \
'mozilla-fira-*' `# A nice font family` \
file-roller-nautilus `# More Archives supported in nautilus` \
nautilus-extensions `# What it says on the tin` \
nautilus-image-converter `# Image converter option in context menu` \
nautilus-search-tool `# Searh option in context menu` \
gnome-terminal-nautilus `# GNOME Terminal extension for Nautilus` \
nautilus-python `# Python bindings for Nautilus` \
beesu `# Graphical wrapper for su` \
gtkhash-nautilus `# To get a file hash via GUI` \
gnome-extensions-app `# Manage GNOME Shell extensions` \
gnome-tweaks `# Your central place to make gnome like you want` \
gnome-shell-extension-user-theme `# Enables theming the gnome shell` \
papirus-icon-theme `# Free and open source SVG icon theme based on Paper Icon Set` \
arc-theme `# Flat theme with transparent elements`

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
flathub com.jgraph.drawio.desktop
EOF

echo ""
echo "FEDORA-SETUP: Installing and configuring Flathub and applications finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Configure and use Snap
#####

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap."
echo ""

# Install snapd
dnf install -y snapd

# Create symlink to ensure proper functioning
ln -s /var/lib/snapd/snap /snap

# Install Snap Store
snap install snap-store

# Install Spotify
snap install spotify

echo ""
echo "FEDORA-SETUP: Installing and configuring Snap finished."
echo ""

# ----------------------------------------------------------------------------
#####
# Install and configure nvidia and CUDA drivers
#####

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

echo ""
echo "FEDORA-SETUP: Installing NVidia drivers finished."
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

# Run launcher icon locator
bash /opt/zotero/set_launcher_icon

# Create symlink to desktop launcher
ln -s /opt/zotero/zotero.desktop $home_selected/.local/share/applications/zotero.desktop

# Clean root user folder from the downloaded tarvball
rm -f zotero.tar.bz2

echo ""
echo "FEDORA-SETUP: Zotero successfully installed."
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
wget -q -O "jetbrains-toolbox.tar.bz2" -o "/dev/null" "https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.22.10685.tar.gz"
tar -xf jetbrains-toolbox.tar.bz2 --strip-components=1 -C $home_selected/.bin/appimagefiles/
chown $user_selected:$user_selected $home_selected/.bin/appimagefiles/jetbrains-toolbox

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
sudo -E -u $user_selected bash <<EOF
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery false
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery-first-time false
gsettings set org.freedesktop.Tracker3.Miner.Files throttle 15
EOF

# Nautilus (File Manager) Usability
sudo -E -u $user_selected bash <<EOF
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard'
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.list-view default-column-order "['name','size','type','mime_type','owner','group','permissions','where','date_modified','date_created','date_modified_with_time','date_accessed','recency','starred']"
gsettings set org.gnome.nautilus.list-view default-visible-columns "['name','size','type','mime_type','date_modified','date_created','starred']"
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.Settings.FileChooser date-format 'with-time'
EOF

# Usability Improvements
sudo -E -u $user_selected bash <<EOF
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'adaptive'
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
EOF

# Theme configuration
sudo -E -u $user_selected bash <<EOF
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'breeze-dark'
EOF

# # Shell Extensions Activation
# sudo -E -u $user_selected bash <<EOF
# gsettings set org.gnome.shell enabled-extensions "['background-logo@fedorahosted.org','sound-output-device-chooser@kgshank.net','mediacontrols@cliffniff.github.com','caffeine@patapon.info','appindicatorsupport@rgcjonas.gmail.com']"
# EOF

# ----------------------------------------------------------------------------
#####
# Ending setup process
#####

chwon -R $user_selected:$user_selected $home_selected

echo ""
echo "FEDORA-SETUP: Ending setup."
echo ""

# Restart
echo ""
echo "FEDORA-SETUP: Please, restart."
echo ""

Log_Close