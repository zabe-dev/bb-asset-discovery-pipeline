#!/usr/bin/env bash

step_1() {
    echo
    print_step "1" "Domain discovery phase"
    progress "Looking for domains..."

    run_subfinder() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            subfinder -silent -all -d "$DOMAIN" -o "$SCOPE_DIR/subfinder.txt" >/dev/null 2>&1
            count=$(wc -l < "$SCOPE_DIR/subfinder.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[subfinder] $count domains found"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[subfinder] 0 domains found"
                touch "$SCOPE_DIR/subfinder.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_findomain() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            findomain -t "$DOMAIN" -q -r -u "$SCOPE_DIR/findomain.txt" >/dev/null 2>&1
            count=$(wc -l < "$SCOPE_DIR/findomain.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[findomain] $count domains found"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[findomain] 0 domains found"
                touch "$SCOPE_DIR/findomain.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_assetfinder() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            assetfinder -subs-only "$DOMAIN" > "$SCOPE_DIR/assetfinder.txt" 2>/dev/null
            count=$(wc -l < "$SCOPE_DIR/assetfinder.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[assetfinder] $count domains found"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[assetfinder] 0 domains found"
                touch "$SCOPE_DIR/assetfinder.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_tlsx() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            tlsx -u "$DOMAIN" -san -cn -silent -resp-only > "$SCOPE_DIR/tlsx.txt" 2>/dev/null
            count=$(wc -l < "$SCOPE_DIR/tlsx.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[tlsx] $count assets found"
                if [[ -s "$SCOPE_DIR/tlsx.txt" ]]; then
                    grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' "$SCOPE_DIR/tlsx.txt" | sort -u > "$SCOPE_DIR/tlsx-domains.txt" 2>/dev/null || touch "$SCOPE_DIR/tlsx-domains.txt"
                else
                    touch "$SCOPE_DIR/tlsx-domains.txt"
                fi
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[tlsx] 0 assets found"
                touch "$SCOPE_DIR/tlsx.txt" "$SCOPE_DIR/tlsx-domains.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_crtsh() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15
        local tmp_file="$(mktemp)"
        local output_file="$SCOPE_DIR/crtsh.txt"

        > "$output_file"

        while [ $attempt -le $max_attempts ]; do
            crt_data=$(curl -s --connect-timeout 10 "https://crt.sh/?q=%25.$DOMAIN&output=json")

            if [[ -n "$crt_data" ]]; then
                echo "$crt_data" | jq -r ".[].common_name, .[].name_value" 2>/dev/null | \
                    LC_ALL=C tr 'A-Z' 'a-z' | sort -u > "$tmp_file"

                if [[ -s "$tmp_file" ]]; then
                    mv "$tmp_file" "$output_file"
                    count=$(wc -l < "$output_file" | awk '{print $1}')
                    success "[crt.sh] $count domains found"
                    rm -f "$tmp_file"
                    return 0
                fi
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[crt.sh] 0 domains found"
                rm -f "$tmp_file"
                touch "$output_file"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_chaos() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        if [[ -z "${CHAOS_API_KEY:-}" ]]; then
            warning "[chaos] CHAOS_API_KEY not set"
            touch "$SCOPE_DIR/chaos.txt"
            return 0
        fi

        while [ $attempt -le $max_attempts ]; do
            chaos -key "$CHAOS_API_KEY" -d "$DOMAIN" -silent -o "$SCOPE_DIR/chaos.txt" >/dev/null 2>&1
            count=$(wc -l < "$SCOPE_DIR/chaos.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[chaos] $count domains found"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[chaos] 0 domains found"
                touch "$SCOPE_DIR/chaos.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_shuffledns() {
        if [[ "$RUN_SHUFFLEDNS" != true ]]; then
            touch "$SCOPE_DIR/shuffledns.txt"
            return
        fi

        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            shuffledns -d "$DOMAIN" -w "$WORDLIST_PATH" -r "$RESOLVERS_PATH" -mode bruteforce -silent -o "$SCOPE_DIR/shuffledns.txt" >/dev/null 2>&1
            count=$(wc -l < "$SCOPE_DIR/shuffledns.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[shuffledns] $count domains found"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[shuffledns] 0 domains found"
                touch "$SCOPE_DIR/shuffledns.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_port_scan() {
        if [[ "$RUN_PORT_SCAN" != true ]]; then
            return
        fi

        if [[ ! -s "$SCOPE_DIR/domains.txt" ]]; then
            warning "[port scan] No domains to scan"
            return
        fi

        progress "[port scan] Starting port scan..."

        cat "$SCOPE_DIR/domains.txt" | dnsx -silent -r "$RESOLVERS_PATH" -ro | naabu -silent -tp full -nmap-cli 'nmap -sV -oX nmap-output.xml' >/dev/null 2>&1

        if [[ -f "nmap-output.xml" ]]; then
            mv nmap-output.xml "$SCOPE_DIR/nmap-output.xml"
            success "[port scan] Scan completed"
        else
            warning "[port scan] No results generated"
        fi
    }

    run_crtsh
    run_chaos
    run_subfinder
    run_assetfinder
    run_findomain
    run_tlsx
    run_shuffledns

    cat "$SCOPE_DIR/subfinder.txt" "$SCOPE_DIR/findomain.txt" "$SCOPE_DIR/assetfinder.txt" "$SCOPE_DIR/tlsx-domains.txt" "$SCOPE_DIR/crtsh.txt" "$SCOPE_DIR/chaos.txt" "$SCOPE_DIR/shuffledns.txt" 2>/dev/null | sort -u > "$SCOPE_DIR/domains-raw.txt"

    run_httpx "$SCOPE_DIR/domains-raw.txt" "$SCOPE_DIR/domains-resolved.txt"

    if [[ -s "$SCOPE_DIR/domains-resolved.txt" ]]; then
        count_res=$(wc -l < "$SCOPE_DIR/domains-resolved.txt" | awk '{print $1}')
        count_raw=$(wc -l < "$SCOPE_DIR/domains-raw.txt" | awk '{print $1}')
        success "Found $count_res/$count_raw reponsive domains"
    fi

    filter_domains "$SCOPE_DIR/domains-resolved.txt" "$DOMAIN" "$SCOPE_DIR/domains.txt"

    if [[ "$TAKE_SCREENSHOTS" == true ]]; then
        if [[ -s "$SCOPE_DIR/domains.txt" ]]; then
            (
                cd "$SCOPE_DIR" || return
                gowitness scan file -f "domains.txt" --write-none >/dev/null 2>&1
            )
            success "Screenshots taken for visual review"
        else
            warning "No domains to capture screenshots"
        fi
    fi

    run_port_scan
}
