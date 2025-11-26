#!/usr/bin/env bash

# =========================================
#               CONFIGURATION
# =========================================

readonly CONFIG_FILE="release-config.json"
readonly DEFAULT_CONFIG='{}'

if ! command -v jq &> /dev/null; then
    log_fatal "Command \"jq\" not found"
fi

# =========================================
#           CONFIG FUNCTIONS
# =========================================

setup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        CONFIG_CONTENT=$(< "$CONFIG_FILE")
    else
        log_warning "Config file $CONFIG_FILE not found. Using default configuration."
        CONFIG_CONTENT="$DEFAULT_CONFIG"
    fi
}

get_config_value() {
    local key="$1"  # e.g., "repository.url"
    echo "$CONFIG_CONTENT" | jq -r --arg key "$key" '.[$key] // empty'
}
