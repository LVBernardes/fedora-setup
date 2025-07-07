#!/usr/bin/env bash

# Import shell tools.
source ./00_shell_tools.sh


# DNF configuration file path.
DNF_CONF_FILE="/etc/dnf/dnf.conf"
BACKUP_FILE="$DNF_CONF_FILE.bkp"


# Function to add or update configuration.
update_unitary_dnf_config() {
    local key=$1
    local value=$2
    
    # Check if setting already exists with the same value.
    if grep -q "^${key}=${value}$" "$DNF_CONF_FILE"; then
        color_echo "orange" "[INFO] - Setting ${key}=${value} already exists."
        return 0
    fi
    
    if grep -q "^${key}=" "$DNF_CONF_FILE"; then
        # Update existing setting.
        color_echo "blue" "[INFO] - Updating existing setting: ${key}=${value}."
        if ! sudo sed -i "s/^${key}=.*/${key}=${value}/" "$DNF_CONF_FILE"; then
            color_echo "red" "[ERROR] - Failed to update setting: ${key}."
            return 1
        fi
    else
        # Add new setting.
        color_echo "blue" "[INFO] - Adding new setting: ${key}=${value}."
        if ! echo "${key}=${value}" | sudo tee -a "$DNF_CONF_FILE" > /dev/null; then
            color_echo "red" "[ERROR] - Failed to add setting: ${key}."
            return 1
        fi
    fi
}


update_dnf_config() {

    local configs=$1

    # Check if DNF configuration file exists.
    if [[ ! -f "${DNF_CONF_FILE}" ]]; then
        color_echo "red" "[ERROR] - DNF configuration file not found at ${DNF_CONF_FILE}."
        exit 1
    fi

    # Create backup only if it doesn't exist
    if [[ ! -f "$BACKUP_FILE" ]]; then
        color_echo "green" "[INFO] - Creating backup of original DNF configuration."
        if ! sudo cp "${DNF_CONF_FILE}" "${BACKUP_FILE}"; then
            color_echo "red" "[ERROR] - Failed to create backup file."
            exit 1
        fi
        color_echo "green" "[INFO] - Backup created at ${BACKUP_FILE}."
    else
        color_echo "orange" "[INFO] - Backup file already exists at ${BACKUP_FILE}."
    fi

    # Counter for successful changes.
    local changes_made=0
    local errors=0

    # Add/Update DNF optimizations
    for key in "${!configs[@]}"; do
        if update_unitary_dnf_config "$key" "${configs[$key]}"; then
            ((changes_made++))
        else
            ((errors++))
        fi
    done


    # Final status report
    color_echo() "blue" "[INFO] - Configuration Summary."
    color_echo() "green" "Successfully processed configurations: $changes_made"
    if [ $errors -gt 0 ]; then
        color_echo() "red" "Errors encountered: $errors"
    fi

    color_echo() "blue" "[INFO] - Current DNF Configuration:"
    color_echo() "orange" "$(grep -E "^(fastestmirror|max_parallel_downloads|defaultyes|keepcache|deltarpm)=" "$DNF_CONF_FILE")" 

    # Verify if changes were successful
    if [ $errors -eq 0 ]; then
        color_echo() "green" "[SUCCESS] - DNF configuration has been optimized successfully."
    else
        color_echo() "red" "[WARNING] - DNF configuration completed with some errors."
        exit 1
    fi
}

# Add RPM Fusion Free and Non-Free
add_fusion_rpm_repositories() {

    color_echo "blue" "[INFO] - Adding Fusion Free and Non-Free repos."

    sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm 
    sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
    color_echo "green" "[SUCCESS] - Repos added successfully"


    color_echo "blue" "[INFO] - Enabling Cisco OpenH264 repo."
    if [[ "$(rpm -E %fedora)" -ge 41 ]]; then
        sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1;
        handle_error "Failed to enable Cisco OpenH264 repo."
    else
        sudo dnf config-manager --enable fedora-cisco-openh264;
        handle_error "Failed to enable Cisco OpenH264 repo."
    fi

    color_echo "blue" "[INFO] - Enabled repositories:"
    color_echo "orange" "$(dnf repolist --enabled)"
}

update_pre_installed_packages() {
    color_echo "blue" "[INFO] - Update/upgrade pre-installed packages."

    dnf install upgrade --best --allowerasing --refresh -y
    dnf distro-sync -y

    handle_error "Failed to update upgrade."

    color_echo "green" "[SUCCESS] - Updated pre-installed packages with success."
}


download_and_install_rpm_packages () {

    user=$1
    user_directory="$( get_user_home_dir "$user" )"
    package_list=$2
    download_dir="${user_home_dir}/Downloads"

  # Add the directory for downloads if it does not exist
  [[ ! -d "$download_dir" ]] && mkdir "$download_dir"

  for url in "${package_list[@]}"; do
    package_name=$(basename "${url}")
    destination_path="$download_dir/${package_name}"

    color_echo "blue" "[INFO] - Downloading package from URL: ${url}."
    wget -c "${url}" -P "$download_dir" &> /dev/null

    color_echo "blue" "[INFO] - Installing package: ${package_name}."
    sudo dnf install "$destination_path" -y
    handle_error "Failed to install ${package_name}."
    color_echo "green" "[SUCCESS] - '${package_name}' installed successfully."
  done
}

install_dnf_packages() {
    packages=$1

    if [[ ${#packages[@]} -lt 1 ]]; then
        color_echo "yellow" "[WARNING] - No packages were informed for installation."
    else
        color_echo "blue" "[INFO] - Installing packages."
        sudo dnf install -y --allowerasing --skip-broken "${packages[*]}"
        handle_error "Failed to install some or all the packages."

        color_echo "green" "[SUCCESS] - Packages installed successfully."
    fi

}