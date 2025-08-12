#!/bin/bash

##########################################################################################
#       Universal Airlink Installer by G-flame @ https://github.com/g-flame              #
#       Panel and Daemon by Airlinklabs @ https://github.com/airlinklabs                 #
#                                                                                        #
#       MIT License                                                                      #
#                                                                                        #
#       Copyright (c) 2025 G-flame-OSS                                                   #
#                                                                                        #
#       Permission is hereby granted, free of charge, to any person obtaining a copy     #
#       of this software and associated documentation files (the "Software"), to deal    #
#       in the Software without restriction, including without limitation the rights     #
#       to use, copy, modify, merge, publish, distribute, sublicense, and/or sell        #
#       copies of the Software, and to permit persons to whom the Software is            #
#       furnished to do so, subject to the following conditions:                         #
#                                                                                        #
#       The above copyright notice and this permission notice shall be included in all   #
#       copies or substantial portions of the Software.                                  #
#                                                                                        #
#       THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR       #
#       IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,         #
#       FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE      #
#       AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER           #
#       LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,    #
#       OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE    #
#       SOFTWARE.                                                                        #
##########################################################################################

set -euo pipefail

# Global variables
SCRIPT_VERSION="2.0.0"
LOG_FILE="/tmp/airlink-installer.log"
NODE_VERSION="20"
INSTALLER_DIR="/tmp/Airlink-installer"
DIALOG_HEIGHT=20
DIALOG_WIDTH=70

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
    log "INFO: $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    log "SUCCESS: $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    log "WARNING: $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    log "ERROR: $*"
}

# Progress bar function
show_progress() {
    local duration=$1
    local message=$2
    local progress=0
    local bar_length=50
    
    echo -e "${CYAN}${message}${NC}"
    while [ $progress -le $duration ]; do
        local filled=$((progress * bar_length / duration))
        local empty=$((bar_length - filled))
        
        printf "\r${GREEN}["
        printf "%0.s#" $(seq 1 $filled)
        printf "%0.s-" $(seq 1 $empty)
        printf "] %d%%${NC}" $((progress * 100 / duration))
        
        sleep 0.1
        ((progress++))
    done
    echo
}

# System detection
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    else
        log_error "Cannot detect operating system"
        exit 1
    fi
    
    case "$OS" in
        ubuntu|debian|linuxmint|elementary|pop)
            DISTRO_FAMILY="debian"
            PKG_MANAGER="apt"
            ;;
        fedora|centos|rhel|rocky|almalinux)
            DISTRO_FAMILY="redhat"
            PKG_MANAGER="yum"
            command -v dnf >/dev/null 2>&1 && PKG_MANAGER="dnf"
            ;;
        opensuse|sles)
            DISTRO_FAMILY="opensuse"
            PKG_MANAGER="zypper"
            ;;
        arch|manjaro|endeavouros)
            DISTRO_FAMILY="arch"
            PKG_MANAGER="pacman"
            ;;
        alpine)
            DISTRO_FAMILY="alpine"
            PKG_MANAGER="apk"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    log_info "Detected OS: $OS ($DISTRO_FAMILY family)"
}

# Check dependencies
check_dependencies() {
    local deps=("curl" "wget" "dialog")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        install_basic_dependencies "${missing_deps[@]}"
    fi
}

# Install basic dependencies based on distro
install_basic_dependencies() {
    local deps=("$@")
    
    log_info "Installing basic dependencies: ${deps[*]}"
    
    case "$DISTRO_FAMILY" in
        debian)
            apt-get update >/dev/null 2>&1
            apt-get install -y "${deps[@]}" >/dev/null 2>&1
            ;;
        redhat)
            $PKG_MANAGER install -y "${deps[@]}" >/dev/null 2>&1
            ;;
        opensuse)
            zypper install -y "${deps[@]}" >/dev/null 2>&1
            ;;
        arch)
            pacman -Sy --noconfirm "${deps[@]}" >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache "${deps[@]}" >/dev/null 2>&1
            ;;
    esac
}

# Root check
check_root() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Permission Error" --msgbox "This script must be run as root or with sudo privileges." 8 50
        exit 1
    fi
}

# Repository connectivity check
check_repository() {
    log_info "Checking repository connectivity..."
    
    if git ls-remote https://github.com/airlinklabs/panel.git -q >/dev/null 2>&1; then
        return 0
    else
        log_warning "Primary repository unreachable, using fallback"
        return 1
    fi
}

# Node.js installation function
install_nodejs() {
    log_info "Installing Node.js $NODE_VERSION..."
    
    # Remove existing installations
    remove_existing_nodejs
    
    case "$DISTRO_FAMILY" in
        debian)
            install_nodejs_debian
            ;;
        redhat)
            install_nodejs_redhat
            ;;
        opensuse)
            install_nodejs_opensuse
            ;;
        arch)
            install_nodejs_arch
            ;;
        alpine)
            install_nodejs_alpine
            ;;
    esac
    
    verify_nodejs_installation
}

remove_existing_nodejs() {
    log_info "Removing existing Node.js installations..."
    
    case "$DISTRO_FAMILY" in
        debian)
            apt-get remove -y nodejs npm >/dev/null 2>&1 || true
            rm -f /etc/apt/sources.list.d/nodesource.list
            rm -f /etc/apt/keyrings/nodesource.gpg
            ;;
        redhat)
            $PKG_MANAGER remove -y nodejs npm >/dev/null 2>&1 || true
            ;;
        opensuse)
            zypper remove -y nodejs20 npm20 >/dev/null 2>&1 || true
            ;;
        arch)
            pacman -R --noconfirm nodejs npm >/dev/null 2>&1 || true
            ;;
        alpine)
            apk del nodejs npm >/dev/null 2>&1 || true
            ;;
    esac
}

install_nodejs_debian() {
    # Install Node.js via NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - >/dev/null 2>&1
    apt-get install -y nodejs >/dev/null 2>&1
}

install_nodejs_redhat() {
    # Install Node.js via NodeSource repository
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash - >/dev/null 2>&1
    $PKG_MANAGER install -y nodejs >/dev/null 2>&1
}

install_nodejs_opensuse() {
    # Install Node.js from official repositories
    zypper install -y nodejs${NODE_VERSION} npm${NODE_VERSION} >/dev/null 2>&1
}

install_nodejs_arch() {
    # Install Node.js from official repositories
    pacman -Sy --noconfirm nodejs npm >/dev/null 2>&1
}

install_nodejs_alpine() {
    # Install Node.js from official repositories
    apk add --no-cache nodejs npm >/dev/null 2>&1
}

verify_nodejs_installation() {
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local node_ver=$(node -v)
        local npm_ver=$(npm -v)
        log_success "Node.js $node_ver and npm $npm_ver installed successfully"
        
        # Install TypeScript globally
        npm install -g typescript >/dev/null 2>&1
        log_success "TypeScript installed globally"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
}

# Docker installation function
install_docker() {
    log_info "Installing Docker..."
    
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker is already installed"
        return 0
    fi
    
    case "$DISTRO_FAMILY" in
        debian|redhat|opensuse)
            curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
            ;;
        arch)
            pacman -Sy --noconfirm docker >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache docker >/dev/null 2>&1
            ;;
    esac
    
    # Enable and start Docker service
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker >/dev/null 2>&1
    
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker installed and started successfully"
    else
        log_error "Docker installation failed"
        exit 1
    fi
}

# Git installation function
install_git() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi
    
    log_info "Installing Git..."
    
    case "$DISTRO_FAMILY" in
        debian)
            apt-get install -y git >/dev/null 2>&1
            ;;
        redhat)
            $PKG_MANAGER install -y git >/dev/null 2>&1
            ;;
        opensuse)
            zypper install -y git >/dev/null 2>&1
            ;;
        arch)
            pacman -Sy --noconfirm git >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache git >/dev/null 2>&1
            ;;
    esac
    
    log_success "Git installed successfully"
}

# Panel installation function
install_panel() {
    local use_fallback=${1:-false}
    local repo_url="https://github.com/airlinklabs/panel.git"
    
    if [[ "$use_fallback" == "true" ]]; then
        repo_url="https://github.com/g-flame/airlink-panel-fork.git"
    fi
    
    log_info "Installing Airlink Panel..."
    
    # Verify prerequisites
    verify_prerequisites
    
    # Create directory and clone repository
    mkdir -p /var/www
    cd /var/www || { log_error "Failed to change to /var/www"; exit 1; }
    
    # Remove existing installation
    if [[ -d "/var/www/panel" ]]; then
        log_warning "Removing existing panel installation"
        rm -rf /var/www/panel
    fi
    
    # Clone repository
    show_progress 20 "Cloning panel repository..." &
    PROGRESS_PID=$!
    
    if ! git clone "$repo_url" panel >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to clone panel repository"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    cd panel || { log_error "Failed to enter panel directory"; exit 1; }
    
    # Set permissions
    chown -R www-data:www-data /var/www/panel 2>/dev/null || chown -R root:root /var/www/panel
    chmod -R 755 /var/www/panel
    
    # Setup environment
    if [[ -f "example.env" ]]; then
        cp example.env .env
    else
        log_error "example.env file not found"
        exit 1
    fi
    
    # Install dependencies
    show_progress 30 "Installing panel dependencies..." &
    PROGRESS_PID=$!
    
    if ! npm install --production >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to install panel dependencies"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    # Run migrations
    show_progress 15 "Running database migrations..." &
    PROGRESS_PID=$!
    
    if ! npm run migrate:dev >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to run database migrations"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    # Build TypeScript
    show_progress 25 "Building TypeScript files..." &
    PROGRESS_PID=$!
    
    if ! npm run build-ts >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to build TypeScript files"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    # Create systemd service
    create_panel_service
    
    # Start and enable service
    systemctl daemon-reload
    systemctl enable airlink-panel.service >/dev/null 2>&1
    systemctl start airlink-panel.service >/dev/null 2>&1
    
    if systemctl is-active --quiet airlink-panel.service; then
        log_success "Panel installed and started successfully"
    else
        log_error "Panel service failed to start. Check logs: journalctl -u airlink-panel.service"
        exit 1
    fi
}

# Daemon installation function
install_daemon() {
    local use_fallback=${1:-false}
    local repo_url="https://github.com/airlinklabs/daemon.git"
    
    if [[ "$use_fallback" == "true" ]]; then
        repo_url="https://github.com/g-flame/airlink-daemon-fork.git"
    fi
    
    log_info "Installing Airlink Daemon..."
    
    # Verify prerequisites
    verify_prerequisites
    install_docker
    
    # Create directory and clone repository
    cd /etc || { log_error "Failed to change to /etc"; exit 1; }
    
    # Remove existing installation
    if [[ -d "/etc/daemon" ]]; then
        log_warning "Removing existing daemon installation"
        rm -rf /etc/daemon
    fi
    
    # Clone repository
    show_progress 20 "Cloning daemon repository..." &
    PROGRESS_PID=$!
    
    if ! git clone "$repo_url" daemon >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to clone daemon repository"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    cd daemon || { log_error "Failed to enter daemon directory"; exit 1; }
    
    # Set permissions
    chown -R www-data:www-data /etc/daemon 2>/dev/null || chown -R root:root /etc/daemon
    chmod -R 755 /etc/daemon
    
    # Setup environment
    if [[ -f "example.env" ]]; then
        cp example.env .env
    else
        log_error "example.env file not found"
        exit 1
    fi
    
    # Install dependencies
    show_progress 30 "Installing daemon dependencies..." &
    PROGRESS_PID=$!
    
    if ! npm install >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to install daemon dependencies"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    # Build daemon
    show_progress 20 "Building daemon..." &
    PROGRESS_PID=$!
    
    if ! npm run build >/dev/null 2>&1; then
        kill $PROGRESS_PID 2>/dev/null || true
        log_error "Failed to build daemon"
        exit 1
    fi
    
    kill $PROGRESS_PID 2>/dev/null || true
    
    # Create systemd service
    create_daemon_service
    
    # Start and enable service
    systemctl daemon-reload
    systemctl enable airlink-daemon.service >/dev/null 2>&1
    systemctl start airlink-daemon.service >/dev/null 2>&1
    
    if systemctl is-active --quiet airlink-daemon.service; then
        log_success "Daemon installed and started successfully"
    else
        log_error "Daemon service failed to start. Check logs: journalctl -u airlink-daemon.service"
        exit 1
    fi
}

# Service creation functions
create_panel_service() {
    cat > /etc/systemd/system/airlink-panel.service << EOF
[Unit]
Description=Airlink Panel Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
WorkingDirectory=/var/www/panel
ExecStart=/usr/bin/npm start
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
}

create_daemon_service() {
    cat > /etc/systemd/system/airlink-daemon.service << EOF
[Unit]
Description=Airlink Daemon Service
After=network.target docker.service
Requires=docker.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
WorkingDirectory=/etc/daemon
ExecStart=/usr/bin/npm run start
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
}

# Prerequisite verification
verify_prerequisites() {
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        log_error "Node.js or npm not found. Installing..."
        install_nodejs
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        install_git
    fi
}

# Removal functions
remove_panel() {
    log_info "Removing Airlink Panel..."
    
    # Stop and disable service
    systemctl stop airlink-panel.service >/dev/null 2>&1 || true
    systemctl disable airlink-panel.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/airlink-panel.service
    systemctl daemon-reload
    
    # Remove files
    if [[ -d "/var/www/panel" ]]; then
        rm -rf /var/www/panel
        log_success "Panel removed successfully"
    else
        log_warning "Panel installation not found"
    fi
}

remove_daemon() {
    log_info "Removing Airlink Daemon..."
    
    # Stop and disable service
    systemctl stop airlink-daemon.service >/dev/null 2>&1 || true
    systemctl disable airlink-daemon.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/airlink-daemon.service
    systemctl daemon-reload
    
    # Remove files
    if [[ -d "/etc/daemon" ]]; then
        rm -rf /etc/daemon
        log_success "Daemon removed successfully"
    else
        log_warning "Daemon installation not found"
    fi
}

remove_dependencies() {
    log_info "Removing dependencies..."
    
    # Remove Docker
    if command -v docker >/dev/null 2>&1; then
        log_info "Removing Docker..."
        systemctl stop docker >/dev/null 2>&1 || true
        systemctl disable docker >/dev/null 2>&1 || true
        
        case "$DISTRO_FAMILY" in
            debian)
                apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 || true
                rm -f /etc/apt/sources.list.d/docker.list
                rm -f /etc/apt/keyrings/docker.gpg
                ;;
            redhat)
                $PKG_MANAGER remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 || true
                ;;
            arch)
                pacman -R --noconfirm docker >/dev/null 2>&1 || true
                ;;
            alpine)
                apk del docker >/dev/null 2>&1 || true
                ;;
        esac
    fi
    
    # Remove Node.js
    if command -v node >/dev/null 2>&1; then
        log_info "Removing Node.js..."
        npm uninstall -g typescript >/dev/null 2>&1 || true
        remove_existing_nodejs
    fi
    
    # Clean up package cache
    case "$DISTRO_FAMILY" in
        debian)
            apt-get autoremove -y >/dev/null 2>&1
            apt-get autoclean >/dev/null 2>&1
            ;;
        redhat)
            $PKG_MANAGER autoremove -y >/dev/null 2>&1 || true
            ;;
        arch)
            pacman -Rns --noconfirm $(pacman -Qtdq) >/dev/null 2>&1 || true
            ;;
    esac
    
    log_success "Dependencies removed successfully"
}

# Display functions
display_logo() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "    ╔══════════════════════════════════════════════════════════════╗"
    echo "    ║                    AIRLINK INSTALLER v${SCRIPT_VERSION}                  ║"
    echo "    ╠══════════════════════════════════════════════════════════════╣"
    echo "    ║      ___  _      _ _       _                                  ║"
    echo "    ║     / _ \\(_)_ __| (_)_ __ | | __                              ║"
    echo "    ║    / /_\\ / | '__| | | '_ \\| |/ /                              ║"
    echo "    ║    |  _  | | |  | | | | | |   <                               ║"
    echo "    ║    | | | |_| |  |_|_|_| |_|_|\\_\\                              ║"
    echo "    ║                                                              ║"
    echo "    ╠══════════════════════════════════════════════════════════════╣"
    echo -e "    ║  ${GREEN}Panel and Daemon by ${CYAN}Airlinklabs${BLUE} © MIT License           ║"
    echo -e "    ║  ${GREEN}Universal Installer by ${YELLOW}G-flame${BLUE}                        ║"
    echo -e "    ║  ${PURPLE}Detected: $OS ($DISTRO_FAMILY)${BLUE}                               ║"
    echo "    ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_completion_message() {
    local service_type="$1"
    local port="$2"
    
    dialog --title "Installation Complete" \
           --msgbox "Airlink $service_type has been installed successfully!\n\nAccess it at: http://localhost:$port\n\nService status: systemctl status airlink-$service_type.service\nLogs: journalctl -u airlink-$service_type.service" \
           12 60
}

# Main menu function
show_main_menu() {
    local use_fallback=${1:-false}
    local repo_status="Primary"
    
    if [[ "$use_fallback" == "true" ]]; then
        repo_status="Fallback"
    fi
    
    while true; do
        display_logo
        
        choice=$(dialog --clear --title "Airlink Installer - $repo_status Repositories" \
                       --menu "Choose an installation option:" \
                       $DIALOG_HEIGHT $DIALOG_WIDTH 12 \
                       1 "Install Panel + Daemon (Full Stack)" \
                       2 "Install Panel Only" \
                       3 "Install Daemon Only" \
                       4 "Install Dependencies Only" \
                       5 "Remove Panel + Daemon" \
                       6 "Remove Panel Only" \
                       7 "Remove Daemon Only" \
                       8 "Remove Dependencies Only" \
                       9 "Remove Everything" \
                       10 "View System Information" \
                       11 "View Installation Logs" \
                       0 "Exit" 3>&1 1>&2 2>&3)
        
        case $choice in
            1)
                dialog --title "Full Installation" --infobox "Installing Panel and Daemon with dependencies..." 5 50
                install_nodejs
                install_git
                install_panel "$use_fallback"
                install_daemon "$use_fallback"
                show_completion_message "panel" "3000"
                dialog --title "Installation Complete" --msgbox "Both Panel (port 3000) and Daemon (port 3002) are now running!" 8 50
                ;;
            2)
                dialog --title "Panel Installation" --infobox "Installing Panel with dependencies..." 5 50
                install_nodejs
                install_git
                install_panel "$use_fallback"
                show_completion_message "panel" "3000"
                ;;
            3)
                dialog --title "Daemon Installation" --infobox "Installing Daemon with dependencies..." 5 50
                install_nodejs
                install_git
                install_daemon "$use_fallback"
                show_completion_message "daemon" "3002"
                ;;
            4)
                dialog --title "Dependencies Installation" --infobox "Installing all dependencies..." 5 50
                install_nodejs
                install_git
                install_docker
                dialog --title "Success" --msgbox "All dependencies installed successfully!" 6 40
                ;;
            5)
                dialog --title "Removal" --yesno "Remove both Panel and Daemon?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_panel
                    remove_daemon
                    dialog --title "Success" --msgbox "Panel and Daemon removed successfully!" 6 40
                fi
                ;;
            6)
                dialog --title "Removal" --yesno "Remove Panel only?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_panel
                    dialog --title "Success" --msgbox "Panel removed successfully!" 6 40
                fi
                ;;
            7)
                dialog --title "Removal" --yesno "Remove Daemon only?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_daemon
                    dialog --title "Success" --msgbox "Daemon removed successfully!" 6 40
                fi
                ;;
            8)
                dialog --title "Removal" --yesno "Remove all dependencies?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_dependencies
                    dialog --title "Success" --msgbox "Dependencies removed successfully!" 6 40
                fi
                ;;
            9)
                dialog --title "Complete Removal" --yesno "Remove EVERYTHING (Panel, Daemon, and Dependencies)?" 8 50
                if [[ $? -eq 0 ]]; then
                    remove_panel
                    remove_daemon
                    remove_dependencies
                    dialog --title "Success" --msgbox "Everything removed successfully!" 6 40
                fi
                ;;
            10)
                show_system_info
                ;;
            11)
                show_logs
                ;;
            0)
                dialog --title "Exit" --yesno "Are you sure you want to exit?" 6 40
                if [[ $? -eq 0 ]]; then
                    clear
                    log_info "Installer exited by user"
                    echo -e "${GREEN}Thank you for using the Airlink Installer!${NC}"
                    exit 0
                fi
                ;;
            *)
                dialog --title "Error" --msgbox "Invalid selection. Please try again." 6 40
                ;;
        esac
    done
}

show_system_info() {
    local node_version="Not installed"
    local npm_version="Not installed"
    local docker_version="Not installed"
    local git_version="Not installed"
    
    command -v node >/dev/null 2>&1 && node_version=$(node -v)
    command -v npm >/dev/null 2>&1 && npm_version=$(npm -v)
    command -v docker >/dev/null 2>&1 && docker_version=$(docker -v | cut -d' ' -f3 | sed 's/,//')
    command -v git >/dev/null 2>&1 && git_version=$(git --version | cut -d' ' -f3)
    
    dialog --title "System Information" \
           --msgbox "Operating System: $OS $OS_VERSION
Distribution Family: $DISTRO_FAMILY
Package Manager: $PKG_MANAGER

Installed Components:
- Node.js: $node_version
- npm: $npm_version
- Docker: $docker_version
- Git: $git_version

Services Status:
- Panel: $(systemctl is-active airlink-panel.service 2>/dev/null || echo 'not installed')
- Daemon: $(systemctl is-active airlink-daemon.service 2>/dev/null || echo 'not installed')" \
           18 70
}

show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        dialog --title "Installation Logs" --textbox "$LOG_FILE" 20 80
    else
        dialog --title "No Logs" --msgbox "No installation logs found." 6 30
    fi
}

# Service management functions
check_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

restart_services() {
    local services=("$@")
    for service in "${services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_info "Restarting $service..."
            systemctl restart "$service"
            if check_service_status "$service"; then
                log_success "$service restarted successfully"
            else
                log_error "$service failed to restart"
            fi
        fi
    done
}

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    
    # Remove temporary files
    rm -rf /tmp/node-*
    rm -rf /tmp/npm-*
    
    # Clear package manager cache based on distro
    case "$DISTRO_FAMILY" in
        debian)
            apt-get clean >/dev/null 2>&1
            ;;
        redhat)
            $PKG_MANAGER clean all >/dev/null 2>&1
            ;;
        arch)
            pacman -Sc --noconfirm >/dev/null 2>&1
            ;;
        alpine)
            apk cache clean >/dev/null 2>&1
            ;;
    esac
    
    log_success "Cleanup completed"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "An error occurred on line $line_number with exit code $exit_code"
    
    dialog --title "Error Occurred" \
           --msgbox "An error occurred during installation.\nCheck the logs for more details: $LOG_FILE\n\nLine: $line_number\nExit Code: $exit_code" \
           10 50
    
    cleanup
    exit $exit_code
}

# Trap for error handling
trap 'handle_error $LINENO' ERR

# Signal handling
handle_interrupt() {
    log_warning "Installation interrupted by user"
    dialog --title "Interrupted" --msgbox "Installation was interrupted. Cleaning up..." 6 40
    cleanup
    clear
    exit 1
}

trap handle_interrupt INT TERM

# Update check function
check_for_updates() {
    local current_version="$SCRIPT_VERSION"
    local latest_version
    
    log_info "Checking for installer updates..."
    
    # Try to fetch the latest version from GitHub
    if latest_version=$(curl -s https://api.github.com/repos/g-flame/airlink-installer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")' 2>/dev/null); then
        if [[ "$latest_version" != "$current_version" ]]; then
            dialog --title "Update Available" \
                   --yesno "A newer version of the installer is available:\nCurrent: $current_version\nLatest: $latest_version\n\nWould you like to download it?" \
                   10 50
            
            if [[ $? -eq 0 ]]; then
                log_info "User chose to update installer"
                dialog --title "Update" --msgbox "Please visit https://github.com/g-flame/airlink-installer to download the latest version." 8 60
            fi
        else
            log_info "Installer is up to date"
        fi
    else
        log_warning "Could not check for updates"
    fi
}

# Backup and restore functions
create_backup() {
    local component="$1"
    local backup_dir="/tmp/airlink-backup-$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating backup of $component..."
    mkdir -p "$backup_dir"
    
    case "$component" in
        panel)
            if [[ -d "/var/www/panel" ]]; then
                cp -r /var/www/panel "$backup_dir/"
                log_success "Panel backup created at $backup_dir"
            fi
            ;;
        daemon)
            if [[ -d "/etc/daemon" ]]; then
                cp -r /etc/daemon "$backup_dir/"
                log_success "Daemon backup created at $backup_dir"
            fi
            ;;
        both)
            [[ -d "/var/www/panel" ]] && cp -r /var/www/panel "$backup_dir/"
            [[ -d "/etc/daemon" ]] && cp -r /etc/daemon "$backup_dir/"
            log_success "Full backup created at $backup_dir"
            ;;
    esac
    
    echo "$backup_dir" > /tmp/airlink-last-backup
}

# Configuration validation
validate_installation() {
    local component="$1"
    local errors=()
    
    log_info "Validating $component installation..."
    
    case "$component" in
        panel)
            [[ ! -d "/var/www/panel" ]] && errors+=("Panel directory not found")
            [[ ! -f "/var/www/panel/.env" ]] && errors+=("Panel configuration missing")
            [[ ! -f "/etc/systemd/system/airlink-panel.service" ]] && errors+=("Panel service not found")
            ! check_service_status "airlink-panel.service" && errors+=("Panel service not running")
            ;;
        daemon)
            [[ ! -d "/etc/daemon" ]] && errors+=("Daemon directory not found")
            [[ ! -f "/etc/daemon/.env" ]] && errors+=("Daemon configuration missing")
            [[ ! -f "/etc/systemd/system/airlink-daemon.service" ]] && errors+=("Daemon service not found")
            ! check_service_status "airlink-daemon.service" && errors+=("Daemon service not running")
            ! command -v docker >/dev/null 2>&1 && errors+=("Docker not available")
            ;;
    esac
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        log_success "$component validation passed"
        return 0
    else
        log_error "$component validation failed:"
        printf '%s\n' "${errors[@]}" | while read -r error; do
            log_error "  - $error"
        done
        return 1
    fi
}

# Port availability check
check_port_availability() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":$port " && return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -q ":$port " && return 1
    fi
    return 0
}

# Pre-installation checks
pre_installation_check() {
    log_info "Running pre-installation checks..."
    
    # Check available disk space (minimum 2GB)
    local available_space=$(df /var 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [[ $available_space -lt 2097152 ]]; then
        dialog --title "Insufficient Space" --msgbox "Insufficient disk space. At least 2GB required in /var directory." 8 50
        exit 1
    fi
    
    # Check if ports are available
    local ports_in_use=()
    ! check_port_availability 3000 && ports_in_use+=("3000 (Panel)")
    ! check_port_availability 3002 && ports_in_use+=("3002 (Daemon)")
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        local port_list=""
        for port in "${ports_in_use[@]}"; do
            port_list="$port_list\n- $port"
        done
        
        dialog --title "Ports in Use" \
               --yesno "The following ports are already in use:$port_list\n\nContinue anyway?" \
               10 50
        
        [[ $? -ne 0 ]] && exit 1
    fi
    
    log_success "Pre-installation checks passed"
}

# Main execution flow
main() {
    # Initialize logging
    touch "$LOG_FILE"
    log_info "Starting Airlink Installer v$SCRIPT_VERSION"
    
    # Check if running as root
    check_root
    
    # Detect operating system
    detect_os
    
    # Check and install basic dependencies
    check_dependencies
    
    # Check for updates
    check_for_updates
    
    # Run pre-installation checks
    pre_installation_check
    
    # Check repository connectivity
    if check_repository; then
        log_info "Using primary repositories"
        show_main_menu false
    else
        log_warning "Primary repositories unavailable, using fallback"
        dialog --title "Repository Notice" \
               --msgbox "Primary repositories are not accessible.\nUsing fallback repositories instead." \
               8 50
        show_main_menu true
    fi
}

# Version information
show_version() {
    echo "Airlink Universal Installer v$SCRIPT_VERSION"
    echo "Copyright (c) 2025 G-flame-OSS"
    echo "Licensed under MIT License"
}

# Help information
show_help() {
    cat << EOF
Airlink Universal Installer v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help       Show this help message
    -v, --version    Show version information
    --log-file FILE  Specify custom log file location
    --no-color       Disable colored output
    --debug          Enable debug mode

EXAMPLES:
    $0                    # Run interactive installer
    $0 --version          # Show version
    $0 --log-file /tmp/my.log  # Use custom log file

For more information, visit: https://github.com/g-flame/airlink-installer
EOF
}

# Command line argument handling
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --no-color)
            RED=''
            GREEN=''
            YELLOW=''
            BLUE=''
            PURPLE=''
            CYAN=''
            WHITE=''
            BOLD=''
            NC=''
            shift
            ;;
        --debug)
            set -x
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Start main execution
main
