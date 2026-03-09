#!/usr/bin/env bash

run_directory_scan() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/dirs.txt"
    : > "$out"

    append_section_header "$out" "DIRECTORY DISCOVERY"
    echo "Target: $TARGET" >> "$out"
    local base_url
    base_url="$(target_base_url)"

    if tool_exists "ffuf"; then
        print_info "Using ffuf"
        run_with_spinner "$out" "FFUF scan" ffuf -u "$base_url/FUZZ" -w "$WORDLIST" -mc all -fc 404 -s
    elif tool_exists "gobuster"; then
        print_info "Using gobuster"
        run_with_spinner "$out" "Gobuster scan" gobuster dir -u "$base_url" -w "$WORDLIST" -q
    elif tool_exists "dirb"; then
        print_info "Using dirb"
        run_with_spinner "$out" "DIRB scan" dirb "$base_url" "$WORDLIST" -S
    else
        print_warn "Neither gobuster nor dirb found. Using curl path checks"
        run_basic_dir_checks "$out" "$base_url"
    fi

    copy_latest "$out" "dirs.txt"
    print_ok "Directory scan saved: $TARGET_DIR/dirs.txt"
}

run_basic_dir_checks() {
    local out="$1"
    local base_url="$2"
    local paths=("admin" "login" "backup" "config" "api")

    {
        echo "Fallback HTTP checks"
        echo
    } >> "$out"

    for p in "${paths[@]}"; do
        local url="$base_url/$p"
        local code
        code="$(curl -sk -o /dev/null -w '%{http_code}' "$url")"
        if [[ "$code" != "000" ]]; then
            printf "%s -> HTTP %s\n" "$url" "$code" >> "$out"
            log_info "Path checked: $url ($code)"
        fi
    done
}
