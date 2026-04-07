#!/usr/bin/env bash

# Read stdin
INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')

# Only process .nix files
if [[ ! "$FILE_PATH" =~ \.nix$ ]]; then
  exit 0
fi

# Extract working directory
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Run nix flake check in project directory
cd "$CWD"
nix flake check 2>&1 || true  # Always exit 0, show output
