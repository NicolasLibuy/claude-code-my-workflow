# CLAUDE.MD — Healthcare Capacity Constraints for Chile

**Project:** Healthcare Capacity Constraints for Chile  
**Institution:** Universidad Adolfo Ibáñez (UAI)  
**Branch:** main

---

## Core Principles

- **Plan first** — enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** — run scripts and confirm outputs at the end of every task
- **Single source of truth** — R scripts under `scripts/R/` are authoritative for all indicator outputs; Beamer `.tex` documents methodology once analysis matures; Quarto `.qmd` mirrors Beamer for web publication
- **Quality gates** — nothing ships below 80/100
- **[LEARN] tags** — when corrected, save `[LEARN:category] wrong → right` to [MEMORY.md](MEMORY.md)

Cross-session context lives in [MEMORY.md](MEMORY.md); past plans, specs, and session logs are in [quality_reports/](quality_reports/).

---

## Folder Structure

```
healthcare_capacity_constrains/
├── CLAUDE.md                    # This file
├── .claude/                     # Rules, skills, agents, hooks
├── Bibliography_base.bib        # Centralized bibliography
├── Figures/                     # Figures and images
├── Preambles/header.tex         # LaTeX headers (blue/gold palette)
├── Slides/                      # Beamer .tex files (methodology decks)
├── Quarto/                      # RevealJS .qmd files + theme
├── data/                        # MINSAL source files (Excel + PDF) — see data/README.md
├── docs/                        # Project docs + authoritative indicator spec
│   └── analisis_presion_hospitalaria_cancer.docx   # ← indicator definitions (authoritative)
├── scripts/R/                   # Analysis pipeline (01–05) — PRIMARY ARTIFACT
│   └── _outputs/                # Generated tables, figures, RDS (gitignored)
├── quality_reports/             # Plans, session logs, merge reports, decision records
├── explorations/                # Research sandbox (see rules)
├── templates/                   # Session log, quality report templates
└── master_supporting_docs/      # Papers and supporting slides
```

> **Indicator definitions:** All occupancy/congestion and outcome-quality measures are
> defined in `docs/analisis_presion_hospitalaria_cancer.docx`. Every R implementation
> must be traceable to that document's formulas.

---

## Commands

```bash
# R pipeline (run from repo root)
Rscript scripts/R/00_run_all.R          # full pipeline
Rscript scripts/R/01_load.R             # debug individual script

# LaTeX (3-pass, XeLaTeX only)
cd Slides && TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex
BIBINPUTS=..:$BIBINPUTS bibtex file
TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex
TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex

# Deploy Quarto to GitHub Pages
./scripts/sync_to_docs.sh LectureN

# Quality score
python scripts/quality_score.py Quarto/file.qmd

# Palette sync (LaTeX ↔ SCSS)
./scripts/check-palette-sync.sh
```

**Palette contract:** color names in `Preambles/header.tex` must match SCSS variables in `Quarto/theme-template.scss`. See [`Preambles/README.md`](Preambles/README.md).

---

## Project Context

Sub-project of Fondecyt 2025: "Health shocks and human capital in Chile."

**Primary deliverable:** panel of hospital-level indicators (`z_i`) measuring ex-ante variation in healthcare access and quality, used as moderator in a Dynamic DiD design.

**Two indicator families (defined in `docs/analisis_presion_hospitalaria_cancer.docx`):**
1. **Occupancy / congestion** — hospital-network occupancy rates following Guidetti (2024)
2. **Outcome-based quality** — risk-adjusted death rates following Chan et al. (2023) and Otero (2024)

**Data source:** MINSAL Monthly Statistical Summaries (2014–2025) + SNSS/non-SNSS bed capacity registers — see `data/README.md`.

---

## Quality Thresholds (advisory)

| Score | Checkpoint | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready for deployment |
| 95 | Excellence | Aspirational |

Enforced by `/commit` (halts + asks for override); not enforced by a git pre-commit hook.

---

## Skills Quick Reference

| Command | What It Does |
|---------|-------------|
| `/data-analysis [dataset]` | End-to-end R analysis pipeline |
| `/review-r [file]` | R code quality review |
| `/audit-reproducibility [paper]` | Enforce replication tolerance thresholds |
| `/compile-latex [file]` | 3-pass XeLaTeX + bibtex |
| `/deploy [LectureN]` | Render Quarto + sync to docs/ |
| `/extract-tikz [LectureN]` | TikZ → PDF → SVG |
| `/proofread [file]` | Grammar/typo/overflow review |
| `/visual-audit [file]` | Slide layout audit |
| `/pedagogy-review [file]` | Narrative, notation, pacing review |
| `/qa-quarto [LectureN]` | Adversarial Quarto vs Beamer QA |
| `/slide-excellence [file]` | Combined multi-agent review |
| `/translate-to-quarto [file]` | Beamer → Quarto translation |
| `/validate-bib` | Cross-reference citations |
| `/commit [msg]` | Stage, commit, PR, merge |
| `/lit-review [topic]` | Literature search + synthesis |
| `/research-ideation [topic]` | Research questions + strategies |
| `/review-paper [file]` | Manuscript review (single-pass / `--adversarial` / `--peer <journal>`) |
| `/respond-to-referees [report] [manuscript]` | R&R cross-reference + response draft |
| `/verify-claims [file]` | Chain-of-Verification fact-check |
| `/context-status` | Show session health + context usage |
| `/seven-pass-review` | Seven-pass adversarial manuscript review |
| `/checkpoint [topic]` | Save structured state snapshot |
| `/preregister [--style osf|aspredicted|aea-rct]` | Draft a preregistration document |

---

## Beamer Custom Environments

| Environment | Effect | Use Case |
| --- | --- | --- |
| `keybox` | Gold background box | Key results, main takeaways |
| `definitionbox[Title]` | Blue-bordered titled box | Formal definitions, estimands |

## Quarto CSS Classes

| Class | Effect | Use Case |
| --- | --- | --- |
| `.smaller` | 85% font | Dense content, code output |
| `.positive` | Green bold | Good / identified results |

---

## Current Analysis State

| Module | Scripts | Status | Key Content |
| --- | --- | --- | --- |
| 01: Data loading | `scripts/R/01_load.R` | Template — replace | Read MINSAL Excel files into R |
| 02: Cleaning & harmonization | `scripts/R/02_clean.R` | Template — replace | Hospital panel, bed capacity harmonization |
| 03: Capacity / congestion indicators | `scripts/R/03_analyze.R` | Template — replace | Occupancy rates (Guidetti 2024) |
| 04: Quality indicators + tables | `scripts/R/04_tables.R` | Template — replace | Risk-adjusted death rates (Chan et al. 2023) |
| 05: Figures & output dataset | `scripts/R/05_figures.R` | Template — replace | Publication-ready maps and trends |
| Slides: Methodology | `Slides/capacity_measures.tex` | Not started | Methods deck for collaborators |
