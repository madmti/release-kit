#!/usr/bin/env bash

# =========================================
#               READ FUNCTIONS
# =========================================

get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"
}

get_commits_since() {
    local last_tag="$1"

    if [ "$last_tag" == "v0.0.0" ]; then    # No tags found, get all commits
        git log HEAD --pretty=format:"%s"
    else                                    # Get commits since last tag
        git log "${last_tag}..HEAD" --pretty=format:"%s"
    fi
}
get_current_hash() {
    git rev-parse --short HEAD
}

# =========================================
#               WRITE FUNCTIONS
# =========================================

setup_git_user() {
    local name="${1:-GitHub Actions}"
    local email="${2:-actions@github.com}"
    git config user.name "$name"
    git config user.email "$email"
}

has_staged_changes() {
    ! git diff --cached --quiet
}

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
