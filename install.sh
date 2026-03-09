#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'
RESET='\e[0m'

print() {
    local color="$1"
    shift
    echo -e "${color}$*${RESET}"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

install_core_apt() {
    sudo apt update
    sudo apt install -y nmap dnsutils curl
}

install_optional_apt() {
    local packages=(whatweb dirb gobuster ffuf amass dnsrecon dnsenum wafw00f theharvester masscan rustscan gau)
    for p in "${packages[@]}"; do
        sudo apt install -y "$p" >/dev/null 2>&1 || print "$YELLOW" "Optional package unavailable: $p"
    done
}

install_core_dnf() {
    sudo dnf install -y nmap bind-utils curl
}

install_optional_dnf() {
    local packages=(gobuster ffuf amass dnsenum masscan)
    for p in "${packages[@]}"; do
        sudo dnf install -y "$p" >/dev/null 2>&1 || print "$YELLOW" "Optional package unavailable: $p"
    done
}

install_core_pacman() {
    sudo pacman -Sy --noconfirm nmap bind curl
}

install_optional_pacman() {
    local packages=(whatweb gobuster ffuf amass dnsrecon dnsenum wafw00f theharvester masscan rustscan)
    for p in "${packages[@]}"; do
        sudo pacman -S --noconfirm "$p" >/dev/null 2>&1 || print "$YELLOW" "Optional package unavailable: $p"
    done
}

install_core_zypper() {
    sudo zypper refresh
    sudo zypper install -y nmap bind-utils curl
}

install_optional_zypper() {
    local packages=(gobuster ffuf amass dnsrecon dnsenum masscan)
    for p in "${packages[@]}"; do
        sudo zypper install -y "$p" >/dev/null 2>&1 || print "$YELLOW" "Optional package unavailable: $p"
    done
}

main() {
    print "$CYAN" "[DATTA-CYBER-TOOLKIT] Linux dependency installer"
    print "$YELLOW" "For educational and authorized penetration testing only."

    local missing=()
    local deps=(nmap dig curl)

    for d in "${deps[@]}"; do
        if ! need_cmd "$d"; then
            missing+=("$d")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        print "$GREEN" "All dependencies are already installed."
    else
        print "$YELLOW" "Missing core tools: ${missing[*]}"
        if need_cmd apt; then
            install_core_apt
            install_optional_apt
        elif need_cmd dnf; then
            install_core_dnf
            install_optional_dnf
        elif need_cmd pacman; then
            install_core_pacman
            install_optional_pacman
        elif need_cmd zypper; then
            install_core_zypper
            install_optional_zypper
        else
            print "$RED" "No supported package manager detected. Install tools manually."
        fi
    fi

    print "$CYAN" "Recommended optional tools for Kali/full mode:"
    print "$CYAN" "whatweb subfinder amass assetfinder dnsrecon dnsenum naabu httpx ffuf dirb gobuster wafw00f theharvester masscan rustscan gau waybackurls"

    chmod +x "$ROOT_DIR/toolkit.sh" "$ROOT_DIR/install.sh"
    chmod +x "$ROOT_DIR/core/"*.sh "$ROOT_DIR/modules/"*.sh

    print "$GREEN" "Installation complete. Run: ./toolkit.sh"
}

main
