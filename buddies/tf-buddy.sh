#!/bin/bash

set -euo pipefail

DRY_RUN=false
VERBOSE=false
SCRIPT_NAME="tf-buddy"
VERSION="1.0.0"

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

Format Terraform files in your Git repository.

Options:
    -d, --dry-run     Show what would be done without making changes
    -v, --verbose     Enable verbose output
    -V, --version     Display version information
    -h, --help        Display this help message

Examples:
    $SCRIPT_NAME                   # Format all changed .tf files
    $SCRIPT_NAME --dry-run         # Show what would be formatted
    $SCRIPT_NAME --verbose         # Show detailed output

Requirements:
    - Git repository
    - Terraform CLI
    - Bash shell

EOF
    exit 0
}

version() {
    echo "$SCRIPT_NAME version $VERSION"
    exit 0
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
}

check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "Not inside a Git repository."
        log_error "Please run this command from within a Git repository."
        exit 1
    fi
}

get_changed_files() {
    local changed_files=()
    
    while IFS= read -r -d '' file; do
        changed_files+=("$file")
    done < <(git diff --name-only --diff-filter=ACM -z | grep -z '\.tf$' || true)

    while IFS= read -r -d '' file; do
        if [[ "$file" == *.tf ]]; then
            changed_files+=("$file")
        fi
    done < <(git ls-files --others --exclude-standard -z || true)
    
    if [[ ${#changed_files[@]} -eq 0 ]]; then
        echo ""
    else
        echo "${changed_files[@]}"
    fi
}

format_file() {
    local file="$1"
    local dry_run="$2"
    
    if [[ ! -f "$file" ]]; then
        log_warning "File not found: $file"
        return 1
    fi
    
    if "$dry_run"; then
        log_info "Would format: $file"
        return 0
    fi
    
    if terraform fmt "$file"; then
        if "$VERBOSE"; then
            log_success "Formatted: $file"
        fi
        return 0
    else
        log_error "Failed to format: $file"
        return 1
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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
    
    check_dependencies
    check_git_repo
    
    if "$VERBOSE"; then
        log_info "Starting Terraform formatting..."
        log_info "Dry run mode: $DRY_RUN"
    fi
    
    local changed_files_str
    changed_files_str=$(get_changed_files)
    
    if [[ -z "$changed_files_str" ]]; then
        if "$VERBOSE"; then
            log_info "No Terraform files have been changed."
        fi
        exit 0
    fi
    
    local changed_files=()
    if [[ -n "$changed_files_str" ]]; then
        IFS=' ' read -ra changed_files <<< "$changed_files_str"
    fi
    
    if "$VERBOSE"; then
        log_info "Found ${#changed_files[@]} changed Terraform file(s):"
        for file in "${changed_files[@]}"; do
            log_info "  - $file"
        done
    fi
    
    local failed_files=()
    for file in "${changed_files[@]}"; do
        if ! format_file "$file" "$DRY_RUN"; then
            failed_files+=("$file")
        fi
    done
    
    if [[ ${#failed_files[@]} -gt 0 ]]; then
        log_error "Failed to format ${#failed_files[@]} file(s):"
        for file in "${failed_files[@]}"; do
            log_error "  - $file"
        done
        exit 1
    fi
    
    if "$VERBOSE"; then
        log_success "Formatting complete. All files processed successfully."
    fi
}

main "$@"
