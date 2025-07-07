#!/usr/bin/env bash

source ./00_shell_tools.sh
source ./01_dnf_and_rpm_tools.sh
source ./02_os_tools.sh
source ./03_flatpak_tools.sh


color_echo "blue" "[BLUE] - Starting initial configuration setup"

###########################################################
################### DNF configuration #####################
###########################################################
color_echo "blue" "[INFO] - Starting DNF configuration optimization"

# Array of configurations to add/update.
declare -A configs=(
    ["fastestmirror"]="True"
    ["max_parallel_downloads"]="10"
    ["keepcache"]="True"
    ["deltarpm"]="True"
)

update_dnf_config configs

# Add DNF Plugins Core.
color_echo "blue" "[INFO] - Install dnf-plugins-core"

dnf install -y dnf-plugins-core

handle_error "Failed to install dnf-plugins-core"

color_echo "green" "[SUCCESS] - dnf-plugins-core installed."

add_fusion_rpm_repositories

###########################################################
################# Flatpak configuration ###################
###########################################################

add_flathub_repo

###########################################################
###### Upgrade firmwares and pre-installed packages #######
###########################################################

# Update/upgrade pre-installed packages
update_pre_installed_packages

# Update firmware and drivers packages
update_firmware


color_echo "blue" "[BLUE] - Finishing initial configuration setup"
color_echo "" "---------------------------------------"
