#!/usr/bin/env bash

run_url_mining() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/urls.txt"
    local js_out="$RUN_DIR/js_endpoints.txt"
    : > "$out"
    : > "$js_out"

    append_section_header "$out" "URL MINING"
    echo "Target: $TARGET" >> "$out"

    local tmp_dir="$RUN_DIR/.urlmining"
    mkdir -p "$tmp_dir"
    local pids=()

    if tool_exists "gau"; then
        print_info "Queueing gau"
        run_and_log "$tmp_dir/gau.txt" gau "$TARGET" &
        pids+=("$!")
    else
        print_warn "gau not found"
    fi

    if tool_exists "waybackurls"; then
        print_info "Queueing waybackurls"
        run_and_log "$tmp_dir/waybackurls.txt" waybackurls "$TARGET" &
        pids+=("$!")
    else
        print_warn "waybackurls not found"
    fi

    if [[ ${#pids[@]} -gt 0 ]]; then
        print_info "Running URL collectors in parallel"
        for pid in "${pids[@]}"; do
            wait "$pid" || true
        done
        cat "$tmp_dir"/*.txt 2>/dev/null >> "$out" || true
    fi

    if [[ -s "$out" ]]; then
        normalize_urls_file "$out"
    fi

    if [[ -s "$out" ]]; then
        grep -Ei '\.js($|\?)' "$out" | head -n 120 > "$RUN_DIR/js_urls.txt" || true
        if [[ -s "$RUN_DIR/js_urls.txt" ]]; then
            xargs -I {} -P "${MAX_PARALLEL:-5}" sh -c 'curl -sk --max-time 8 "$1" 2>/dev/null | grep -Eo "https?://[^\"<> ]+"' _ < "$RUN_DIR/js_urls.txt" >> "$js_out" 2>/dev/null || true
            normalize_urls_file "$js_out"
        fi
    fi

    finalize_output_file "$out" "urls.txt" "urls"
    finalize_output_file "$js_out" "js_endpoints.txt" "urls"

    print_ok "URL mining saved: $TARGET_DIR/urls.txt"
    print_ok "JS endpoint hints: $TARGET_DIR/js_endpoints.txt"
}
