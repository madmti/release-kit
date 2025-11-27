#!/usr/bin/env bash
#
# Git Operations Module
#
# Provides functions for Git repository operations including tag retrieval,
# commit analysis, and release management. Handles both new repositories
# (without tags) and existing repositories with version history.
#
# Functions:
#   Read Operations:
#     - get_last_tag()       Get the most recent Git tag or default
#     - get_commits_since()  Get commit messages since specified tag
#     - get_current_hash()   Get current commit hash (short format)
#
#   Write Operations:
#     - setup_git_user()        Configure Git user for commits
#     - has_staged_changes()    Check if there are staged changes
#     - create_release_commit() Create release commit and tag
#     - update_tag_latest()     Update floating 'latest' tag
#     - update_tag_major()      Update floating major version tag
#
# Dependencies:
#   - git command
#   - log.sh (for logging functions)

# =========================================
#               READ FUNCTIONS
# =========================================

#######################################
# Get the most recent Git tag from the repository
# Retrieves the latest annotated or lightweight tag. Falls back to v0.0.0
# for repositories without any tags (initial release scenario).
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes tag name to stdout (e.g., "v1.2.3" or "v0.0.0")
# Returns:
#   0 always (uses fallback for error cases)
#######################################
get_last_tag() {
    # CRITICAL: Uses --match "v*.*.*" to ignore floating tags like 'latest', 'v1', 'v2'
    # This ensures version calculation is based on precise semantic version tags only
    git describe --tags --match "v*.*.*" --abbrev=0 2>/dev/null || echo "v0.0.0"
}

#######################################
# Get commit messages since specified tag
# Retrieves all commit messages between the specified tag and HEAD.
# Handles special case where no previous tags exist (v0.0.0).
# Globals:
#   None
# Arguments:
#   $1: last_tag - Git tag to start from (e.g., "v1.2.3" or "v0.0.0")
# Outputs:
#   Writes commit messages to stdout, one per line (subject only)
# Returns:
#   0 on success, non-zero on git failure
# Special Cases:
#   - If last_tag is "v0.0.0", returns all commits from HEAD
#   - Empty output if no commits since tag
#######################################
get_commits_since() {
    local last_tag="$1"

    if [ "$last_tag" == "v0.0.0" ]; then    # No tags found, get all commits
        git log HEAD --pretty=format:"%s"
    else                                    # Get commits since last tag
        git log "${last_tag}..HEAD" --pretty=format:"%s"
    fi
}
#######################################
# Get current commit hash in short format
# Retrieves the abbreviated hash of the current HEAD commit.
# Useful for debugging and logging purposes.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes short commit hash to stdout (e.g., "a1b2c3d")
# Returns:
#   0 on success, non-zero if not in git repository
#######################################
get_current_hash() {
    git rev-parse --short HEAD
}

# =========================================
#               WRITE FUNCTIONS
# =========================================

#######################################
# Configure Git user identity for commits
# Sets up Git user.name and user.email configuration for the current
# repository. Uses sensible defaults for CI environments.
# Globals:
#   None
# Arguments:
#   $1: name - Git user name (optional, default: "GitHub Actions")
#   $2: email - Git user email (optional, default: "actions@github.com")
# Outputs:
#   None
# Returns:
#   0 on success, non-zero on git config failure
#######################################
setup_git_user() {
    local name="${1:-GitHub Actions}"
    local email="${2:-actions@github.com}"
    git config user.name "$name"
    git config user.email "$email"
}

#######################################
# Check if there are staged changes in the Git index
# Determines whether there are any files staged for commit.
# Used to decide if a release commit needs to be created.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0 if there are staged changes, 1 if staging area is clean
#######################################
has_staged_changes() {
    ! git diff --cached --quiet
}

#######################################
# Create release commit and tag, then push to remote
# Creates a release commit with all staged changes, creates a Git tag,
# and pushes both the commit and tag to the remote repository.
# Only commits if there are staged changes to avoid empty commits.
# Globals:
#   None
# Arguments:
#   $1: version_tag - Git tag name to create (e.g., "v1.2.3")
# Outputs:
#   Info message if no changes to commit
#   Git command output to stdout/stderr
# Returns:
#   0 on success, non-zero on git operation failure
# Side Effects:
#   - Creates commit with staged changes (if any)
#   - Creates annotated or lightweight tag
#   - Pushes current branch and all tags to origin
#######################################
create_release_commit() {
    local version_tag="$1"  # e.g., "v1.2.3"
    local message="chore: release $version_tag"

    if has_staged_changes; then
        git commit -m "$message"
    else
        log_info "No changes to commit for release $version_tag"
    fi

    git tag "$version_tag"
    git push origin HEAD --tags
}

# =========================================
#           FLOATING TAGS FUNCTIONS
# =========================================

#######################################
# Update the 'latest' floating tag to point to current HEAD
# Moves the 'latest' tag to the current commit and force pushes it to remote.
# This allows users to always reference the most recent stable release using 'latest'.
# SECURITY WARNING: Uses force push which overwrites remote tag history.
# Globals:
#   None
# Arguments:
#   None (operates on current HEAD)
# Outputs:
#   Progress information via log_info
#   Git command output to stdout/stderr
# Returns:
#   0 on success, non-zero on git operation failure
# Side Effects:
#   - Forces 'latest' tag to current HEAD
#   - Force pushes tag to origin (overwrites remote history)
# Usage Example:
#   After creating release v1.2.3, call this to update 'latest' → v1.2.3
#######################################
update_tag_latest() {
    log_info "Updating 'latest' tag to current HEAD..."
    git tag -f latest
    git push origin latest --force
}

#######################################
# Update major version floating tag to point to current HEAD
# Extracts the major version from a full semantic version tag and updates
# the corresponding floating major tag (e.g., v1.2.3 → updates 'v1' tag).
# SECURITY WARNING: Uses force push which overwrites remote tag history.
# Globals:
#   None
# Arguments:
#   $1: full_tag - Complete semantic version tag (e.g., "v1.2.3")
# Outputs:
#   Progress information via log_info
#   Git command output to stdout/stderr (if update needed)
# Returns:
#   0 always (early return if no major version to extract)
# Side Effects:
#   - Forces major version tag to current HEAD (e.g., 'v1')
#   - Force pushes tag to origin (overwrites remote history)
# Examples:
#   update_tag_major "v1.2.3"  # Updates 'v1' tag
#   update_tag_major "v2.0.1"  # Updates 'v2' tag
#   update_tag_major "v1"      # No-op (already major version)
#######################################
update_tag_major() {
    local full_tag="$1"

    # Extract major version (everything before first dot)
    local major_tag=$(echo "$full_tag" | cut -d. -f1)

    # Skip if input is already a major version tag (no dots)
    if [[ "$major_tag" == "$full_tag" ]]; then
        log_debug "Tag '$full_tag' is already a major version, skipping update"
        return 0
    fi

    log_info "Updating major version tag '$major_tag' to current HEAD..."
    git tag -f "$major_tag"
    git push origin "$major_tag" --force
}
