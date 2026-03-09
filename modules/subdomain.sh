#!/usr/bin/env bash

BRUTE_SUBS=(
    www mail dev test api stage beta admin app portal
)

run_subdomain_enum() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/subdomains.txt"
    : > "$out"

    append_section_header "$out" "SUBDOMAIN ENUMERATION"
    echo "Target: $TARGET" >> "$out"

    local found_any=0

    if tool_exists "subfinder"; then
        print_info "Using subfinder"
        run_with_spinner "$out" "Running subfinder" subfinder -d "$TARGET" -silent
        found_any=1
    fi

    if tool_exists "amass"; then
        print_info "Using amass passive enum"
        run_with_spinner "$out" "Running amass" amass enum -passive -d "$TARGET"
        found_any=1
    fi

    if tool_exists "assetfinder"; then
        print_info "Using assetfinder"
        run_with_spinner "$out" "Running assetfinder" assetfinder --subs-only "$TARGET"
        found_any=1
    fi

    if tool_exists "dnsrecon"; then
        print_info "Using dnsrecon brute"
        run_with_spinner "$out" "Running dnsrecon" dnsrecon -d "$TARGET" -t brt
        found_any=1
    fi

    if [[ $found_any -eq 0 ]]; then
        print_warn "No advanced subdomain tools found. Using dig brute-force method"
    fi

    run_subdomain_bruteforce "$out"

    grep -Eio "([a-zA-Z0-9_-]+\.)+$TARGET" "$out" | sort -u > "$out.clean" 2>/dev/null || true
    if [[ -s "$out.clean" ]]; then
        mv "$out.clean" "$out"
    else
        rm -f "$out.clean"
    fi

    copy_latest "$out" "subdomains.txt"
    print_ok "Subdomain results saved: $TARGET_DIR/subdomains.txt"
}

run_subdomain_bruteforce() {
    local out="$1"

    for sub in "${BRUTE_SUBS[@]}"; do
        local fqdn="$sub.$TARGET"
        local ans
        ans="$(dig +short "$fqdn" | head -n 1)"
        if [[ -n "$ans" ]]; then
            echo "$fqdn -> $ans" >> "$out"
            print_ok "Found: $fqdn"
            log_info "Subdomain found: $fqdn -> $ans"
        fi
    done
}
