#!/bin/bash
# SimpleLLMs Suite Orchestrator - v1.0.0
# The entry point for the complete agentic engineering team

set -e

# Resolve $0 through any symlinks so `--marge` finds src/marge/marge.sh
# whether we're invoked directly, via ~/.local/bin/simplellms, or via any
# other symlink chain. Portable across bash 3 (macOS) and bash 4+ (Linux).
_src="$0"
while [[ -L "$_src" ]]; do
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    [[ "$_src" != /* ]] && _src="$_dir/$_src"
done
SIMPLELLMS_ROOT="$(cd -P "$(dirname "$_src")" && pwd)"
unset _src _dir

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
    echo -e "${CYAN}SimpleLLMs - Simple LLM Suite Orchestrator${NC}"
    echo ""
    echo "Usage:"
    echo -e "${YELLOW}--- The Clinicals (Claude-Native) ---${NC}"
    echo "  simplellms --lisa \"Task\"        Run research-first research (L.I.S.A.)"
    echo "  simplellms --bart \"Task\"        Run creative innovation (B.A.R.T.)"
    echo "  simplellms --marge \"Task\"       Run system integration (M.A.R.G.E.)"
    echo "  simplellms --claudog \"Task\"     Run web QA hunting (C.L.A.U.D.O.G.)"
    echo ""
    echo -e "${YELLOW}--- The Industrials (Gemini-Native) ---${NC}"
    echo "  simplellms --homer \"Task\"       Run massive-scale processing (H.O.M.E.R.)"
    echo "  simplellms --hound \"Task\"       Run adversarial security audit (H.O.U.N.D.)"
    echo "  simplellms --maggie \"Task\"      Run compliance & safety scan (M.A.G.G.I.E.)"
    echo ""
    echo -e "${YELLOW}--- Shared Services ---${NC}"
    echo "  simplellms --blackboard \"Task\"  Check governance and anti-petterns"
    echo "  simplellms --wiki \"Task\"        Query the project knowledge base"
    echo "  simplellms --ralph \"Task\"       Run persistent loops (R.A.L.P.H.)"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help"
    echo "  --version                   Show version info"
    echo "  --install                   Install all agents in the suite"
    echo ""
}

case "${1:-}" in
    --lisa)
        shift
        claude --profile lisa "$@"
        ;;
    --marge)
        shift
        # M.A.R.G.E. — Epic orchestrator. Plans an epic into tickets,
        # dispatches them in parallel worktrees (H.O.M.E.R. DNA), reviews
        # via M.A.G.G.I.E., and summons B.A.R.T. on stuck tickets.
        # Task-Master-compatible verbs.
        MARGE_SCRIPT="$SIMPLELLMS_ROOT/src/marge/marge.sh"
        if [[ ! -x "$MARGE_SCRIPT" ]]; then
            echo -e "${RED}marge orchestrator not found at $MARGE_SCRIPT${NC}" >&2
            exit 1
        fi
        case "${1:-}" in
            init|plan|parse|list|ls|next|show|set-status|run|review|execute|go|summary|prune|help|-h|--help|"")
                exec "$MARGE_SCRIPT" "$@"
                ;;
            *)
                # Bare string after --marge → treat as an epic to plan
                exec "$MARGE_SCRIPT" plan "$*"
                ;;
        esac
        ;;
    --bart)
        shift
        # B.A.R.T. — Creative-pivot one-shot (the legacy behavior).
        # For the epic orchestrator, use --marge instead. M.A.R.G.E. itself
        # calls this same persona internally when a reviewer flags needs_pivot.
        claude --profile bart "$@"
        ;;
    --claudog)
        shift
        # Claudog is the Claude-powered web hunter
        echo -e "${CYAN}C.L.A.U.D.O.G. Web QA Hunter Activated...${NC}"
        # Trigger claudog if in path, otherwise use npx
        if command -v claudog &> /dev/null; then
            claudog hunt "$@"
        else
            npx claudog hunt "$@"
        fi
        ;;
    --homer)
        shift
        claude --homer "$@"
        ;;
    --hound)
        shift
        # Check if hound is in path, otherwise use local
        if command -v hound &> /dev/null; then
            hound scan "$@"
        else
            echo -e "${YELLOW}H.O.U.N.D. not found in PATH. Running via Node...${NC}"
            node "$(dirname "$0")/../hound-agent/dist/cli.js" scan "$@"
        fi
        ;;
    --maggie)
        shift
        # Maggie is a compliance guardian, checking against SOPs and safety rules
        echo -e "${CYAN}M.A.G.G.I.E. Compliance Guardian Activated...${NC}"
        claude --profile maggie "$@"
        ;;
    --blackboard)
        shift
        if command -v blackboard &> /dev/null; then
            blackboard "$@"
        else
            "$(dirname "$0")/../simplellms-blackboard/blackboard-cli.sh" "$@"
        fi
        ;;
    --wiki)
        shift
        claude --profile wiki "$@"
        ;;
    --ralph)
        shift
        if command -v ralph &> /dev/null; then
            ralph "$@"
        else
            "$(dirname "$0")/../ralph-agent/ralph" "$@"
        fi
        ;;
    --install)
        echo -e "${CYAN}Installing SimpleLLMs Suite...${NC}"
        # Trigger individual installers
        for agent in lisa-agent bart-agent homer-agent marge-agent simplellms-blackboard hound-agent ralph-agent; do
            echo -e "Installing ${GREEN}$agent${NC}..."
            if [ -f "$(dirname "$0")/../$agent/install.sh" ]; then
                bash "$(dirname "$0")/../$agent/install.sh"
            fi
        done
        ;;
    -h|--help|help)
        show_help
        ;;
    --version)
        echo "SimpleLLMs Orchestrator v1.0.0"
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            echo -e "${RED}Unknown flag: $1${NC}"
            show_help
            exit 1
        else
            show_help
        fi
        ;;
esac
