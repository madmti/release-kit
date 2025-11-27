#!/usr/bin/env bash

# For package.json and other JSON files that have a "version" field at root level
_update_json() {
    local file="$1"
    local version="$2"

    # Usamos un archivo temporal para escribir el cambio
    jq --arg v "$version" '.version = $v' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# For Python files with a __version__ variable
_update_python() {
    local file="$1"
    local version="$2"

    # Change the line that defines __version__
    sed -i "s/^__version__ = .*/__version__ = \"$version\"/" "$file"
}

# For custom regex patterns provided in the config
_update_custom() {
    local file="$1"
    local version="$2"
    local pattern="$3"

    if [[ -z "$pattern" ]]; then
        log_warning "No pattern provided for custom-regex in $file"
        return
    fi

    # Replace %VERSION% placeholder with actual version
    local sed_cmd=${pattern//%VERSION%/$version}

    sed -i "$sed_cmd" "$file"
}

run_updaters() {
    local new_version="$1"

    local targets_json=$(get_config_value "targets")

    if [[ -z "$targets_json" || "$targets_json" == "null" ]]; then
        log_info "No file updates configured."
        return
    fi

    log_info "Updating project files to version $new_version:"

    echo "$targets_json" | jq -c '.[]' | while read -r target; do
        local path=$(echo "$target" | jq -r '.path')
        local type=$(echo "$target" | jq -r '.type')
        local pattern=$(echo "$target" | jq -r '.pattern // empty') # Only for custom-regex

        if [[ ! -f "$path" ]]; then
            log_warning "File not found: $path. Skipping."
            continue
        fi

        log_info "  -> Updating $path ($type)"

        case "$type" in
            "npm"|"json")
                _update_json "$path" "$new_version"
                ;;
            "text")
                echo "$new_version" > "$path"
                ;;
            "python")
                _update_python "$path" "$new_version"
                ;;
            "custom-regex")
                _update_custom "$path" "$new_version" "$pattern"
                ;;
            *)
                log_warning "Unknown updater type: $type"
                ;;
        esac

        git add "$path"
    done
}
