#!/usr/bin/env bash

# Import shell tools.
source ./00_shell_tools.sh

add_flathub_repo() {
    color_echo "blue" "[INFO] - Setting up flathub repo"
    
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    handle_error "Failed to add Flathub repo"

    color_echo "green" "[SUCCESS] - Flathub successfully added."

    color_echo "blue" "[INFO] - Updating flathub index"
    
    sudo flatpak repair
    flatpak update 
    handle_error "Failed to update Flathub repo"

    color_echo "green" "[SUCCESS] - Flathub index successfully updated"
}

install_flatpak_app() {

    flatpak_list=$1

    if [[ ${#flatpak_list[@]} -lt 1 ]]; then
        color_echo "yellow" "[WARNING] - No flatpaks applications were informed."
    else
        for program in ${flatpak_list[@]}; do
        if ! flatpak list | grep -q ${program}; then
            color_echo "blue" "[INFO] - Installing ${program}..."
            flatpak install flathub "${program}" -y
        else
            color_echo "yellow" "[WARNING] - $program flatpak is already installed."
        fi
        done
    fi
}

