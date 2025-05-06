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
    
    # Clean up any existing Node.js installations that might cause conflicts
    echo -e "${YELLOW}Cleaning up any existing Node.js installations...${NC}"
    apt-get remove -y nodejs nodejs-doc node-gyp npm
    apt-get autoremove -y
    
    # Clean up any existing repository configurations
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /etc/apt/keyrings/nodesource.gpg
    
    # Install NVM (Node Version Manager) which is more reliable for Node.js installation
    echo -e "${YELLOW}Installing Node.js 20.x using NVM method...${NC}"
    
    # Create temp directory for NVM installation
    mkdir -p ~/.nvm
    
    # Install NVM
    export NVM_DIR="$HOME/.nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Load NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Make NVM available in the current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install Node.js 20.x
    nvm install 20
    nvm use 20
    nvm alias default 20
    
    # Create global symlinks for system-wide access
    n=$(which node)
    n=${n%/bin/node}
    chmod -R 755 $n/bin/*
    sudo cp -r $n/{bin,lib,share} /usr/local/
    
    # Verify installation
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        echo -e "${GREEN}Successfully installed Node.js ${NODE_VERSION}${NC}"
        
        # Install npm if it's not installed
        if ! command -v npm &> /dev/null; then
            echo -e "${YELLOW}Installing npm...${NC}"
            apt-get update
            curl -L https://npmjs.org/install.sh | sh
        fi
        
        # Install git if it's not installed
        if ! command -v git &> /dev/null; then
            echo -e "${YELLOW}Installing git...${NC}"
            apt-get install -y git
        fi
    else
        echo -e "${RED}Failed to install Node.js using NVM. Trying alternative method...${NC}"
        
        # Try direct binary installation as a fallback
        echo -e "${YELLOW}Installing Node.js from direct binary...${NC}"
        cd /tmp
        
        # Get architecture
        ARCH=$(uname -m)
        
        if [ "$ARCH" = "x86_64" ]; then
            NODE_URL="https://nodejs.org/dist/v20.12.1/node-v20.12.1-linux-x64.tar.xz"
        elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            NODE_URL="https://nodejs.org/dist/v20.12.1/node-v20.12.1-linux-arm64.tar.xz"
        else
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            echo -e "${RED}Please install Node.js 20.x manually and try again.${NC}"
            return 1
        fi
        
        curl -O $NODE_URL
        tar -xf node-v20.12.1-linux-*.tar.xz
        cd node-v20.12.1-linux-*/
        cp -R bin/* /usr/local/bin/
        cp -R lib/* /usr/local/lib/
        cp -R include/* /usr/local/include/
        cp -R share/* /usr/local/share/
        
        # Verify installation
        if command -v node &> /dev/null; then
            NODE_VERSION=$(node -v)
            echo -e "${GREEN}Successfully installed Node.js ${NODE_VERSION} using direct binary method${NC}"
            
            # Install git if it's not installed
            if ! command -v git &> /dev/null; then
                echo -e "${YELLOW}Installing git...${NC}"
                apt-get install -y git
            fi
        else
            echo -e "${RED}Failed to install Node.js. Please install Node.js 20.x manually and try again.${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}Node.js setup complete.${NC}"
}

# Installation functions
panel_depends() {
    echo -e "${GREEN}Installing panel dependencies...${NC}"
    # Ensure Node.js is set up correctly first
    setup_nodejs
    
    # Check if npm command is available before proceeding
    if command -v npm &> /dev/null; then
        echo -e "${GREEN}Installing TypeScript globally...${NC}"
        npm install -g typescript
        echo -e "${GREEN}Panel dependencies installed successfully!${NC}"
    else
        echo -e "${RED}npm command not found. Panel dependencies installation failed.${NC}"
        echo -e "${YELLOW}Please ensure Node.js and npm are properly installed before continuing.${NC}"
        return 1
    fi
}

daemon_depends() {
    echo -e "${GREEN}Installing daemon dependencies...${NC}"
    # Ensure Node.js is set up correctly first
    setup_nodejs
    
    # Install Docker
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    
    # Check if npm command is available before proceeding
    if command -v npm &> /dev/null; then
        echo -e "${GREEN}Installing TypeScript globally...${NC}"
        npm install -g typescript
        echo -e "${GREEN}Daemon dependencies installed successfully!${NC}"
    else
        echo -e "${RED}npm command not found. Daemon dependencies installation incomplete.${NC}"
        echo -e "${YELLOW}Docker was installed, but TypeScript installation failed.${NC}"
        echo -e "${YELLOW}Please ensure Node.js and npm are properly installed before continuing.${NC}"
        return 1
    fi
}

install_panel() {
    echo -e "${GREEN}Installing panel...${NC}"
    
    # Verify Node.js and npm are properly installed before continuing
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo -e "${RED}Node.js or npm is not installed properly. Cannot continue with panel installation.${NC}"
        echo -e "${YELLOW}Please ensure Node.js and npm are correctly installed before proceeding.${NC}"
        return 1
    fi
    
    mkdir -p /var/www
    cd /var/www/ || { echo -e "${RED}Failed to change directory to /var/www/${NC}"; return 1; }
    
    # Check if panel directory already exists
    if [ -d "/var/www/panel" ]; then
        echo -e "${YELLOW}Panel directory already exists. Removing it before installation...${NC}"
        rm -rf /var/www/panel
    fi
    
    # Clone repository with error handling
    if ! git clone https://github.com/AirlinkLabs/panel.git; then
        echo -e "${RED}Failed to clone panel repository. Please check your internet connection.${NC}"
        return 1
    fi
    
    cd panel || { echo -e "${RED}Failed to change directory to panel${NC}"; return 1; }
    sudo chown -R www-data:www-data /var/www/panel
    sudo chmod -R 755 /var/www/panel
    
    if [ -f "example.env" ]; then
        cp example.env .env
    else
        echo -e "${RED}example.env file not found!${NC}"
        return 1
    fi
    
    # Install dependencies with error handling
    echo -e "${YELLOW}Installing panel dependencies...${NC}"
    if ! npm install --production; then
        echo -e "${RED}Failed to install panel dependencies. Please check npm and Node.js setup.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running database migrations...${NC}"
    if ! npm run migrate:dev; then
        echo -e "${RED}Failed to run database migrations.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Building TypeScript files...${NC}"
    if ! npm run build-ts; then
        echo -e "${RED}Failed to build TypeScript files.${NC}"
        return 1
    fi
    
    # Check if service file exists before trying to move it
    if [ -f "/tmp/Airlink-installer/systemd/airlink-panel.service" ]; then
        mv /tmp/Airlink-installer/systemd/airlink-panel.service /etc/systemd/system/
    else
        echo -e "${RED}Service file not found at /tmp/Airlink-installer/systemd/airlink-panel.service${NC}"
        echo -e "${YELLOW}Creating a basic service file...${NC}"
        cat > /etc/systemd/system/airlink-panel.service << EOF
[Unit]
Description=Airlink Panel Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/panel
ExecStart=/usr/local/bin/node /var/www/panel/dist/index.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=airlink-panel

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    sudo systemctl daemon-reload
    sudo systemctl enable airlink-panel.service
    if ! sudo systemctl start airlink-panel.service; then
        echo -e "${RED}Failed to start airlink-panel service. Please check the logs with 'journalctl -u airlink-panel.service'${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Panel installation completed successfully!${NC}"
}

install_daemon() {
    echo -e "${GREEN}Installing daemon...${NC}"
    
    # Verify Node.js and npm are properly installed before continuing
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo -e "${RED}Node.js or npm is not installed properly. Cannot continue with daemon installation.${NC}"
        echo -e "${YELLOW}Please ensure Node.js and npm are correctly installed before proceeding.${NC}"
        return 1
    fi
    
    # Verify Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Attempting to install Docker...${NC}"
        if ! curl -sSL https://get.docker.com/ | CHANNEL=stable bash; then
            echo -e "${RED}Failed to install Docker. Please install Docker manually and try again.${NC}"
            return 1
        fi
    fi
    
    cd /etc/ || { echo -e "${RED}Failed to change directory to /etc/${NC}"; return 1; }
    
    # Check if daemon directory already exists
    if [ -d "/etc/daemon" ]; then
        echo -e "${YELLOW}Daemon directory already exists. Removing it before installation...${NC}"
        rm -rf /etc/daemon
    fi
    
    # Clone repository with error handling
    if ! git clone https://github.com/AirlinkLabs/daemon.git; then
        echo -e "${RED}Failed to clone daemon repository. Please check your internet connection.${NC}"
        return 1
    fi
    
    cd daemon || { echo -e "${RED}Failed to change directory to daemon${NC}"; return 1; }
    sudo chown -R www-data:www-data /etc/daemon
    sudo chmod -R 755 /etc/daemon
    
    if [ -f "example.env" ]; then
        cp example.env .env
    else
        echo -e "${RED}example.env file not found!${NC}"
        return 1
    fi
    
    # Install dependencies with error handling
    echo -e "${YELLOW}Installing daemon dependencies...${NC}"
    if ! npm install; then
        echo -e "${RED}Failed to install daemon dependencies. Please check npm and Node.js setup.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Building daemon...${NC}"
    if ! npm run build; then
        echo -e "${RED}Failed to build daemon.${NC}"
        return 1
    fi
    
    # Check if service file exists before trying to move it
    if [ -f "/tmp/Airlink-installer/systemd/airlink-daemon.service" ]; then
        mv /tmp/Airlink-installer/systemd/airlink-daemon.service /etc/systemd/system/
    else
        echo -e "${RED}Service file not found at /tmp/Airlink-installer/systemd/airlink-daemon.service${NC}"
        echo -e "${YELLOW}Creating a basic service file...${NC}"
        cat > /etc/systemd/system/airlink-daemon.service << EOF
[Unit]
Description=Airlink Daemon Service
After=network.target docker.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/etc/daemon
ExecStart=/usr/local/bin/node /etc/daemon/dist/index.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=airlink-daemon

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    sudo systemctl daemon-reload
    sudo systemctl enable airlink-daemon.service
    if ! sudo systemctl start airlink-daemon.service; then
        echo -e "${RED}Failed to start airlink-daemon service. Please check the logs with 'journalctl -u airlink-daemon.service'${NC}"
        return 1
    fi
    
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
echo ""
# Run initial Node.js setup but don't show the menu yet
clear
show_menu