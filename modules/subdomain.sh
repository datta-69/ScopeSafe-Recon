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

    local tmp_dir="$RUN_DIR/.subenum"
    mkdir -p "$tmp_dir"
    local pids=()
    local found_any=0

    if tool_exists "subfinder"; then
        print_info "Queueing subfinder"
        run_and_log "$tmp_dir/subfinder.txt" subfinder -d "$TARGET" -silent &
        pids+=("$!")
        found_any=1
    fi

    if tool_exists "amass"; then
        print_info "Queueing amass passive enum"
        run_and_log "$tmp_dir/amass.txt" amass enum -passive -d "$TARGET" &
        pids+=("$!")
        found_any=1
    fi

    if tool_exists "assetfinder"; then
        print_info "Queueing assetfinder"
        run_and_log "$tmp_dir/assetfinder.txt" assetfinder --subs-only "$TARGET" &
        pids+=("$!")
        found_any=1
    fi

    if tool_exists "dnsrecon"; then
        print_info "Queueing dnsrecon brute"
        run_and_log "$tmp_dir/dnsrecon.txt" dnsrecon -d "$TARGET" -t brt &
        pids+=("$!")
        found_any=1
    fi

    if [[ ${#pids[@]} -gt 0 ]]; then
        print_info "Running subdomain providers in parallel"
        for pid in "${pids[@]}"; do
            wait "$pid" || true
        done
        cat "$tmp_dir"/*.txt 2>/dev/null >> "$out" || true
    fi

    if [[ $found_any -eq 0 ]]; then
        print_warn "No advanced subdomain tools found. Using dig brute-force method"
    fi

    run_subdomain_bruteforce "$out"

    finalize_output_file "$out" "subdomains.txt" "subdomains"
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
