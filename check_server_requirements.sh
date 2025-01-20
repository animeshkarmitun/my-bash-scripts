#!/bin/bash

# -------------------------------------------------------------
# Script: Docker Installation on Linux
# Author: Animesh Kar
# Description: This script installs Docker on a Linux VM.
# Features:
#   - Checks system compatibility (architecture, kernel version, etc.)
#   - Validates and installs dependencies
#   - Prompts for user confirmation during key operations
#   - Installs or updates Docker as needed using Docker's official repository
# -------------------------------------------------------------

# -------------------- Color Codes --------------------
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'

# -------------------- Utility Functions --------------------

# Display an error message and exit
error_exit() {
    echo -e "${RED}${BOLD}$1${RESET}"
    exit 1
}

# Prompt user for confirmation
prompt_user() {
    echo -e "${CYAN}${BOLD}$1${RESET} (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation aborted.${RESET}"
        exit 0
    fi
}

# -------------------- Compatibility Checks --------------------

# Check system architecture (Docker requires 64-bit)
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    echo -e "${GREEN}${BOLD}System architecture:${RESET} ${GREEN}64-bit (compatible with Docker)${RESET}"
else
    echo -e "${RED}${BOLD}System architecture:${RESET} ${RED}$arch (Docker requires a 64-bit system)${RESET}"
    error_exit "Exiting due to incompatible architecture."
fi

# Check kernel version (Docker requires >= 3.10)
kernel_version=$(uname -r | awk -F'-' '{print $1}')
required_kernel_version="3.10"
if [[ "$(echo -e "$kernel_version\n$required_kernel_version" | sort -V | head -n 1)" == "$required_kernel_version" ]]; then
    echo -e "${GREEN}${BOLD}Kernel version:${RESET} ${GREEN}$kernel_version (compatible with Docker)${RESET}"
else
    echo -e "${RED}${BOLD}Kernel version:${RESET} ${RED}$kernel_version (Docker requires at least version 3.10)${RESET}"
    error_exit "Exiting due to incompatible kernel version."
fi

# Check if the system is running a supported Linux distribution
distro=$(cat /etc/os-release | grep -E '^NAME=' | awk -F= '{print $2}' | tr -d '"')
if [[ "$distro" =~ "Ubuntu" || "$distro" =~ "Debian" || "$distro" =~ "CentOS" || "$distro" =~ "Fedora" ]]; then
    echo -e "${GREEN}${BOLD}Linux distribution:${RESET} ${GREEN}$distro (compatible with Docker)${RESET}"
else
    echo -e "${RED}${BOLD}Linux distribution:${RESET} ${RED}$distro (may not be compatible with Docker)${RESET}"
    error_exit "Exiting due to unsupported distribution."
fi

# -------------------- Dependency Installation --------------------

echo -e "${BLUE}${BOLD}Checking and installing required dependencies...${RESET}"
dependencies=("curl" "apt-transport-https" "ca-certificates" "software-properties-common")
for pkg in "${dependencies[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        echo -e "${GREEN}$pkg is already installed${RESET}"
    else
        echo -e "${YELLOW}$pkg is not installed. Installing...${RESET}"
        sudo apt-get install -y "$pkg" || error_exit "Failed to install $pkg. Exiting."
    fi
    done

# -------------------- Docker Installation --------------------

# Check if Docker is already installed
if command -v docker &>/dev/null; then
    installed_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    latest_version=$(curl -s https://download.docker.com/linux/static/stable/x86_64/ | grep -oP 'docker-\K[0-9.]+(?=-ce\.tgz)' | head -n 1)

    echo -e "${GREEN}${BOLD}Docker is already installed!${RESET}"
    echo -e "${YELLOW}${BOLD}Installed version:${RESET} $installed_version"
    echo -e "${CYAN}${BOLD}Latest version:${RESET} $latest_version"

    # Display additional Docker info
    echo -e "${BLUE}${BOLD}Additional Docker Information:${RESET}"
    docker info | grep -E 'Containers|Images|Server Version'

    if [[ "$installed_version" != "$latest_version" ]]; then
        echo -e "${YELLOW}${BOLD}Notice:${RESET} Installed Docker version is outdated."
        prompt_user "Would you like to update Docker to the latest version?"
        echo -e "${GREEN}${BOLD}Updating Docker...${RESET}"
        sudo apt-get install --only-upgrade docker-ce -y || error_exit "Failed to update Docker. Exiting."
    else
        echo -e "${GREEN}${BOLD}Your Docker version is up-to-date.${RESET}"
    fi
else
    echo -e "${RED}${BOLD}Docker is not installed.${RESET}"
    prompt_user "Would you like to install Docker now?"

    echo -e "${CYAN}${BOLD}Setting up Docker repository...${RESET}"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo -e "${CYAN}${BOLD}Installing Docker...${RESET}"
    sudo apt-get update || error_exit "Failed to update package lists. Exiting."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io || error_exit "Failed to install Docker. Exiting."
    echo -e "${GREEN}${BOLD}Docker installation completed successfully!${RESET}"
fi

# -------------------- Completion --------------------
echo -e "${CYAN}${BOLD}Docker setup completed! You can start using Docker.${RESET}"
