#!/usr/bin/env bash
# Fast preview of one problem and solution, without building all three PDFs.
#
# Usage:
#   bash-scripts/test-newest.sh [ENTRY] [--open]
#
#   ENTRY   Which entry to preview: a leading number ("35") or part of a
#           filename ("Ukraine"). Default is the entry with the highest
#           leading number across Soal/ and Solusi/, so a new entry is
#           picked up with no edits to any filename in this script.
#   --open  Open the PDF after building (Skim when available, else the
#           system default viewer).
#
# Examples:
#   bash-scripts/test-newest.sh
#   bash-scripts/test-newest.sh 35
#   bash-scripts/test-newest.sh Ukraine --open
#
# This writes test-newest.tex at the repo root (gitignored) and compiles it
# with compile-one.sh, leaving test-newest.pdf behind. One entry builds in
# seconds, against minutes for the full documents.
#
# Every solution file starts with \input{Soal/...}, so the wrapper inputs
# the solution only and the problem statement is printed once. If the
# solution file does not exist yet, the wrapper previews the problem alone.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILE_ONE="$ROOT/bash-scripts/compile-one.sh"
WRAPPER="$ROOT/test-newest.tex"
PDF="$ROOT/test-newest.pdf"

OPEN=0
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--open) OPEN=1; shift ;;
    -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         args+=("$1"); shift ;;
  esac
done

if [ "${#args[@]}" -gt 1 ]; then
  echo "Pass at most one entry (see bash-scripts/test-newest.sh --help)"
  exit 1
fi

# Highest leading number among "N Description.tex" files in DIR.
max_num() {
  local dir="$1" max=0 base n
  for f in "$dir"/*.tex; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .tex)"
    if [[ "$base" =~ ^([0-9]+)\  ]]; then
      n="$((10#${BASH_REMATCH[1]}))"
      [ "$n" -gt "$max" ] && max="$n"
    fi
  done
  echo "$max"
}

# Full path of the file in DIR named "NUM *.tex". Prints nothing when there
# is none; fails when NUM matches more than one file.
file_for_num() {
  local dir="$1" num="$2" matches=()
  while IFS= read -r -d '' f; do
    matches+=("$f")
  done < <(find "$dir" -maxdepth 1 -type f -name "$num *.tex" -print0)
  case "${#matches[@]}" in
    0) return 0 ;;
    1) echo "${matches[0]}"; return 0 ;;
    *) echo "Multiple files numbered $num in ${dir#$ROOT/}:" >&2
       printf '  %s\n' "${matches[@]#$ROOT/}" >&2
       return 1 ;;
  esac
}

# Leading number of one .tex path (".../35 Ukraine MO 2004.tex" -> 35).
num_of() {
  local base
  base="$(basename "$1" .tex)"
  [[ "$base" =~ ^([0-9]+)\  ]] && echo "$((10#${BASH_REMATCH[1]}))"
}

# Resolve the ENTRY argument to a leading number.
resolve_entry() {
  local q="$1" hits=()
  if [[ "$q" =~ ^[0-9]+$ ]]; then
    echo "$((10#$q))"
    return 0
  fi
  while IFS= read -r -d '' f; do
    hits+=("$f")
  done < <(find "$ROOT/Solusi" "$ROOT/Soal" -maxdepth 1 -type f \
                 -iname "*$q*.tex" -print0)
  if [ "${#hits[@]}" -eq 0 ]; then
    echo "No .tex file in Soal/ or Solusi/ matching '$q'" >&2
    return 1
  fi
  # Hits can be the matching Soal/Solusi pair for one entry. They agree
  # on a number exactly when they are that pair, so compare numbers.
  # A plain string (not an array) tracks the numbers seen, since empty
  # arrays trip `set -u` on older bash.
  seen=" "
  for f in "${hits[@]}"; do
    n="$(num_of "$f")" || {
      echo "File has no leading number: ${f#$ROOT/}" >&2
      return 1
    }
    [[ "$seen" == *" $n "* ]] || seen+="$n "
  done
  if [[ "$seen" =~ ^\ ([0-9]+)\ $ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  echo "Multiple entries match '$q':" >&2
  printf '  %s\n' "${hits[@]#$ROOT/}" >&2
  echo "Pass more of the name, or its number, to disambiguate." >&2
  return 1
}

if [ "${#args[@]}" -eq 1 ]; then
  num="$(resolve_entry "${args[0]}")" || exit 1
else
  soaln="$(max_num "$ROOT/Soal")"
  soln="$(max_num "$ROOT/Solusi")"
  num="$soaln"
  [ "$soln" -gt "$num" ] && num="$soln"
  if [ "$num" -eq 0 ]; then
    echo "No numbered entries in Soal/ or Solusi/"
    exit 1
  fi
fi

soal="$(file_for_num "$ROOT/Soal" "$num")" || exit 1
sol="$(file_for_num "$ROOT/Solusi" "$num")" || exit 1

if [ -z "$soal" ] && [ -z "$sol" ]; then
  echo "No entry numbered $num in Soal/ or Solusi/"
  exit 1
fi

if [ -n "$sol" ]; then
  display="$(basename "$sol" .tex)"
else
  display="$(basename "$soal" .tex)"
fi

soal_rel=""
sol_rel=""
[ -n "$soal" ] && soal_rel="${soal#$ROOT/}" && soal_rel="${soal_rel%.tex}"
[ -n "$sol" ] && sol_rel="${sol#$ROOT/}" && sol_rel="${sol_rel%.tex}"

# The solution already inputs its problem, so input the solution only and
# the statement is printed once. Only a solution that skips that convention
# gets explicit Soal/Solusi sections.
body=""
if [ -n "$sol" ]; then
  if head -n 1 "$sol" | grep -q '^\\input{Soal/'; then
    body="\\input{$sol_rel}"
  elif [ -n "$soal" ]; then
    body="\\section*{Soal}
\\input{$soal_rel}

\\section*{Solusi}
\\input{$sol_rel}"
  else
    body="\\input{$sol_rel}"
  fi
else
  body="\\input{$soal_rel}"
fi

{
  echo '\input{settings}'
  echo
  echo "\\title{Test: $display}"
  echo '\date{\today}'
  echo
  echo '\begin{document}'
  echo
  echo '\maketitle'
  echo
  printf '%s\n' "$body"
  echo
  echo '\end{document}'
} > "$WRAPPER"

echo "Previewing entry $num: $display"
[ -n "$soal" ] && echo "  problem:  ${soal#$ROOT/}"
[ -n "$sol" ] && echo "  solution: ${sol#$ROOT/}"

bash "$COMPILE_ONE" "$WRAPPER" || exit 1

if [ "$OPEN" -eq 1 ] && [ -f "$PDF" ]; then
  if [ -d /Applications/Skim.app ]; then
    open -a Skim "$PDF"
  else
    open "$PDF"
  fi
fi
