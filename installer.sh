#!/bin/bash

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

LOG_FILE="/var/log/install_script.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
    log "INFO: $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    log "WARNING: $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    log "ERROR: $*"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Permission Error" --msgbox "This script must be run as root or with sudo privileges." 8 50
        exit 1
    fi
}

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
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
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

    log_info "Detected OS: $OS ($DISTRO_FAMILY family), using package manager: $PKG_MANAGER"
}

install_packages() {
    local packages=("$@")
    log_info "Installing packages: ${packages[*]}"

    case "$PKG_MANAGER" in
        apt)
            apt update && apt install -y "${packages[@]}"
            ;;
        dnf|yum)
            $PKG_MANAGER install -y "${packages[@]}"
            ;;
        zypper)
            zypper install -y "${packages[@]}"
            ;;
        pacman)
            pacman -Sy --noconfirm "${packages[@]}"
            ;;
        apk)
            apk add --no-cache "${packages[@]}"
            ;;
        *)
            log_error "Unsupported package manager: $PKG_MANAGER"
            exit 1
            ;;
    esac
}

install_basic_dependencies() {
    local missing=("$@")
    local choices=()

    for dep in "${missing[@]}"; do
        # Add to dialog checklist: package tag + description + default checked state
        choices+=("$dep" "Install $dep" "off")
    done

    local selected=$(dialog --checklist "Select packages to install:" 15 50 5 "${choices[@]}" 3>&1 1>&2 2>&3 3>&-)
    clear

    if [[ -z "$selected" ]]; then
        log_warning "No packages selected for installation. Exiting."
        exit 1
    fi

    # dialog returns quoted space-separated values, remove quotes, convert to array
    read -r -a to_install <<< "$(echo $selected | sed 's/"//g')"

    install_packages "${to_install[@]}"
}

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
    else
        log_info "All dependencies are installed."
    fi
}

# Script startup execution
check_root
detect_os
check_dependencies

curl -s https://raw.githubusercontent.com/g-flame-oss/Airlink-installer/refs/heads/main/script.sh -o airlink-installer.sh && chmod +x airlink-installer.sh && sudo ./airlink-installer.sh && rm airlink-installer.sh installer.sh 
