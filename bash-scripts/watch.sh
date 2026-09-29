#!/usr/bin/env bash
# Live preview: rebuild on every save and refresh the open PDF.
#
# Usage:
#   bash-scripts/watch.sh [--doc DOC] [--no-open] NAME_OR_PATH
#
#   NAME: any .tex in the repo, given as a path or as part of its filename
#         (e.g. "14 Baltic" or "Solusi/14 Baltic Way 2012 Problem 3.tex").
#         Files under Soal/ and Solusi/ are
#         fragments, so the script watches the fragment but compiles the
#         entry-point document that pulls it in:
#
#             Soal/...   -> main-problems.tex
#             Solusi/... -> main-solutions.tex
#             an entry point -> itself
#
#   --doc DOC   Compile this document instead of the one guessed above.
#               Takes the same short names as compile-one.sh:
#               all | problems | solutions.
#   --no-open   Do not open a PDF viewer; just watch and rebuild.
#
# Examples:
#   bash-scripts/watch.sh "14 Baltic"
#   bash-scripts/watch.sh --doc all "Solusi/14 Baltic Way 2012 Problem 3.tex"
#
# Press Ctrl-C to stop. Build artifacts are cleaned up on exit, leaving the
# PDF (under its main*.pdf name, not the published one). Polls the watched
# file's modification time once a second and runs pdflatex from the repo root,
# so azzam.sty and the .asy library files resolve.
#
# Opens the PDF in Skim when available, since it reloads in place and keeps
# your scroll position; falls back to the system default viewer. Turn on
# Skim -> Preferences -> Sync -> "Check for file changes" once. Preview.app
# jumps back to page 1 on every rebuild, so it is a poor fit here.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACT_EXTS=(aux log out toc fls fdb_latexmk pre synctex.gz lof lot idx ind
               ilg bbl blg bcf run.xml nav snm vrb auxlock xdv)

DOC=""
OPEN=1
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --doc)     DOC="${2:-}"; shift 2 ;;
    --no-open) OPEN=0; shift ;;
    -h|--help) sed -n '2,37p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         args+=("$1"); shift ;;
  esac
done

if [ "${#args[@]}" -ne 1 ]; then
  echo "Usage: bash-scripts/watch.sh [--doc DOC] [--no-open] NAME_OR_PATH"
  exit 1
fi

# A path, or a substring of a filename found anywhere in the repo.
resolve_tex() {
  local arg="$1" name="${1%.tex}" matches=()

  if [ -f "$arg" ]; then
    echo "$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"; return 0
  elif [ -f "$name.tex" ]; then
    echo "$(cd "$(dirname "$name.tex")" && pwd)/$(basename "$name.tex")"; return 0
  elif [ -f "$ROOT/$arg" ]; then
    echo "$ROOT/$arg"; return 0
  elif [ -f "$ROOT/$name.tex" ]; then
    echo "$ROOT/$name.tex"; return 0
  fi

  while IFS= read -r -d '' f; do
    matches+=("$f")
  done < <(find "$ROOT" -type d -name .git -prune -o \
                -type f -iname "*$(basename "$name")*.tex" -print0)

  case "${#matches[@]}" in
    0) echo "No .tex file found matching '$arg'" >&2; return 1 ;;
    1) echo "${matches[0]}"; return 0 ;;
    *)
      {
        echo "Multiple .tex files match '$arg':"
        printf '  %s\n' "${matches[@]#$ROOT/}"
        echo "Pass more of the name, or a full path, to disambiguate."
      } >&2
      return 1
      ;;
  esac
}

# Which entry point pulls this fragment in.
guess_doc() {
  local rel="${1#$ROOT/}"
  case "$rel" in
    main.tex)                       echo "main" ;;
    main-problems.tex)              echo "main-problems" ;;
    main-solutions.tex)             echo "main-solutions" ;;
    Soal/*)                         echo "main-problems" ;;
    Solusi/*)                       echo "main-solutions" ;;
    *)                              echo "main" ;;
  esac
}

normalise_doc() {
  case "${1%.tex}" in
    all|main)                 echo "main" ;;
    problems|main-problems)   echo "main-problems" ;;
    solutions|main-solutions) echo "main-solutions" ;;
    *) echo "Unknown document '$1' (try: all, problems, solutions)" >&2; return 1 ;;
  esac
}

texfile="$(resolve_tex "${args[0]}")" || exit 1

if [ -n "$DOC" ]; then
  base="$(normalise_doc "$DOC")" || exit 1
else
  base="$(guess_doc "$texfile")"
fi

pdf="$ROOT/$base.pdf"

cleanup() {
  trap - EXIT INT TERM   # so an INT/TERM does not also fire the EXIT trap
  echo
  echo "Stopping watch; cleaning build artifacts..."
  for ext in "${ARTIFACT_EXTS[@]}"; do
    rm -f "$ROOT/$base.$ext"
  done
  rm -f "$ROOT/$base"-[0-9]*.asy "$ROOT/$base"-[0-9]*.pdf
  echo "PDF kept: $base.pdf"
  exit 0
}
trap cleanup EXIT INT TERM

# One build: the full pdflatex / asy / pdflatex / pdflatex round trip the
# asymptote package needs, reporting any errors TeX recovered from. Never
# -halt-on-error, so one broken figure still yields a PDF with the rest intact.
build() {
  local nerr nfig=0 asyfile pass

  cd "$ROOT" || return

  rm -f "$ROOT/$base"-[0-9]*.asy "$ROOT/$base"-[0-9]*.pdf
  pdflatex --shell-escape -interaction=nonstopmode "$base.tex" >/dev/null 2>&1 || true

  for asyfile in "$ROOT/$base"-[0-9]*.asy; do
    [ -e "$asyfile" ] || continue
    asy "$asyfile" >/dev/null 2>&1 || echo "      asy failed on $(basename "$asyfile")"
    nfig=$((nfig + 1))
  done

  for pass in 2 3; do
    pdflatex --shell-escape -interaction=nonstopmode "$base.tex" >/dev/null 2>&1 || true
  done

  if [ ! -f "$ROOT/$base.pdf" ]; then
    echo "    FAILED - no PDF produced"
    return
  fi

  nerr=0
  [ -f "$ROOT/$base.log" ] && nerr="$(grep -c '^!' "$ROOT/$base.log" || true)"
  if [ "$nerr" -gt 0 ]; then
    echo "    $nfig figure(s), $nerr error(s) recovered:"
    grep -A 3 '^!' "$ROOT/$base.log" 2>/dev/null | head -20 | sed 's/^/      /'
  else
    echo "    ok ($nfig figure(s))"
  fi
}

echo "Watching:  ${texfile#$ROOT/}"
echo "Compiling: $base.tex"
echo "PDF:       $base.pdf"
echo "Save the .tex to rebuild. Ctrl-C to stop."
echo

echo "==> Building $(date +%H:%M:%S)"
build

if [ "$OPEN" -eq 1 ] && [ -f "$pdf" ]; then
  if [ -d /Applications/Skim.app ]; then
    open -a Skim "$pdf"
  else
    open "$pdf"
  fi
fi

# Poll the watched file's modification time once a second and rebuild on change.
last="$(stat -f %m "$texfile" 2>/dev/null || echo 0)"
while true; do
  sleep 1
  [ -f "$texfile" ] || continue
  now="$(stat -f %m "$texfile" 2>/dev/null || echo 0)"
  if [ "$now" != "$last" ]; then
    last="$now"
    echo "==> Rebuilding $(date +%H:%M:%S)"
    build
  fi
done
