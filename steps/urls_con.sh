#!/opt/homebrew/bin/bash

step_3() {
    echo
    print_step "3" "URL consolidation phase"

    if [[ -s "$SCOPE_DIR/hurls-raw.txt" ]]; then
        > "$SCOPE_DIR/hurls.txt"

        clean_domain=$(extract_domain "$DOMAIN")
        grep -i "$clean_domain" "$SCOPE_DIR/hurls-raw.txt" >> "$SCOPE_DIR/hurls.txt"

        sort -u -o "$SCOPE_DIR/hurls.txt" "$SCOPE_DIR/hurls.txt"
    else
        touch "$SCOPE_DIR/hurls.txt"
    fi

    progress "Merging collected URLs..."

    for file in "$SCOPE_DIR/wurls.txt" "$SCOPE_DIR/kurls.txt" "$SCOPE_DIR/purls.txt" "$SCOPE_DIR/hurls.txt"; do
        [[ ! -f "$file" ]] && touch "$file"
    done

    cat "$SCOPE_DIR/wurls.txt" "$SCOPE_DIR/kurls.txt" "$SCOPE_DIR/purls.txt" "$SCOPE_DIR/hurls.txt" | \
    sort -u > "$SCOPE_DIR/raw-urls.txt"

    progress "Filtering valid URLs..."

    awk '
    /^[[:space:]]*$/ { next }
    {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        url = $0

        if (length(url) > 2048) next
        if (!match(url, /^https?:\/\/[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/)) next
        if (match(url, /[[:space:]<>"'"'"'{}|\\^`\[\]]|\.\.\//)) next
        if (match(url, /(utm_source|utm_medium|utm_campaign|gclid|fbclid)=/)) next
        if (match(url, /^https?:\/\/\/+/)) next

        param_count = 1
        if (match(url, /\?/)) {
            query_part = substr(url, RSTART + 1)
            param_count = gsub(/&/, "&", query_part) + 1
            if (param_count > 5) next
        }

        path_depth = gsub(/\//, "/", url) - 2
        if (path_depth > 5) next

        print url
        clean_count++
    }
    END {
        removed_count = (NR - clean_count)
        if (removed_count > 0) {
            print "[!] Total removed: " removed_count " URLs" > "/dev/stderr"
        }
        if (clean_count == 0) {
            print "[!] 0 URLs found" > "/dev/stderr"
        }
    }
    ' "$SCOPE_DIR/raw-urls.txt" > "$CRAWLED_URLS"

    final_urls=$(wc -l < "$CRAWLED_URLS" | awk '{print $1}')
    success "Total filtered: $final_urls URLs"
}
