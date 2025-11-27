#!/usr/bin/env bash
#
# Configuration Management Module
#
# Handles loading and parsing of release configuration from JSON files.
# Provides safe access to configuration values with fallback defaults.
# Supports both custom configuration files and built-in default values.
#
# Functions:
#   - setup_config()          Initialize configuration system and validate dependencies
#   - get_config_value()      Safely extract values from configuration using jq path syntax
#   - check_github_enable()   Check if GitHub integration is enabled
#   - get_commit_types()      Get commit type definitions (custom or default)
#   - check_changelog_enable() Check if changelog generation is enabled
#   - get_changelog_output()  Get configured changelog output path
#   - check_update_latest()   Check if 'latest' floating tag should be updated
#   - check_update_majors()   Check if major version floating tags should be updated
#
# Global Variables:
#   CONFIG_CONTENT - Holds the parsed configuration content (populated by setup_config)
#
# Dependencies: jq (required for JSON parsing)

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

#######################################
# Initialize configuration system and load config file
# Validates that required dependencies are available and loads configuration
# from file or uses default configuration as fallback.
# Globals:
#   CONFIG_FILE (readonly)
#   CONFIG_CONTENT (set by this function)
#   DEFAULT_CONFIG (readonly)
# Arguments:
#   None
# Outputs:
#   Writes warning to stderr if config file not found
# Returns:
#   0 on success
# Exits:
#   1 if jq command is not available
#######################################
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

#######################################
# Safely extract configuration value using jq path syntax
# Retrieves configuration values using dot-notation paths (e.g., "github.enable").
# Returns empty string for missing or null values.
# Globals:
#   CONFIG_CONTENT
# Arguments:
#   $1: key - Dot-separated path to configuration value (e.g., "github.enable")
# Outputs:
#   Writes configuration value to stdout, or empty string if not found
# Returns:
#   0 always
# Examples:
#   get_config_value "github.enable"     # returns: true/false
#   get_config_value "changelog.output"  # returns: path or empty
#######################################
get_config_value() {
    local key="$1"
    echo "$CONFIG_CONTENT" | jq -r --arg path "$key" 'getpath($path | split(".")) // empty'
}

# =========================================
#       SPECIFIC CONFIG TOOLS
# =========================================

#######################################
# Check if GitHub integration is enabled in configuration
# Examines the configuration for GitHub settings and determines if
# GitHub release creation should be performed.
# Globals:
#   CONFIG_CONTENT (via get_config_value)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0 if GitHub integration is enabled, 1 otherwise
#######################################
check_github_enable() {
    local github_exists=$(get_config_value "github")

    if [[ -n "$github_exists" && "$github_exists" != "null" ]]; then
        local is_active=$(get_config_value "github.enable")

        if [[ "$is_active" == "true" ]]; then
            return 0 # True
        fi
    fi

    return 1 # False
}

#######################################
# Get commit type configuration array
# Returns either custom commit types from configuration file or default
# commit types if no custom configuration is provided.
# Globals:
#   CONFIG_CONTENT
#   DEFAULT_COMMIT_TYPES (readonly)
# Arguments:
#   None
# Outputs:
#   Writes JSON array of commit type definitions to stdout
# Returns:
#   0 always
# Output Format:
#   JSON array with objects containing: type, section, bump, hidden
#######################################
get_commit_types() {
    local custom_types=$(echo "$CONFIG_CONTENT" | jq -c '.commitTypes // empty')

    if [[ -n "$custom_types" && "$custom_types" != "null" ]]; then
        echo "$custom_types"
    else
        echo "$DEFAULT_COMMIT_TYPES"
    fi
}

#######################################
# Check if changelog generation is enabled
# Determines whether the changelog file should be generated and updated.
# Defaults to enabled (true) if not explicitly disabled.
# Globals:
#   CONFIG_CONTENT (via get_config_value)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0 if changelog generation is enabled (default), 1 if disabled
#######################################
check_changelog_enable() {
    local is_enabled=$(get_config_value "changelog.enable")

    if [[ "$is_enabled" == "false" ]]; then
        return 1
    else
        return 0 # Default
    fi
}

#######################################
# Get configured changelog output file path
# Returns the configured path for changelog output, or default path
# if no custom path is configured.
# Globals:
#   CONFIG_CONTENT (via get_config_value)
# Arguments:
#   None
# Outputs:
#   Writes changelog output path to stdout
# Returns:
#   0 always
# Default:
#   "CHANGELOG.md" if no custom path configured
#######################################
get_changelog_output() {
    local output_path=$(get_config_value "changelog.output")

    if [[ -z "$output_path" || "$output_path" == "null" ]]; then
        echo "CHANGELOG.md"
    else
        echo "$output_path"
    fi
}

#######################################
# Check if 'latest' floating tag should be updated
# Determines whether the 'latest' tag should be moved to point to new releases.
# This allows users to reference the most recent stable version using 'latest'.
# Defaults to disabled for safety (force push operations).
# Globals:
#   CONFIG_CONTENT (via get_config_value)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0 if latest tag updates are enabled, 1 if disabled (default)
# Configuration:
#   "floatingTags.latest": true/false
# Security Note:
#   When enabled, performs force push operations that overwrite remote tag history
#######################################
check_update_latest() {
    local enabled=$(get_config_value "floatingTags.latest")

    if [[ "$enabled" == "true" ]]; then
        return 0 # True
    else
        return 1 # False (Default)
    fi
}

#######################################
# Check if major version floating tags should be updated
# Determines whether major version tags (v1, v2, etc.) should be moved to point
# to new releases within the same major version. Enables GitHub Actions usage
# patterns like 'uses: owner/repo@v1' which automatically get latest v1.x.x.
# Defaults to disabled for safety (force push operations).
# Globals:
#   CONFIG_CONTENT (via get_config_value)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0 if major version tag updates are enabled, 1 if disabled (default)
# Configuration:
#   "floatingTags.majors": true/false
# Security Note:
#   When enabled, performs force push operations that overwrite remote tag history
# Examples:
#   Release v1.2.3 → moves 'v1' tag to point to v1.2.3 commit
#   Release v2.0.1 → moves 'v2' tag to point to v2.0.1 commit
#######################################
check_update_majors() {
    local enabled=$(get_config_value "floatingTags.majors")

    if [[ "$enabled" == "true" ]]; then
        return 0 # True
    else
        return 1 # False (Default)
    fi
}
