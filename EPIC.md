# EPIC — SimpleLLMs M.A.R.G.E. v0.2

> Dogfood spec sheet. This is what M.A.R.G.E. would plan if you ran:
> `simplellms --marge parse ./EPIC.md` at the root of this repo.
> It is the remaining work after v0.1 landed in `src/marge/`.

## Title

Harden M.A.R.G.E. to v0.2 — observability, import/export, subtasks, OpenRouter backend.

## Why

v0.1 is a working epic orchestrator with plan → dispatch (parallel worktrees) → review → pivot, Task-Master-compatible verbs, and a pluggable agent backend (claude | gemini | amp | echo). What's missing for a genuinely "white glove" experience:

- No `marge expand` — you can't break a ticket into subtasks after planning.
- No round-trip with Task Master's `tasks.json`.
- No streaming / progress UI during long batches (only batch-end summaries).
- Agent backends are hard-coded to three CLIs; OpenRouter is the obvious fourth.
- No unit tests — the whole thing is shell, and bash-scripted logic rots fast.

## Tickets

### T001 — Add `marge expand <id>` to break a ticket into subtasks
- **details**: Given a ticket id, call the planner prompt in "subtask mode" (a new `prompts/expand.md`) with the ticket's `details` + `acceptance_criteria` as input. Write the returned subtask array back under `.tickets[] | select(.id==id).subtasks`. When dispatching, subtasks should be walked before their parent ticket is marked `done` — parent status becomes `done` only when every subtask is `done`.
- **acceptance_criteria**:
  - `prompts/expand.md` exists with the same output-contract discipline as `plan.md`
  - `marge expand T001` on a real ticket writes a non-empty `subtasks` array
  - `marge list` renders subtasks indented under their parent
  - `marge execute` walks subtasks before marking parent done
- **test_strategy**: echo-backend test: plan a 2-ticket epic, expand T001 into canned subtasks via a fixture, assert graph shape
- **priority**: high
- **dependencies**: []

### T002 — Task Master import/export
- **details**: Add `marge import <path/to/tasks.json>` and `marge export [path]`. Import translates Task Master's tasks.json (integer ids, `details`, `dependencies`, `status`, `subtasks`) into Marge's `epic.json` shape. Export does the inverse, mapping `needs_pivot`/`needs_human`/`failed` → Task Master's `pending` with a note in `details`.
- **acceptance_criteria**:
  - `marge import` on a valid Task Master file produces a `.marge/epic.json` that passes our JSON schema
  - `marge export` on a planned epic produces JSON that passes Task Master's own shape (int ids mapped from T001 → 1)
  - A round-trip (`import` → `export`) preserves titles, dependencies, statuses, and subtask structure
- **test_strategy**: fixture `tests/fixtures/taskmaster-sample.json`, assert round-trip idempotence
- **priority**: medium
- **dependencies**: []

### T003 — Streaming progress during `marge execute`
- **details**: Today, during a long batch, you see nothing until the batch ends. Add a simple line-oriented progress stream: `[T003] ↻ running... 00:42` that updates in place for each in-flight ticket. When a worker writes to `.marge/worktrees/<id>/.marge-progress`, surface the latest line in the dashboard. Claude Code's `--output-format stream-json` can emit tokens; wire that through `agent_run` when available.
- **acceptance_criteria**:
  - A new lib function `marge_progress.sh` renders a multi-line updating dashboard
  - With `MARGE_AGENT=echo` and a fixture that writes progress lines, the dashboard updates visibly
  - Dashboard is silent when `MARGE_COLOR=0` or stdout isn't a TTY (CI-friendly)
- **test_strategy**: manual smoke + echo-backend test with a sleep-and-write-progress fixture
- **priority**: medium
- **dependencies**: []

### T004 — OpenRouter agent backend
- **details**: Add `MARGE_AGENT=openrouter`. Implement in `lib/agent.sh` — `curl` against `https://openrouter.ai/api/v1/chat/completions` with `$OPENROUTER_API_KEY`, selectable model via `$MARGE_MODEL` (default: `anthropic/claude-sonnet-4-6`). This is the "can I run this without installing Claude Code" escape hatch.
- **acceptance_criteria**:
  - `MARGE_AGENT=openrouter MARGE_MODEL=anthropic/claude-sonnet-4-6 marge plan "trivial"` returns a valid `epic.json`
  - Missing `OPENROUTER_API_KEY` fails fast with a clear error (not a curl 401)
  - README lists the new backend with a one-line example
- **test_strategy**: manual test with a real key; a mock test intercepting `curl` and serving canned JSON
- **priority**: medium
- **dependencies**: []

### T005 — Minimal test harness (`tests/`)
- **details**: Add a `tests/run.sh` that sets `MARGE_AGENT=echo`, cds into a temporary git repo, runs the verb surface against fixtures, and asserts state. No external framework — just bash + jq. One test file per verb. CI-friendly.
- **acceptance_criteria**:
  - `tests/run.sh` exits 0 on a clean checkout
  - Covers: `init`, `plan` (with a fixture), `list`, `next`, `set-status`, `summary`
  - Uses temp dirs, cleans up on exit, does not touch the user's `~/` anywhere
- **test_strategy**: the test harness is itself the test strategy
- **priority**: high
- **dependencies**: []

### T006 — Blackboard anti-pattern integration
- **details**: On every `needs_pivot` and `needs_human` verdict, append a draft entry to `.marge/blackboard.md` using the SimpleLLMs Anti-Pattern Template from the root README. That draft can later be promoted by the user into the shared `simplellms-blackboard` registry.
- **acceptance_criteria**:
  - Every `needs_pivot` writes an entry with `Severity`, `Agent`, `Context`, `Root Cause` fields filled from the reviewer verdict
  - Template matches the block in the root README verbatim
  - File is append-only; re-running never duplicates
- **test_strategy**: echo-backend fixture that returns a canned `needs_pivot` verdict; assert `.marge/blackboard.md` contents
- **priority**: low
- **dependencies**: [T005]

### T007 — `marge doctor`
- **details**: A diagnostic verb that reports: installed CLIs (claude, gemini, jq, python3, git), versions, current `MARGE_*` env values, whether the cwd is a git repo, whether a `.marge/` exists and its summary. Zero-exit when healthy, nonzero otherwise.
- **acceptance_criteria**:
  - `marge doctor` prints a checklist with ✓ / ✗ for each dependency
  - Exit code is 0 on a healthy install, 1 otherwise
  - Output is parseable with `--format json`
- **test_strategy**: echo test, assert json output shape
- **priority**: low
- **dependencies**: []
