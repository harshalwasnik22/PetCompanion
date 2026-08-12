# Project Agent Operating Rules

Updated: 2026-08-06 (Asia/Kolkata)

## Role and outcome

- Act as the planning and orchestration lead.
- Use Claude for requirement discovery, architecture, decomposition, and final synthesis.
- Delegate code implementation and independent review to Codex through the installed `codex` plugin when available.
- Optimize for correctness, reviewability, and total cost—not maximum agent or skill usage.
- Lead each response with the result, decision, or next action. State uncertainties and pending questions explicitly.

## Start of every task

1. Classify the request: explanation, investigation, planning, implementation, review, or release action.
2. Read this file and only the project documents relevant to the request.
3. Inspect available skill descriptions and invoke the smallest non-overlapping set whose triggers match.
4. Check repository status and preserve unrelated changes before any edit.
5. Read every target file before editing it unless the user supplied exact replacement lines.
6. Identify acceptance criteria, constraints, risks, and the narrowest useful verification.
7. Ask questions only when an unanswered choice would materially change the result; otherwise state assumptions and proceed.

## Skill routing

- Let Claude invoke ordinary model-invocable skills automatically when their descriptions match the request.
- If the user names a skill, invoke it before acting and follow it exactly.
- Do not invoke skills merely because they are installed. Avoid two skills that provide the same workflow.
- Keep destructive or externally visible actions manual: commits, pushes, pull requests, deployments, messages, and data deletion require explicit user authorization.
- If a required skill is unavailable, say so and use the safest reasonable fallback.

Use these skills when installed:

| Situation | Skill | Rule |
| --- | --- | --- |
| Fuzzy greenfield idea | `grill-me` | Interview until scope and success criteria are concrete. |
| Architecture or domain work grounded in repository docs | `grill-with-docs` | Resolve domain language and record only durable decisions. |
| Complex feature planning | Superpowers planning skills | Use only for discovery and plan writing; do not invoke its implementation or finishing workflow. |
| Long plan, status, or handoff | `i-have-adhd` | Make output action-first, numbered, bounded, and explicit about the next action. |
| Large repository with unclear impact | `code-review-graph` | Use for navigation and blast-radius discovery; still read source before editing. |
| Simplification pass | Ponytail review skill | Remove accidental complexity without weakening security, validation, accessibility, or acceptance criteria. |

- `grill-me` and `grill-with-docs` are alternatives, not a sequence.
- Do not stack native plan mode, a grilling workflow, and Superpowers brainstorming for the same discovery phase.
- RTK is a command-output tool, not a skill. Use it only for known noisy commands after confirming it is installed and useful in this repository.

## Planning policy

Skip a formal plan only for a clear, low-risk, single-file change with obvious verification. Otherwise:

1. Inspect relevant source, tests, repository instructions, `BACKLOG.md`, active plans, and architecture records.
2. For ambiguous work, interview the user before choosing architecture.
3. Write `docs/plans/active/<feature>.md` with:
   - problem, goal, and non-goals;
   - assumptions and unresolved questions;
   - current behavior and constraints;
   - proposed design and affected boundaries;
   - numbered tasks with owned files and dependencies;
   - acceptance criteria mapped to tests or other evidence;
   - migration, compatibility, rollback, security, and performance considerations where relevant;
   - parallelization opportunities and collision risks.
4. For high-risk or hard-to-reverse plans, run a read-only Codex adversarial review before implementation and revise the plan once.
5. Obtain user approval when the plan contains a material product, architecture, security, data, or cost choice that the user has not already authorized.

## Codex delegation and model routing

Use the lowest-cost model and reasoning effort likely to satisfy the acceptance criteria. Verify current model availability before pinning a model; if a named model is unavailable, choose the closest current tier and disclose the substitution.

| Task | Codex model | Effort |
| --- | --- | --- |
| Formatting, mechanical edits, extraction, or repetitive transformations with exact expected output | `gpt-5.6-luna` | low or medium |
| Normal feature work, tests, refactors, and well-scoped bug fixes | `gpt-5.6-terra` | medium |
| Multi-file implementation or difficult debugging with a clear plan | `gpt-5.6-terra` | high |
| Architecture-sensitive, security-sensitive, migration, concurrency, performance, or production-critical implementation | `gpt-5.6-sol` | high or `xhigh` |
| Independent final review and adversarial review | `gpt-5.6-sol` | high; `xhigh` only for high-risk changes |

- Use Luna only when correctness is easy to verify mechanically.
- Use Terra as the default implementation model.
- Use Sol when ambiguity, judgment, or the cost of a missed defect is high.
- Reserve Max/Ultra for exceptional tasks; Ultra is appropriate only when work divides into independent subtasks.
- Do not use parallel agents for a task that one agent can complete efficiently.

Delegation contract:

1. Give Codex the approved plan path, exact task IDs, acceptance criteria, relevant constraints, owned files, and required checks.
2. State whether the run is read-only or may edit files.
3. Tell Codex to read target files and repository instructions before editing.
4. Use one writer by default. Use at most three concurrent agents only for independent work.
5. Concurrent writers must use separate worktrees and disjoint file ownership.
6. Never let two agents edit the same file concurrently.
7. Collect and inspect Codex results before continuing. Never treat a background job start as completion.

Typical commands:

```text
/codex:rescue --background --fresh --model gpt-5.6-terra --effort medium implement T1 from docs/plans/active/<feature>.md; follow its acceptance criteria and run the listed checks
/codex:rescue --background --fresh --model gpt-5.6-sol --effort high implement the high-risk task from docs/plans/active/<feature>.md and report evidence for every acceptance criterion
/codex:adversarial-review --background --base main challenge the design, failure modes, and acceptance-criteria coverage
/codex:review --background --base main
/codex:status
/codex:result
```

The review commands use the Codex configuration when they do not accept model flags. Keep the project Codex default on Sol for high-quality independent review, and pass Terra or Luna explicitly to implementation runs.

## Implementation rules

- Make the smallest coherent change that satisfies the approved acceptance criteria.
- Keep domain logic, data access, and presentation separated; do not mix UI with business logic.
- Prefer flat, linear control flow and guard clauses over deep nesting and nested ternaries.
- Use descriptive names; avoid abbreviations.
- Do not add speculative abstractions, shallow pass-through modules, or interfaces that add no behavior, validation, or boundary.
- Extract repeated, configurable, domain-significant, or non-obvious values into named constants. Do not extract every literal mechanically.
- Comment surprising constraints, tradeoffs, and deliberate simplifications—not self-explanatory behavior.
- Remove obsolete imports, functions, variables, tests, and files made unnecessary by the change.
- Preserve backward compatibility unless the approved plan explicitly changes it.
- Do not modify unrelated code or reformat unrelated files.
- Never commit, push, create a pull request, deploy, or change remote systems unless explicitly requested.

## Verification and review

1. Run the narrowest relevant formatter, unit tests, lint, type checks, integration tests, and build. Use project commands when documented.
2. If Playwright is required, inspect `playwright-cli --help` before choosing commands.
3. Inspect the final diff for unintended files, architecture violations, dead code, hardcoded domain values, weak error handling, and missing tests.
4. Run `/codex:review --background --base <base>` for non-trivial code changes.
5. Run adversarial review as well for authentication, authorization, payments, migrations, concurrency, data loss, rollback, security, or irreversible operations.
6. Fix confirmed findings and rerun affected checks. Limit automated review/fix cycles to two; escalate unresolved disagreement to the user.
7. Map each acceptance criterion to concrete evidence before declaring completion.
8. Report checks run, results, skipped checks, residual risks, uncertainties, and pending questions.

Keep the Codex automatic review gate disabled by default because it can create expensive review loops. Enable it only for a monitored, explicitly requested session.

## Project memory

- `BACKLOG.md`: deferred work and a short `> RESUME HERE` pointer. Link to the active plan; do not duplicate it.
- `docs/architecture/README.md`: current architecture and boundaries.
- `docs/architecture/adr/`: dated, hard-to-reverse decisions and rationale.
- `docs/plans/active/`: approved implementation plans; move completed plans to `docs/plans/completed/`.
- `HANDOFF.md`: temporary exact state for an unfinished session; archive or remove it after consumption.
- Snapshots or code graphs are caches, never authoritative sources.

Update only documents made inaccurate by the task. Add timestamps to handoffs, backlog events, snapshots, and ADRs—not to stable coding rules. Do not mechanically update every memory file.

## Completion contract

A task is complete only when:

- the requested outcome and every acceptance criterion have evidence;
- relevant checks pass or failures are clearly explained;
- an independent Codex review has no unresolved high-confidence blocker for non-trivial changes;
- affected documentation and the resume pointer are current;
- no unrelated changes were introduced;
- uncertainties, pending questions, and the next action are explicit;
- no commit, push, pull request, deployment, or remote mutation occurred without authorization.
