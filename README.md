# SimpleLLMs - Simple LLM Suite

> **Five Specialized Agents for Autonomous Development**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude-Code-purple)](https://claude.ai/claude-code)

SimpleLLMs implements the autonomous loop pattern for Claude Code, extending the R.A.L.P.H. methodology with five specialized agent behaviors.

---

## Attribution

Inspired by [snarktank/ralph](https://github.com/snarktank/ralph) ([ghuntley.com/ralph](https://ghuntley.com/ralph))

Integrates with [NotebookLM MCP](https://github.com/PleasePrompto/notebooklm-mcp)

---

## The Agents

| Agent | Acronym | Philosophy | Best For |
|-------|---------|------------|----------|
| [**R.A.L.P.H.**](https://github.com/midnightnow/ralph-plugin) | Retry And Loop Persistently until Happy | Blind persistence | Simple retry loops |
| [**B.A.R.T.**](https://github.com/midnightnow/bart-plugin) | Branch Alternative Retry Trees | Creative chaos | Breaking through blocks |
| [**L.I.S.A.**](https://github.com/midnightnow/lisa-plugin) | Lookup, Investigate, Synthesize, Act | Research + quality | Production code |
| [**M.A.R.G.E.**](https://github.com/midnightnow/marge-plugin) | Maintain Adapters, Reconcile, Guard Execution | Organize chaos | Integration & cleanup |
| [**H.O.M.E.R.**](https://github.com/midnightnow/homer-plugin) | Harness Omni-Mode Execution Resources | Parallel volume | Speed & throughput |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SIMPLLMS ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐        │
│  │   Claude    │────▶│  SimpleLLMs   │────▶│    Code     │        │
│  │    Code     │     │   Agents    │     │   Output    │        │
│  └─────────────┘     └──────┬──────┘     └─────────────┘        │
│                             │                                    │
│                             ▼                                    │
│                    ┌─────────────────┐                          │
│                    │  NotebookLM MCP │                          │
│                    │  (Research Layer)│                          │
│                    └─────────────────┘                          │
│                             │                                    │
│                             ▼                                    │
│                    ┌─────────────────┐                          │
│                    │ Your Documents  │                          │
│                    │ (Zero Hallucination)                       │
│                    └─────────────────┘                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Install

```bash
# Install all agents
curl -fsSL https://raw.githubusercontent.com/midnightnow/ralph-family-plugins/main/install.sh | bash

# Or install individually
git clone https://github.com/midnightnow/ralph-plugin.git && cd ralph-plugin && ./install.sh
git clone https://github.com/midnightnow/bart-plugin.git && cd bart-plugin && ./install.sh
git clone https://github.com/midnightnow/lisa-plugin.git && cd lisa-plugin && ./install.sh
git clone https://github.com/midnightnow/marge-plugin.git && cd marge-plugin && ./install.sh
git clone https://github.com/midnightnow/homer-plugin.git && cd homer-plugin && ./install.sh
```

---

## NotebookLM Integration

SimpleLLMs leverages [NotebookLM MCP](https://github.com/PleasePrompto/notebooklm-mcp) for grounded research:

```bash
# Install NotebookLM MCP
claude mcp add notebooklm npx notebooklm-mcp@latest

# L.I.S.A. automatically queries your documentation
simplellms --lisa "Implement the authentication system"
```

| Agent | NotebookLM Usage |
|-------|------------------|
| **R.A.L.P.H.** | None (blind persistence) |
| **B.A.R.T.** | Optional (creative research) |
| **L.I.S.A.** | **Primary** (research-first) |
| **M.A.R.G.E.** | Optional (integration docs) |
| **H.O.M.E.R.** | Batch queries |

---

## Usage

### The Orchestrator

```bash
# Let the orchestrator decide
simplellms "Fix the failing tests"           # → R.A.L.P.H.
simplellms "I'm stuck, nothing works"        # → B.A.R.T.
simplellms "Build a new feature properly"   # → L.I.S.A.
simplellms "Make these systems work together" # → M.A.R.G.E.
simplellms "Process entire codebase fast"   # → H.O.M.E.R.

# Or specify directly
simplellms --ralph "Retry until tests pass"
simplellms --bart "Find a creative solution"
simplellms --lisa "Research and implement properly"
simplellms --marge "Clean up this mess"
simplellms --homer "Batch process everything"
```

### Sequential Workflow

For complex projects, use agents in sequence:

```bash
simplellms --ralph "Get the basic feature working"
simplellms --bart "We're stuck on the edge case"
simplellms --lisa "Add tests and documentation"
simplellms --marge "Integrate with existing systems"
simplellms --homer "Apply pattern across all modules"
```

---

## Configuration

Global config at `~/.simplellmsrc`:

```json
{
  "default_agent": "lisa",
  "orchestrator_enabled": true,
  "notebooklm_integration": true,
  "max_iterations": {
    "ralph": 30,
    "bart": 20,
    "lisa": 15,
    "marge": 30,
    "homer": 50
  }
}
```

---

## Agent Comparison

| Feature | R.A.L.P.H. | B.A.R.T. | L.I.S.A. | M.A.R.G.E. | H.O.M.E.R. |
|---------|------------|----------|----------|------------|------------|
| Persistence | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Creativity | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐ |
| Quality | ⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| Speed | ⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐ | ⭐⭐⭐ |
| Integration | ⭐ | ⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| Parallelism | ⭐ | ⭐ | ⭐ | ⭐ | ⭐⭐⭐ |

---

## Lineage

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

## Contributing

Each agent has its own repository. PRs welcome!

- [ralph-plugin](https://github.com/midnightnow/ralph-plugin)
- [bart-plugin](https://github.com/midnightnow/bart-plugin)
- [lisa-plugin](https://github.com/midnightnow/lisa-plugin)
- [marge-plugin](https://github.com/midnightnow/marge-plugin)
- [homer-plugin](https://github.com/midnightnow/homer-plugin)

---

## License

MIT - Use freely.

---

*SimpleLLMs - Simple LLM Suite*
*Five agents, one powerful workflow.*
*Grounded by NotebookLM. Inspired by R.A.L.P.H.*
