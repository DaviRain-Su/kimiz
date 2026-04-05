# KimiZ Documentation Structure

This directory contains all project documentation. Files are organized by purpose — do not dump new documents in the root.

---

## Directory Map

| Directory | Purpose | Examples |
|-----------|---------|----------|
| **`lifecycle/`** | 7-Phase methodology documents (PRD, Architecture, Tech Spec, etc.) | `01-prd.md`, `03-technical-spec.md` |
| **`reports/`** | Audit reports, review reports, handoff documents | `08-project-audit-report.md`, `review-report.md` |
| **`guides/`** | Quick references, migration guides, how-tos | `ZIG-0.16-BREAKING-CHANGES-SUMMARY.md`, `NULLCLAW-LESSONS-QUICKREF.md` |
| **`research/`** | Analysis of external projects, patterns, and integrations | `TIGERBEETLE-PATTERNS-ANALYSIS.md`, `OPENCLI-ANALYSIS.md` |
| **`comparison/`** | Competitive analysis and product comparisons | `LETTA-KIMIZ-COMPARISON.md` |
| **`design/`** | Architecture diagrams and design proposals | `SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md` |
| **`planning/`** | Task breakdowns and planning documents | `TASK-BREAKDOWN-20250405.md` |
| **`specs/`** | Current executable technical specs | Sprint task specs (FIX-ZIG-015, T-092, etc.) |
| **`skills/`** | Skill-specific documentation | Per-skill guides |
| **`reviews/`** | Code review archives | Past review reports |

---

## Root-Level Files (Keep These Here)

These are active indexes and should stay in `docs/` root:

- **`CURRENT-SPRINT.md`** — Current sprint status
- **`DESIGN-REFERENCES.md`** — Mapping of analysis docs to implementation phases
- **`FEATURES.md`** — Feature inventory
- **`ROADMAP-v2.md`** — 0-10 phase roadmap

---

## Where to Put New Documents

- **Implementing a task?** Write the spec in `specs/`, copy it to `tasks/active/sprint-YYYY-MM/`
- **Analyzing an external project?** Put it in `research/`
- **Writing a comparison?** Put it in `comparison/`
- **Creating a migration guide?** Put it in `guides/`
- **Producing a review/audit?** Put it in `reports/`
- **Updating the 7-phase methodology?** Put it in `lifecycle/`
