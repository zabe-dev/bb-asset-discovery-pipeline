#!/opt/homebrew/bin/bash

cleanup() {
    rm -f /tmp/httpx_* /tmp/scope_*.txt 2>/dev/null || true
    rm -rf results 2>/dev/null || true
}
