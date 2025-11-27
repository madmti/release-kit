#!/usr/bin/env bash
#
# GitHub Platform Integration Module
#
# Provides functions for creating GitHub releases using the GitHub CLI.
# This module is loaded conditionally when GitHub integration is enabled
# in the configuration. Handles release creation with proper error handling.
#
# Functions:
#   - check_gh_cli()            Validates GitHub CLI availability
#   - create_gh_release()       Creates GitHub release with tag and notes
#   - publish_floating_release() Creates/updates floating GitHub releases
#
# Dependencies:
#   - gh (GitHub CLI tool)
#   - log.sh (for logging functions)
#
# Environment Variables:
#   GITHUB_TOKEN - Required for GitHub CLI authentication

#######################################
# Verify GitHub CLI tool is installed and available
# Checks if the 'gh' command is available in PATH. Required for GitHub
# release creation functionality.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   Does not return on failure (script exits via log_fatal)
# Exits:
#   1 if GitHub CLI is not installed
#######################################
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log_fatal "GitHub CLI (gh) is not installed. Please install it to proceed."
    fi
}

#######################################
# Create GitHub release with specified tag and release notes
# Creates a new GitHub release using the GitHub CLI with the provided
# tag name and release notes. Falls back to automated message if notes are empty.
# Globals:
#   None
# Arguments:
#   $1: tag - Git tag name for the release (e.g., "v1.2.3")
#   $2: notes - Release notes content (markdown format supported)
# Outputs:
#   Progress information via log_info
#   GitHub CLI output to stdout/stderr
# Returns:
#   0 on success, non-zero on GitHub CLI failure
# Notes:
#   - Requires GITHUB_TOKEN environment variable for authentication
#   - Tag must already exist in the repository
#   - Release title will match the tag name
#######################################
create_gh_release() {
    local tag="$1"
    local notes="$2"

    # Provide default notes if none specified
    if [ -z "$notes" ]; then
            notes="Automated release $tag"
    fi

    log_info "Creating GitHub release for tag $tag"
    gh release create "$tag" \
        --title "$tag" \
        --notes "$notes"
}

#######################################
# Create or update floating GitHub release
# Creates a GitHub release for a floating tag (latest, v1, v2, etc.) that points
# to a specific semantic version release. Deletes any existing release with the
# same floating tag name and recreates it to ensure it always references the
# latest version. This enables users to consume floating releases in GitHub Actions.
# SECURITY WARNING: Deletes and recreates releases which may affect download statistics.
# Globals:
#   None
# Arguments:
#   $1: float_tag - Floating tag name (e.g., "latest", "v1", "v2")
#   $2: real_tag - Actual semantic version tag this floating release points to (e.g., "v1.2.3")
#   $3: notes - Original release notes from the semantic version release
# Outputs:
#   Progress information via log_info
#   GitHub CLI output to stdout/stderr
# Returns:
#   0 on success, non-zero on GitHub CLI failure
# Side Effects:
#   - Deletes existing GitHub release with floating tag name (if exists)
#   - Creates new GitHub release with floating tag name
#   - Sets latest=false to prevent interference with main releases
# Usage Examples:
#   publish_floating_release "latest" "v1.2.3" "Release notes..."
#   publish_floating_release "v1" "v1.2.3" "Release notes..."
# GitHub Actions Usage:
#   Users can then reference 'uses: owner/repo@latest' or 'uses: owner/repo@v1'
#######################################

publish_floating_release() {
    local float_tag="$1"
    local real_tag="$2"
    local notes="$3"

    log_info "Updating GitHub Release for floating tag '$float_tag' → $real_tag..."

    # Delete existing floating release (ignore errors if it doesn't exist)
    # The -y flag bypasses confirmation prompt
    gh release delete "$float_tag" -y 2>/dev/null || true

    # Create new floating release pointing to the semantic version
    # --latest=false prevents this from being marked as the "latest" release
    # which should be reserved for the actual semantic version releases
    gh release create "$float_tag" \
        --title "$float_tag (Matches $real_tag)" \
        --notes "This is a floating release that points to the latest version: **$real_tag**.

$notes" \
        --latest=false
}
