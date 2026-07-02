# Project Trinity

A personal LaTeX compilation of math olympiad problems and solutions (Indonesian), non-geometry, curated by the author. Compiles to three PDFs.

## Structure

- `Soal/N <title>.tex` — problem statement N (Indonesian: "Soal" = problems)
- `Solusi/N <title>.tex` — solution N (Indonesian: "Solusi" = solutions), each starts with `\input{Soal/N <title>}` then wraps the solution in a `solusi` environment
- `problems.tex` / `solutions.tex` — master lists that `\subsection{...}` + `\input{}` each numbered file, in order
- `main.tex` — combined problems+solutions document (title: "Project Trinity")
- `main-problems.tex` — problems-only document
- `main-solutions.tex` — solutions-only document
- `settings.tex` — shared preamble (`scrartcl`, `azzam` package)
- `azzam.sty` — personal olympiad-typesetting package, derived from `evan.sty` (Evan Chen's package); both are BOOST-licensed, keep copyright headers intact if modified

Problems and solutions are numbered and paired by filename prefix (e.g. `Soal/14 Baltic Way 2012 Problem 3.tex` ↔ `Solusi/14 Baltic Way 2012 Problem 3.tex`). When adding a new problem, add both files, then append a matching `\subsection`+`\input` entry to both `problems.tex` and `solutions.tex` (numbers must stay in sync).

## Build

```bash
bash run.sh
```

This runs, in order:
1. `build.sh` — compiles `main.tex`, `main-problems.tex`, `main-solutions.tex` with `pdflatex`, each run twice (for the table of contents)
2. `rename.sh` — renames the three output PDFs to `Project Trinity.pdf`, `Project Trinity [Problems].pdf`, `Project Trinity [Solutions].pdf`
3. `delete.sh` — removes LaTeX build artifacts (`.aux`, `.log`, `.toc`, `.out`, `.fls`, `.fdb_latexmk`, `.pre`, `.eps`, `main-*.asy`, `test-*.asy`)

Requires a working `pdflatex`/TeX Live install (uses `scrartcl`, `asymptote` support via `azzam.sty`).

## Conventions

- Problem/solution prose is written in Indonesian.
- Solutions are wrapped in the custom `solusi` environment from `azzam.sty`.
- Keep `Soal/` and `Solusi/` file numbering and titles identical between the two directories and between `problems.tex`/`solutions.tex`.
