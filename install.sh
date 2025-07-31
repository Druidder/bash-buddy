#!/bin/bash

set -euo pipefail

SCRIPT_NAME="bash-buddy-installer"
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

Install Bash Buddy scripts to your system PATH.

Options:
    -d, --directory DIR    Install to custom directory (default: ~/.local/bin)
    -f, --force           Force installation even if files exist
    -u, --uninstall       Uninstall Bash Buddy scripts
    -V, --version         Display version information
    -h, --help            Display this help message

Examples:
    $SCRIPT_NAME                    # Install to default location
    $SCRIPT_NAME --directory /usr/local/bin  # Install to custom location
    $SCRIPT_NAME --uninstall       # Remove installed scripts

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

check_directory_writable() {
    local dir="$1"
    if [[ ! -w "$dir" ]] && [[ ! -w "$(dirname "$dir")" ]]; then
        log_error "Directory is not writable: $dir"
        log_error "Please choose a different directory or run with sudo."
        exit 1
    fi
}

create_backup() {
    local target_dir="$1"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        rm -rf "$BACKUP_DIR"
    fi
    
    mkdir -p "$BACKUP_DIR"
    
    for script in buddies/*.sh; do
        local script_name=$(basename "$script" .sh)
        local target_file="${target_dir}/${script_name}"
        
        if [[ -f "$target_file" ]]; then
            log_info "Backing up existing file: $target_file"
            cp "$target_file" "$BACKUP_DIR/"
        fi
    done
}

install_scripts() {
    local target_dir="$1"
    local force="$2"
    
    log_info "Installing Bash Buddy scripts to: $target_dir"
    
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi
    
    local existing_scripts=()
    for script in buddies/*.sh; do
        local script_name=$(basename "$script" .sh)
        local target_file="${target_dir}/${script_name}"
        
        if [[ -f "$target_file" ]]; then
            existing_scripts+=("$script_name")
        fi
    done
    
    if [[ ${#existing_scripts[@]} -gt 0 ]] && [[ "$force" != "true" ]]; then
        log_warning "The following scripts already exist: ${existing_scripts[*]}"
        log_warning "Use --force to overwrite existing files"
        log_warning "Use --uninstall to remove existing installations"
        exit 1
    fi
    
    if [[ ${#existing_scripts[@]} -gt 0 ]]; then
        create_backup "$target_dir"
    fi
    
    local installed_count=0
    for script in buddies/*.sh; do
        if [[ ! -f "$script" ]]; then
            continue
        fi
        
        local script_name=$(basename "$script" .sh)
        local target_file="${target_dir}/${script_name}"
        
        log_info "Installing: $script_name"
        
        cp "$script" "$target_file"
        chmod +x "$target_file"
        
        installed_count=$((installed_count + 1))
    done
    
    log_success "Installed $installed_count script(s)"
    
    if [[ ":$PATH:" != *":$target_dir:"* ]]; then
        log_warning "Directory $target_dir is not in your PATH"
        log_warning "Add the following line to your shell configuration file:"
        echo ""
        echo "export PATH=\"$target_dir:\$PATH\""
        echo ""
        log_warning "Then restart your terminal or run: source ~/.bashrc"
    else
        log_success "Scripts are now available in your PATH"
    fi
}

uninstall_scripts() {
    local target_dir="$1"
    
    log_info "Uninstalling Bash Buddy scripts from: $target_dir"
    
    if [[ ! -d "$target_dir" ]]; then
        log_warning "Target directory does not exist: $target_dir"
        return 0
    fi
    
    local removed_count=0
    for script in buddies/*.sh; do
        if [[ ! -f "$script" ]]; then
            continue
        fi
        
        local script_name=$(basename "$script" .sh)
        local target_file="${target_dir}/${script_name}"
        
        if [[ -f "$target_file" ]]; then
            log_info "Removing: $script_name"
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
    local uninstall=false
    
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
            -u|--uninstall)
                uninstall=true
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
    
    if [[ ! -d "buddies" ]]; then
        log_error "Buddies directory not found. Please run this script from the bash-buddy root directory."
        exit 1
    fi
    
    local script_count=0
    for script in buddies/*.sh; do
        if [[ -f "$script" ]]; then
            script_count=$((script_count + 1))
        fi
    done
    
    if [[ $script_count -eq 0 ]]; then
        log_error "No buddy scripts found in buddies/ directory."
        exit 1
    fi
    
    check_directory_writable "$target_dir"
    
    if "$uninstall"; then
        uninstall_scripts "$target_dir"
    else
        install_scripts "$target_dir" "$force"
    fi
}

main "$@" 