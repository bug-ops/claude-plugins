# Task Loop

The `task-loop` chain implements an approved `tasks.md` one task per fresh developer session, one commit per task. Input: `{spec}`, a committed `specs/{slug}/` package whose `tasks.md` follows the sdd skill's task format. Spawn template, outcomes, naming, and shutdown follow the `team-lead` protocol; Steps 8, 8.5, 9, and 10 of the SKILL apply unchanged.

**Code ownership line**: `only developer-t{NNN} edits source, one task at a time; tester edits only the acceptance test files it lists; sdd-orchestrator edits only the spec package. Only team-lead commits.`

## progress.json

`{spec root}/progress.json`, written only by the lead:

```json
{"spec": "specs/{slug}", "tasks": [{"id": "T001", "status": "pending", "commit": null}]}
```

`status` is one of `pending`, `in_progress`, `done`, `blocked`. The lead changes only `status` and `commit` (the task's commit sha); ids and order come from `tasks.md` in dependency order and never change.

## Start

1. Read `tasks.md`; create `progress.json` when absent. The spec must have no `[NEEDS CLARIFICATION]` markers, otherwise stop and ask the user.
2. Ask the user (`AskUserQuestion`) for the validation group size: `3 tasks (Recommended)`, `1 task`, `all tasks`.
3. Resume: read `progress.json` and `git log --oneline`. A `done` task must have its sha in the log. An `in_progress` task whose commit is in the log becomes `done`; one without a commit goes to the user: discard its working-tree changes and redo it, or stop. A `blocked` task goes to the user before anything else runs.

## Iteration (per task, in order, skipping `done`)

1. Smoke test: the lead runs the profile's test command on the working tree. A red baseline stops the loop and goes to the user.
2. Set the task `in_progress`.
3. Spawn `tester-t{NNN}` in tests-first mode (Step 4.6) for this task's acceptance criteria. Add the listed test files to `.local/protected-tests`; they are not committed separately.
4. Spawn a fresh `developer-t{NNN}` with the task text, `{spec}`, the protected tests, and the previous tasks' handoff frontmatter only. A `blocked` handoff sets the task `blocked`, stops the loop, and goes to the user.
5. The lead re-runs the task's acceptance tests and the profile's full check suite. A failure goes back to the same developer, at most 3 rounds; then the task is `blocked`.
6. The lead commits the task as `T{NNN}: {title}`, sets `done` with the sha, removes the task's lines from `.local/protected-tests`, and shuts down both task agents.

## Validation (after each group)

Spawn `tester` (validate-tests), `impl-critic` (mandatory, with the Scope gate), `perf`, `security`, and `reviewer` on the group's diff, as in new-feature. Fixes run through Step 8 and land as an extra commit per fix round, not as an amended task commit.

## End

After the last group: Step 8.5 (spec sync), then Step 9 once: the full check suite on the final diff, one push, one PR with the per-task commits.
