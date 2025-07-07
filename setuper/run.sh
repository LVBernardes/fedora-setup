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

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/01_pkg_management_setup.sh

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/02_pkg_installation.sh

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/03_user_home_setup.sh

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/04_app_configuration.sh

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/03_user_home_setup.sh

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/03_user_home_setup.sh

echo -e "${GREEN}[INFO] - Executing package manager and repos setup...${NO_COLOR}"
sleep 2

# Run the DNF configuration optimization script
./scripts/03_user_home_setup.sh
