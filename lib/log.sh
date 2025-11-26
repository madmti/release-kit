#!/usr/bin/env bash

# =========================================
#                   COLORS
# =========================================

readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m'

# =========================================
#               LOG FUNCTIONS
# =========================================

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $(get_timestamp) - $message"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $(get_timestamp) - $message"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $(get_timestamp) - $message" >&2
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $(get_timestamp) - $message" >&2
}

log_debug() {
    local message="$1"
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${GRAY}[DEBUG]${NC} $(get_timestamp) - $message" >&2
    fi
}

log_fatal() {
    local message="$1"
    local exit_code="${2:-1}"
    log_error "$message"
    exit "$exit_code"
}
