#!/usr/bin/env bash

# =========================================
#               CONFIGURATION
# =========================================
readonly CONFIG_FILE="${CONFIG_FILE_PATH:-release-config.json}"
readonly DEFAULT_CONFIG='{"github": {"active": true}}'
readonly DEFAULT_COMMIT_TYPES='[
  {"type": "feat", "section": "Features", "bump": "minor", "hidden": false},
  {"type": "fix", "section": "Bug Fixes", "bump": "patch", "hidden": false},
  {"type": "perf", "section": "Performance", "bump": "patch", "hidden": false},
  {"type": "revert", "section": "Reverts", "bump": "patch", "hidden": false},
  {"type": "docs", "section": "Documentation", "bump": "none", "hidden": true},
  {"type": "style", "section": "Styles", "bump": "none", "hidden": true},
  {"type": "chore", "section": "Chores", "bump": "none", "hidden": true},
  {"type": "refactor", "section": "Refactor", "bump": "none", "hidden": true},
  {"type": "test", "section": "Tests", "bump": "none", "hidden": true},
  {"type": "build", "section": "Build", "bump": "none", "hidden": true},
  {"type": "ci", "section": "CI", "bump": "none", "hidden": true}
]'

# =========================================
#           LOAD CONFIGURATION
# =========================================

setup_config() {
    if ! command -v jq &> /dev/null; then
        log_fatal "Command \"jq\" not found. It is required for configuration parsing."
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        CONFIG_CONTENT=$(< "$CONFIG_FILE")
    else
        log_warning "Config file $CONFIG_FILE not found. Using default configuration."
        CONFIG_CONTENT="$DEFAULT_CONFIG"
    fi
}

get_config_value() {
    local key="$1"
    echo "$CONFIG_CONTENT" | jq -r --arg path "$key" 'getpath($path | split(".")) // empty'
}

# =========================================
#       SPECIFIC CONFIG TOOLS
# =========================================

check_github_active() {
    local github_exists=$(get_config_value "github")

    if [[ -n "$github_exists" && "$github_exists" != "null" ]]; then
        local is_active=$(get_config_value "github.active")

        if [[ "$is_active" == "true" ]]; then
            return 0 # True
        fi
    fi

    return 1 # False
}

get_commit_types() {
    local custom_types=$(echo "$CONFIG_CONTENT" | jq -c '.commitTypes // empty')

    if [[ -n "$custom_types" && "$custom_types" != "null" ]]; then
        echo "$custom_types"
    else
        echo "$DEFAULT_COMMIT_TYPES"
    fi
}
