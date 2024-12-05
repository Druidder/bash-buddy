#!/bin/bash

set -euo pipefail

if ! command -v git &> /dev/null; then
  echo "ERROR: 'git' command not found." >&2
  exit 1
fi

if ! command -v terraform &> /dev/null; then
  echo "ERROR: 'terraform' command not found." >&2
  exit 1
fi

changed_files=$(git diff --name-only --diff-filter=ACM | grep '\.tf$' || true)

if [[ -z "$changed_files" ]]; then
  exit 0
fi

for file in $changed_files; do
  if ! terraform fmt "$file"; then
    echo "ERROR: Failed to format $file" >&2
    exit 1
  fi
done