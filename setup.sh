#!/usr/bin/env bash
# One-command fresh Mac setup. Public entry point; contains no secrets.
#   curl -fsSL <url-of-this-file> | bash
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-euwars/dotfiles}"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

say "Installing Claude Code"
export PATH="$HOME/.local/bin:$PATH"
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash

say "Installing Cua Driver (lets Claude see and control the screen)"
command -v cua-driver >/dev/null ||
  /bin/bash -c "$(curl -fsSL https://cua.ai/driver/install.sh)" -- --no-modify-path
claude mcp get cua-driver >/dev/null 2>&1 ||
  claude mcp add --scope user --transport stdio cua-driver -- "$HOME/.local/bin/cua-driver" mcp

say "Screen control permissions"
echo "Click Allow on each macOS prompt for CuaDriver."
until "$HOME/.local/bin/cua-driver" permissions grant </dev/tty; do
  read -rp "Permissions not granted yet. Press Enter to try again... " </dev/tty
done

# Start Claude in a fresh Terminal window so it picks up the new PATH and MCP server.
KICKOFF="Set up this Mac hands-off. Use the cua-driver tools for anything with a GUI. \
Download GitHub Desktop from https://central.github.com/deployments/desktop/desktop/latest/darwin-arm64, \
unzip it into /Applications, open it and sign me in (ask me when GitHub needs 2FA), \
then clone $GITHUB_REPO to ~/gits/dotfiles. Then follow ~/gits/dotfiles/SETUP.md end to end."
LAUNCH="$HOME/.claude-setup-launch.command"
cat > "$LAUNCH" <<EOF
#!/bin/zsh
rm -f "$LAUNCH"
export PATH="\$HOME/.local/bin:\$PATH"
claude "$KICKOFF"
EOF
chmod +x "$LAUNCH"

say "Restarting Terminal and handing over to Claude"
nohup sh -c "sleep 2; open -a Terminal '$LAUNCH'" >/dev/null 2>&1 &
osascript -e 'tell application "Terminal" to quit' >/dev/null 2>&1 || true
