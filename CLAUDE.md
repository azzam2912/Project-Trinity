# Project Trinity

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

A LaTeX project collecting non-geometry olympiad problems and their solutions, compiled into PDF documents. Solutions are written in Indonesian (Bahasa Indonesia).

## Finishing a task: always commit and push

**Standing instruction from the owner, no need to ask each time.** When you finish a piece of work in this repo, commit it and push to `master`:

```bash
git add -A && git commit -m "<what changed>" && git push origin master
```

- Commit **directly to `master`**; do not create a branch or open a PR. This is a single-author repo; a branch just strands the files.
- Do this at the end of the task, once the `.tex` compiles, not after every intermediate edit.
- `git add -A` is intended: build artifacts are already gitignored, so it picks up sources only. Note that the three renamed PDFs (`Project Trinity*.pdf`) **are** tracked, so a rebuild will show up in the commit; that is fine and expected. Still, glance at `git status` first, and if it sweeps in unrelated half-finished edits the owner was working on, commit only your own paths instead and say so.
- If the push is rejected because `origin/master` moved, `git pull --rebase origin master` and push again. Report a genuine conflict rather than resolving it blind.
- The one thing to ask about first: deleting or moving files the owner did not ask you to touch.

## Building the PDFs

There are three main LaTeX entry points:

```bash
# Full document (problems + solutions)
pdflatex --shell-escape main.tex

# Problems only
pdflatex --shell-escape main-problems.tex

# Solutions only
pdflatex --shell-escape main-solutions.tex
```

The `--shell-escape` flag is required because `azzam.sty` loads the `asymptote` package, which calls out to the `asy` binary to render figures. Run `pdflatex` twice if the table of contents is out of date.

Auxiliary files (`.aux`, `.log`, `.out`, `.fls`, `.fdb_latexmk`, `.toc`, `.eps`, `main-*.asy`, `.pre`, and the rest of the extensions `bash-scripts/clean.sh` knows about) are gitignored.

### The `bash-scripts/` helpers

For a full rebuild, prefer the scripts over bare `pdflatex` calls. Run them from the repo root:

| Script | Use |
|--------|-----|
| `bash bash-scripts/compile.sh` | the everyday case: builds all three documents in parallel (pdflatex → asy → pdflatex ×2 each) and renames the PDFs to their published names. `--serial` builds one at a time; `--no-rename` skips the rename. |
| `bash bash-scripts/compile-one.sh DOC [DOC ...]` | build a single entry point (`all` / `problems` / `solutions`, or any other `.tex` path). `--rename` publishes the PDF; `--keep-asy` keeps the extracted per-figure `main-N.asy`/`.pdf` files for debugging one diagram. This is what `compile.sh` calls under the hood. |
| `bash bash-scripts/clean.sh` | delete leftover build artifacts and per-figure `.asy`/`.pdf` files. `--dir FOLDER` scopes it to one folder, `-n`/`--dry-run` previews, `--pdf` also wipes the published PDFs (off by default, since those are tracked). |
| `bash bash-scripts/watch.sh NAME_OR_PATH` | live preview: watches one `.tex` (an entry point or a fragment under `Soal/` or `Solusi/`), rebuilds on save, and reopens the PDF in Skim (or the system viewer). `--doc DOC` overrides which entry point it compiles; `--no-open` skips opening a viewer. |
| `bash bash-scripts/test-newest.sh [ENTRY]` | fast check while drafting: builds only one entry into `test-newest.pdf` (gitignored) instead of all three documents. Default is the entry with the highest number across `Soal/` and `Solusi/`, so a new entry is picked up with no filename edits. Pass a number or filename fragment to preview one entry instead; `--open` opens the PDF. |

Every script supports `-h`/`--help` with fuller usage and examples. The figure-rendering step globs `main-N.asy` files rather than looping a fixed range, so it never misses a diagram and there is no bound to bump as the project grows.

**Compile before you commit.** Editing a `.tex` and not checking that it still builds is an incomplete task. A single malformed environment can take down the whole document, so at minimum run the entry point that includes the file you touched, e.g. `bash bash-scripts/compile-one.sh solutions`. While drafting one entry, `bash bash-scripts/test-newest.sh` is enough; run the full build before pushing.

## Project Architecture

The document tree is:

```
main.tex / main-problems.tex / main-solutions.tex
  └── settings.tex          # \documentclass + \usepackage[hagavi]{azzam}
  └── problems.tex          # \subsection + \input for each Soal/ file
  └── solutions.tex         # \subsection + \input for each Solusi/ file
        └── Soal/N ...      # raw problem statement (plain math, no preamble)
        └── Solusi/N ...    # \inputs its problem; solution in solusi env
```

### Numbering convention

Every problem is assigned a sequential integer N. Files are named `N Description.tex` (e.g. `14 Baltic Way 2012 Problem 3.tex`). The same N is used in both directories (`Soal/`, `Solusi/`).

### Problem files (`Soal/`)

Contain only the raw problem statement — plain LaTeX math, no `\begin{document}` or preamble. Example:

```latex
Tentukan semua tripel bilangan asli $(a,b,c)$ sehingga ...
```

### Solution files (`Solusi/`)

Follow this structure:

```latex
\input{Soal/N ...}

\begin{solusi}
...solution body...
\end{solusi}
```

The `solusi` environment (plus helpers like `\dangle` and `lemmarev`) comes from the custom `azzam` package loaded in `settings.tex`. Note that `azzam.sty` here is derived from `evan.sty` (Evan Chen's package); both are BOOST-licensed, so keep the copyright headers intact if the package is modified.

### Aggregator files (`problems.tex`, `solutions.tex`)

Each entry is a `\subsection{Display Name}` followed by `\input{Soal/N ...}` or `\input{Solusi/N ...}`. When adding a new problem, append to **both** aggregator files, keeping numbers in sync.

## Adding a New Problem

1. Create `Soal/N Name.tex` with the problem statement.
2. Create `Solusi/N Name.tex` starting with `\input{Soal/N Name}` and the solution in a `solusi` environment.
3. Append a `\subsection` + `\input` entry to `problems.tex`.
4. Append a matching entry to `solutions.tex`.

## Writing style: avoid AI-sounding prose

Solutions here are written in Indonesian, in the owner's own voice. A solution can be completely correct and still read as machine-written. These are the signals to hunt for and remove before finishing any prose (solution bodies, problem statements, commit messages, chat replies) in this repo. The examples are English, but the same habits show up in Indonesian and get the same treatment.

| Signal | Sounds like AI | Write this instead |
|---|---|---|
| The em dash | "The triangle is isosceles—and that is the whole trick." | Use a comma, a colon, or a full stop. Never the long dash. |
| Hyphenated compounds | "a classic angle-chasing shortcut" | "a classic angle chasing shortcut" |
| AI vocabulary | "Let us delve into this robust approach and leverage the key insight." | "Let us look at what makes this approach work." |
| The "not X but Y" move | "This is not just about angles, it is about seeing the configuration." | "The trick is to see the configuration differently." |
| Reflexive lists of three | "Look at the sides, the angles, and the symmetry." | "Look at the sides and the angles." (Two is enough when two is enough.) |
| Hedging pile-up | "This might perhaps be one possible way you could arguably approach it." | "Here is one way to approach it." |
| Uniform rhythm | Every sentence the same length and shape. | Vary it. Short sentence. Then a longer one that takes its time and lets the idea settle before it stops. |
| "It is worth noting" | "It is worth noting that $OI \perp BC$." | "Note that $OI \perp BC$." |
| Empty summary closer | "In conclusion, we have successfully solved the problem." | Cut it. The `\blacksquare` already says so. |

Never use a hyphen or en/em dash as a sentence-joining punctuation mark. A hyphenated compound word is fine only when it is standard spelling and no natural unhyphenated alternative exists; when in doubt, write it as two words.

Keep the mathematical register the existing solutions use: directed angles via `\dangle`, named lemmas in `lemmarev`, and the step actually stated rather than gestured at. Do not pad a proof with restatements of what was just proved.
