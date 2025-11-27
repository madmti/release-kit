#!/usr/bin/env bash
#
# Bash Release Kit - Main Release Script
#
# Description: Zero-dependency semantic release automation tool for Git repositories.
#              Analyzes commit history based on conventional commits, creates Git tags,
#              generates changelogs, publishes GitHub releases, and updates version
#              numbers in specified files (npm, python, text, etc). Supports floating
#              tags and releases for simplified consumption in GitHub Actions.
#
# Author: MADMTI
# Repository: https://github.com/madmti/release-kit
# License: See LICENSE file (MIT)
#
# Usage: ./release.sh
#
# Environment Variables:
#   CONFIG_FILE_PATH - Path to configuration file (default: release-config.json)
#   GITHUB_TOKEN     - GitHub token for creating releases (required for GitHub integration)
#   DEBUG           - Enable debug logging (true/false, default: false)
#
# Dependencies:
#   - jq           (required for JSON configuration parsing)
#   - git          (required for repository operations)
#   - gh           (optional, required only for GitHub releases and floating releases)
#
# Exit Codes:
#   0 - Success
#   1 - General error (missing dependencies, configuration issues)
#   2 - No new commits since last tag (informational exit)
#
# Security Notes:
#   - Validates all file paths to prevent directory traversal
#   - Sanitizes regex patterns to prevent code injection
#   - Uses safe git operations with proper user validation
#   - Force push operations for floating tags (configurable, disabled by default)
#   - GitHub release deletion/recreation for floating releases (when enabled)
#   - Loop prevention mechanism to avoid infinite releases with PAT tokens

# ======================================== #
#                   INIT
# ======================================== #
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "dev")
source "$SCRIPT_DIR/lib/changelog.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/git.sh"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/semver.sh"
source "$SCRIPT_DIR/lib/updaters.sh"

# ======================================== #
#               Workflow
# ======================================== #

# Initialize the release process
log_info "<< Bash Release Kit [$KIT_VERSION] >>"

# Step 1: Load and validate configuration
setup_config

# Step 1.1: Loop Prevention Mechanism
# Prevents infinite release loops when using Personal Access Tokens (PAT) instead of secrets.GITHUB_TOKEN
# This occurs because PAT commits trigger workflow runs, unlike secrets.GITHUB_TOKEN which doesn't
#######################################
# Check if the last commit is a release commit to prevent release loops
# When using PAT tokens, release commits can trigger new workflow runs, creating
# an infinite loop. This check prevents duplicate releases by detecting previous
# release commits made by the automation system.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Warning message and exits if loop detected
# Returns:
#   Does not return if loop detected (script exits with code 0)
# Exit Scenarios:
#   - Last commit message starts with "chore: release v"
#   - Last commit author is "GitHub Actions"
#   - Both conditions must be true to trigger loop prevention
#######################################
LAST_MSG=$(git log -1 --pretty=%s)
LAST_AUTHOR=$(git log -1 --pretty=%an)
RELEASE_PATTERN="chore: release v"

if [[ $LAST_MSG == $RELEASE_PATTERN* ]] && [[ $LAST_AUTHOR == "GitHub Actions" ]]; then
    log_warning "Loop Prevention: Last commit is a release commit by GitHub Actions. Exiting to prevent duplicate releases."
    log_warning "Tip: Use secrets.GITHUB_TOKEN instead of PAT to avoid this check, or implement workflow-level filtering."
    exit 0
fi

# Step 2: Determine the last release tag in the repository
LAST_TAG=$(get_last_tag)
log_info "Last tag: $LAST_TAG"

# Step 3: Get all commits since the last tag
COMMITS=$(get_commits_since "$LAST_TAG")
if [[ -z "$COMMITS" ]]; then
    log_info "No new commits since last tag. Exiting."
    exit 0
fi

# Step 4: Display commits for transparency
log_info "Commits since last tag:"
while IFS= read -r line; do
    log_info "  - $line"
done <<< "$COMMITS"

# Step 5: Analyze commit messages to determine version bump type
BUMP_TYPE=$(get_bump_type "$COMMITS")
NEXT_VERSION=$(calculate_next_version "$LAST_TAG" "$BUMP_TYPE")
NEW_TAG="v$NEXT_VERSION"

log_info "Bump type: $BUMP_TYPE"
log_info "Changing version from $LAST_TAG to $NEW_TAG"

# Step 6: Generate release notes from commit messages
RELEASE_NOTES=$(get_notes "$COMMITS")

# Step 7: Update local changelog file (if enabled)
if check_changelog_enable; then
    CHANGELOG_PATH=$(get_changelog_output)
    write_changelog "$NEW_TAG" "$RELEASE_NOTES" "$CHANGELOG_PATH"
    log_success "Changelog updated at $CHANGELOG_PATH"
else
    log_info "Changelog generation is disabled."
fi

# Step 8: Update version numbers in project files
run_updaters "$NEW_TAG"

# Step 9: Create release commit and tag
setup_git_user "GitHub Actions" "actions@github.com"
create_release_commit "$NEW_TAG"

log_success "Release $NEW_TAG created successfully!"

# Step 10: Update floating tags (if enabled)
# Floating tags allow users to reference latest versions without specifying exact versions
# e.g., 'uses: owner/repo@v1' or 'uses: owner/repo@latest' in GitHub Actions
if check_update_latest; then
    update_tag_latest
fi

if check_update_majors; then
    update_tag_major "$NEW_TAG"
fi

# =========================================
#               Platform Integration
# =========================================

# Step 11: Publish to external platforms (GitHub, etc.)
if check_github_enable; then
    source "$SCRIPT_DIR/lib/platforms/github.sh"

    # Verify GitHub CLI is available
    check_gh_cli

    # Create GitHub release with generated notes
    create_gh_release "$NEW_TAG" "$RELEASE_NOTES"

    # Step 11.1: Create floating GitHub releases (if enabled)
    # Creates additional GitHub releases for floating tags that enable simplified
    # consumption patterns in GitHub Actions (e.g., uses: owner/repo@latest)
    if check_update_latest; then
        publish_floating_release "latest" "$NEW_TAG" "$RELEASE_NOTES"
        log_success "GitHub floating release 'latest' updated to $NEW_TAG"
    fi

    if check_update_majors; then
        # Extract major version from full tag (e.g., "v1.2.3" → "v1")
        MAJOR_TAG=$(echo "$NEW_TAG" | cut -d. -f1)

        # Only create major floating release if it's different from the full tag
        # (prevents unnecessary operation for initial releases like "v1" itself)
        if [[ "$MAJOR_TAG" != "$NEW_TAG" ]]; then
            publish_floating_release "$MAJOR_TAG" "$NEW_TAG" "$RELEASE_NOTES"
            log_success "GitHub floating release '$MAJOR_TAG' updated to $NEW_TAG"
        fi
    fi

    log_success "GitHub release $NEW_TAG created successfully!"
fi
