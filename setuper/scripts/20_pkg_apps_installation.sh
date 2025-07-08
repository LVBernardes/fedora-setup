#!/usr/bin/env bash

source ./00_shell_tools.sh
source ./01_dnf_and_rpm_tools.sh
source ./02_os_tools.sh
source ./03_flatpak_tools.sh
source ./04_appimage_tools.sh


color_echo "blue" "[BLUE] - Starting packages and applications installation."


BASIC_PACKAGES=(
    akmods # Automatic kmods build and install tool (used for building nvidia driver kernel modules)
    ansible # SSH-based configuration management, deployment, and task execution system
    ansible-collection-ansible-netcommon # Ansible Network Collection for Common Cod
    ansible-collection-ansible-posix # Ansible Collection targeting POSIX and POSIX-ish platforms
    ansible-collection-ansible-utils # Ansible Network Collection for Common Code
    ansible-core-doc # Documentation for Ansible Bas
    bat # cat(1) clone with wings
    ca-certificates# The Mozilla CA root certificate bundle
    url # A utility for getting files from remote servers (FTP, HTTP, and others)
    exa # Modern replacement for ls
    exfatprogs # Userspace utilities for exFAT filesystems
    use # File System in Userspace (FUSE) v2 utilities
    fastfetch # Fast neofetch-like system information tool
    fuse-common # Common files for File System in Userspace (FUSE) v2 and v3
    fuse-sshfs # FUSE-Filesystem to access remote filesystems via SSH
    fzf # A command-line fuzzy finder written in Go
    gcc # Various compilers (C, C++, Objective-C, ...)
    gcc-c++ # C++ support for GCC
    git # Fast Version Control System
    htop # Interactive CLI process monitor
    httpie # A Curl-like tool for humans
    jq # Command-line JSON processor
    kmodtool # Tool for building kmod packages (used for building nvidia driver kernel modules)
    lm_sensors # Hardware monitoring tools
    lm_sensors-sensord # Daemon that periodically logs sensor readings
    lsd # Ls command with a lot of pretty colors and some other stuff
    kernel-devel # Development package for building kernel modules to match the kernel
    kernel-modules # kernel modules to match the core kernel
    mokutil # Tool to manage UEFI Secure Boot MoK Keys (used for signing nvidia driver or other kernel modules)
    nano # Because pressing i is too hard sometimes
    neovim # Vim-fork focused on extensibility and agility
    nethogs # Whats using all your traffic? Now you know!
    NetworkManager-openvpn-gnome # To enforce that its possible to import .ovpn files in the settings
    openssh-askpass # Base Lib to let applications request ssh pass via gui
    openssl # Utilities from the general purpose cryptography library with TLS implementation
    p7zip # Very high compression ratio file archiver
    p7zip-plugins # Additional plugins for p7zip
    pv # A tool for monitoring the progress of data through a pipeline ( | )
    python3 # Python core library
    python3-devel # Python Development Gear
    python3-neovim # Python Neovim Libs
    ripgrep # Line oriented search tool | used with FZF
    snapd # A transactional software package manager. Analogous to Flatpak.
    solaar # Device manager for a wide range of Logitech devices
    squashfuse # FUSE filesystem to mount squashfs archives
    texlive-scheme-full # Texlive complete package
    tuned # Tuned can optimize your performance according to metrics. tuned-adm profile powersave can help you on laptops, alot
    tuned-gtk # GTK GUI for tuned
    tuned-switcher # Simple utility to manipulate the Tuned service
    tuned-utils # Various tuned utilities
    unar # free rar decompression
    unzip # A utility for unpacking zip files
    util-linux-user # A utility with chsh program to change shell
    vim-enhanced # full vim
    wget # A utility for retrieving files using the HTTP or FTP protocols
    zsh # zshell installation in preparation for oh-my-zsh
)

BASIC_GUI_PACKAGES=(
    blender # 3D Software Powerhouse
    darktable # Easy RAW Editor
    darktable-tools-noise# The noise profiling tools to support new cameras
    dconf-editor # Configuration editor for dconf
    filezilla # S/FTP Access
    gparted # Gnome Partition Editor
    gwe # System utility designed to provide information of NVIDIA card
    libreoffice-draw # LibreOffice Drawing Application
    vlc # The cross-platform open-source multimedia framework, player and server
)

FLATPAK_APPS=(
    io.github.nokse22.asciidraw # Draw diagrams, tables, tree view, art and more using only characters.
    com.github.wwmm.easyeffects # Audio effects for PipeWire applications
    com.calibre_ebook.calibre # Ebook management
    org.gnome.Extensions # GNOME Extensions handles updating extensions, configuring extension preferences and removing or disabling unwanted extensions. 
    com.mattjakeman.ExtensionManager # A utility for browsing and installing GNOME Shell Extensions.
    org.flameshot.Flameshot # Powerful and simple to use screenshot software
    com.github.tchx84.Flatseal # Flatseal is a graphical utility to review and modify permissions from your Flatpak applications.
    it.mijorus.gearlever # An utility to manage AppImages with ease
    org.gimp.GIMP # The Image Editing Powerhouse - and its plugins
    org.inkscape.Inkscape # Working with .svg files
    io.missioncenter.MissionCenter # Windows-like graphical resource monitor.
    com.obsproject.Studio # Free and open source software for video capturing, recording, and live streaming.
    md.obsidian.Obsidian # Obsidian is a powerful knowledge base that works on top of a local folder of plain text Markdown files.
    org.kde.okular # Okular is a universal document viewer developed by KDE.
    io.podman_desktop.PodmanDesktop # Podman Desktop is an open source graphical tool enabling you to seamlessly work with containers and Kubernetes from your local environment.
    org.qbittorrent.qBittorrent # A bittorrent Client
    com.spotify.Client
    org.stellarium.Stellarium # Stellarium renders 3D photo-realistic skies in real time with OpenGL.
    org.texstudio.TeXstudio # A feature-rich editor for LaTeX documents
    org.mozilla.Thunderbird # Mozilla Thunderbird mail/newsgroup client
    org.zotero.Zotero # Zotero is a free, easy-to-use tool to help you collect, organize, cite, and share your research sources.
)

# Array of configurations to add/update.
declare -A APPIMAGES=(
    "insomnia"="Kong/Insomnia"
    "drawio"="jgraph/drawio-desktop"
)

install_dnf_packages $BASIC_PACKAGES

install_dnf_packages $BASIC_GUI_PACKAGES

install_flatpak_app $FLATPAK_APPS

install_appimages_from_github $ACTUAL_USER $APPIMAGES