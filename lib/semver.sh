#!/usr/bin/env bash

# =========================================
#           SEMANTIC VERSIONING
# =========================================

get_bump_type() {
    local commits="$1"          # Multiline string of commit messages

    if grep -qE '^(BREAKING CHANGE|feat!|fix!)(\(.+\))?:' <<< "$commits"; then
        echo "major"
    elif grep -qE '^(feat|feature)(\(.+\))?:' <<< "$commits"; then
        echo "minor"
    elif  grep -qE '^(fix|bugfix|hotfix)(\(.+\))?:' <<< "$commits"; then
        echo "patch"
    else
        echo "none"
    fi
}

calculate_next_version() {
    local current_version="$1"  # e.g., "v1.2.3"
    local bump_type="$2"        # e.g., "major", "minor", "patch", "none"

    IFS='.' read -r major minor patch <<< "$current_version"

    major=${major#v}

    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}

    log_debug "major: $major, minor: $minor, patch: $patch"

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        none)
            ;;
        *)
            log_error "Unknown bump type: $bump_type"
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}
