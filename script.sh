#!/bin/bash

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Check if script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run with root account or use sudo to start the script!${NC}"
        exit 1
    fi
}

# Function to compare version strings
version_gt() { 
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Node.js installation/verification function
setup_nodejs() {
    echo -e "${YELLOW}Checking Node.js installation...${NC}"
    
    # Check if Node.js is installed
    if command -v node &> /dev/null; then
        # Get current version
        CURRENT_VERSION=$(node -v | cut -d 'v' -f 2)
        echo -e "Current Node.js version: ${GREEN}v${CURRENT_VERSION}${NC}"
        
        # Get the latest available LTS version from NodeSource (20.x)
        LATEST_VERSION="20"
        MAJOR_VERSION=$(echo $CURRENT_VERSION | cut -d '.' -f 1)
        
        # Check if current version is already Node.js 20.x
        if [ "$MAJOR_VERSION" -eq "$LATEST_VERSION" ]; then
            echo -e "${GREEN}Node.js 20.x is already installed. No action needed.${NC}"
        else
            echo -e "${YELLOW}Upgrading Node.js from v${CURRENT_VERSION} to latest 20.x version...${NC}"
            
            # Remove existing Node.js installation
            echo -e "${YELLOW}Removing existing Node.js installation...${NC}"
            apt-get remove -y nodejs npm
            rm -f /etc/apt/sources.list.d/nodesource.list
            rm -f /etc/apt/keyrings/nodesource.gpg
            apt-get autoremove -y
            
            # Install Node.js 20.x
            echo -e "${YELLOW}Installing Node.js 20.x...${NC}"
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
            apt update
            apt install -y nodejs npm git
            
            # Verify new installation
            NEW_VERSION=$(node -v | cut -d 'v' -f 2)
            echo -e "${GREEN}Successfully upgraded Node.js to v${NEW_VERSION}${NC}"
        fi
    else
        echo -e "${YELLOW}Node.js is not installed. Installing Node.js 20.x...${NC}"
        
        # Install Node.js 20.x
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
        apt update
        apt install -y nodejs npm git
        
        # Verify installation
        NEW_VERSION=$(node -v | cut -d 'v' -f 2)
        echo -e "${GREEN}Successfully installed Node.js v${NEW_VERSION}${NC}"
    fi
    
    echo -e "${GREEN}Node.js setup complete.${NC}"
}

# Installation functions
panel_depends() {
    echo -e "${GREEN}Installing panel dependencies...${NC}"
    # Ensure Node.js is set up correctly first
    setup_nodejs
    npm install -g typescript
    echo -e "${GREEN}Panel dependencies installed successfully!${NC}"
}

daemon_depends() {
    echo -e "${GREEN}Installing daemon dependencies...${NC}"
    # Ensure Node.js is set up correctly first
    setup_nodejs
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    npm install -g typescript
    echo -e "${GREEN}Daemon dependencies installed successfully!${NC}"
}

install_panel() {
    echo -e "${GREEN}Installing panel...${NC}"
    mkdir -p /var/www
    cd /var/www/ || { echo -e "${RED}Failed to change directory to /var/www/${NC}"; return 1; }
    
    # Check if panel directory already exists
    if [ -d "/var/www/panel" ]; then
        echo -e "${YELLOW}Panel directory already exists. Removing it before installation...${NC}"
        rm -rf /var/www/panel
    fi
    
    git clone https://github.com/AirlinkLabs/panel.git
    cd panel || { echo -e "${RED}Failed to change directory to panel${NC}"; return 1; }
    sudo chown -R www-data:www-data /var/www/panel
    sudo chmod -R 755 /var/www/panel
    
    if [ -f "example.env" ]; then
        cp example.env .env
    else
        echo -e "${RED}example.env file not found!${NC}"
        return 1
    fi
    
    npm install --production
    npm run migrate:dev
    npm run build-ts
    mv /tmp/Airlink-installer/systemd/airlink-panel.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable airlink-panel.service
    sudo systemctl start airlink-panel.service
    echo -e "${GREEN}Panel installation completed successfully!${NC}"
}

install_daemon() {
    echo -e "${GREEN}Installing daemon...${NC}"
    cd /etc/ || { echo -e "${RED}Failed to change directory to /etc/${NC}"; return 1; }
    
    # Check if daemon directory already exists
    if [ -d "/etc/daemon" ]; then
        echo -e "${YELLOW}Daemon directory already exists. Removing it before installation...${NC}"
        rm -rf /etc/daemon
    fi
    
    git clone https://github.com/AirlinkLabs/daemon.git
    cd daemon || { echo -e "${RED}Failed to change directory to daemon${NC}"; return 1; }
    sudo chown -R www-data:www-data /etc/daemon
    sudo chmod -R 755 /etc/daemon
    
    if [ -f "example.env" ]; then
        cp example.env .env
    else
        echo -e "${RED}example.env file not found!${NC}"
        return 1
    fi
    
    npm install
    npm run build
    mv /tmp/Airlink-installer/systemd/airlink-daemon.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable airlink-daemon.service
    sudo systemctl start airlink-daemon.service
    echo -e "${GREEN}Daemon installation completed successfully!${NC}"
}

# Removal functions
remove_panel() {
    echo -e "${YELLOW}Removing panel...${NC}"
    if [ -d "/var/www/panel" ]; then
        rm -rf /var/www/panel
        echo -e "${GREEN}Panel removed successfully!${NC}"
    else
        echo -e "${YELLOW}Panel not found, nothing to remove.${NC}"
    fi
}

remove_daemon() {
    echo -e "${YELLOW}Removing daemon...${NC}"
    if [ -d "/etc/daemon" ]; then
        rm -rf /etc/daemon
        echo -e "${GREEN}Daemon removed successfully!${NC}"
    else
        echo -e "${YELLOW}Daemon not found, nothing to remove.${NC}"
    fi
}

remove_dependencies() {
    echo -e "${YELLOW}Removing dependencies...${NC}"
    
    # Remove Docker if installed
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}Removing Docker...${NC}"
        apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        rm -f /etc/apt/sources.list.d/docker.list
        rm -f /etc/apt/keyrings/docker.gpg
    fi
    
    # Remove Node.js if installed
    if command -v node &> /dev/null; then
        echo -e "${YELLOW}Removing Node.js...${NC}"
        apt-get remove -y nodejs npm git
        rm -f /etc/apt/sources.list.d/nodesource.list
        rm -f /etc/apt/keyrings/nodesource.gpg
    fi
    
    apt-get autoremove -y
    apt-get autoclean
    apt-get update
    echo -e "${GREEN}Dependencies removed successfully!${NC}"
}

tip_panel() {
    clear
    echo -e "${YELLOW}----------------------------------------------------${WHITE}"
    echo -e "${YELLOW}|${RED}Your panel has been started visit localhost:3000  ${YELLOW}|${WHITE}"
    echo -e "${YELLOW}----------------------------------------------------${WHITE}"
}

tip_daemon() {
    clear
    echo -e "${YELLOW}-----------------------------------------------------${WHITE}"
    echo -e "${YELLOW}|${RED}Your daemon has been started visit localhost:3002  ${YELLOW}|${WHITE}"
    echo -e "${YELLOW}-----------------------------------------------------${WHITE}"
}

tip_both() {
    clear
    echo -e "${YELLOW}-----------------------------------------------------${WHITE}"
    echo -e "${YELLOW}|${RED}Your panel has been started visit localhost:3000  ${YELLOW} |${WHITE}"
    echo -e "${YELLOW}|${RED}Your daemon has been started visit localhost:3002  ${YELLOW}|${WHITE}"
    echo -e "${YELLOW}-----------------------------------------------------${WHITE}"
}

# Install both dependencies
install_dependencies() {
    panel_depends
    daemon_depends
}

# Display ASCII art logo
display_logo() {
echo -e " ${BLUE}----${GREEN}INSTALLER HOME${YELLOW}--------${WHITE}"
echo -e " ${BLUE}    ___  _                _                ${WHITE}"
echo -e " ${BLUE}   / _ \(_)     _(_)     | |               ${WHITE}"
echo -e " ${BLUE}  / /_\ \ \_ _ | |_ _ __ | | __            ${WHITE}"
echo -e " ${BLUE}  |  _  | | '__| | | '_ \| |/ /            ${WHITE}"
echo -e " ${BLUE}  | | | | | |  | | | | | |   <             ${WHITE}"
echo -e " ${BLUE}  \_| |_/_|_|  |_|_|_| |_|_|\_\            ${WHITE}"
echo -e " ${BLUE}                                           ${WHITE}"
echo -e " ${BLUE}airlink${WHITE} asm software installer!            "
echo -e " panel and daemon by ${BLUE}airlinklabs${WHITE} © ${WHITE}"
echo -e " install script by ${GREEN}G-flame!${WHITE}" 
}

# Main UI function
show_menu() {
    check_root
    display_logo
    echo -e "1) ${GREEN}Install ${BLUE}panel and daemon${NC} (dependencies too)!"
    echo -e "2) ${GREEN}Install ${BLUE}panel${NC} only!"
    echo -e "3) ${GREEN}Install ${BLUE}daemon${NC} only!"
    echo -e "4) ${GREEN}Install ${BLUE}dependencies${NC} (both panel and daemon depends) only!"
    echo -e "5) ${RED}Remove ${BLUE}panel and daemon${NC}!"
    echo -e "6) ${RED}Remove ${BLUE}panel${NC} only!"
    echo -e "7) ${RED}Remove ${BLUE}daemon${NC} only!"
    echo -e "8) ${RED}Remove ${BLUE}dependencies${NC} only!"
    echo -e "9) ${RED}Exit${NC} installer!"
    
    read -p "What do you want to do? [1-9]: " choice
    
    case $choice in
        1)
            install_dependencies
            install_panel
            install_daemon
            tip_both
            ;;
        2)
            panel_depends
            install_panel
            tip_panel
            ;;
        3)
            daemon_depends
            install_daemon
            tip_daemon
            ;;
        4)
            install_dependencies
            ;;
        5)
            remove_panel
            remove_daemon
            ;;
        6)
            remove_panel
            ;;
        7)
            remove_daemon
            ;;
        8)
            remove_dependencies
            ;;
        9)
            echo -e "${GREEN}Thank you for using the installer. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}That's not a valid option! Please try again.${NC}"
            ;;
    esac
    
    echo -e "${YELLOW}-_--_--_--_--_--_-${GREEN}Log End${YELLOW}-_--_--_--_--_--_--_--_--_-${NC}"
    echo -e "${GREEN}Operation completed!${NC}"
    echo -e "\nPress Enter to return to the menu..."
    read
    clear
    show_menu
}

# Start the script
clear
show_menu