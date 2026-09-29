#!/usr/bin/env bash
# Compile one of the three entry-point documents and clean up build artifacts.
#
# Usage:
#   bash-scripts/compile-one.sh [--rename] [--keep-asy] DOC [DOC ...]
#
#   DOC: an entry point, by short name or filename:
#          all | main            -> main.tex
#          problems              -> main-problems.tex
#          solutions             -> main-solutions.tex
#        A path to any other .tex is accepted too, but note that the files
#        under Soal/ and Solusi/ are fragments
#        with no preamble: they cannot be compiled on their own. To check one
#        of those, compile the document that \inputs it, or use watch.sh.
#
#   --rename     After compiling, rename the PDF to its published name
#                ("Project Trinity [Solutions].pdf" etc.). Only
#                applies to the three entry points.
#   --keep-asy   Keep the extracted per-figure main-N.asy / main-N.pdf files
#                instead of deleting them. Useful when debugging one diagram.
#
# Examples:
#   bash-scripts/compile-one.sh solutions
#   bash-scripts/compile-one.sh --rename all problems solutions
#
# Each document is built in three stages, which is what the asymptote package
# requires: pdflatex writes one main-N.asy per \begin{asy} block, `asy` turns
# each into a PDF figure, then pdflatex runs twice more so the figures are
# included and the table of contents settles.
#
# Errors are tolerated: nonstopmode without -halt-on-error, so one broken
# figure still yields a PDF with every other problem intact.
# When TeX recovered from errors the script says so and leaves a .errlog.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACT_EXTS=(aux log out toc fls fdb_latexmk pre synctex.gz lof lot idx ind
               ilg bbl blg bcf run.xml nav snm vrb auxlock xdv)

RENAME=0
KEEP_ASY=0
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --rename)   RENAME=1; shift ;;
    --keep-asy) KEEP_ASY=1; shift ;;
    -h|--help)  sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          args+=("$1"); shift ;;
  esac
done

if [ "${#args[@]}" -eq 0 ]; then
  echo "Usage: bash-scripts/compile-one.sh [--rename] [--keep-asy] DOC [DOC ...]"
  echo "  DOC: all | problems | solutions, or a path to a .tex file"
  exit 1
fi

# Map a short name to its entry-point .tex, or accept a path as given.
resolve_doc() {
  local arg="$1" name="${1%.tex}"

  case "$name" in
    all|main)             echo "$ROOT/main.tex";           return 0 ;;
    problems|main-problems)   echo "$ROOT/main-problems.tex";  return 0 ;;
    solutions|main-solutions) echo "$ROOT/main-solutions.tex"; return 0 ;;
  esac

  if [ -f "$arg" ]; then
    echo "$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"; return 0
  elif [ -f "$name.tex" ]; then
    echo "$(cd "$(dirname "$name.tex")" && pwd)/$(basename "$name.tex")"; return 0
  elif [ -f "$ROOT/$arg" ]; then
    echo "$ROOT/$arg"; return 0
  elif [ -f "$ROOT/$name.tex" ]; then
    echo "$ROOT/$name.tex"; return 0
  fi

  echo "No document found matching '$arg' (try: all, problems, solutions)" >&2
  return 1
}

# The published name each entry point is renamed to.
published_name() {
  case "$1" in
    main)           echo "Project Trinity.pdf" ;;
    main-problems)  echo "Project Trinity [Problems].pdf" ;;
    main-solutions) echo "Project Trinity [Solutions].pdf" ;;
    *)              echo "" ;;
  esac
}

total=0
failed=0
warned=0

for arg in "${args[@]}"; do
  texfile="$(resolve_doc "$arg")" || { failed=$((failed + 1)); continue; }

  total=$((total + 1))
  base="$(basename "${texfile%.tex}")"

  echo "==> Compiling ${texfile#$ROOT/}"

  cd "$ROOT" || exit 1

  # Stale figure sources from an earlier run would otherwise be re-rendered
  # and silently included even after their \begin{asy} block was deleted.
  rm -f "$ROOT/$base"-[0-9]*.asy "$ROOT/$base"-[0-9]*.pdf

  # Pass 1: writes main-N.asy for each inline asy block.
  pdflatex --shell-escape -interaction=nonstopmode "$base.tex" >/dev/null 2>&1 || true

  # Render each extracted figure. Globbing beats the old fixed 1..50 loop:
  # it never misses a figure and never spends time on ones that do not exist.
  # The [0-9] guard keeps "main" from picking up main-problems-3.asy.
  nfig=0
  for asyfile in "$ROOT/$base"-[0-9]*.asy; do
    [ -e "$asyfile" ] || continue
    asy "$asyfile" >/dev/null 2>&1 || echo "    asy failed on $(basename "$asyfile")"
    nfig=$((nfig + 1))
  done
  [ "$nfig" -gt 0 ] && echo "    $nfig figure(s) rendered"

  # Passes 2 and 3: include the figures, then settle the table of contents.
  for pass in 2 3; do
    pdflatex --shell-escape -interaction=nonstopmode "$base.tex" >/dev/null 2>&1 || true
  done

  if [ ! -f "$ROOT/$base.pdf" ]; then
    echo "    FAILED - no PDF produced, see $base.errlog"
    [ -f "$ROOT/$base.log" ] && cp "$ROOT/$base.log" "$ROOT/$base.errlog"
    failed=$((failed + 1))
  else
    nerr=0
    [ -f "$ROOT/$base.log" ] && nerr="$(grep -c '^!' "$ROOT/$base.log" || true)"
    if [ "$nerr" -gt 0 ]; then
      echo "    OK with $nerr error(s) - details in $base.errlog"
      grep -A 3 '^!' "$ROOT/$base.log" > "$ROOT/$base.errlog" 2>/dev/null
      warned=$((warned + 1))
    else
      rm -f "$ROOT/$base.errlog"
    fi

    outname="$base.pdf"
    if [ "$RENAME" -eq 1 ]; then
      pub="$(published_name "$base")"
      if [ -n "$pub" ]; then
        mv -f "$ROOT/$base.pdf" "$ROOT/$pub"
        outname="$pub"
      fi
    fi
    echo "    PDF: $outname"
  fi

  # Clean up only this document's artifacts, so a parallel build of another
  # entry point is left alone.
  for ext in "${ARTIFACT_EXTS[@]}"; do
    rm -f "$ROOT/$base.$ext"
  done
  if [ "$KEEP_ASY" -eq 0 ]; then
    rm -f "$ROOT/$base"-[0-9]*.asy "$ROOT/$base"-[0-9]*.pdf
  fi
done

echo
echo "Done: $total document(s) processed, $warned with recovered errors, $failed failed."
[ "$failed" -eq 0 ]
