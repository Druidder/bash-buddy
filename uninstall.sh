#!/bin/bash

set -euo pipefail

SCRIPT_NAME="bash-buddy-uninstaller"
VERSION="1.0.0"
BUDDY_DIR="${HOME}/.local/bin"
BACKUP_DIR="${HOME}/.bash-buddy-backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Remove Bash Buddy scripts from your system PATH.

Options:
    -d, --directory DIR    Remove from custom directory (default: ~/.local/bin)
    -f, --force           Force removal without confirmation
    -V, --version         Display version information
    -h, --help            Display this help message

Examples:
    $SCRIPT_NAME                    # Remove from default location
    $SCRIPT_NAME --directory /usr/local/bin  # Remove from custom location
    $SCRIPT_NAME --force           # Remove without confirmation

Requirements:
    - Bash shell
    - Write permissions to target directory

EOF
    exit 0
}

version() {
    echo "$SCRIPT_NAME version $VERSION"
    exit 0
}

confirm_uninstall() {
    local target_dir="$1"
    
    echo ""
    log_warning "This will remove all Bash Buddy scripts from: $target_dir"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled."
        exit 0
    fi
}

remove_scripts() {
    local target_dir="$1"
    local force="$2"
    
    if [[ ! -d "$target_dir" ]]; then
        log_warning "Target directory does not exist: $target_dir"
        return 0
    fi
    
    local removed_count=0
    local buddy_scripts=("tf-buddy")
    
    for script in "${buddy_scripts[@]}"; do
        local target_file="${target_dir}/${script}"
        
        if [[ -f "$target_file" ]]; then
            log_info "Removing: $script"
            rm -f "$target_file"
            removed_count=$((removed_count + 1))
        fi
    done
    
    if [[ $removed_count -eq 0 ]]; then
        log_warning "No Bash Buddy scripts found in $target_dir"
    else
        log_success "Removed $removed_count script(s)"
    fi
    
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Restoring backup files..."
        for backup_file in "$BACKUP_DIR"/*; do
            if [[ -f "$backup_file" ]]; then
                local filename=$(basename "$backup_file")
                log_info "Restoring: $filename"
                cp "$backup_file" "${target_dir}/${filename}"
                chmod +x "${target_dir}/${filename}"
            fi
        done
        rm -rf "$BACKUP_DIR"
        log_success "Backup restored"
    fi
}

main() {
    local target_dir="$BUDDY_DIR"
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--directory)
                target_dir="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -V|--version)
                version
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Uninstalling Bash Buddy scripts from: $target_dir"
    
    if [[ "$force" != "true" ]]; then
        confirm_uninstall "$target_dir"
    fi
    
    remove_scripts "$target_dir" "$force"
    
    log_success "Uninstallation complete!"
}

main "$@" 