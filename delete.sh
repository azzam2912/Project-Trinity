#!/bin/bash

# Define the file patterns to delete
patterns=(
    "main-*.asy"
    "test-*.asy"
    "*.out"
    "*.aux"
    "*.fdb_latexmk"
    "*.log"
    "*.pre"
    "*.fls"
    "*.toc"
    "*.eps"
)

# Loop through the patterns and delete matching files
for pattern in "${patterns[@]}"; do
    files_to_delete=$(find . -type f -name "$pattern")
    if [ -n "$files_to_delete" ]; then
        echo "Deleting files matching pattern: $pattern"
        rm -v $files_to_delete
    fi
done