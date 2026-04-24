# M.A.R.G.E. — SimpleLLMs Epic Orchestrator

> *"Let me handle this, everyone."*

M.A.R.G.E. is the **epic-level orchestrator** for the SimpleLLMs suite. She takes a large, vague feature request ("build an agent-management dashboard with auth") and drives it end-to-end — delegating planning to L.I.S.A., parallel execution to H.O.M.E.R., review to M.A.G.G.I.E., and summoning B.A.R.T. when a ticket gets stuck.

```
 epic (markdown)
   │
   ▼
┌──────────────────────────────────────────────────────────┐
│  PLAN         L.I.S.A.-style decomposition               │
│               → .marge/epic.json (ticket graph)           │
├──────────────────────────────────────────────────────────┤
│  DISPATCH     Topological ready-set → N parallel git     │
│               worktrees, each with its own coding agent  │
├──────────────────────────────────────────────────────────┤
│  REVIEW       M.A.G.G.I.E.-style acceptance-criteria     │
│               verification of each diff                  │
├──────────────────────────────────────────────────────────┤
│  PIVOT        Stuck tickets get one creative retry       │
│               (B.A.R.T. creative-pivot persona)          │
└──────────────────────────────────────────────────────────┘
   │
   ▼
 needs_human? ─ yes → escalate
 needs_human? ─ no  → next batch
```

This is **not** a Ralph-style blind retry loop. Every batch is reviewed against spec-level acceptance criteria, and pivots are a bounded creative alternative, not infinite retries.

## Quick start

```bash
cd /path/to/your/project            # must be a git repo
~/simplellms/simplellms.sh --marge init
~/simplellms/simplellms.sh --marge plan "Build an auth-gated dashboard that lists agents and lets me create new ones"
~/simplellms/simplellms.sh --marge list
~/simplellms/simplellms.sh --marge execute --concurrency 3
```

For an existing spec sheet:

```bash
simplellms --marge parse ./EPIC.md
simplellms --marge execute
```

## Verbs (Task-Master compatible)

| Verb | Purpose |
|---|---|
| `init`                       | Create `.marge/` in the current git repo |
| `plan "<epic>"`              | Decompose a prompt into a ticket graph |
| `parse <file.md>`            | Same, from a file (EPIC.md / PRD.md / SPEC.md) |
| `list`                       | Render the ticket graph with status icons |
| `next`                       | Print the next ready ticket id (for scripting) |
| `show <id>`                  | Full JSON for one ticket |
| `set-status <id> <status>`   | Manually override a ticket status |
| `run <id>`                   | Execute one ticket (no review) |
| `review <id>`                | Re-review an already-executed ticket |
| `execute`                    | Full orchestrator loop (plan-if-needed → dispatch → review → pivot → repeat) |
| `summary`                    | One-line progress dashboard |
| `prune`                      | Remove all marge worktrees (destructive) |

## Env vars

| Var | Default | Meaning |
|---|---|---|
| `MARGE_AGENT`       | `claude`    | `claude` \| `gemini` \| `amp` \| `echo` (dry-run) |
| `MARGE_CONCURRENCY` | `1`         | Max parallel tickets per batch (uses `git worktree`) |
| `MARGE_MAX_PIVOTS`  | `1`         | How many pivots a single ticket gets before → `needs_human` |
| `MARGE_ROOT`        | `.marge`     | Name of the state dir inside the target repo |
| `MARGE_COLOR`       | `auto`      | `1` force colors, `0` disable |

## State layout

All state lives inside the **target repo**, not inside SimpleLLMs:

```
<your-repo>/.marge/
├── epic.md              # original user-supplied brief (verbatim)
├── epic.json            # authoritative ticket graph — validated against schema
├── tickets/
│   └── T001.md          # human-readable per-ticket spec + orchestrator notes
├── batches/
│   └── batch-001.json   # each dispatch round + status snapshot
├── worktrees/
│   └── T001/            # git worktree on branch marge/<slug>/T001
├── log.md               # append-only orchestrator log
└── .base-ref            # HEAD when `marge init` ran (diff baseline)
```

Everything is plain text / JSON / markdown — diffable, greppable, and safe to commit (or add to `.gitignore`, your call).

## Ticket schema

See `schemas/epic.schema.json`. The shape is deliberately compatible with [Task Master](https://github.com/eyaltoledano/claude-task-master) so you can hand-author a `tasks.json` elsewhere and import it.

Key fields per ticket:

```json
{
  "id": "T001",
  "title": "Create auth middleware",
  "description": "Express middleware that validates JWT on protected routes",
  "details": "<full markdown spec>",
  "acceptance_criteria": [
    "File src/middleware/auth.ts exists",
    "Exports default function `requireAuth(req, res, next)`",
    "Returns 401 when Authorization header missing",
    "npm test -- auth passes"
  ],
  "test_strategy": "run `npm test -- auth` in the worktree",
  "priority": "high",
  "dependencies": ["T000"],
  "status": "pending"
}
```

## How it differs from Task Master

- **Task Master** is a brilliant task manager with dependency-aware `next` and `expand` — but it's a planning surface, not an executor. M.A.R.G.E. uses its schema and verbs, then **actually runs the tickets** in parallel worktrees and reviews them against spec-level acceptance criteria.
- **Local-first.** State lives in your own repo, as plain JSON + markdown. Your agent budget is your own; nothing calls home.

## Pipeline internals

- **Plan**: `prompts/plan.md` is handed to the selected agent with the epic text. The agent returns JSON matching `schemas/epic.schema.json`. `agent_run_json` is lenient — it strips ` ```json ` fences and extracts the first balanced object.
- **Dispatch**: `graph_ready_tickets` returns ids whose `dependencies` are all `done`. We take up to `$MARGE_CONCURRENCY` and fan out. Each ticket gets its own `git worktree` rooted at `.base-ref` on branch `marge/<slug>/<id>`.
- **Review**: the reviewer sees the full diff plus the ticket's acceptance criteria, and must return `{outcome, reason, criteria_results[]}`. A false `done` is the main failure mode — the prompt is tuned to be strict.
- **Pivot**: on `needs_pivot`, the worktree is reset to `.base-ref`, pivots counter increments, and the pivot prompt is given the reviewer's `pivot_hint`. Capped at `$MARGE_MAX_PIVOTS` per ticket.

## Safety

- M.A.R.G.E. **never** auto-commits and **never** auto-merges. Completed tickets leave their branch dirty on `marge/<slug>/<id>`; you inspect and merge.
- `marge prune` is destructive — it removes worktrees but leaves branches.
- The `echo` agent is safe for CI / tests — it produces a canned response without calling any LLM.

## Tests

```bash
bash tests/run.sh
```

21 tests covering the full verb surface (help, init, plan/parse, list, show, summary, next/set-status dependency logic, routing, schema validity, syntax). Runs with `MARGE_AGENT=echo` and fixtures under `tests/fixtures/` — no LLM calls, no external deps beyond what M.A.R.G.E. already needs (bash, git, jq, python3).

## Dogfooding

See `../../EPIC.md` at the repo root for the v0.2 roadmap expressed as a Marge spec sheet — the intent is that the next real `--marge execute` run will finish building Marge herself.
