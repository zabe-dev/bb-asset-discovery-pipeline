#!/opt/homebrew/bin/bash

error() { echo "[x] $1" >&2; }
success() { echo "[+] $1"; }
warning() { echo "[!] $1"; }
progress() { echo "[~] $1"; }

print_step() {
    echo "[$1] $2"
}

extract_domain() {
    echo "$1" | sed -E 's|^https?://||; s|^www\.||; s|[:/].*||'
}

run_httpx() {
    local input_file="$1"
    local output_file="$2"

    if [[ ! -f "$input_file" ]] || [[ ! -s "$input_file" ]]; then
        touch "$output_file"
        return 0
    fi

    httpx -l "$input_file" -o "$output_file" -silent -fr >/dev/null 2>&1

    if [[ -f "$output_file" ]]; then
        return 0
    else
        error "httpx failed"
        touch "$output_file"
        return 1
    fi
}

filter_domains() {
    local input_domains="$1"
    local target_domain="$2"
    local output_file="$3"

    > "$output_file"

    clean_domain=$(extract_domain "$target_domain")
    grep -E "\.${clean_domain}$|^${clean_domain}$" "$input_domains" | sort -u > "$output_file" 2>/dev/null || touch "$output_file"

    count=$(wc -l < "$output_file" 2>/dev/null | awk '{print $1}' || echo "0")
    success "Filtered $count domains as targets"
}

count_file_lines() {
    if [[ -f "$1" && -s "$1" ]]; then
        wc -l < "$1" | awk '{print $1}'
    else
        echo "0"
    fi
}

show_summary() {
    echo
    echo "[+] Domain Enumeration"
    echo "| subfinder: $(count_file_lines "$SCOPE_DIR/subfinder.txt")"
    echo "| findomain: $(count_file_lines "$SCOPE_DIR/findomain.txt")"
    echo "| assetfinder: $(count_file_lines "$SCOPE_DIR/assetfinder.txt")"
    echo "| tlsx: $(count_file_lines "$SCOPE_DIR/tlsx-domains.txt")"
    echo "| crt.sh: $(count_file_lines "$SCOPE_DIR/crtsh.txt")"
    echo "| chaos: $(count_file_lines "$SCOPE_DIR/chaos.txt")"
    echo "| dnsx: $(count_file_lines "$SCOPE_DIR/dnsx.txt")"
    echo "| shuffledns: $(count_file_lines "$SCOPE_DIR/shuffledns.txt")"
    echo "| Total unique: $(count_file_lines "$SCOPE_DIR/domains-raw.txt")"
    echo "| Resolved domains: $(count_file_lines "$SCOPE_DIR/domains-resolved.txt")"
    echo "| Filtered domains: $(count_file_lines "$SCOPE_DIR/domains.txt")"

    echo
    echo "[+] URL Enumeration"
    echo "| waymore: $(count_file_lines "$SCOPE_DIR/wurls.txt")"
    echo "| katana: $(count_file_lines "$SCOPE_DIR/kurls.txt")"
    echo "| paramspider: $(count_file_lines "$SCOPE_DIR/purls.txt")"
    echo "| hakrawler: $(count_file_lines "$SCOPE_DIR/hurls.txt")"
    echo "| Raw unique URLs: $(count_file_lines "$SCOPE_DIR/raw-urls.txt")"
    echo "| Filtered URLs: $(count_file_lines "$CRAWLED_URLS")"

    echo
    echo "[+] Categorized URLs"
    echo "| Sensitive URLs: $(count_file_lines "$SENSITIVE_URLS")"
    echo "| API endpoints: $(count_file_lines "$API_URLS")"
    echo "| Static file URLs: $(count_file_lines "$ALL_STATIC_URLS_RAW")"
    echo "| Resolved static URLs: $(count_file_lines "$LIVE_STATIC_URLS")"
    echo "| Total URLs found: $(($(count_file_lines "$SENSITIVE_URLS") + $(count_file_lines "$API_URLS") + $(count_file_lines "$LIVE_STATIC_URLS")))"

    cleanup
}
