# SimpleLLMs - Simple LLM Suite
<img width="1078" height="793" alt="Screenshot 2026-01-11 at 12 11 19 pm" src="https://github.com/user-attachments/assets/47dce665-d866-4792-bd60-1b405d8e64e2" />

### The Complete Autonomous Engineering Ecosystem for Claude Code

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude-Code-purple)](https://claude.ai/claude-code)

**SimpleLLMs** is a suite of agentic behaviors designed to transform Claude Code from a chat interface into a production-grade autonomous engineering team.

Inspired by the [original R.A.L.P.H. pattern](https://github.com/snarktank/ralph), this suite introduces specialized logic loops for research, creative pivoting, system integration, security auditing, and massive-scale processing—each encoded with a specific **Model DNA** for maximum effectiveness.

---

## Agentic DNA & Model Genesis 🧬

While all SimpleLLMs are model-selectable, they are rooted in the "DNA" of their origin engines. This bimodal architecture ensures a perfectly balanced autonomous team.

### 🏛️ The Clinicals (Claude-Native)
*Precision, Reasoning, & User Experience*
- **L.I.S.A., B.A.R.T., M.A.R.G.E.**
- **Strengths**: Deep reasoning, nuanced refactoring, empathetic UI/UX, and complex decision-making.

### ⚡ The Industrials (Gemini-Native)
*Scale, Security, & Compliance*
- **H.O.M.E.R., H.O.U.N.D., M.A.G.G.I.E.**
- **Strengths**: Massive context windows (1.5M+ tokens), high-throughput parallel processing, adversarial security benchmarks, and low-latency compliance monitoring.

## The Cognitive Pipeline

Unlike standard "blind loops," SimpleLLMs agents are **grounded**.

1. **Grounded Synthesis**: Integrate with [NotebookLM MCP](https://github.com/PleasePrompto/notebooklm-mcp) to distill project documentation, PDFs, and whitepapers into a "Source of Truth."
2. **Specialized Execution**: Select the agent behavior that matches your current bottleneck (e.g., Use **L.I.S.A.** for research-heavy features or **B.A.R.T.** for creative debugging).

---

## 🍩 The Core Ecosystem (Simpsons Family)

These agents form the primary operational unit, leveraging specialized personas for specific development phases.

| Agent | DNA Engine | Role | Repository | Best For |
|-------|------------|------|------------|----------|
| **L.I.S.A.** | Claude | Research | [lisa-agent](https://github.com/midnightnow/lisa-agent) | Deep-diving into complex docs and NotebookLM insights |
| **B.A.R.T.** | Claude | Innovation | [bart-agent](https://github.com/midnightnow/bart-agent) | High-entropy creative pivots and breaking through blocks |
| **M.A.R.G.E.** | Claude | Integration | [marge-agent](https://github.com/midnightnow/marge-agent) | Large-scale refactoring and system orchestration |
| **H.O.M.E.R.** | Gemini | Scale | [homer-agent](https://github.com/midnightnow/homer-agent) | Brute-force parallel processing and massive context handling |
| **M.A.G.G.I.E.** | Gemini | Compliance | [maggie-agent](https://github.com/midnightnow/maggie-agent) | Human-in-the-loop oversight and SOP enforcement |

---

## 🛠️ Specialized Utility & Governance

Discreet, purpose-built tools for security, quality assurance, and persistent memory.

| Agent/Tool | DNA Engine | Role | Repository | Best For |
|------------|------------|------|------------|----------|
| **H.O.U.N.D.** | Gemini | Security | [hound-agent](https://github.com/midnightnow/hound-agent) | Adversarial testing and red-teaming exploits |
| **C.L.A.U.D.O.G.** | Claude | QA | [claudog](https://github.com/midnightnow/claudog) | Gamified bug hunting and rigorous web-layer testing |
| **R.A.L.P.H.** | Claude | Persistence | [ralph-agent](https://github.com/midnightnow/ralph-agent) | Relentless Automated Loop Processing Heuristic - "keep trying until it passes" |
| **Blackboard** | Shared | Governance | [simplellms-blackboard](https://github.com/midnightnow/simplellms-blackboard) | Registry of anti-patterns and cross-agent memory |
| **Wiki** | Shared | Context | [claude-code-wiki](https://github.com/midnightnow/claude-code-wiki) | Project indexing and high-level architectural memory |

---

## Quick Start

### 1. Install Individual Agents

```bash
# Clone and install any agent
git clone https://github.com/midnightnow/lisa-agent.git
cd lisa-agent && ./install.sh
```

### 2. Connect Your Knowledge Base

Follow the [NotebookLM MCP Setup Guide](https://github.com/PleasePrompto/notebooklm-mcp) to ground your agents in your documentation.

### 3. Run Your First Loop

```bash
# Research-first development
simplellms --lisa "Implement the new authentication service"

# Epic orchestrator (M.A.R.G.E.) — plan, dispatch in parallel worktrees, review, pivot
simplellms --marge plan "Build an auth-gated dashboard that lists and creates agents"
simplellms --marge execute --concurrency 3

# Creative-pivot one-shot (still works; also invoked internally by M.A.R.G.E. on stuck tickets)
simplellms --bart "Find a way around this dependency conflict"

# Batch processing
simplellms --homer "Refactor all components to TypeScript strict mode"

# Security audit
simplellms --hound "Scan this repo for vulnerabilities"

# Check compliance
simplellms --blackboard "Verify all agents are behaving"
```

---

## When to Use Each Agent

```
┌─────────────────────────────────────────────────────────────────┐
│                    SIMPLELLMS DECISION TREE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  "What's blocking you?"                                          │
│                                                                  │
│  ├── Need to understand before coding?                           │
│  │   └── L.I.S.A. → Research first, then implement              │
│  │                                                               │
│  ├── Stuck on the same error repeatedly?                         │
│  │   └── B.A.R.T. → Creative pivots and alternative paths       │
│  │                                                               │
│  ├── Multiple systems fighting each other?                       │
│  │   └── M.A.R.G.E. → Reconcile and guard execution             │
│  │                                                               │
│  ├── Need to process massive codebase fast?                      │
│  │   └── H.O.M.E.R. → Parallel batch operations                 │
│  │                                                               │
│  ├── Concerned about UI or UX regressions? (Claude-powered)         │
│  │   └── C.L.A.U.D.O.G. → Playwright-driven bug hunting         │
│  │                                                               │
│  ├── Worried about security or exploits? (Gemini-powered)        │
│  │   └── H.O.U.N.D. → Adversarial testing & exploits            │
│  │                                                               │
│  ├── Need compliance oversight or "SOP" enforcement?             │
│  │   └── M.A.G.G.I.E. → Human-in-the-loop & Safety Guardian      │
│  │                                                               │
│  ├── Lost in the codebase context?                               │
│  │   └── Wiki → Self-healing indexing & search                  │
│  │                                                               │
│  └── Simple task, just need persistence?                         │
│      └── R.A.L.P.H. → Loop until it works                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎼 M.A.R.G.E. Epic Orchestrator Mode

M.A.R.G.E.'s scope grows from "reconcile fighting systems" to **epic orchestrator** for the whole suite. She drives the other agents as pipeline stages and runs end-to-end without babysitting:

```
 epic → L.I.S.A.-plan → H.O.M.E.R.-dispatch (parallel worktrees)
        → M.A.G.G.I.E.-review → B.A.R.T.-pivot (if stuck) → repeat
```

Task-Master-compatible verbs:

```bash
simplellms --marge init                              # in any git repo
simplellms --marge plan "<epic>"                     # or: --marge parse ./EPIC.md
simplellms --marge list                              # ticket graph w/ status
simplellms --marge execute --concurrency 3           # the whole loop
simplellms --marge show T001                         # ticket details
simplellms --marge summary                           # progress dashboard
```

State lives in `.marge/` inside the **target** repo (plain JSON + markdown, git-friendly). Pluggable backends: `MARGE_AGENT=claude|gemini|amp|echo`. See [src/marge/README.md](src/marge/README.md) for the full pipeline, schema, and env vars; see [EPIC.md](EPIC.md) for the v0.2 roadmap expressed as a Marge spec sheet.

**Design note.** The classical Blackboard Pattern separates *shared state* (the board) from the *controller* that schedules knowledge sources. That mirror here is deliberate: `.marge/epic.json` is the board; M.A.R.G.E. is the controller; L.I.S.A. / H.O.M.E.R. / M.A.G.G.I.E. / B.A.R.T. are the knowledge sources. The existing SimpleLLMs Blackboard stays in its passive-governance role.

**B.A.R.T. stays B.A.R.T.** — the creative-pivot one-shot (`simplellms --bart "<task>"`) still works, and M.A.R.G.E. calls the same persona internally when a reviewer returns `needs_pivot`.

---

## Attribution & Lineage

SimpleLLMs implements and extends the autonomous loop pattern pioneered by:

- [Geoffrey Huntley's Ralph Concept](https://ghuntley.com/ralph/)
- [snarktank/ralph](https://github.com/snarktank/ralph) (Amp CLI implementation)
- [NotebookLM MCP](https://github.com/PleasePrompto/notebooklm-mcp) (Research grounding)

```
ghuntley.com/ralph (Concept)
        │
        ▼
snarktank/ralph (Amp CLI Implementation)
        │
        ▼
SimpleLLMs (Claude Code Extension)
    ├── R.A.L.P.H. ← Direct port and extension of Ralph pattern (fork of [snarktank/ralph](https://github.com/snarktank/ralph))
    ├── B.A.R.T.   ← + Creative pivot strategy
    ├── L.I.S.A.   ← + Research-first + NotebookLM
    ├── M.A.R.G.E. ← + Integration/cleanup focus
    ├── H.O.U.N.D. ← + Adversarial security testing (Gemini Engine)
    ├── C.L.A.U.D.O.G. ← + Playwright bug hunting (Claude Engine)
    ├── M.A.G.G.I.E. ← + Compliance & Safety Guardian (Gemini Engine)
    ├── Blackboard ← + Anti-pattern & Governance registry
    └── Wiki ← + Agentic project indexing & context engine
```

---

## License

MIT - Use freely. Build faster. Loop with purpose.

---

---

## Blackboard Governance

SimpleLLMs uses a federated Blackboard system to track and enforce agent behaviors. 

### Standard Anti-Pattern Template
Every violation recorded on the board follows this structure to ensure multi-agent compatibility:

```markdown
### I WILL NOT [CONCISE_SUMMARY]
- **Severity**: [Critical | High | Medium | Low]
- **Agent**: [Agent Name | Universal]
- **Context**: [Description of the failing scenario]
- **Root Cause**: [Why the agent took this path (e.g., hallucination, missing check)]
- **Corrected Behavior**: [What the agent MUST do instead]
- **Evidence**: [Link to failing log or code snippet]
```

---

*SimpleLLMs - Simple LLM Suite*
*Nine specialized agents, one powerful ecosystem.*
