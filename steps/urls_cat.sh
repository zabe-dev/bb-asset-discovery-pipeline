#!/opt/homebrew/bin/bash

step_4() {
    echo
    print_step "4" "URL categorization phase"

    if [[ ! -s "$CRAWLED_URLS" ]]; then
        warning "No URLs to categorize"
        touch "$SENSITIVE_URLS" "$API_URLS" "$STATIC_URLS"
        return 0
    fi

    progress "Extracting URLs..."

    extract_sensitive() {
        if grep -Ea '([?&])(code|token|ticket|key|secret|password|pass|pwd|auth|session|sid|jwt|bearer|access_token|refresh_token|api_key|apikey|client_secret|private_key|oauth|callback|redirect|redirect_uri|state|nonce)=' "$CRAWLED_URLS" | sort -u > "$SENSITIVE_URLS"; then
            count=$(wc -l < "$SENSITIVE_URLS" | awk '{print $1}')
            success "Sensitive URLs: $count entries"
        else
            touch "$SENSITIVE_URLS"
        fi
    }

    extract_apis() {
        if grep -Ea '^https?://api\.|^https?://[^/]+/api(/v[0-9]+)?|/graphql|/graphiql|/playground|/api/v[0-9]+|/v[1-6]/graphql|\.api\.' "$CRAWLED_URLS" | grep -Ev '\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|ttf)' | sort -u > "$API_URLS"; then
            count=$(wc -l < "$API_URLS" | awk '{print $1}')
            success "API endpoints: $count entries"
        else
            touch "$API_URLS"
        fi
    }

    extract_static() {
        if grep -Eao 'https?://\S*\.(js|css|txt|json|xml|pdf|doc|docx|xls|xlsx|ppt|pptx|zip|tar|gz|rar|7z|exe|dmg|pkg|deb|rpm|iso|img|svg|ico|woff|woff2|ttf|eot|otf|mp3|mp4|wav|avi|mov|wmv|flv|webm|ogg|png|jpg|jpeg|gif|bmp|tiff|webp)(\?\S*)?' "$CRAWLED_URLS" | sort -u > "$STATIC_URLS"; then
            count=$(wc -l < "$STATIC_URLS" | awk '{print $1}')
            success "Static file URLs: $count entries"
        else
            touch "$STATIC_URLS"
        fi
    }

    extract_sensitive &
    extract_apis &
    extract_static &
    wait
}
