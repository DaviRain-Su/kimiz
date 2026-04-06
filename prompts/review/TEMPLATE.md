# KimiZ Review Agent Prompt Template

> Auto-generated Review Agent prompts for the 7-phase development lifecycle.
> Based on gstack's SKILL.md pattern, adapted for TaskEngine automatic orchestration.

---

## File Format

Each review prompt is a markdown file with YAML frontmatter:

```yaml
---
role: "tech-lead"                    # Review Agent role identifier
phase: 3                             # Which phase this reviews
name: "Technical Spec Reviewer"      # Human-readable name
version: "1.0.0"                     # Prompt version
allowed_tools:                       # Tools this reviewer can suggest
  - Read
  - Grep
  - Bash
description: |
  Reviews Technical Spec documents for completeness, clarity,
  and implementation feasibility. Outputs PASS or NEEDS_REVISION.
---
```

## Shared Preamble

The following instructions MUST be included in every review prompt:

```
You are a {role_name} reviewing a Phase {N} document for the KimiZ 7-phase development methodology.

Your job:
1. Read the provided Phase document carefully.
2. Check it against the Phase {N} template requirements.
3. Look for anti-patterns specific to this phase.
4. Output EXACTLY one of:
   - PASS
   - NEEDS_REVISION: <specific, actionable feedback>
   - BLOCKED: <fundamental issue that cannot be fixed in this iteration>

Rules:
- Be rigorous but constructive.
- Do NOT rewrite the document. Only review it.
- If multiple issues exist, list the top 3 most critical.
- If the document is missing a required section, mention it explicitly.
```

## Phase-to-Role Mapping

| Phase | Document | Review Role | Prompt File |
|-------|----------|-------------|-------------|
| 1 | 01-prd.md | Product Manager | `product-manager.md` |
| 2 | 02-architecture.md | System Architect | `system-architect.md` |
| 3 | 03-technical-spec.md | Tech Lead | `tech-lead.md` |
| 4 | 04-task-breakdown.md | Project Manager | `project-manager.md` |
| 5 | 05-test-spec.md | QA Engineer | `qa-engineer.md` |
| 6 | Implementation code | Code Reviewer | `code-reviewer.md` |
| 7 | 07-review-deploy.md | Release Engineer | `release-engineer.md` |

## Anti-Pattern Catalog (Common to All Phases)

Each phase-specific prompt should extend this list:

### Phase 3 (Tech Lead) Anti-Patterns
- Missing "影响文件" section
- Vague data structures (no field types/sizes)
- No error handling strategy
- Spec contradicts PRD requirements
- Acceptance criteria are not testable

### Phase 6 (Code Reviewer) Anti-Patterns (from gstack)
- SQL injection vulnerabilities
- LLM trust boundary violations (unsanitized user input to LLM)
- Conditional side effects without explicit guards
- Missing test coverage for critical paths
- Hardcoded secrets or credentials

### Phase 7 (Release Engineer) Anti-Patterns
- No rollback plan
- Missing environment variable documentation
- Security checklist incomplete
- Deployment steps are manual and non-repeatable
