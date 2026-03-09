#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=core/colors.sh
source "$ROOT_DIR/core/colors.sh"
# shellcheck source=core/banner.sh
source "$ROOT_DIR/core/banner.sh"
# shellcheck source=core/utils.sh
source "$ROOT_DIR/core/utils.sh"

# shellcheck source=modules/recon.sh
source "$ROOT_DIR/modules/recon.sh"
# shellcheck source=modules/portscan.sh
source "$ROOT_DIR/modules/portscan.sh"
# shellcheck source=modules/subdomain.sh
source "$ROOT_DIR/modules/subdomain.sh"
# shellcheck source=modules/dirscan.sh
source "$ROOT_DIR/modules/dirscan.sh"
# shellcheck source=modules/urlscan.sh
source "$ROOT_DIR/modules/urlscan.sh"

print_help() {
    cat << 'EOF'
DATTA-CYBER-TOOLKIT

Usage:
  ./toolkit.sh                          # interactive mode
  ./toolkit.sh --target example.com --full-auto --profile deep

Options:
  --target <domain-or-ip>               Set target directly
  --full-auto                           Run full recon pipeline and exit
  --profile <quick|standard|deep>       Load scan profile
  --resume                              Skip already completed phases in current run
  --deep                                Enable deeper scans where supported
  --scope-file <path>                   Scope file path (default: scope.txt)
  --wordlist <path>                     Override directory scan wordlist
  --timeout <seconds>                   Timeout setting for tools
  --max-parallel <n>                    Max parallel jobs hint
  -h, --help                            Show help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                TARGET="$2"
                shift 2
                ;;
            --full-auto)
                set_runtime_option non_interactive 1
                shift
                ;;
            --profile)
                set_runtime_option profile "$2"
                shift 2
                ;;
            --resume)
                set_runtime_option resume 1
                shift
                ;;
            --deep)
                set_runtime_option deep 1
                shift
                ;;
            --scope-file)
                set_runtime_option scope_file "$2"
                shift 2
                ;;
            --wordlist)
                set_runtime_option wordlist "$2"
                shift 2
                ;;
            --timeout)
                set_runtime_option timeout "$2"
                shift 2
                ;;
            --max-parallel)
                set_runtime_option max_parallel "$2"
                shift 2
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                if [[ -z "$TARGET" && "$1" != -* ]]; then
                    TARGET="$1"
                    shift
                else
                    print_error "Unknown option: $1"
                    print_help
                    exit 1
                fi
                ;;
        esac
    done
}

run_phase() {
    local phase="$1"
    local handler="$2"

    if [[ "$RESUME_MODE" -eq 1 ]] && is_phase_done "$phase"; then
        print_info "Skipping completed phase: $phase"
        return 0
    fi

    "$handler"
    mark_phase_done "$phase"
}

generate_report() {
    prompt_target_if_missing || return 1

    local report="$RUN_DIR/report.txt"
    : > "$report"

    {
        echo "DATTA-CYBER-TOOLKIT RECON REPORT"
        echo "Generated: $(now)"
        echo "Target: $TARGET"
        echo "Run ID: $RUN_ID"
    } >> "$report"

    append_file_or_note "$report" "RECON" "$RUN_DIR/recon.txt"
    append_file_or_note "$report" "SUBDOMAINS" "$RUN_DIR/subdomains.txt"
    append_file_or_note "$report" "PORTS" "$RUN_DIR/portscan.txt"
    append_file_or_note "$report" "DIRECTORIES" "$RUN_DIR/dirs.txt"
    append_file_or_note "$report" "WEB TECHNOLOGY" "$RUN_DIR/webtech.txt"
    append_file_or_note "$report" "URL MINING" "$RUN_DIR/urls.txt"
    append_file_or_note "$report" "JS ENDPOINT HINTS" "$RUN_DIR/js_endpoints.txt"

    copy_latest "$report" "report.txt"
    print_ok "Report saved: $TARGET_DIR/report.txt"
}

choose_target() {
    while true; do
        read -r -p "Enter target domain/IP > " target_input
        if validate_target "$target_input"; then
            validate_target_scope "$target_input" || continue
            init_session "$target_input"
            write_session_metadata
            show_tool_versions
            print_ok "Target set: $TARGET"
            break
        fi
        print_error "Invalid target. Try example.com or 192.168.1.10"
    done
}

full_auto_recon() {
    prompt_target_if_missing || return 1

    print_info "Starting Full Auto Recon Mode for $TARGET"
    show_loading "Preparing modules"

    run_phase "recon" run_recon
    run_phase "subdomains" run_subdomain_enum
    run_phase "ports" run_portscan
    run_phase "dirs" run_directory_scan
    run_phase "webtech" run_web_tech_detection
    run_phase "urls" run_url_mining
    generate_report

    print_ok "Full auto recon completed"
    print_info "Check: $RUN_DIR"
    print_run_summary
}

show_menu() {
    show_banner
    echo -e "${BOLD}${BRIGHT_GREEN}=====================================${RESET}"
    echo -e "${BOLD}${BRIGHT_GREEN}        DATTA CYBER TOOLKIT         ${RESET}"
    echo -e "${BOLD}${BRIGHT_GREEN}=====================================${RESET}"
    echo
    echo "1) Target Reconnaissance"
    echo "2) Port Scanning"
    echo "3) Subdomain Enumeration"
    echo "4) Directory Discovery"
    echo "5) Web Technology Detection"
    echo "6) URL/JS Mining"
    echo "7) Full Auto Recon Mode"
    echo "8) Generate Report"
    echo "9) Exit"
    echo

    if [[ -n "${TARGET:-}" ]]; then
        color_echo "$BRIGHT_CYAN" "Current Target: $TARGET"
        color_echo "$DIM" "Run Directory: ${RUN_DIR:-not initialized}"
    else
        color_echo "$BRIGHT_YELLOW" "Current Target: Not set"
    fi
    hr
}

handle_choice() {
    local choice="$1"

    case "$choice" in
        1) run_recon ;;
        2) run_portscan ;;
        3) run_subdomain_enum ;;
        4) run_directory_scan ;;
        5) run_web_tech_detection ;;
        6) run_url_mining ;;
        7) full_auto_recon ;;
        8) generate_report ;;
        9)
            print_info "Exiting DATTA-CYBER-TOOLKIT"
            exit 0
            ;;
        *) print_warn "Invalid option selected" ;;
    esac
}

main() {
    mkdir -p "$RESULTS_ROOT"
    parse_args "$@"
    load_profile "$PROFILE" || true

    if [[ -n "$TARGET" ]]; then
        if ! validate_target "$TARGET"; then
            print_error "Invalid target format: $TARGET"
            exit 1
        fi
        validate_target_scope "$TARGET" || exit 1
        init_session "$TARGET"
        write_session_metadata
        show_tool_versions
    fi

    require_authorized_use
    check_dependencies || true
    print_info "Tip: run as root for better nmap OS detection accuracy"
    echo

    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        [[ -z "$TARGET" ]] && print_error "--target is required with --full-auto"
        full_auto_recon
        exit 0
    fi

    while true; do
        show_menu
        read -r -p "Select option > " option
        handle_choice "$option"
        pause_enter
    done
}

main "$@"
