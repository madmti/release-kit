#!/usr/bin/env bash

# =========================================
#           SEMANTIC VERSIONING
# =========================================

get_bump_type() {
    local commits="$1"          # Multiline string of commit messages

    if echo "$commits" | grep -qE 'BREAKING CHANGE|^[a-z]+(\(.+\))?!:'; then
        echo "major"
        return 0
    fi

    local types_config=$(get_commit_types)

    check_bump_level() {
        local level="$1"

        local types_to_check=$(echo "$types_config" | jq -r --arg lvl "$level" '.[] | select(.bump == $lvl) | .type')

        if [ -z "$types_to_check" ]; then
            return 1
        fi

        local regex_pattern="^($(echo "$types_to_check" | tr '\n' '|' | sed 's/|$//'))(\(.+\))?:"

        if echo "$commits" | grep -qE "$regex_pattern"; then
            return 0
        else
            return 1
        fi
    }

    if check_bump_level "major"; then
        echo "major"
        return 0
    fi

    if check_bump_level "minor"; then
        echo "minor"
        return 0
    fi

    if check_bump_level "patch"; then
        echo "patch"
        return 0
    fi

    echo "none"
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
