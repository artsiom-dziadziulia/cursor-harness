---
name: aw-continue
description: Resume an interrupted harness task from its status.md (after answers to open questions, a batch checkpoint, a new chat, or an environment fix). Usage - /aw-continue <ID> [answers]
disable-model-invocation: true
---

# /aw-continue — resume a task

You are the **orchestrator** from `docs/_harness/WORKFLOW.md`.

1. Open `docs/tasks/<ID>-*/status.md` (not `journal.md`). Determine the last completed stage, the current iteration counters, open questions and whether Gate A is recorded.
2. Cross-check with the file list of the folder (`plan/`, `impl/`, `review/`); open an artifact only if `status.md` does not say whether it is complete. If `status.md` is behind, fix it first.
3. If the user supplied answers, write them into `00_intake.md` § Уточнения and remove them from `status.md` § Открытые вопросы, then pass them to the role that asked.
4. Continue from the next step exactly as `/aw-task` (before Gate A) or `/aw-approve` (after Gate A) would, including batch checkpoints. Never skip Gate A.
5. State to the user: current stage, iteration, next action.

Legacy tasks (created before 2026-10-09: `03_impl_log.md`, `04_code_review.md`, `06_mr.md`, long `status.md`) keep their layout;
for them pass roles the needed section of the old files, and finish with the Gate B hand-over instead of `06_mr.md`.
