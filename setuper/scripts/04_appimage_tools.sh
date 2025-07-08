#!/usr/bin/env bash

# Import shell tools.
source ./00_shell_tools.sh


install_appimages_from_github() {
    local user=$1
    local appimages_array=$2
    local user_directory="$( get_user_home_dir "$user" )"
    local appimages_directory="${user_directory}/.local/share/appimages"

    # mkdir -p "$appimages_directory"
    # chown "${user}":"${user}" "${appimages_directory}"


    [[ ! -d "$appimages_directory" ]] && mkdir -p "$appimages_directory"

    if [[ ${#appimages_array[@]} -lt 1 ]]; then
    color_echo "yellow" "[WARNING] - No AppImages applications were informed."

    for key in "${!appimages_array[@]}"; do
        app_name="${key}"
        github_repo="${appimages_array[$key]}"
        destination_path="${appimages_directory}/${app_name}.AppImage"

        color_echo "blue" "[INFO] - Downloading package from Github repo: ${github_repo}."
        wget -q -O "${app_name}" -o "/dev/null" $(wget -q -O - "https://api.github.com/repos/${github_repo}/releases" | jq -r 'map(select(.prerelease==false)) | first | .assets[] | select(.name | endswith(".AppImage") and (contains("arm64")|not)).browser_download_url')
        handle_error "Failed to download ${app_name}."
        chmod +x "${destination_path}"
        handle_error "Failed to change ${app_name} permissions to executable."
        color_echo "green" "[SUCCESS] - '${app_name}' installed successfully."
    done
    
    }



    