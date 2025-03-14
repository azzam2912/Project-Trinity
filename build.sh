#!/bin/bash

# Compile main.tex twice to generate table of contents
pdflatex main.tex
pdflatex main-problems.tex
pdflatex main-solutions.tex

pdflatex main.tex
pdflatex main-problems.tex
pdflatex main-solutions.tex
