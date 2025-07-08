#!/usr/bin/env bash

# console message colors
RED='\e[1;91m'
GREEN='\e[1;92m'
BLUE='\e[1;94m'
ORANGE='\e[1;93m'
NO_COLOR='\e[0m'


# Make all shell script files executable
echo -e "${GREEN}[INFO] - Making all files in scripts/ directory executable...${NO_COLOR}"
chmod +x ./scripts/*.sh

echo -e "${GREEN}[INFO] - Sourcing shell tools script...${NO_COLOR}"
sleep 2

source ./scripts/00_shell_tools.sh

# Run the DNF configuration optimization script
echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2
sudo -E -u $ACTUAL_USER bash ./scripts/10_initial_config_setup.sh
handle_error "Failed to start package manager and repos setup script."

# Run the DNF configuration optimization script
echo -e "${GREEN}[INFO] - Executing package and applications installation script...${NO_COLOR}"
sudo -E -u $ACTUAL_USER bash ./scripts/20_pkg_apps_installation.sh
handle_error "Failed to start package manager and repos setup script."

# echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
# sleep 2

# # Run the DNF configuration optimization script
# ./scripts/03_user_home_setup.sh

# echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
# sleep 2

# # Run the DNF configuration optimization script
# ./scripts/04_app_configuration.sh

# echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
# sleep 2

# # Run the DNF configuration optimization script
# ./scripts/03_user_home_setup.sh

# echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
# sleep 2

# # Run the DNF configuration optimization script
# ./scripts/03_user_home_setup.sh

# echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
# sleep 2

# # Run the DNF configuration optimization script
# ./scripts/03_user_home_setup.sh
