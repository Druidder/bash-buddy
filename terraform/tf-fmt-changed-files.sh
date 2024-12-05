#!/bin/bash

set -euo pipefail

DRY_RUN=false
VERBOSE=false

SCRIPT_NAME=$(basename "$0")

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -d, --dry-run     Show what would be done without making changes
  -v, --verbose     Enable verbose output
  -h, --help        Display this help message
EOF
  exit 0
}

error() {
  local msg="$1"
  echo "$SCRIPT_NAME: error: $msg" >&2
}

warn() {
  local msg="$1"
  echo "$SCRIPT_NAME: warning: $msg" >&2
}

# Process command-line options
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
    -h|--help)
      usage
      ;;
    *)
      error "unknown option: $1"
      usage
      ;;
  esac
done

if ! command -v git &> /dev/null; then
  error "'git' command not found."
  exit 1
fi

if ! command -v terraform &> /dev/null; then
  error "'terraform' command not found."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  error "not inside a Git repository."
  exit 1
fi

changed_files=()
while IFS= read -r -d '' file; do
  changed_files+=("$file")
done < <(git diff --name-only --diff-filter=ACM -z | grep -z '\.tf$' || true)

if [[ ${#changed_files[@]} -eq 0 ]]; then
  if "$VERBOSE"; then
    echo "$SCRIPT_NAME: no Terraform files have been changed."
  fi
  exit 0
fi

for file in "${changed_files[@]}"; do
  if "$VERBOSE"; then
    echo "$SCRIPT_NAME: processing file: $file"
  fi
  if "$DRY_RUN"; then
    echo "$SCRIPT_NAME: would format $file"
  else
    if ! terraform fmt "$file"; then
      error "failed to format $file"
      exit 1
    fi
    if "$VERBOSE"; then
      echo "$SCRIPT_NAME: formatted $file"
    fi
  fi
done

if "$VERBOSE"; then
  echo "$SCRIPT_NAME: formatting complete."
fi
