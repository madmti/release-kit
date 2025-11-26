#!/usr/bin/env bash

CHANGELOG_FILE="CHANGELOG.md"

_filter_commits_by_type() {
    local commits="$1"
    local type="$2"

    echo "$commits" | grep -E "^${type}(\(.*\))?!?: "
}

get_notes() {
    local commits="$1"
    local output=""

    local breaking=$(echo "$commits" | grep -E "BREAKING CHANGE|!:")

    if [[ -n "$breaking" ]]; then
        echo "### ⚠ BREAKING CHANGES"
        echo ""
        echo "$breaking" | sed 's/^/- /'
        echo ""
    fi

    local types_json=$(get_commit_types)

    echo "$types_json" | jq -c '.[]' | while read -r block; do
        local type=$(echo "$block" | jq -r '.type')
        local section=$(echo "$block" | jq -r '.section')
        local hidden=$(echo "$block" | jq -r '.hidden')

        if [[ "$hidden" == "true" ]]; then
            continue
        fi

        local matches=$(_filter_commits_by_type "$commits" "$type")

        if [[ -n "$matches" ]]; then
            echo "### $section"
            echo ""
            echo "$matches" | sed 's/^/- /'
            echo ""
        fi
    done
}

write_changelog() {
    local version="$1"
    local notes="$2"
    local date=$(date +%Y-%m-%d)

    log_info "Writing changelog to $CHANGELOG_FILE"

    local temp_file="TEMP_CHANGELOG.md"

    echo "# $version ($date)" > "$temp_file"
    echo "" >> "$temp_file"

    echo "$notes" >> "$temp_file"
    echo "" >> "$temp_file"

    if [[ -f "$CHANGELOG_FILE" ]]; then
        cat "$CHANGELOG_FILE" >> "$temp_file"
    fi

    mv "$temp_file" "$CHANGELOG_FILE"

    git add "$CHANGELOG_FILE"
}
