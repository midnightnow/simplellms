#!/bin/bash
# SimpleLLMs Suite Installer
# "The first step to an autonomous engineering firm."

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/local/bin"
ORCHESTRATOR="simplellms.sh"
ALIAS_NAME="simplellms"

echo "🎯 Installing SimpleLLMs Autonomous Engineering Suite..."
echo ""

# Make orchestrator executable
chmod +x "$SCRIPT_DIR/$ORCHESTRATOR"

# Create symlink in /usr/local/bin if possible
if [ -d "$BIN_DIR" ] && [ -w "$BIN_DIR" ]; then
    echo "🔗 Creating symlink in $BIN_DIR..."
    ln -sf "$SCRIPT_DIR/$ORCHESTRATOR" "$BIN_DIR/$ALIAS_NAME"
    echo "✅ Symlink created: $BIN_DIR/$ALIAS_NAME"
else
    echo "⚠️  Could not write to $BIN_DIR. Creating local symlink..."
    ln -sf "$SCRIPT_DIR/$ORCHESTRATOR" "$SCRIPT_DIR/$ALIAS_NAME"
    echo "✅ Local symlink created: ./$ALIAS_NAME"
    echo "👉 Add this to your PATH: export PATH=\$PATH:$SCRIPT_DIR"
fi

# Initialize individual agents (optional / detection)
echo ""
echo "🔍 Detecting existing agents in suite..."
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

for agent in lisa-agent bart-agent homer-agent marge-agent simplellms-blackboard hound-agent maggie-agent claudog; do
    if [ -d "$PARENT_DIR/$agent" ]; then
        echo "✅ Detected $agent"
        if [ -f "$PARENT_DIR/$agent/install.sh" ]; then
            echo "  🚀 Running $agent installer..."
            bash "$PARENT_DIR/$agent/install.sh"
        fi
    else
        echo "⏳ $agent not found. (Install via 'git clone https://github.com/midnightnow/$agent.git')"
    fi
done

echo ""
echo "✅ SimpleLLMs installation complete!"
echo ""
echo "🚀 Usage:"
echo "   simplellms --help"
echo "   simplellms --lisa \"Research this codebase\""
echo "   simplellms --hound \"Run security audit\""
echo ""
echo "Stop micromanaging. Let the family handle it."
