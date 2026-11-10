# Workflow: from ticket to hand-over

Canonical process for every bug fix and feature in this project. The main chat agent is the
**orchestrator**; specialist roles run as subagents defined in `.cursor/agents/00-harness/`.
Entry commands: `/aw-task`, `/aw-approve`, `/aw-continue` (see `.cursor/skills/`).

## Hard rules

1. **No code changes before the user approves the plan** (Gate A). Docs inside `docs/tasks/<ID>/` are the only files written before approval.
2. **Git is read-only.** Allowed: `git status`, `git diff`, `git log`, `git show`, `git blame`, `git branch --show-current`, `git rev-parse`. Forbidden: `add`, `commit`, `push`, `pull`, `fetch`, `checkout`, `switch`, `restore`, `reset`, `stash`, `merge`, `rebase`, `cherry-pick`, `tag`, `branch -d/-m`, `clean`, `worktree`. The user creates branches, commits and MRs.
3. **No CI.** Never trigger pipelines, never push to trigger them, never call Bitbucket/Teamwork APIs that change state.
4. **No dependency changes** (`composer require/update/remove`, `npm install`) without explicit user approval.
5. **Host is the source of truth**; the container is only a runtime (see `ENVIRONMENT.md`).
6. **Everything is recorded** in `docs/tasks/<ID>-<slug>/`. The orchestrator updates `status.md` after every step.
7. **Docs before code:** read `docs/<Module>/AGENTS.md` and the relevant module docs before analysing code. If Codebase Memory has indexes for that module’s code and/or docs roots, **query CBM first** (see `CODEBASE_MEMORY.md`); use disk reads for edits and for paths with coverage gaps. For Magento XML wiring (plugins, preferences, observers, webapi, routes) use **magento-wiring** MCP first (`MAGENTO_WIRING_MCP.md`); never claim wiring facts from CBM alone.
8. Each module under `app/code/Aheadworks/<Module>` is its **own git repository**.
   Exception: `Bup`, `Ca`, `Captcha`, `Core`, `FakeDataGenerator`, `Giftcard`, `Nmi`, `RewardPoints`, `Sarp2BraintreeByPaypal` have no `.git` — no MR is possible; flag it at S0 Intake and ask the user how changes to them should be delivered.

## Task folder

```
docs/tasks/<ID>-<slug>/          ID = Teamwork task id (e.g. 41496729); slug = kebab-case summary
  status.md                      dashboard only, ≤ 60 lines (template: templates/status.md)        RU
  journal.md                     append-only event log; written by the orchestrator, read by nobody EN
  00_intake.md                   ticket as received + clarifications                               RU
  01_analysis.md                 bug analysis (RCA) or feature specification (TZ)                  RU
  01_analysis_review.md          spec reviewer verdicts (features only)                            EN
  02_plan.md                     solution, file table, task index, verification, docs, risks       RU
  plan/task-NN.md                one file per plan task (template: templates/plan_task.md)        RU
  02_plan_review.md              plan reviewer verdicts                                            EN
  impl/task-NN.md                developer log of plan task NN (template: templates/impl_task.md) EN
  review/task-NN.md              code review of plan task NN, all iterations                       EN
  05_test_report.md              baseline + final gate tables, smoke                               EN
```

Templates: `docs/_harness/templates/`. RU files are read by the user; EN files are internal working
logs (cheaper in tokens). Code, identifiers, commit messages and MR titles are always English.
A plan with ≤ 3 tasks may keep the task sections inline in `02_plan.md` instead of `plan/task-NN.md`.
Tasks created before 2026-10-09 keep their old single-file layout (`03_impl_log.md`, `04_code_review.md`, `06_mr.md`).

### Size discipline

- `status.md` is a dashboard: stages, task table (one line per task), open questions, accepted exceptions.
  No history, no review details, no struck-through items — history goes to `journal.md`, details to the task files.
- Requirements that a review carries over to a later plan task are written into that `plan/task-NN.md`
  (§ Carried over), not into `status.md`. Delete them there once done.
- `check-harness.sh` warns when a `status.md` exceeds 80 lines or 12 000 characters.

## Stages

| Stage | Role (subagent) | Reads | Writes | Exit criteria |
|---|---|---|---|---|
| S0 Intake | orchestrator | ticket text / bug report | task folder, `00_intake.md`, `status.md` | type (bug/feature), module(s), ID known; else ask |
| S1 Analysis | `aw-analyst` | `00_intake.md`, `docs/<Module>/*` | `01_analysis.md` | no blocking questions open |
| S1R Spec review | `aw-spec-reviewer` (**features only**) | `01_analysis.md`, intake | `01_analysis_review.md` | APPROVED (max 2 review cycles) |
| S2 Plan | `aw-planner` | analysis, module docs | `02_plan.md`, `plan/task-NN.md` | complete per template |
| S2R Plan review | `aw-plan-reviewer` (bugs: also reviews the analysis) | plan, analysis | `02_plan_review.md` | APPROVED (max 1 rework) |
| **Gate A** | **user** | plan summary | approval recorded in `status.md` | user says approve (`/aw-approve`) |
| S3 Baseline | `aw-qa` | module | `05_test_report.md` § Baseline | baseline recorded |
| S4 Implement | `aw-developer` | `plan/task-NN.md` (+ `02_plan.md` § Решение) | code + `impl/task-NN.md` | task done, unit tests written, gates green |
| S5 Code review | `aw-code-reviewer` | diff, `plan/task-NN.md`, `impl/task-NN.md` | `review/task-NN.md` | APPROVED (max 1 fix cycle per task) |
| S6 Verify | `aw-qa` | changed files, smoke from plan | `05_test_report.md` § Final | all blocking gates pass (`QUALITY_GATES.md`) |
| S7 Docs | `aw-doc-keeper` | diff, `02_plan.md` § Влияние на документацию | updated `docs/<Module>/*` | docs reflect new behaviour; `check-harness.sh` passes |
| **Gate B** | **user** | hand-over summary in chat | user commits/pushes/opens MR | — |

S4–S5 loop per plan task (or per group, see below); S6 runs once at the end over the whole change.

### Fast lane (small bug fixes)

Allowed when all hold: one module, no `db_schema.xml` / public API change, expected diff ≲ 80 lines.
Then S1+S2 are produced by `aw-analyst` as one document (`01_analysis.md` with a "План" section,
no `02_plan.md`), one combined review is done by `aw-plan-reviewer`. **Gate A is never skipped.**

### Simple lane (`/aw-simple-task`)

For trivial changes: one module, diff ≲ 30 lines, no `db_schema.xml` / patches / public API / new `di.xml` entries,
the place to change is clear without research. One agent, no subagents, one artifact `docs/tasks/<ID>-<slug>/task.md`,
one approval stop on a ≤ 5-line mini-plan, gates via `gates.sh --files`, self-check instead of review.
Steps: `.cursor/skills/aw-simple-task/SKILL.md`. If the change outgrows the criteria, it switches to `/aw-task`.

### Grouping small plan tasks

The planner marks a task `size: S` when its expected diff is ≲ 50 lines. Up to 3 consecutive `S` tasks
of one module may go through one S4 → S5 cycle (one `impl/` and one `review/` file named after the first task,
e.g. `task-04-06.md`).

### Re-review is targeted

Iteration 2 of any review checks only: the remarks of iteration 1, and the files the author changed while
fixing them (listed in the rework note). It does not re-review untouched parts and does not re-run gates
that the author already recorded as green after the fix.

## Iteration limits and escalation

| Loop | Max | After the limit |
|---|---|---|
| Analysis ↔ spec review | 2 reviews | critical remarks → stop and ask the user; minor → continue with warning in `status.md` |
| Plan ↔ plan review | 2 reviews | same |
| Code ↔ code review (per task) | 2 reviews | same |
| Gates failing after fixes | 2 fix attempts | stop, report evidence |

Blocking questions from any role: stop, write them to `status.md` § Открытые вопросы, present to the
user in one message, resume the same role with the answers.

**Plan deviation:** if implementation needs anything outside the approved plan (new file in another
module, schema change, changed public API, different approach), stop, write a "Plan amendment" in
`02_plan.md`, and get user approval again. Trivial deviations (extra private helper, test fixtures)
are just logged in `impl/task-NN.md`.

**Environment blockers** (container down, drift, stale generated code, cache): `aw-qa` may fix the
environment (start-up hint, `sync.sh`, `cache:flush`, removing `generated/code/Aheadworks/<Module>`)
but never product code or task scope. Mirror sync (`--mirror`) and DB-destructive actions need user consent.

## How the orchestrator delegates

- Spawn the role with the Task tool (`subagent_type` = role name, e.g. `aw-analyst`). Pass only:
  task folder path, the **exact files (and sections) to read**, module name(s), and the concrete instruction.
  Never ask a role to "read the task folder".
- Roles never read `status.md` or `journal.md`; the orchestrator owns both.
- Every role returns at most 10 lines: verdict/result, artifact path, blocking questions. Details stay in the artifact.
- Rework instruction template: "Fix only the remarks in `<review file>` (iteration N). Do not change unrelated parts. List the files you changed."
- After each role returns: check the artifact exists, update `status.md` (one line) and append one line to `journal.md`.
- **Batches:** if the plan has more than 6 implementation units, stop after every 5 units: update `status.md`,
  tell the user the progress in ≤ 3 lines and ask to continue in a **new chat** with `/aw-continue <ID>`.
- Before Gate A and Gate B, give the user a short summary in Russian: what, why, risks, open points, and the file to read.
- Domain helpers in `.cursor/agents/10-domain-helpers/` (`magento-issue-debugger`, `magento-security-analyst`,
  `magento-index-analyst`, `magento-hyva-specialist`) may be consulted by any role; they never write task artifacts.
  More specialists are archived in `.cursor/agents-library/` (not loaded by Cursor).

## Gate B hand-over (orchestrator, no artifact)

For every touched repository run `git -C app/code/Aheadworks/<Module> status --porcelain` and `diff --stat`, then tell the user:
current branch, number of changed files, **files that are not part of the plan or were already staged before the task**
(must not go into the commit), suggested branch and commit message (conventions below), deploy notes
(`setup:upgrade` / reindex / cache), gate results and pre-existing failures, docs updated.

## Branch, commit and MR conventions (observed in module repos)

- Branch: `bugfix/<ID>-<Teamwork-Title-With-Dashes>` or `feature/<ID>-<Teamwork-Title-With-Dashes>` (suffixes like `___2`, `-2` mark retries); release branches `release/<version>`.
- Base branch: `develop` (features/bugfixes are merged into `develop`; `release/*` is merged into `master` and `develop`). If the user names another base, use it.
- Commit message (verified in AdvancedReports, Sarp2, Rma, OneStepCheckout, ShippingTableRates):
  `https://ravedigital.teamwork.com/app/tasks/<ID> <Teamwork task title>`
  Optional markers: `[NOT FOR CHANGELOG]` for internal changes. Never suggest `[SKIP CI]` unless the user asks.
- MR (Bitbucket pull request) title: same as the commit message; merge commits look like `Merged in <branch> (pull request #N)`.
- One MR per module repository.

## Definition of done

- [ ] Gate A approval recorded
- [ ] All plan tasks implemented, reviewed, logged
- [ ] Blocking quality gates pass (or exceptions accepted by the user and listed)
- [ ] Regression/unit tests added for the change
- [ ] `docs/<Module>/` updated, `check-harness.sh` passes
- [ ] `status.md` final, ≤ 60 lines, consistent with the artifacts
- [ ] Gate B hand-over summary given to the user
