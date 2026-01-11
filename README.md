# SimpleLLMs - Simple LLM Suite

### Five Specialized Autonomous Agents for Claude Code

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude-Code-purple)](https://claude.ai/claude-code)

**SimpleLLMs** is a suite of agentic behaviors designed to transform Claude Code from a chat interface into a production-grade autonomous engineering team.

Inspired by the [original R.A.L.P.H. pattern](https://github.com/snarktank/ralph), this suite introduces specialized logic loops for research, creative pivoting, system integration, and massive-scale processing.

---

## The Cognitive Pipeline

Unlike standard "blind loops," SimpleLLMs agents are **grounded**.

1. **Grounded Synthesis**: Integrate with [NotebookLM MCP](https://github.com/PleasePrompto/notebooklm-mcp) to distill project documentation, PDFs, and whitepapers into a "Source of Truth."
2. **Specialized Execution**: Select the agent behavior that matches your current bottleneck (e.g., Use **L.I.S.A.** for research-heavy features or **B.A.R.T.** for creative debugging).

---

## Meet the Family

| Agent | Acronym | Role | Best For |
|-------|---------|------|----------|
| **L.I.S.A.** | **L**ookup, **I**nvestigate, **S**ynthesize, **A**ct | Research | Grounding code in docs via NotebookLM |
| **B.A.R.T.** | **B**ranch **A**lternative **R**etry **T**rees | Innovation | Breaking through blocks with creative pivots |
| **M.A.R.G.E.** | **M**aintain **A**dapters, **R**econcile, **G**uard **E**xecution | Integration | Merging complex systems and safety checks |
| **H.O.M.E.R.** | **H**arness **O**mni-Mode **E**xecution **R**esources | Scale | Batch processing and massive codebase refactors |
| **R.A.L.P.H.** | **R**etry **A**nd **L**oop **P**ersistently until **H**appy | Persistence | Standard "keep trying until it passes" loops |

<img width="1184" height="864" alt="image" src="https://github.com/user-attachments/assets/3f59bbee-1d61-4510-a436-45f814b29f12" />

---

## Repositories

| Agent | Repository | Description |
|-------|------------|-------------|
| **L.I.S.A.** | [lisa-agent](https://github.com/midnightnow/lisa-agent) | Research-first development engine |
| **B.A.R.T.** | [bart-agent](https://github.com/midnightnow/bart-agent) | Creative pivot and branching logic |
| **M.A.R.G.E.** | [marge-agent](https://github.com/midnightnow/marge-agent) | Safety guardian and system reconciler |
| **H.O.M.E.R.** | [homer-agent](https://github.com/midnightnow/homer-agent) | High-throughput parallel processing |
| **R.A.L.P.H.** | [snarktank/ralph](https://github.com/snarktank/ralph) | The original autonomous loop (upstream) |

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

# Creative problem solving
simplellms --bart "Find a way around this dependency conflict"

# System integration
simplellms --marge "Reconcile these three microservices"

# Batch processing
simplellms --homer "Refactor all components to TypeScript strict mode"
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
│  └── Simple task, just need persistence?                         │
│      └── R.A.L.P.H. → Loop until it works                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

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
    ├── R.A.L.P.H. ← Direct port of Ralph pattern
    ├── B.A.R.T.   ← + Creative pivot strategy
    ├── L.I.S.A.   ← + Research-first + NotebookLM
    ├── M.A.R.G.E. ← + Integration/cleanup focus
    └── H.O.M.E.R. ← + Parallel batch processing
```

---

## License

MIT - Use freely. Build faster. Loop with purpose.

---

*SimpleLLMs - Simple LLM Suite*
*Five agents, one powerful workflow.*
