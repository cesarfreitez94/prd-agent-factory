#!/bin/bash
if ! grep -qE '#[0-9]+' "$1"; then
    echo "Error: commit message must include an issue number (Fixes #N)"
    exit 1
fi
