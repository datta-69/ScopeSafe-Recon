#!/usr/bin/env bash

run_recon() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/recon.txt"
    : > "$out"

    append_section_header "$out" "TARGET RECONNAISSANCE"
    echo "Target: $TARGET" >> "$out"

    print_info "Running reconnaissance for $TARGET"

    append_section_header "$out" "IP RESOLUTION"
    run_and_log "$out" dig +short "$TARGET"
    run_if_tool "$out" nslookup "Resolving with nslookup" nslookup "$TARGET"

    append_section_header "$out" "DNS RECORDS"
    run_and_log "$out" dig "$TARGET" ANY
    run_and_log "$out" dig "$TARGET" NS +short
    run_and_log "$out" dig "$TARGET" MX +short
    run_and_log "$out" dig "$TARGET" TXT +short
    run_if_tool "$out" dnsrecon "Collecting DNS data with dnsrecon" dnsrecon -d "$TARGET" -t std
    run_if_tool "$out" dnsenum "Collecting DNS data with dnsenum" dnsenum "$TARGET"

    append_section_header "$out" "BASIC HOST INFO"
    run_if_tool "$out" host "Host lookup" host "$TARGET"
    run_if_tool "$out" ping "Ping probe" ping -c 2 "$TARGET"
    run_if_tool "$out" traceroute "Network path trace" traceroute -m 12 "$TARGET"

    append_section_header "$out" "HTTP HEADERS"
    local base_url
    base_url="$(target_base_url)"
    run_and_log "$out" curl -skI "$base_url"
    run_and_log "$out" curl -skI "http://$TARGET"
    run_and_log "$out" curl -skI "https://$TARGET"

    append_section_header "$out" "WEB TECHNOLOGY DETECTION"
    run_web_tech_detection_internal "$out"

    append_section_header "$out" "PASSIVE INTEL"
    run_if_tool "$out" theHarvester "Running theHarvester (quick mode)" theHarvester -d "$TARGET" -b all -l 100

    finalize_output_file "$out" "recon.txt" "lines"
    print_ok "Recon saved: $TARGET_DIR/recon.txt"
}

run_web_tech_detection_internal() {
    local out="$1"
    local base_url
    base_url="$(target_base_url)"

    if tool_exists "whatweb"; then
        run_with_spinner "$out" "Detecting web technologies (whatweb)" whatweb --no-errors "$base_url"
    else
        print_warn "whatweb not found. Falling back to HTTP header fingerprinting."
        {
            echo "whatweb missing - fallback heuristic"
            echo ""
            curl -skI "$base_url" | grep -Ei 'server:|x-powered-by:|via:'
        } >> "$out" 2>&1
    fi

    run_if_tool "$out" wafw00f "Detecting WAF" wafw00f "$base_url"
    run_if_tool "$out" httpx "Probing HTTP services" httpx -u "$base_url" -title -status-code -tech-detect
}

run_web_tech_detection() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/webtech.txt"
    : > "$out"

    append_section_header "$out" "WEB TECHNOLOGY DETECTION"
    echo "Target: $TARGET" >> "$out"
    run_web_tech_detection_internal "$out"

    finalize_output_file "$out" "webtech.txt" "lines"
    print_ok "Web tech results saved: $TARGET_DIR/webtech.txt"
}
