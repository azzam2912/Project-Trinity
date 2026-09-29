#!/usr/bin/env bash
# Build all three entry-point documents, in parallel, and publish the PDFs.
#
# Usage:
#   bash-scripts/compile.sh [--serial] [--no-rename]
#
#   --serial      Build one document at a time. Slower, but the log output
#                 stays readable, so use it when a build is going wrong.
#   --no-rename   Leave the output as main.pdf / main-problems.pdf /
#                 main-solutions.pdf instead of the published names.
#
# This is the everyday full rebuild. Each document is compiled by
# compile-one.sh, which handles the pdflatex / asy / pdflatex / pdflatex
# round trip and cleans up after itself.
#
# Parallel builds are safe because each document writes only its own
# main*.aux / main*-N.asy files, and compile-one.sh only ever deletes its own.
#
# The three published PDFs are tracked in git, so a rebuild will show up in
# `git status`. That is expected: commit them along with the source.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILE_ONE="$ROOT/bash-scripts/compile-one.sh"

SERIAL=0
RENAME_FLAG="--rename"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --serial)     SERIAL=1; shift ;;
    --no-rename)  RENAME_FLAG=""; shift ;;
    -h|--help)    sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "Unknown option '$1' (see bash-scripts/compile.sh --help)"; exit 1 ;;
  esac
done

DOCS=(all problems solutions)

if [ "$SERIAL" -eq 1 ]; then
  echo "Building ${#DOCS[@]} documents, one at a time..."
  echo
  bash "$COMPILE_ONE" ${RENAME_FLAG:+$RENAME_FLAG} "${DOCS[@]}"
  exit $?
fi

echo "Building ${#DOCS[@]} documents in parallel..."
echo

logdir="$(mktemp -d)"
pids=()
for doc in "${DOCS[@]}"; do
  bash "$COMPILE_ONE" ${RENAME_FLAG:+$RENAME_FLAG} "$doc" >"$logdir/$doc.log" 2>&1 &
  pids+=($!)
done

status=0
for pid in "${pids[@]}"; do
  wait "$pid" || status=1
done

# Print each build's output as one block, so the parallel runs do not interleave.
for doc in "${DOCS[@]}"; do
  cat "$logdir/$doc.log"
done
rm -rf "$logdir"

if [ "$status" -eq 0 ]; then
  echo "All documents built."
else
  echo "At least one document failed; see the output above."
fi
exit "$status"
