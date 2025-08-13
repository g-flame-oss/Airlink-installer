#!/bin/bash

##########################################################################################
#       Universal Airlink Installer by G-flame @ https://github.com/g-flame              #
#       Panel and Daemon by Airlinklabs @ https://github.com/airlinklabs                 #
#       MIT License - Copyright (c) 2025 G-flame-OSS                                     #
##########################################################################################

set -euo pipefail

# Script basics
version="2.0.0"
logfile="/tmp/airlink-installer.log"
node_ver="20"
temp_dir="/tmp/Airlink-installer"
menu_height=20
menu_width=70

# Colors that make sense
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
white='\033[1;37m'
bold='\033[1m'
reset='\033[0m'

# Simple logging
write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$logfile"
}

say_info() {
    echo -e "${cyan}[INFO]${reset} $*"
    write_log "INFO: $*"
}

say_good() {
    echo -e "${green}[SUCCESS]${reset} $*"
    write_log "SUCCESS: $*"
}

say_warn() {
    echo -e "${yellow}[WARNING]${reset} $*"
    write_log "WARNING: $*"
}

say_error() {
    echo -e "${red}[ERROR]${reset} $*"
    write_log "ERROR: $*"
}

# Nice progress bar
show_progress() {
    local time=$1
    local msg=$2
    local current=0
    local bar_size=50
    
    echo -e "${cyan}${msg}${reset}"
    while [ $current -le $time ]; do
        local filled=$((current * bar_size / time))
        local empty=$((bar_size - filled))
        
        printf "\r${green}["
        printf "%0.s#" $(seq 1 $filled)
        printf "%0.s-" $(seq 1 $empty)
        printf "] %d%%${reset}" $((current * 100 / time))
        
        sleep 0.1
        ((current++))
    done
    echo
}

# Figure out what OS we're on
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        current_os=$ID
        os_version=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        current_os="rhel"
    elif [[ -f /etc/debian_version ]]; then
        current_os="debian"
    else
        say_error "Can't figure out what OS this is"
        exit 1
    fi
    
    case "$current_os" in
        ubuntu|debian|linuxmint|elementary|pop)
            os_family="debian"
            pkg_tool="apt"
            ;;
        fedora|centos|rhel|rocky|almalinux)
            os_family="redhat"
            pkg_tool="yum"
            command -v dnf >/dev/null 2>&1 && pkg_tool="dnf"
            ;;
        opensuse|sles)
            os_family="opensuse"
            pkg_tool="zypper"
            ;;
        arch|manjaro|endeavouros)
            os_family="arch"
            pkg_tool="pacman"
            ;;
        alpine)
            os_family="alpine"
            pkg_tool="apk"
            ;;
        *)
            say_error "Sorry, $current_os isn't supported yet"
            exit 1
            ;;
    esac
    
    say_info "Found: $current_os ($os_family family)"
}

# Check if we have what we need
check_basics() {
    local needed=("curl" "wget" "dialog")
    local missing=()
    
    for tool in "${needed[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        say_warn "Missing: ${missing[*]}"
        install_basics "${missing[@]}"
    fi
}

# Install the basic stuff we need
install_basics() {
    local tools=("$@")
    
    say_info "Installing basics: ${tools[*]}"
    
    case "$os_family" in
        debian)
            apt-get update >/dev/null 2>&1
            apt-get install -y "${tools[@]}" >/dev/null 2>&1
            ;;
        redhat)
            $pkg_tool install -y "${tools[@]}" >/dev/null 2>&1
            ;;
        opensuse)
            zypper install -y "${tools[@]}" >/dev/null 2>&1
            ;;
        arch)
            pacman -Sy --noconfirm "${tools[@]}" >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache "${tools[@]}" >/dev/null 2>&1
            ;;
    esac
}

# Make sure we're root
need_root() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Need Root" --msgbox "This needs to run as root or with sudo." 8 50
        exit 1
    fi
}

# Check if we can reach the repos
check_repos() {
    say_info "Testing repo connection..."
    
    if git ls-remote https://github.com/airlinklabs/panel.git -q >/dev/null 2>&1; then
        return 0
    else
        say_warn "Main repo down, using backup"
        return 1
    fi
}

# Get Node.js ready
setup_nodejs() {
    say_info "Setting up Node.js $node_ver..."
    
    # Clean house first
    remove_old_nodejs
    
    case "$os_family" in
        debian)
            get_nodejs_debian
            ;;
        redhat)
            get_nodejs_redhat
            ;;
        opensuse)
            get_nodejs_opensuse
            ;;
        arch)
            get_nodejs_arch
            ;;
        alpine)
            get_nodejs_alpine
            ;;
    esac
    
    test_nodejs
}

remove_old_nodejs() {
    say_info "Cleaning old Node.js..."
    
    case "$os_family" in
        debian)
            apt-get remove -y nodejs npm >/dev/null 2>&1 || true
            rm -f /etc/apt/sources.list.d/nodesource.list
            rm -f /etc/apt/keyrings/nodesource.gpg
            ;;
        redhat)
            $pkg_tool remove -y nodejs npm >/dev/null 2>&1 || true
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

get_nodejs_debian() {
    curl -fsSL https://deb.nodesource.com/setup_${node_ver}.x | bash - >/dev/null 2>&1
    apt-get install -y nodejs >/dev/null 2>&1
}

get_nodejs_redhat() {
    curl -fsSL https://rpm.nodesource.com/setup_${node_ver}.x | bash - >/dev/null 2>&1
    $pkg_tool install -y nodejs >/dev/null 2>&1
}

get_nodejs_opensuse() {
    zypper install -y nodejs${node_ver} npm${node_ver} >/dev/null 2>&1
}

get_nodejs_arch() {
    pacman -Sy --noconfirm nodejs npm >/dev/null 2>&1
}

get_nodejs_alpine() {
    apk add --no-cache nodejs npm >/dev/null 2>&1
}

test_nodejs() {
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local node_version=$(node -v)
        local npm_version=$(npm -v)
        say_good "Node.js $node_version and npm $npm_version ready"
        
        # Get TypeScript too
        npm install -g typescript >/dev/null 2>&1
        say_good "TypeScript installed"
    else
        say_error "Node.js setup failed"
        exit 1
    fi
}

# Get Docker ready
setup_docker() {
    say_info "Setting up Docker..."
    
    if command -v docker >/dev/null 2>&1; then
        say_info "Docker already here"
        return 0
    fi
    
    case "$os_family" in
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
    
    # Start it up
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker >/dev/null 2>&1
    
    if command -v docker >/dev/null 2>&1; then
        say_good "Docker is running"
    else
        say_error "Docker setup failed"
        exit 1
    fi
}

# Make sure git is ready
setup_git() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi
    
    say_info "Getting Git..."
    
    case "$os_family" in
        debian)
            apt-get install -y git >/dev/null 2>&1
            ;;
        redhat)
            $pkg_tool install -y git >/dev/null 2>&1
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
    
    say_good "Git ready"
}

# Install the panel
install_panel() {
    local use_backup=${1:-false}
    local repo_url="https://github.com/airlinklabs/panel.git"
    
    if [[ "$use_backup" == "true" ]]; then
        repo_url="https://github.com/g-flame/airlink-panel-fork.git"
    fi
    
    say_info "Installing Airlink Panel..."
    
    # Make sure we have what we need
    check_prereqs
    
    # Set up shop
    mkdir -p /var/www
    cd /var/www || { say_error "Can't get to /var/www"; exit 1; }
    
    # Clean slate
    if [[ -d "/var/www/panel" ]]; then
        say_warn "Removing old panel"
        rm -rf /var/www/panel
    fi
    
    # Get the code
    show_progress 20 "Getting panel code..." &
    progress_pid=$!
    
    if ! git clone "$repo_url" panel >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Couldn't get panel code"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    cd panel || { say_error "Can't enter panel folder"; exit 1; }
    
    # Fix permissions
    chown -R www-data:www-data /var/www/panel 2>/dev/null || chown -R root:root /var/www/panel
    chmod -R 755 /var/www/panel
    
    # Set up config
    if [[ -f "example.env" ]]; then
        cp example.env .env
    else
        say_error "Missing example.env file"
        exit 1
    fi
    
    # Get dependencies
    show_progress 30 "Installing panel stuff..." &
    progress_pid=$!
    
    if ! npm install --production >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Panel dependencies failed"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    # Set up database
    show_progress 15 "Setting up database..." &
    progress_pid=$!
    
    if ! npm run migrate:dev >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Database setup failed"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    # Build it
    show_progress 25 "Building panel..." &
    progress_pid=$!
    
    if ! npm run build-ts >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Panel build failed"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    # Make it a service
    create_panel_service
    
    # Start it up
    systemctl daemon-reload
    systemctl enable airlink-panel.service >/dev/null 2>&1
    systemctl start airlink-panel.service >/dev/null 2>&1
    
    if systemctl is-active --quiet airlink-panel.service; then
        say_good "Panel is running"
    else
        say_error "Panel won't start. Check: journalctl -u airlink-panel.service"
        exit 1
    fi
}

# Install the daemon
install_daemon() {
    local use_backup=${1:-false}
    local repo_url="https://github.com/airlinklabs/daemon.git"
    
    if [[ "$use_backup" == "true" ]]; then
        repo_url="https://github.com/g-flame/airlink-daemon-fork.git"
    fi
    
    say_info "Installing Airlink Daemon..."
    
    # Make sure we have what we need
    check_prereqs
    setup_docker
    
    # Set up shop
    cd /etc || { say_error "Can't get to /etc"; exit 1; }
    
    # Clean slate
    if [[ -d "/etc/daemon" ]]; then
        say_warn "Removing old daemon"
        rm -rf /etc/daemon
    fi
    
    # Get the code
    show_progress 20 "Getting daemon code..." &
    progress_pid=$!
    
    if ! git clone "$repo_url" daemon >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Couldn't get daemon code"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    cd daemon || { say_error "Can't enter daemon folder"; exit 1; }
    
    # Fix permissions
    chown -R www-data:www-data /etc/daemon 2>/dev/null || chown -R root:root /etc/daemon
    chmod -R 755 /etc/daemon
    
    # Set up config
    if [[ -f "example.env" ]]; then
        cp example.env .env
    else
        say_error "Missing example.env file"
        exit 1
    fi
    
    # Get dependencies
    show_progress 30 "Installing daemon stuff..." &
    progress_pid=$!
    
    if ! npm install >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Daemon dependencies failed"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    # Build it
    show_progress 20 "Building daemon..." &
    progress_pid=$!
    
    if ! npm run build >/dev/null 2>&1; then
        kill $progress_pid 2>/dev/null || true
        say_error "Daemon build failed"
        exit 1
    fi
    
    kill $progress_pid 2>/dev/null || true
    
    # Make it a service
    create_daemon_service
    
    # Start it up
    systemctl daemon-reload
    systemctl enable airlink-daemon.service >/dev/null 2>&1
    systemctl start airlink-daemon.service >/dev/null 2>&1
    
    if systemctl is-active --quiet airlink-daemon.service; then
        say_good "Daemon is running"
    else
        say_error "Daemon won't start. Check: journalctl -u airlink-daemon.service"
        exit 1
    fi
}

# Create service files
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

# Make sure we have what we need
check_prereqs() {
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        say_error "Need Node.js. Installing..."
        setup_nodejs
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        setup_git
    fi
}

# Remove stuff
remove_panel() {
    say_info "Removing Airlink Panel..."
    
    # Stop it
    systemctl stop airlink-panel.service >/dev/null 2>&1 || true
    systemctl disable airlink-panel.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/airlink-panel.service
    systemctl daemon-reload
    
    # Delete it
    if [[ -d "/var/www/panel" ]]; then
        rm -rf /var/www/panel
        say_good "Panel removed"
    else
        say_warn "Panel wasn't installed"
    fi
}

remove_daemon() {
    say_info "Removing Airlink Daemon..."
    
    # Stop it
    systemctl stop airlink-daemon.service >/dev/null 2>&1 || true
    systemctl disable airlink-daemon.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/airlink-daemon.service
    systemctl daemon-reload
    
    # Delete it
    if [[ -d "/etc/daemon" ]]; then
        rm -rf /etc/daemon
        say_good "Daemon removed"
    else
        say_warn "Daemon wasn't installed"
    fi
}

remove_everything() {
    say_info "Removing all dependencies..."
    
    # Bye Docker
    if command -v docker >/dev/null 2>&1; then
        say_info "Removing Docker..."
        systemctl stop docker >/dev/null 2>&1 || true
        systemctl disable docker >/dev/null 2>&1 || true
        
        case "$os_family" in
            debian)
                apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 || true
                rm -f /etc/apt/sources.list.d/docker.list
                rm -f /etc/apt/keyrings/docker.gpg
                ;;
            redhat)
                $pkg_tool remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 || true
                ;;
            arch)
                pacman -R --noconfirm docker >/dev/null 2>&1 || true
                ;;
            alpine)
                apk del docker >/dev/null 2>&1 || true
                ;;
        esac
    fi
    
    # Bye Node.js
    if command -v node >/dev/null 2>&1; then
        say_info "Removing Node.js..."
        npm uninstall -g typescript >/dev/null 2>&1 || true
        remove_old_nodejs
    fi
    
    # Clean up
    case "$os_family" in
        debian)
            apt-get autoremove -y >/dev/null 2>&1
            apt-get autoclean >/dev/null 2>&1
            ;;
        redhat)
            $pkg_tool autoremove -y >/dev/null 2>&1 || true
            ;;
        arch)
            pacman -Rns --noconfirm $(pacman -Qtdq) >/dev/null 2>&1 || true
            ;;
    esac
    
    say_good "Everything cleaned up"
}

# Show the logo
show_logo() {
    clear
    echo -e "${bold}${blue}"
    echo "    ╔══════════════════════════════════════════════════════════════╗"
    echo "    ║                    AIRLINK INSTALLER v${version}                  ║"
    echo "    ╠══════════════════════════════════════════════════════════════╣"
    echo "    ║      ___  _      _ _       _                                  ║"
    echo "    ║     / _ \\(_)_ __| (_)_ __ | | __                              ║"
    echo "    ║    / /_\\ / | '__| | | '_ \\| |/ /                              ║"
    echo "    ║    |  _  | | |  | | | | | |   <                               ║"
    echo "    ║    | | | |_| |  |_|_|_| |_|_|\\_\\                              ║"
    echo "    ║                                                              ║"
    echo "    ╠══════════════════════════════════════════════════════════════╣"
    echo -e "    ║  ${green}Panel and Daemon by ${cyan}Airlinklabs${blue} © MIT License           ║"
    echo -e "    ║  ${green}Universal Installer by ${yellow}G-flame${blue}                        ║"
    echo -e "    ║  ${purple}Detected: $current_os ($os_family)${blue}                               ║"
    echo "    ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${reset}"
}

show_done() {
    local what="$1"
    local port="$2"
    
    dialog --title "All Done!" \
           --msgbox "Airlink $what is ready!\n\nAccess it at: http://localhost:$port\n\nService status: systemctl status airlink-$what.service\nLogs: journalctl -u airlink-$what.service" \
           12 60
}

# The main menu
show_menu() {
    local use_backup=${1:-false}
    local repo_status="Primary"
    
    if [[ "$use_backup" == "true" ]]; then
        repo_status="Backup"
    fi
    
    while true; do
        show_logo
        
        choice=$(dialog --clear --title "Airlink Installer - $repo_status Repos" \
                       --menu "What would you like to do?" \
                       $menu_height $menu_width 12 \
                       1 "Install Everything (Panel + Daemon)" \
                       2 "Install Panel Only" \
                       3 "Install Daemon Only" \
                       4 "Install Dependencies Only" \
                       5 "Remove Panel + Daemon" \
                       6 "Remove Panel Only" \
                       7 "Remove Daemon Only" \
                       8 "Remove Dependencies Only" \
                       9 "Remove Everything" \
                       10 "System Info" \
                       11 "View Logs" \
                       0 "Exit" 3>&1 1>&2 2>&3)
        
        case $choice in
            1)
                dialog --title "Full Install" --infobox "Installing everything..." 5 50
                setup_nodejs
                setup_git
                install_panel "$use_backup"
                install_daemon "$use_backup"
                show_done "panel" "3000"
                dialog --title "All Done!" --msgbox "Panel (port 3000) and Daemon (port 3002) are running!" 8 50
                ;;
            2)
                dialog --title "Panel Install" --infobox "Installing panel..." 5 50
                setup_nodejs
                setup_git
                install_panel "$use_backup"
                show_done "panel" "3000"
                ;;
            3)
                dialog --title "Daemon Install" --infobox "Installing daemon..." 5 50
                setup_nodejs
                setup_git
                install_daemon "$use_backup"
                show_done "daemon" "3002"
                ;;
            4)
                dialog --title "Dependencies" --infobox "Installing dependencies..." 5 50
                setup_nodejs
                setup_git
                setup_docker
                dialog --title "Done!" --msgbox "All dependencies ready!" 6 40
                ;;
            5)
                dialog --title "Remove" --yesno "Remove both Panel and Daemon?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_panel
                    remove_daemon
                    dialog --title "Done!" --msgbox "Panel and Daemon removed!" 6 40
                fi
                ;;
            6)
                dialog --title "Remove" --yesno "Remove Panel?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_panel
                    dialog --title "Done!" --msgbox "Panel removed!" 6 40
                fi
                ;;
            7)
                dialog --title "Remove" --yesno "Remove Daemon?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_daemon
                    dialog --title "Done!" --msgbox "Daemon removed!" 6 40
                fi
                ;;
            8)
                dialog --title "Remove" --yesno "Remove all dependencies?" 6 40
                if [[ $? -eq 0 ]]; then
                    remove_everything
                    dialog --title "Done!" --msgbox "Dependencies removed!" 6 40
                fi
                ;;
            9)
                dialog --title "Remove Everything" --yesno "Remove EVERYTHING?" 8 50
                if [[ $? -eq 0 ]]; then
                    remove_panel
                    remove_daemon
                    remove_everything
                    dialog --title "Done!" --msgbox "Everything removed!" 6 40
                fi
                ;;
            10)
                show_system_info
                ;;
            11)
                show_logs
                ;;
            0)
                dialog --title "Exit" --yesno "Really exit?" 6 40
                if [[ $? -eq 0 ]]; then
                    clear
                    write_log "User exited"
                    echo -e "${green}Thanks for using Airlink Installer!${reset}"
                    exit 0
                fi
                ;;
            *)
                dialog --title "Oops" --msgbox "That's not a valid choice." 6 40
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
    
    dialog --title "System Info" \
           --msgbox "OS: $current_os $os_version
Family: $os_family
Package Manager: $pkg_tool

What's Installed:
- Node.js: $node_version
- npm: $npm_version
- Docker: $docker_version
- Git: $git_version

Service Status:
- Panel: $(systemctl is-active airlink-panel.service 2>/dev/null || echo 'not running')
- Daemon: $(systemctl is-active airlink-daemon.service 2>/dev/null || echo 'not running')" \
           18 70
}

show_logs() {
    if [[ -f "$logfile" ]]; then
        dialog --title "Logs" --textbox "$logfile" 20 80
    else
        dialog --title "No Logs" --msgbox "No logs found yet." 6 30
    fi
}

# Clean up temp files
cleanup() {
    write_log "Cleaning up..."
    
    # Remove temp files
    rm -rf /tmp/node-*
    rm -rf /tmp/npm-*
    
    # Clean package cache
    case "$os_family" in
        debian)
            apt-get clean >/dev/null 2>&1
            ;;
        redhat)
            $pkg_tool clean all >/dev/null 2>&1
            ;;
        arch)
            pacman -Sc --noconfirm >/dev/null 2>&1
            ;;
        alpine)
            apk cache clean >/dev/null 2>&1
            ;;
    esac
    
    say_good "Cleanup done"
}

# Handle errors nicely
handle_error() {
    local exit_code=$?
    local line_num=$1
    
    say_error "Something went wrong on line $line_num (code $exit_code)"
    
    dialog --title "Oops!" \
           --msgbox "Something went wrong during installation.\nCheck logs: $logfile\n\nLine: $line_num\nCode: $exit_code" \
           10 50
    
    cleanup
    exit $exit_code
}

# Handle interruptions
handle_interrupt() {
    write_log "User interrupted"
    dialog --title "Interrupted" --msgbox "Installation stopped. Cleaning up..." 6 40
    cleanup
    clear
    exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR
trap handle_interrupt INT TERM

# Check for script updates
check_updates() {
    local current="$version"
    local latest
    
    write_log "Checking for updates..."
    
    if latest=$(curl -s https://api.github.com/repos/g-flame/airlink-installer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")' 2>/dev/null); then
        if [[ "$latest" != "$current" ]]; then
            dialog --title "Update Available" \
                   --yesno "New version available:\nCurrent: $current\nLatest: $latest\n\nWant to get it?" \
                   10 50
            
            if [[ $? -eq 0 ]]; then
                write_log "User wants to update"
                dialog --title "Update" --msgbox "Visit https://github.com/g-flame/airlink-installer for the latest version." 8 60
            fi
        else
            write_log "Already up to date"
        fi
    else
        say_warn "Couldn't check for updates"
    fi
}

# Check if ports are free
check_port() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":$port " && return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -q ":$port " && return 1
    fi
    return 0
}

# Pre-flight checks
pre_checks() {
    write_log "Running pre-checks..."
    
    # Check disk space (need at least 2GB)
    local space=$(df /var 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [[ $space -lt 2097152 ]]; then
        dialog --title "Not Enough Space" --msgbox "Need at least 2GB free in /var directory." 8 50
        exit 1
    fi
    
    # Check if ports are busy
    local busy_ports=()
    ! check_port 3000 && busy_ports+=("3000 (Panel)")
    ! check_port 3002 && busy_ports+=("3002 (Daemon)")
    
    if [[ ${#busy_ports[@]} -gt 0 ]]; then
        local port_list=""
        for port in "${busy_ports[@]}"; do
            port_list="$port_list\n- $port"
        done
        
        dialog --title "Ports Busy" \
               --yesno "These ports are already used:$port_list\n\nContinue anyway?" \
               10 50
        
        [[ $? -ne 0 ]] && exit 1
    fi
    
    say_good "Pre-checks passed"
}

# Main function
main() {
    # Start logging
    touch "$logfile"
    write_log "Starting Airlink Installer v$version"
    
    # Need root
    need_root
    
    # Figure out the system
    detect_system
    
    # Get basics ready
    check_basics
    
    # Check for updates
    check_updates
    
    # Pre-flight checks
    pre_checks
    
    # Test repo connection
    if check_repos; then
        write_log "Using main repos"
        show_menu false
    else
        write_log "Using backup repos"
        dialog --title "Repo Notice" \
               --msgbox "Main repos not available.\nUsing backup repos instead." \
               8 50
        show_menu true
    fi
}

# Show version
show_version() {
    echo "Airlink Universal Installer v$version"
    echo "Copyright (c) 2025 G-flame-OSS"
    echo "MIT License"
}

# Show help
show_help() {
    cat << EOF
Airlink Universal Installer v$version

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help       Show this help
    -v, --version    Show version
    --log-file FILE  Custom log file
    --no-color       No colors
    --debug          Debug mode

EXAMPLES:
    $0                        # Run installer
    $0 --version              # Show version
    $0 --log-file /tmp/my.log # Custom log

More info: https://github.com/g-flame/airlink-installer
EOF
}

# Handle command line args
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
            logfile="$2"
            shift 2
            ;;
        --no-color)
            red=''
            green=''
            yellow=''
            blue=''
            purple=''
            cyan=''
            white=''
            bold=''
            reset=''
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

# Let's go!
main
