#!/bin/bash

# Run build.sh, build-problems.sh, and build-solutions.sh in parallel
echo "Running build.sh"
bash build.sh

echo "Running rename.sh..."
bash rename.sh

echo "Running delete.sh..."
bash delete.sh

echo "All scripts completed."