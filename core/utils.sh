#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORDLIST_DEFAULT="$ROOT_DIR/wordlists/common_dirs.txt"
RESULTS_ROOT="$ROOT_DIR/results"
REQUIRED_TOOLS=("nmap" "dig" "curl")
OPTIONAL_TOOLS=(
    "whatweb" "subfinder" "amass" "assetfinder" "dnsrecon" "dnsenum"
    "naabu" "httpx" "ffuf" "dirb" "gobuster" "wafw00f" "theHarvester"
    "masscan" "rustscan" "gau" "waybackurls" "host" "ping" "nslookup" "traceroute"
)

RUN_ID=""
TARGET=""
TARGET_SAFE=""
TARGET_DIR=""
RUN_DIR=""
LOG_FILE=""
AUTHORIZED_USE_CONFIRMED=0
STATE_DIR=""

# Runtime controls (can be overridden by profile or CLI)
PROFILE="standard"
NON_INTERACTIVE=0
RESUME_MODE=0
DEEP_MODE=0
TIMEOUT_SECS="300"
MAX_PARALLEL="5"
WORDLIST="$WORDLIST_DEFAULT"
SCOPE_FILE="$ROOT_DIR/scope.txt"

now() {
    date '+%Y-%m-%d %H:%M:%S'
}

ts_compact() {
    date '+%Y%m%d_%H%M%S'
}

sanitize_target() {
    local input="$1"
    echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's#https\?://##g; s#/.*##' | tr -cd 'a-zA-Z0-9._-'
}

validate_target() {
    local target="$1"
    [[ -z "$target" ]] && return 1
    [[ "$target" =~ ^[A-Za-z0-9.-]+$ ]] && return 0
    [[ "$target" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && return 0
    return 1
}

init_session() {
    TARGET="$1"
    TARGET_SAFE="$(sanitize_target "$TARGET")"
    TARGET_DIR="$RESULTS_ROOT/$TARGET_SAFE"

    if [[ "$RESUME_MODE" -eq 1 ]]; then
        local latest_run
        latest_run="$(find_latest_run_dir "$TARGET_DIR")"
        if [[ -n "$latest_run" ]]; then
            RUN_DIR="$latest_run"
            RUN_ID="$(basename "$RUN_DIR")"
        else
            RUN_ID="$(ts_compact)"
            RUN_DIR="$TARGET_DIR/$RUN_ID"
        fi
    else
        RUN_ID="$(ts_compact)"
        RUN_DIR="$TARGET_DIR/$RUN_ID"
    fi

    LOG_FILE="$RUN_DIR/toolkit.log"
    STATE_DIR="$RUN_DIR/state"

    mkdir -p "$TARGET_DIR" "$RUN_DIR" "$STATE_DIR"
    touch "$LOG_FILE"

    log_info "Session initialized for target: $TARGET"
    log_info "Run directory: $RUN_DIR"
}

find_latest_run_dir() {
    local target_dir="$1"
    [[ ! -d "$target_dir" ]] && return 0

    local latest
    latest="$(find "$target_dir" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
    echo "$latest"
}

set_runtime_option() {
    local key="$1"
    local value="$2"
    case "$key" in
        profile) PROFILE="$value" ;;
        non_interactive) NON_INTERACTIVE="$value" ;;
        resume) RESUME_MODE="$value" ;;
        deep) DEEP_MODE="$value" ;;
        timeout) TIMEOUT_SECS="$value" ;;
        max_parallel) MAX_PARALLEL="$value" ;;
        wordlist) WORDLIST="$value" ;;
        scope_file) SCOPE_FILE="$value" ;;
    esac
}

load_profile() {
    local profile_name="${1:-standard}"
    local profile_file="$ROOT_DIR/profiles/${profile_name}.conf"

    if [[ ! -f "$profile_file" ]]; then
        print_warn "Profile not found: $profile_name (using standard defaults)"
        PROFILE="standard"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$profile_file"
    PROFILE="$profile_name"
    print_info "Loaded profile: $PROFILE"
    return 0
}

scope_match() {
    local pattern="$1"
    local target="$2"

    if [[ "$pattern" == "$target" ]]; then
        return 0
    fi

    # Support wildcard patterns like *.example.com
    if [[ "$pattern" == *"*"* ]]; then
        local regex
        regex="^${pattern//./\\.}$"
        regex="${regex//\*/.*}"
        [[ "$target" =~ $regex ]] && return 0
    fi

    return 1
}

validate_target_scope() {
    local target="$1"

    # If scope file doesn't exist, allow scan but warn user.
    if [[ ! -f "$SCOPE_FILE" ]]; then
        print_warn "Scope file not found: $SCOPE_FILE"
        print_warn "Create scope.txt for safer bug bounty operations"
        return 0
    fi

    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs 2>/dev/null || true)"
        [[ -z "$line" ]] && continue

        if scope_match "$line" "$target"; then
            log_info "Target matched scope: $line"
            return 0
        fi
    done < "$SCOPE_FILE"

    print_error "Target $target is outside allowed scope ($SCOPE_FILE)"
    return 1
}

phase_state_file() {
    local phase="$1"
    echo "$STATE_DIR/${phase}.done"
}

is_phase_done() {
    local phase="$1"
    [[ -f "$(phase_state_file "$phase")" ]]
}

mark_phase_done() {
    local phase="$1"
    local status_file
    status_file="$(phase_state_file "$phase")"
    {
        echo "phase=$phase"
        echo "timestamp=$(now)"
    } > "$status_file"
}

log_raw() {
    local level="$1"
    shift
    if [[ -z "${LOG_FILE:-}" ]]; then
        return 0
    fi
    echo "[$(now)] [$level] $*" >> "$LOG_FILE"
}

log_info() { log_raw "INFO" "$*"; }
log_warn() { log_raw "WARN" "$*"; }
log_error() { log_raw "ERROR" "$*"; }

append_section_header() {
    local file="$1"
    local title="$2"
    {
        echo
        echo "========== $title =========="
        echo "Timestamp: $(now)"
        echo
    } >> "$file"
}

run_and_log() {
    local out_file="$1"
    shift
    local cmd=("$@")

    log_info "Running command: ${cmd[*]}"
    if tool_exists timeout && [[ "${TIMEOUT_SECS:-0}" -gt 0 ]]; then
        timeout "$TIMEOUT_SECS" "${cmd[@]}" >> "$out_file" 2>&1
    else
        "${cmd[@]}" >> "$out_file" 2>&1
    fi
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        log_warn "Command failed ($rc): ${cmd[*]}"
    fi
    return $rc
}

run_if_tool() {
    local out_file="$1"
    local tool="$2"
    local label="$3"
    shift 3

    if tool_exists "$tool"; then
        print_info "$label"
        run_and_log "$out_file" "$@"
        return $?
    fi

    print_warn "$tool not installed, skipping: $label"
    log_warn "Skipped because tool is missing: $tool ($label)"
    return 127
}

run_with_spinner() {
    local out_file="$1"
    local label="$2"
    shift 2

    local cmd=("$@")
    log_info "Running with spinner: $label => ${cmd[*]}"

    if tool_exists timeout && [[ "${TIMEOUT_SECS:-0}" -gt 0 ]]; then
        timeout "$TIMEOUT_SECS" "${cmd[@]}" >> "$out_file" 2>&1 &
    else
        "${cmd[@]}" >> "$out_file" 2>&1 &
    fi
    local pid=$!
    local spin='|/-\\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(((i + 1) % 4))
        printf "\r[%c] %s" "${spin:$i:1}" "$label"
        sleep 0.1
    done

    wait "$pid"
    local rc=$?
    printf "\r%-70s\r" ""

    if [[ $rc -eq 0 ]]; then
        print_ok "$label completed"
    else
        print_warn "$label finished with warnings (exit=$rc)"
        log_warn "$label non-zero exit: $rc"
    fi

    return $rc
}

tool_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

target_base_url() {
    # If target is an IP, prefer HTTP; otherwise prefer HTTPS then fall back.
    if [[ "$TARGET" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo "http://$TARGET"
        return
    fi

    local code
    code="$(curl -sk -m 5 -o /dev/null -w '%{http_code}' "https://$TARGET")"
    if [[ "$code" =~ ^[23] ]]; then
        echo "https://$TARGET"
    else
        echo "http://$TARGET"
    fi
}

check_dependencies() {
    local missing=0

    print_info "Checking required tools"
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if tool_exists "$tool"; then
            print_ok "$tool found"
        else
            print_warn "$tool not found"
            missing=1
        fi
    done

    if tool_exists "apt" && grep -qi "kali" /etc/os-release 2>/dev/null; then
        print_ok "Kali Linux detected - optimized toolchain available"
    fi

    print_info "Checking optional tools"
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        if tool_exists "$tool"; then
            print_ok "$tool found"
        else
            print_warn "$tool not found (optional)"
        fi
    done

    return $missing
}

copy_latest() {
    local from="$1"
    local name="$2"
    cp -f "$from" "$TARGET_DIR/$name" 2>/dev/null
}

dedupe_file_preserve_order() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    awk 'NF && !seen[$0]++' "$file" > "$file.tmp" 2>/dev/null || return 0
    mv "$file.tmp" "$file"
}

normalize_subdomains_file() {
    local file="$1"
    local target="$2"
    [[ ! -f "$file" ]] && return 0

    grep -Eio "([a-zA-Z0-9_-]+\.)+$target" "$file" \
        | tr '[:upper:]' '[:lower:]' \
        | sort -u > "$file.tmp" 2>/dev/null || true

    if [[ -s "$file.tmp" ]]; then
        mv "$file.tmp" "$file"
    else
        rm -f "$file.tmp"
        : > "$file"
    fi
}

normalize_urls_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    awk '{gsub(/\r/, ""); print}' "$file" \
        | sed 's/[[:space:]]*$//' \
        | sed 's/#.*$//' \
        | grep -Ei '^https?://' \
        | sed 's#/$##' \
        | sort -u > "$file.tmp" 2>/dev/null || true

    if [[ -s "$file.tmp" ]]; then
        mv "$file.tmp" "$file"
    else
        rm -f "$file.tmp"
        : > "$file"
    fi
}

finalize_output_file() {
    local run_file="$1"
    local latest_name="$2"
    local mode="${3:-lines}"

    case "$mode" in
        subdomains) normalize_subdomains_file "$run_file" "$TARGET" ;;
        urls) normalize_urls_file "$run_file" ;;
        lines|*) dedupe_file_preserve_order "$run_file" ;;
    esac

    copy_latest "$run_file" "$latest_name"
}

pause_enter() {
    echo
    read -r -p "Press Enter to continue... " _
}

require_authorized_use() {
    if [[ "$AUTHORIZED_USE_CONFIRMED" -eq 1 ]]; then
        return 0
    fi

    color_echo "$BRIGHT_YELLOW" "Legal Notice: Use only on assets you own or have explicit written permission to test."
    read -r -p "Type I-AGREE to continue > " consent
    if [[ "$consent" != "I-AGREE" ]]; then
        print_error "Authorization not confirmed. Exiting."
        exit 1
    fi

    AUTHORIZED_USE_CONFIRMED=1
    log_info "Authorized-use acknowledgement confirmed"
}

append_file_or_note() {
    local report="$1"
    local title="$2"
    local file="$3"

    {
        echo
        echo "========== $title =========="
        if [[ -s "$file" ]]; then
            cat "$file"
        else
            echo "No results collected for this section."
        fi
    } >> "$report"
}

write_session_metadata() {
    local file="$RUN_DIR/session_meta.txt"
    {
        echo "Target=$TARGET"
        echo "TargetSafe=$TARGET_SAFE"
        echo "RunID=$RUN_ID"
        echo "Started=$(now)"
        echo "User=$(whoami 2>/dev/null || echo unknown)"
        echo "Host=$(hostname 2>/dev/null || echo unknown)"
        echo "Kernel=$(uname -sr 2>/dev/null || echo unknown)"
    } > "$file"
    copy_latest "$file" "session_meta.txt"
}

show_tool_versions() {
    local file="$RUN_DIR/tool_versions.txt"
    : > "$file"

    for tool in "${REQUIRED_TOOLS[@]}" "${OPTIONAL_TOOLS[@]}"; do
        if tool_exists "$tool"; then
            {
                echo "[$tool]"
                "$tool" --version 2>/dev/null | head -n 1 || "$tool" -version 2>/dev/null | head -n 1 || "$tool" -V 2>/dev/null | head -n 1
                echo
            } >> "$file"
        fi
    done

    copy_latest "$file" "tool_versions.txt"
}

print_run_summary() {
    print_info "Run summary"
    echo "Target      : $TARGET"
    echo "Run ID      : $RUN_ID"
    echo "Run folder  : $RUN_DIR"
    echo "Latest files: $TARGET_DIR"
}

prompt_target_if_missing() {
    if [[ -z "$TARGET" ]]; then
        read -r -p "Enter target domain or IP > " input
        if ! validate_target "$input"; then
            print_error "Invalid target format"
            return 1
        fi
        validate_target_scope "$input" || return 1
        init_session "$input"
        write_session_metadata
        show_tool_versions
    fi
    return 0
}
