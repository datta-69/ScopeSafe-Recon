#!/usr/bin/env bash

run_url_mining() {
    prompt_target_if_missing || return 1

    local out="$RUN_DIR/urls.txt"
    local js_out="$RUN_DIR/js_endpoints.txt"
    : > "$out"
    : > "$js_out"

    append_section_header "$out" "URL MINING"
    echo "Target: $TARGET" >> "$out"

    if tool_exists "gau"; then
        run_with_spinner "$out" "Collecting URLs with gau" gau "$TARGET"
    else
        print_warn "gau not found"
    fi

    if tool_exists "waybackurls"; then
        run_with_spinner "$out" "Collecting URLs with waybackurls" waybackurls "$TARGET"
    else
        print_warn "waybackurls not found"
    fi

    if [[ -s "$out" ]]; then
        sort -u "$out" -o "$out"
    fi

    if [[ -s "$out" ]]; then
        grep -Ei '\.js($|\?)' "$out" | head -n 80 > "$RUN_DIR/js_urls.txt" || true
        if [[ -s "$RUN_DIR/js_urls.txt" ]]; then
            while IFS= read -r js_url; do
                curl -sk --max-time 8 "$js_url" 2>/dev/null |
                    grep -Eo 'https?://[^"<> ]+' >> "$js_out" || true
            done < "$RUN_DIR/js_urls.txt"
            sort -u "$js_out" -o "$js_out" 2>/dev/null || true
        fi
    fi

    copy_latest "$out" "urls.txt"
    copy_latest "$js_out" "js_endpoints.txt"

    print_ok "URL mining saved: $TARGET_DIR/urls.txt"
    print_ok "JS endpoint hints: $TARGET_DIR/js_endpoints.txt"
}
