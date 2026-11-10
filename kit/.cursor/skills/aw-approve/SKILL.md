---
name: aw-approve
description: Record the user's approval of a task plan (Gate A) and run implementation, code review, verification and docs update up to the Gate B hand-over. Usage - /aw-approve <ID> [comments]
disable-model-invocation: true
---

# /aw-approve — Gate A passed, implement to hand-over

You are the **orchestrator** from `docs/_harness/WORKFLOW.md`. Read it (the root `AGENTS.md` is already in context).

## Steps
1. Find `docs/tasks/<ID>-*/`. If the user added comments that change the plan, do not implement: send them to `aw-planner` as rework, re-review, and return to Gate A.
2. Record Gate A in `status.md`: date/time and the user's exact words; set `02_plan.md` status to "ОДОБРЕН ПОЛЬЗОВАТЕЛЕМ <date>".
3. **S3 Baseline** — `aw-qa` (baseline mode) for every touched module. If the stack is down, ask the user to start it at http://127.0.0.1/stack/17 and stop.
4. **Implementation units in plan order.** A unit is one plan task, or up to 3 consecutive `size: S` tasks of one module.
   - **S4** `aw-developer` (pass: `plan/task-NN.md`, `02_plan.md` § Решение) → **S5** `aw-code-reviewer` (pass: `plan/task-NN.md`, `impl/task-NN.md`).
     If CHANGES_REQUESTED: one fix round by `aw-developer`, then a targeted second review. Critical remarks after that ⇒ stop and ask the user.
   - Items the reviewer returns "for later tasks" ⇒ write them into the target `plan/task-NN.md` § Перенесено из ревью.
   - If the developer reports "Plan amendment needed" ⇒ write the amendment in `02_plan.md`, stop, ask the user to approve it.
   - Update the task row in `status.md` and one line in `journal.md` after each unit.
   - **Batch checkpoint:** if the plan has more than 6 units, stop after every 5 units: tell the user the progress in ≤ 3 lines
     and ask to continue in a new chat with `/aw-continue <ID>`.
5. **S6 Final** — `aw-qa` (final mode). New blocking failures ⇒ back to `aw-developer` (max 2 attempts), then escalate.
6. **S7** — `aw-doc-keeper`.
7. Check `status.md` against the artifacts (definition of done in WORKFLOW.md).
8. **Gate B — stop.** Do the hand-over check from WORKFLOW.md § "Gate B hand-over" and tell the user in Russian:
   what was done, per repository the changed files count and **files that must not be committed** (not in the plan / staged before the task),
   suggested branch and commit message, deploy notes, gate results, pre-existing issues, docs updated.
   The user runs all git commands and opens the MR.

Never use git write commands. Never trigger CI. Never mirror-sync or touch the DB destructively without consent.
