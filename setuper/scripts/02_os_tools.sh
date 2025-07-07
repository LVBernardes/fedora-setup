#!/usr/bin/env bash

# Import shell tools.
source ./00_shell_tools.sh

update_firmware() {

    color_echo "blue" "[INFO] - Updating devices firmwares and drivers."

    # Update firmware e drivers
    fwupdmgr get-devices
    fwupdmgr refresh --force
    fwupdmgr get-updates
    fwupdmgr update -y

    handle_error "Failed to update devices firmwares or drivers."

    color_echo "green" "[SUCCESS] - Device firmwares and drivers updated successfully."
}

