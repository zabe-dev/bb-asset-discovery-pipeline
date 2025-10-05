#!/opt/homebrew/bin/bash

set -e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/cleanup.sh"
source "$SCRIPT_DIR/steps/domains.sh"
source "$SCRIPT_DIR/steps/urls.sh"
source "$SCRIPT_DIR/steps/urls_con.sh"
source "$SCRIPT_DIR/steps/urls_cat.sh"
source "$SCRIPT_DIR/steps/js.sh"
source "$SCRIPT_DIR/steps/validation.sh"

trap cleanup EXIT INT TERM

show_usage() {
    echo "Usage: $(basename "$0") <domain> [options]"
    echo
    echo "Options:"
    echo "  -ss, --screenshots    Take screenshots of discovered domains"
    echo "  -dx, --dnsx           Enable dnsx for subdomain bruteforcing"
    echo "  -sd, --shuffledns     Enable shuffledns for subdomain bruteforcing"
    echo "  -w, --wordlist        Wordlist path (required when -dx or -sd is used)"
    echo "  -r, --resolvers       Resolvers file path (required when -sd is used)"
    echo "  -h, --help            Show this help message"
    echo
}

DOMAIN=""
WORDLIST_PATH=""
RESOLVERS_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -ss|--screenshots)
            TAKE_SCREENSHOTS=true
            shift
            ;;
        -dx|--dnsx)
            RUN_DNSX=true
            shift
            ;;
        -sd|--shuffledns)
            RUN_SHUFFLEDNS=true
            shift
            ;;
        -w|--wordlist)
            WORDLIST_PATH="$2"
            shift 2
            ;;
        -r|--resolvers)
            RESOLVERS_PATH="$2"
            shift 2
            ;;
        *)
            if [[ -z "$DOMAIN" ]]; then
                DOMAIN=$(extract_domain "$1")
            else
                error "Unexpected argument: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$DOMAIN" ]]; then
    error "Must specify a single domain"
    show_usage
    exit 1
fi

if [[ "$RUN_DNSX" == true || "$RUN_SHUFFLEDNS" == true ]]; then
    if [[ -z "$WORDLIST_PATH" ]]; then
        error "Wordlist path (-w) is required when using -dx or -sd"
        show_usage
        exit 1
    fi
    if [[ ! -f "$WORDLIST_PATH" ]]; then
        error "Wordlist file not found: $WORDLIST_PATH"
        exit 1
    fi
fi

if [[ "$RUN_SHUFFLEDNS" == true ]]; then
    if [[ -z "$RESOLVERS_PATH" ]]; then
        error "Resolvers file path (-r) is required when using -sd"
        show_usage
        exit 1
    fi
    if [[ ! -f "$RESOLVERS_PATH" ]]; then
        error "Resolvers file not found: $RESOLVERS_PATH"
        exit 1
    fi
fi

domain="$DOMAIN"
SCOPE_DIR="scope_$domain"

if [[ -d "$SCOPE_DIR" ]]; then
    rm -rf "$SCOPE_DIR"
fi
mkdir -p "$SCOPE_DIR"

CRAWLED_URLS="$SCOPE_DIR/urls.txt"
SENSITIVE_URLS="$SCOPE_DIR/sen-param-urls.txt"
API_URLS="$SCOPE_DIR/api-urls.txt"
STATIC_URLS="$SCOPE_DIR/static-urls.txt"
GETJS_RAW_URLS="$SCOPE_DIR/getjs-urls-raw.txt"
ALL_STATIC_URLS_RAW="$SCOPE_DIR/all-static-urls-raw.txt"
LIVE_STATIC_URLS="$SCOPE_DIR/static-urls-live.txt"

for step in $(seq 1 6); do
    case $step in
        1) step_1 ;;
        2) step_2 ;;
        3) step_3 ;;
        4) step_4 ;;
        5) step_5 ;;
        6) step_6 ;;
    esac
done

show_summary
