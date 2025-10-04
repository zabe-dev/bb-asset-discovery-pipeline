#!/opt/homebrew/bin/bash

step_2() {
    echo
    print_step "2" "URL discovery phase"
    progress "Looking for URLs..."

    if [[ -s "$SCOPE_DIR/domains.txt" ]]; then
        sort -u "$SCOPE_DIR/domains.txt" > "$SCOPE_DIR/url-targets.txt"
        URL_DISCOVERY_INPUT="$SCOPE_DIR/url-targets.txt"
    else
        URL_DISCOVERY_INPUT="$DOMAIN"
        warning "No resolved domains found, using original target"
    fi

    run_waymore() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            waymore -mode U -t 5 -p 2 -lr 60 -r 5 -oU "$SCOPE_DIR/wurls.txt" -i "$DOMAIN" >/dev/null 2>&1
            count=$(wc -l < "$SCOPE_DIR/wurls.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[waymore] $count URLs collected"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[waymore] 0 URLs collected"
                touch "$SCOPE_DIR/wurls.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_katana() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            if [[ "$URL_DISCOVERY_INPUT" == *.txt ]]; then
                katana -silent -list "$URL_DISCOVERY_INPUT" -jc -d "$CRAWL_DEPTH" -o "$SCOPE_DIR/kurls.txt" >/dev/null 2>&1
            else
                katana -silent -u "$URL_DISCOVERY_INPUT" -jc -d "$CRAWL_DEPTH" -o "$SCOPE_DIR/kurls.txt" >/dev/null 2>&1
            fi
            count=$(wc -l < "$SCOPE_DIR/kurls.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$count" -gt 0 ]; then
                success "[katana] $count URLs collected"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[katana] 0 URLs collected"
                touch "$SCOPE_DIR/kurls.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_paramspider() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            if [[ "$URL_DISCOVERY_INPUT" == *.txt ]]; then
                paramspider -l "$URL_DISCOVERY_INPUT" > "$SCOPE_DIR/paramspider_output.txt" 2>&1
            else
                paramspider -d "$URL_DISCOVERY_INPUT" > "$SCOPE_DIR/paramspider_output.txt" 2>&1
            fi
            if [[ -d "results" ]]; then
                cat results/*.txt 2>/dev/null | sed 's/[&?][^&?]*=FUZZ//g' | sort -u > "$SCOPE_DIR/purls.txt" || touch "$SCOPE_DIR/purls.txt"
            elif [[ -f "$SCOPE_DIR/paramspider_output.txt" ]]; then
                sed 's/[&?][^&?]*=FUZZ//g' "$SCOPE_DIR/paramspider_output.txt" | sort -u > "$SCOPE_DIR/purls.txt"
            else
                touch "$SCOPE_DIR/purls.txt"
            fi
            count=$(wc -l < "$SCOPE_DIR/purls.txt" 2>/dev/null | awk '{print $1}' || echo "0")
            rm -f "$SCOPE_DIR/paramspider_output.txt"
            rm -rf results
            if [ "$count" -gt 0 ]; then
                success "[paramspider] $count URLs collected"
                return 0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[paramspider] 0 URLs collected"
                touch "$SCOPE_DIR/purls.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_hakrawler() {
        local max_attempts=4
        local attempt=1
        local count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            if [[ "$URL_DISCOVERY_INPUT" != *.txt || -s "$URL_DISCOVERY_INPUT" ]]; then
                if [[ "$URL_DISCOVERY_INPUT" == *.txt ]]; then
                    cat "$URL_DISCOVERY_INPUT" | hakrawler -u -i -subs -dr -insecure > "$SCOPE_DIR/hurls-raw.txt" 2>/dev/null
                else
                    hakrawler -u "$URL_DISCOVERY_INPUT" -i -subs -dr -insecure > "$SCOPE_DIR/hurls-raw.txt" 2>/dev/null
                fi
                count=$(wc -l < "$SCOPE_DIR/hurls-raw.txt" 2>/dev/null | awk '{print $1}' || echo "0")
                if [ "$count" -gt 0 ]; then
                    success "[hakrawler] $count URLs collected"
                    return 0
                fi
            else
                count=0
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[hakrawler] 0 URLs collected"
                touch "$SCOPE_DIR/hurls-raw.txt"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    run_waymore
    wait
    run_katana &
    run_paramspider &
    run_hakrawler &
    wait

    total_urls=$(awk 'END{print NR}' "$SCOPE_DIR/wurls.txt" "$SCOPE_DIR/kurls.txt" "$SCOPE_DIR/purls.txt" "$SCOPE_DIR/hurls-raw.txt" 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
    success "Total collected: $total_urls URLs"
}
