#!/usr/bin/env bash

# Terminal color palette
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"

BRIGHT_RED="\e[91m"
BRIGHT_GREEN="\e[92m"
BRIGHT_YELLOW="\e[93m"
BRIGHT_BLUE="\e[94m"
BRIGHT_MAGENTA="\e[95m"
BRIGHT_CYAN="\e[96m"

color_echo() {
    local color="$1"
    shift
    echo -e "${color}$*${RESET}"
}

print_ok() {
    color_echo "$BRIGHT_GREEN" "[+] $*"
}

print_info() {
    color_echo "$BRIGHT_CYAN" "[*] $*"
}

print_warn() {
    color_echo "$BRIGHT_YELLOW" "[!] $*"
}

print_error() {
    color_echo "$BRIGHT_RED" "[-] $*" >&2
}

hr() {
    echo -e "${DIM}------------------------------------------------------------${RESET}"
}
