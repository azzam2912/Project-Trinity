#!/usr/bin/env bash
# Delete LaTeX and Asymptote build artifacts left behind by a compile.
#
# Usage:
#   bash-scripts/clean.sh [--dir FOLDER] [--pdf] [-n|--dry-run]
#
#   --dir FOLDER   Clean only this folder (recursively). Accepts a path
#                  relative to the repo root or cwd, or a bare folder name
#                  searched for anywhere in the repo (case-insensitive).
#                  Default: the whole repository.
#   --pdf          Also delete the three published PDFs. Off by default:
#                  those are tracked in git and are the point of compiling.
#                  The per-figure main-N.pdf files are always cleaned,
#                  with or without this flag.
#   -n, --dry-run  List what would be deleted without deleting anything.
#
# Examples:
#   bash-scripts/clean.sh              # clean artifacts repo-wide
#   bash-scripts/clean.sh -n           # preview only
#   bash-scripts/clean.sh --dir Solusi
#   bash-scripts/clean.sh --pdf        # wipe the published PDFs too
#
# .git/ is never touched. The extensions match what pdflatex and asy generate,
# plus the .errlog files compile-one.sh writes for recovered errors.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACT_EXTS=(aux log out toc fls fdb_latexmk pre errlog eps synctex.gz lof
               lot idx ind ilg glo gls acn acr alg bbl blg bcf run.xml nav
               snm vrb figlist makefile auxlock upa upb xdv)

# Per-figure files the asymptote round trip leaves behind: main-7.asy,
# main-solutions-12.pdf, test-3.asy, and so on.
FIGURE_GLOBS=('main*-[0-9]*.asy' 'main*-[0-9]*.pdf' 'test*-[0-9]*.asy' 'test*-[0-9]*.pdf')

# The published PDFs, deleted only with --pdf.
PUBLISHED_GLOB='Project Trinity*.pdf'

TARGET="$ROOT"
DRY_RUN=0
WITH_PDF=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir|-d)
      FOLDER="${2:-}"
      if [ -z "$FOLDER" ]; then
        echo "Usage: bash-scripts/clean.sh --dir FOLDER"
        exit 1
      fi
      if [ -d "$FOLDER" ]; then
        TARGET="$(cd "$FOLDER" && pwd)"
      elif [ -d "$ROOT/$FOLDER" ]; then
        TARGET="$ROOT/$FOLDER"
      else
        matched=()
        while IFS= read -r -d '' dir; do
          matched+=("$dir")
        done < <(find "$ROOT" -type d -name .git -prune -o -type d -iname "$FOLDER" -print0)
        case "${#matched[@]}" in
          0) echo "No folder found matching '$FOLDER'"; exit 1 ;;
          1) TARGET="${matched[0]}" ;;
          *)
            echo "Multiple folders match '$FOLDER':"
            printf '  %s\n' "${matched[@]#$ROOT/}"
            echo "Pass a full path (relative to the repo root) to disambiguate."
            exit 1
            ;;
        esac
      fi
      shift 2
      ;;
    --pdf)        WITH_PDF=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help)    sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "Unknown option '$1' (see bash-scripts/clean.sh --help)"; exit 1 ;;
  esac
done

# Build the find expression: -name '*.aux' -o -name '*.log' -o ...
find_args=()
for ext in "${ARTIFACT_EXTS[@]}"; do
  [ "${#find_args[@]}" -gt 0 ] && find_args+=(-o)
  find_args+=(-name "*.$ext")
done
for glob in "${FIGURE_GLOBS[@]}"; do
  find_args+=(-o -name "$glob")
done
# main.pdf and friends are gitignored build output; the published copies are
# a separate, tracked thing and need --pdf.
find_args+=(-o -name 'main.pdf' -o -name 'main-problems.pdf' -o -name 'main-solutions.pdf')
[ "$WITH_PDF" -eq 1 ] && find_args+=(-o -name "$PUBLISHED_GLOB")

if [ "$TARGET" = "$ROOT" ]; then
  echo "Cleaning: whole repository"
else
  echo "Cleaning: ${TARGET#$ROOT/}"
fi
[ "$WITH_PDF" -eq 1 ] && echo "Including the published PDFs"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run - nothing will be deleted)"
echo

count=0
while IFS= read -r -d '' f; do
  echo "  ${f#$ROOT/}"
  [ "$DRY_RUN" -eq 0 ] && rm -f "$f"
  count=$((count + 1))
done < <(find "$TARGET" -type d -name .git -prune -o -type f \( "${find_args[@]}" \) -print0 | sort -z)

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would delete $count file(s)."
else
  echo "Deleted $count file(s)."
fi
