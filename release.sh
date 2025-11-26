#!/usr/bin/env bash

# ======================================== #
#                   INIT
# ======================================== #
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/changelog.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/git.sh"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/semver.sh"
source "$SCRIPT_DIR/lib/updaters.sh"

# ======================================== #
#               Workflow
# ======================================== #
setup_config

LAST_TAG=$(get_last_tag)
log_info "Last tag: $LAST_TAG"

COMMITS=$(get_commits_since "$LAST_TAG")
if [[ -z "$COMMITS" ]]; then
    log_info "No new commits since last tag. Exiting."
    exit 0
fi

log_info "Commits since last tag:"
while IFS= read -r line; do
    log_info "  - $line"
done <<< "$COMMITS"

BUMP_TYPE=$(get_bump_type "$COMMITS")
NEXT_VERSION=$(calculate_next_version "$LAST_TAG" "$BUMP_TYPE")
NEW_TAG="v$NEXT_VERSION"

log_info "Bump type: $BUMP_TYPE"
log_info "Changing version from $LAST_TAG to $NEW_TAG"

RELEASE_NOTES=$(get_notes "$COMMITS")
# Release notes are not written to a file yet
# write_changelog "$NEW_TAG" "$RELEASE_NOTES"

setup_git_user
create_release_commit "$NEW_TAG"

log_success "Release $NEW_TAG created successfully!"

if check_github_active; then
    source "$SCRIPT_DIR/lib/platforms/github.sh"

    log_info "Creating GitHub release..."
    check_gh_cli
    create_gh_release "$NEW_TAG" "$RELEASE_NOTES"
    log_success "GitHub release $NEW_TAG created successfully!"
fi
