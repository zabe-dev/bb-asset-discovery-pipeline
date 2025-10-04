#!/opt/homebrew/bin/bash

step_6() {
    echo
    print_step "6" "Asset URLs validation phase"
    progress "Checking for responsive URLs..."

    validate_static_urls() {
        if [[ -s "$ALL_STATIC_URLS_RAW" ]]; then
            if run_httpx "$ALL_STATIC_URLS_RAW" "$LIVE_STATIC_URLS"; then
                resolved_count=$(wc -l < "$LIVE_STATIC_URLS" 2>/dev/null | awk '{print $1}' || echo "0")
                success "[static] $resolved_count URLs resolved"
            else
                error "[httpx] Couldn't finish URL validation"
                touch "$LIVE_STATIC_URLS"
            fi
        else
            error "[static] 0 URLs resolved"
            touch "$LIVE_STATIC_URLS"
        fi
    }

    validate_static_urls &
    wait

    cp "$LIVE_STATIC_URLS" "$SCOPE_DIR/download.txt" 2>/dev/null || touch "$SCOPE_DIR/download.txt"
}
