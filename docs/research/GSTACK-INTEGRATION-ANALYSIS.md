# gstack Integration Analysis for KimiZ TaskEngine

**Analyzed**: 2026-04-06  
**Source**: https://github.com/garrytan/gstack  
**Analyst**: Coding Agent for T-128

---

## 1. What is gstack?

gstack is Garry Tan's open-source "AI builder framework" that turns Claude Code into a virtual engineering team. It consists of **23+ opinionated skills** packaged as directories with `SKILL.md` files.

### Core Philosophy

> "A single builder with the right tooling can move faster than a traditional team."

Garry claims to ship **10,000-20,000 lines of production code per day**, part-time, while running YC.

### Key Numbers

- **64.7k** GitHub stars
- **600,000+ lines** of production code in 60 days (35% tests)
- **140,751 lines added, 362 commits** in one week
- Works across **8 AI coding agents** (Claude Code, Codex, Cursor, etc.)

---

## 2. gstack's Architecture: Skill-as-Directory

### Directory Structure

```
gstack/
├── agents/
│   └── openai.yaml              # OpenAI integration manifest
├── qa/
│   ├── SKILL.md                 # Full QA agent prompt + workflow
│   ├── SKILL.md.tmpl            # Template for regeneration
│   ├── references/              # Supporting docs
│   └── templates/               # Reusable test templates
├── review/
│   ├── SKILL.md                 # Pre-landing code review agent
│   └── SKILL.md.tmpl
├── plan-ceo-review/
│   ├── SKILL.md                 # Strategic scope review agent
│   └── SKILL.md.tmpl
├── plan-eng-review/
│   ├── SKILL.md                 # Architecture lock agent
│   └── SKILL.md.tmpl
├── design-review/
│   ├── SKILL.md                 # Design audit agent
│   └── SKILL.md.tmpl
├── ship/
│   ├── SKILL.md                 # Release engineer agent
│   └── SKILL.md.tmpl
├── ... 23+ similar directories
└── SKILL.md.tmpl                # Master template with shared preamble
```

### SKILL.md Format

Each skill is a markdown file with YAML frontmatter:

```yaml
---
name: plan-ceo-review
preamble-tier: 3
version: 1.0.0
description: |
  CEO/founder-mode plan review. Rethink the problem, find the
  10-star product, challenge premises. Four modes: SCOPE EXPANSION,
  SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION.
  Use when asked to "think bigger", "expand scope", "strategy review".
allowed-tools:
  - Read
  - Grep
  - Bash
  - AskUserQuestion
  - WebSearch
---
```

The body contains:
1. **Preamble** (shared bash setup for telemetry, config, session tracking)
2. **Routing rules** (when to invoke this skill)
3. **Workflow** (step-by-step instructions for the agent)
4. **Checklists** (quality gates)
5. **Output format** (what the agent must produce)

### Master Template System

- `SKILL.md.tmpl` contains shared preamble injected into all skills
- `bun run gen:skill-docs` auto-generates individual `SKILL.md` files from templates
- This ensures consistency across 23+ skills

---

## 3. gstack's Review Agents

### `/plan-ceo-review` — Strategic Review

**Four scope modes** (a powerful framework we should adopt):

1. **SCOPE EXPANSION**: Dream big, 10x the ambition
2. **SELECTIVE EXPANSION**: Hold core scope, cherry-pick expansions
3. **HOLD SCOPE**: Maximum rigor, no scope growth
4. **SCOPE REDUCTION**: Strip to essentials, ruthless prioritization

**Use case**: Before Phase 2 (Architecture), challenge whether the PRD is ambitious enough.

### `/review` — Pre-Landing Code Review

Checks for:
- SQL safety (parameterized queries)
- LLM trust boundary violations
- Conditional side effects
- Structural issues

**Use case**: Phase 6 (Implementation) gate before marking code complete.

### `/qa` — Systematic Testing

Three tiers:
- **Quick**: Critical/high bugs only
- **Standard**: + medium bugs
- **Exhaustive**: + cosmetic bugs

Produces:
- Before/after health scores
- Fix evidence
- Ship-readiness summary

**Use case**: Phase 5/7 validation with real browser testing.

### `/cso` — Chief Security Officer

Runs:
- OWASP audit
- STRIDE threat modeling

**Use case**: Phase 7 (Review & Deploy) security gate.

---

## 4. What gstack Does Well

### A. Opinionated Role Specialization
Each skill is a complete "persona" with:
- Specific goals
- Allowed tools
- Step-by-step workflow
- Checklists
- Output format

This eliminates prompt ambiguity.

### B. Human-Scale Packaging
23 skills = 23 directories = 23 markdown files. No database, no complex registry. Just files.

### C. Shared Infrastructure
All skills share:
- Telemetry
- Config system (`gstack-config`)
- Session tracking
- Update checks
- Routing rules

Via the master `SKILL.md.tmpl` preamble.

### D. Routing Intelligence
The main gstack skill has explicit routing rules:

```markdown
- "is this worth building" → invoke /office-hours
- "think bigger" → invoke /plan-ceo-review
- "review architecture" → invoke /plan-eng-review
- "test the site" → invoke /qa
- "review code" → invoke /review
- "ship" → invoke /ship
```

This means the human doesn't need to remember skill names — natural language triggers the right expert.

---

## 5. What gstack Is Missing (KimiZ's Opportunity)

### A. No Automatic Orchestration
In gstack, **the human must remember to invoke the right skill at the right time**.

- Before coding: human types `/plan-ceo-review`
- After coding: human types `/review`
- Before shipping: human types `/qa`

There is **no state machine** ensuring these reviews happen in the right order. If the human forgets `/review`, bad code lands.

### B. No Project Lifecycle Management
Gstack skills are **stateless tools**. They don't track:
- What phase a project is in
- Whether PRD → Architecture → Tech Spec have been completed
- Which tasks are done vs todo
- When to archive completed work

### C. No Task Breakdown Automation
Gstack has `/autoplan` which generates a plan, but there's no automatic conversion of that plan into a task queue that executes sequentially.

---

## 6. Integration Strategy: KimiZ + gstack

### The Core Insight

**gstack solved "who" (which expert). KimiZ solves "when" (which phase) and "how" (automatic execution).**

Together, they form a complete autonomous development pipeline.

### Integration Layer 1: Prompt Format Compatibility

KimiZ's `prompts/review/*.md` should follow gstack's `SKILL.md` conventions:

```yaml
---
role: "tech-lead"
phase: 3
name: "Technical Spec Reviewer"
version: "1.0.0"
allowed_tools:
  - Read
  - Grep
  - Bash
description: |
  Reviews Technical Spec documents for completeness...
---
```

This makes it easy to port gstack's proven prompts into KimiZ.

### Integration Layer 2: Review Agents as KimiZ Skills

Each Review Agent becomes a `defineSkill` DSL skill:

```zig
pub const tech_lead_review_skill = defineSkill(.{
    .name = "tech-lead-review",
    .description = "Reviews Phase 3 Technical Spec",
    .input = .{
        .phase_doc_path = []const u8,
        .spec_path = []const u8,
    },
    .output = ReviewResult,
    .handler = techLeadReviewHandler,
});
```

This gives us:
- Comptime type safety
- Auto registry
- JSON compatibility
- Subagent dispatchability

### Integration Layer 3: TaskEngine Auto-Triggers Review

Instead of human `/slash-commands`, TaskEngine calls Review Skills at phase boundaries:

```zig
pub const phase_reviews = [7]ReviewRole{
    .product_manager,    // Phase 1 → 2
    .system_architect,   // Phase 2 → 3
    .tech_lead,          // Phase 3 → 4
    .project_manager,    // Phase 4 → 5
    .qa_engineer,        // Phase 5 → 6
    .code_reviewer,      // Phase 6 gate
    .release_engineer,   // Phase 7 final
};
```

### Integration Layer 4: Absorb gstack Best Practices

| gstack Skill | KimiZ Adoption |
|--------------|----------------|
| `/plan-ceo-review` | Phase 2 scope mode assessment (4 modes) |
| `/plan-eng-review` | Phase 3 architecture lock validation |
| `/review` | Phase 6 code review (SQL safety, LLM boundaries, side effects) |
| `/qa` | Phase 5/7 testing with health scores |
| `/cso` | Phase 7 security audit (OWASP + STRIDE) |
| `/ship` | Phase 7 release automation |

---

## 7. Created Artifacts

Based on this analysis, the following KimiZ artifacts have been created:

- `prompts/review/TEMPLATE.md` — Shared prompt structure
- `prompts/review/product-manager.md` — Phase 1 PRD review
- `prompts/review/system-architect.md` — Phase 2 Architecture review (with scope modes)
- `prompts/review/tech-lead.md` — Phase 3 Technical Spec review
- `prompts/review/code-reviewer.md` — Phase 6 Implementation review (with gstack safety checks)

---

## 8. Recommendation

**Do NOT try to reimplement gstack from scratch.** Instead:

1. **Port gstack's best prompts** into KimiZ's `prompts/review/` directory
2. **Wrap each prompt as a `defineSkill` Skill** for type safety and auto-registry
3. **Let TaskEngine orchestrate when each Skill runs** based on the 7-phase state machine
4. **Keep the human in the loop only for BLOCKED decisions** and scope mode selection

This is the fastest path to a production-grade autonomous development system.
