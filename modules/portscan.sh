#!/usr/bin/env bash

run_nmap_profile() {
    local out="$1"
    local profile="$2"

    case "$profile" in
        quick)
            run_with_spinner "$out" "Nmap quick scan" nmap -Pn -T4 --top-ports 200 -sV --open "$TARGET"
            ;;
        standard)
            run_with_spinner "$out" "Nmap standard scan" nmap -Pn -T4 --top-ports 1000 -sV -sC --open "$TARGET"
            ;;
        full)
            if tool_exists "naabu"; then
                local naabu_out="$RUN_DIR/naabu_ports.txt"
                run_with_spinner "$out" "Naabu fast broad discovery" naabu -host "$TARGET" -top-ports 10000 -silent -o "$naabu_out"
                if [[ -s "$naabu_out" ]]; then
                    local ports
                    ports="$(awk -F: '{print $NF}' "$naabu_out" | sort -nu | paste -sd, -)"
                    if [[ -n "$ports" ]]; then
                        run_with_spinner "$out" "Nmap targeted full service detection" nmap -Pn -T4 -p "$ports" -sV -sC "$TARGET"
                    else
                        run_with_spinner "$out" "Nmap full TCP sweep" nmap -Pn -T4 -p- --min-rate 1500 --max-retries 2 "$TARGET"
                    fi
                else
                    run_with_spinner "$out" "Nmap full TCP sweep" nmap -Pn -T4 -p- --min-rate 1500 --max-retries 2 "$TARGET"
                fi
            else
                run_with_spinner "$out" "Nmap full TCP sweep" nmap -Pn -T4 -p- --min-rate 1500 --max-retries 2 "$TARGET"
            fi

            run_with_spinner "$out" "Nmap service detection" nmap -Pn -T4 -sV -sC --top-ports 1000 "$TARGET"
            if is_root; then
                run_with_spinner "$out" "Nmap OS and traceroute" nmap -Pn -O --traceroute "$TARGET"
            else
                print_warn "Root required for -O; skipping OS fingerprint"
            fi
            ;;
        web)
            run_with_spinner "$out" "Nmap web-focused scripts" nmap -Pn -p 80,443,8080,8443 -sV --script http-title,http-headers,http-server-header,ssl-cert,ssl-enum-ciphers "$TARGET"
            ;;
        safe)
            run_with_spinner "$out" "Nmap safe script scan" nmap -Pn -sV --script "default,safe,discovery" "$TARGET"
            ;;
        *)
            print_warn "Unknown profile '$profile', using standard"
            run_with_spinner "$out" "Nmap standard scan" nmap -Pn -T4 --top-ports 1000 -sV -sC --open "$TARGET"
            ;;
    esac
}

choose_nmap_profile() {
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        case "$PROFILE" in
            quick) echo "quick" ;;
            deep) echo "full" ;;
            *) echo "standard" ;;
        esac
        return
    fi

    echo
    echo "Nmap Profiles"
    echo "1) Quick"
    echo "2) Standard"
    echo "3) Full"
    echo "4) Web Focused"
    echo "5) Safe Scripts"
    read -r -p "Select profile [1-5, default 2] > " p

    case "$p" in
        1) echo "quick" ;;
        2|"") echo "standard" ;;
        3) echo "full" ;;
        4) echo "web" ;;
        5) echo "safe" ;;
        *) echo "standard" ;;
    esac
}

run_portscan() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/portscan.txt"
    : > "$out"

    append_section_header "$out" "NMAP PORT SCAN"
    echo "Target: $TARGET" >> "$out"

    if ! tool_exists "nmap"; then
        print_error "nmap is required for port scanning"
        echo "nmap not installed." >> "$out"
        copy_latest "$out" "portscan.txt"
        return 1
    fi

    local profile
    profile="$(choose_nmap_profile)"
    print_info "Running nmap profile: $profile"
    run_nmap_profile "$out" "$profile"

    if is_root; then
        run_if_tool "$out" masscan "Masscan quick sweep (top 1000)" masscan "$TARGET" --top-ports 1000 --rate 1000
    else
        print_warn "Run as root for advanced raw-socket scans (masscan/OS detection)"
        echo "Non-root mode: skipped masscan." >> "$out"
    fi

    run_if_tool "$out" naabu "Naabu TCP discovery" naabu -host "$TARGET" -top-ports 1000
    run_if_tool "$out" rustscan "RustScan quick discovery" rustscan -a "$TARGET" --ulimit 5000 -- -sV

    finalize_output_file "$out" "portscan.txt" "lines"
    print_ok "Port scan saved: $TARGET_DIR/portscan.txt"
}
