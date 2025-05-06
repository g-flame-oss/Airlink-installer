#!/bin/bash
#colours
Blue='\033[0;34m'
White='\033[0;37m'
Green='\033[0;32m'
Red='\033[0;31m'
Yellow='\033[0;33m'
#functions
panel() {
    mkdir /var/www
    cd /var/www/
    git clone https://github.com/AirlinkLabs/panel.git
    cd panel
    sudo chown -R www-data:www-data /var/www/panel
    sudo chmod -R 755 /var/www/panel
    cp example.env .env
    npm install --production
    npm run migrate:dev
    npm run build-ts
    echo -e "${Red}---------------------------------------------${White}"
    echo -e "panel install done!"
}
daemon() {
    cd /etc/
    git clone https://github.com/AirlinkLabs/daemon.git
    cd daemon
    sudo chown -R www-data:www-data /etc/daemon
    sudo chmod -R 755 /etc/daemon
    cp example.env .env
    npm install
    npm run build
    echo -e "${Red}---------------------------------------------${White}"
    echo -e "daemon install done!"
}
panel-depends() {
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" |  tee /etc/apt/sources.list.d/nodesource.list
    apt update
    apt install -y nodejs npm git
    npm install -g typescript
    
}
daemon-depends() {
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" |  tee /etc/apt/sources.list.d/nodesource.list
    apt update
    apt install -y nodejs npm git
    npm install -g typescript
    
}
dependencies() {
    panel-depends
    daemon-depends
}
rm-panel() {
    cd /var/www
    rm -rf panel
}
rm-daemon() {
    cd /etc
    rm -rf daemon
}
rm-dependencies() {
if command -v docker &> /dev/null; then
    apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    rm -f /etc/apt/sources.list.d/docker.list
fi
if command -v node &> /dev/null; then
    apt-get remove -y nodejs git
    rm -f /etc/apt/sources.list.d/nodesource.list
fi
rm -f /etc/apt/keyrings/docker.gpg
rm -f /etc/apt/keyrings/nodesource.gpg
apt-get autoremove -y
apt-get autoclean
apt-get update
echo "Uninstallation of Docker and Node.js is complete."
}
##ui
greet() {
echo -e " ${Blue}----${Green}INSTALLER HOME${Yellow}--------${White}"
echo -e " ${Blue}    ___  _                _                ${White}"
echo -e " ${Blue}   / _ \(_)     _(_)     | |               ${White}"
echo -e " ${Blue}  / /_\ \ \_ _ | |_ _ __ | | __            ${White}"
echo -e " ${Blue}  |  _  | | '__| | | '_ \| |/ /            ${White}"
echo -e " ${Blue}  | | | | | |  | | | | | |   <             ${White}"
echo -e " ${Blue}  \_| |_/_|_|  |_|_|_| |_|_|\_\            ${White}"
echo -e " ${Blue}                                           ${White}"
echo -e " ${Blue}airlink${White} asm software installer!            "
echo -e " panel and daemon by ${Blue}airlinklabs${White} © ${White}"
echo -e " install script by ${Green}G-flame!${White}" 
}


root() {
    if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run with root account or use sudo to start the script!${NC}"
    exit 1
fi 
}
ui() {
    root
    greet
    echo -e "1)${Green}install ${Blue}panel and daemon${White}(dependencies too)!"
    echo -e "2)${Green}install ${Blue}panel${White} only!"
    echo -e "3)${Green}install ${Blue}daemon${White} only!"
    echo -e "4)${Green}install ${Blue}dependencies${White} (both panel and daemon depends!)only!"
    echo -e "5)${Red}remove ${Blue}panel and daemon!${White}!"
    echo -e "6)${Red}remove ${Blue}panel${White} only!"
    echo -e "7)${Red}remove ${Blue}daemon${White} only!"
    echo -e "8)${Red}remove ${Blue}dependencies${White} only !"
    echo -e "9)${Red}exit${White} installer!"
    read -p "what do you want to do ? [1-9]: " choice
    #choice outputs
    case $choice in
    1)
        dependencies
        panel
        daemon
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    2)
        panel-depends
        panel 
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    3)
        daemon-depends
        daemon
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    4)
        dependencies
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    5)
        rm-panel
        rm-daemon
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    6)
        rm-panel
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    7)
        rm-daemon
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    8)
        rm-dependencies
        echo -e "${Yellow}-_--_--_--_--_--_-${Green}Log End${Yellow}-_--_--_--_--_--_--_--_--_-${White}"
        ui
        echo "completed!"
        ;;
    9)
        echo "bye !"
        exit
        ;;
   *)
        echo -e "\n${RED}thats not an option !${White}"
        ui
        ;;
    esac

    echo -e "\nPress Enter to continue..."
    read
}
##EXECUTING 
clear
ui
## i know my code is shit don't rub salt in the wound 


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

# Installation functions
panel_depends() {
    echo -e "${GREEN}Installing panel dependencies...${NC}"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt update
    apt install -y nodejs npm git
    npm install -g typescript
    echo -e "${GREEN}Panel dependencies installed successfully!${NC}"
}

daemon_depends() {
    echo -e "${GREEN}Installing daemon dependencies...${NC}"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt update
    apt install -y nodejs npm git
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

tip-panel() {
    clear
    echo -e "${Yellow}----------------------------------------------------${White}"
    echo -e "${Yellow}|${Red}Your panel has been started visit localhost:3000  ${Yellow}|${White}"
    echo -e "${Yellow}----------------------------------------------------${White}"
}

tip-daemon() {
    clear
    echo -e "${Yellow}-----------------------------------------------------${White}"
    echo -e "${Yellow}|${Red}Your daemon has been started visit localhost:3002  ${Yellow}|${White}"
    echo -e "${Yellow}-----------------------------------------------------${White}"
}

tip-both() {
    clear
    echo -e "${Yellow}-----------------------------------------------------${White}"
    echo -e "${Yellow}|${Red}Your panel has been started visit localhost:3000  ${Yellow} |${White}"
    echo -e "${Yellow}|${Red}Your daemon has been started visit localhost:3002  ${Yellow}|${White}"
    echo -e "${Yellow}-----------------------------------------------------${White}"
}

# Install both dependencies
install_dependencies() {
    panel_depends
    daemon_depends
}

# Display ASCII art logo
display_logo() {
echo -e " ${Blue}----${Green}INSTALLER HOME${Yellow}--------${White}"
echo -e " ${Blue}    ___  _                _                ${White}"
echo -e " ${Blue}   / _ \(_)     _(_)     | |               ${White}"
echo -e " ${Blue}  / /_\ \ \_ _ | |_ _ __ | | __            ${White}"
echo -e " ${Blue}  |  _  | | '__| | | '_ \| |/ /            ${White}"
echo -e " ${Blue}  | | | | | |  | | | | | |   <             ${White}"
echo -e " ${Blue}  \_| |_/_|_|  |_|_|_| |_|_|\_\            ${White}"
echo -e " ${Blue}                                           ${White}"
echo -e " ${Blue}airlink${White} asm software installer!            "
echo -e " panel and daemon by ${Blue}airlinklabs${White} © ${White}"
echo -e " install script by ${Green}G-flame!${White}" 
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
            ;;
        2)
            panel_depends
            install_panel
            ;;
        3)
            daemon_depends
            install_daemon
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