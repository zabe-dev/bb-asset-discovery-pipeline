#!/usr/bin/env bash

step_5() {
    echo
    print_step "5" "JavaScript discovery phase"
    progress "Looking for JavaScript files..."

    discover_js_with_getjs() {
        if [[ -s "$SCOPE_DIR/domains.txt" ]]; then
            GETJS_INPUT="$SCOPE_DIR/domains.txt"
        else
            GETJS_INPUT="$DOMAIN"
        fi

        if ! ( [[ "$GETJS_INPUT" == *.txt ]] && grep -q '[^[:space:]]' "$GETJS_INPUT" ) && [[ "$GETJS_INPUT" != *.txt || ! -s "$GETJS_INPUT" ]]; then
            warning "[getjs] No domains for JS"
            touch "$GETJS_RAW_URLS"
            return
        fi

        local max_attempts=4
        local attempt=1
        local final_count=0
        local interval=15

        while [ $attempt -le $max_attempts ]; do
            > "$GETJS_RAW_URLS"

            if [[ "$GETJS_INPUT" == *.txt ]]; then
                while IFS= read -r domain; do
                    [[ -z "$domain" ]] && continue

                    clean_domain=$(echo "$domain" | awk '{gsub(/^https?:\/\//, ""); gsub(/^www\./, ""); gsub(/\/.*/, ""); print tolower($0)}')

                    getJS -input <(echo "$domain") | while IFS= read -r jsurl; do
                        [[ -z "$jsurl" ]] && continue

                        if [[ "$jsurl" =~ ^/ ]]; then
                            echo "https://$clean_domain$jsurl" >> "$GETJS_RAW_URLS"

                        elif [[ "$jsurl" =~ ^\.\.?/ ]]; then
                            continue

                        elif [[ "$jsurl" =~ ^https?:// ]]; then
                            js_host=$(echo "$jsurl" | sed -E 's|^[a-zA-Z]+://([^/]+).*|\1|' | LC_ALL=C tr 'A-Z' 'a-z')

                            if [[ "$js_host" == *".$clean_domain" ]] || [[ "$js_host" == "$clean_domain" ]]; then
                                echo "$jsurl" >> "$GETJS_RAW_URLS"
                            fi
                        fi
                    done
                done < "$GETJS_INPUT"
            else
                clean_domain=$(echo "$GETJS_INPUT" | awk '{gsub(/^https?:\/\//, ""); gsub(/^www\./, ""); gsub(/\/.*/, ""); print tolower($0)}')

                getJS --url "$GETJS_INPUT" | while IFS= read -r jsurl; do
                    [[ -z "$jsurl" ]] && continue

                    if [[ "$jsurl" =~ ^/ ]]; then
                        echo "https://$clean_domain$jsurl" >> "$GETJS_RAW_URLS"

                    elif [[ "$jsurl" =~ ^\.\.?/ ]]; then
                        continue

                    elif [[ "$jsurl" =~ ^https?:// ]]; then
                        js_host=$(echo "$jsurl" | sed -E 's|^[a-zA-Z]+://([^/]+).*|\1|' | LC_ALL=C tr 'A-Z' 'a-z')

                        if [[ "$js_host" == *".$clean_domain" ]] || [[ "$js_host" == "$clean_domain" ]]; then
                            echo "$jsurl" >> "$GETJS_RAW_URLS"
                        fi
                    fi
                done
            fi

            if [[ -s "$GETJS_RAW_URLS" ]]; then
                sort -u -o "$GETJS_RAW_URLS" "$GETJS_RAW_URLS"
                final_count=$(wc -l < "$GETJS_RAW_URLS" | awk '{print $1}')
                if [ "$final_count" -gt 0 ]; then
                    success "[getjs] $final_count in-scope URLs found"
                    return 0
                fi
            fi

            if [ $attempt -eq $max_attempts ]; then
                success "[getjs] 0 in-scope URLs found"
                touch "$GETJS_RAW_URLS"
                return 0
            fi

            sleep $interval
            ((attempt++))
        done
    }

    discover_js_with_getjs &
    wait

    cat "$STATIC_URLS" "$GETJS_RAW_URLS" 2>/dev/null | grep -E '\.(js|css|txt|json|xml|pdf|doc|docx|xls|xlsx|ppt|pptx|zip|tar|gz|rar|7z|exe|dmg|pkg|deb|rpm|iso|img|svg|ico|woff|woff2|ttf|eot|otf|mp3|mp4|wav|avi|mov|wmv|flv|webm|ogg|png|jpg|jpeg|gif|bmp|tiff|webp)(\?|$)' | sort -u > "$ALL_STATIC_URLS_RAW"

    if [[ -s "$ALL_STATIC_URLS_RAW" ]]; then
        total_count=$(wc -l < "$ALL_STATIC_URLS_RAW" | awk '{print $1}')
        success "Total found: $total_count URLs"
    else
        warning "No URLs available for analysis"
        touch "$ALL_STATIC_URLS_RAW"
    fi
}
