#!/usr/bin/env bash
# One-command fresh Mac setup. Public entry point; contains no secrets.
#   curl -fsSL https://raw.githubusercontent.com/euwars/mac-setup/main/setup.sh | bash
#
# Part 1 (about 5 minutes, needs you): password, sign-ins, permissions.
# Part 2 (walk away): Claude installs and configures everything, then leaves
# "Mac Setup Report" on the Desktop.
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-euwars/dotfiles}"
DIR="$HOME/gits/dotfiles"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ask() { read -rp "$* " </dev/tty; }

say "Part 1 of 2: about 5 minutes of your input. After that, walk away."

# 1. Mac password, once. Claude uses it for admin dialogs; both the sudo rule
#    and the Keychain copy are removed when setup finishes.
say "Your Mac password"
read -rsp "Password: " PW </dev/tty; echo
echo "$PW" | sudo -S -p '' -v
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-mac-setup >/dev/null
sudo chmod 440 /etc/sudoers.d/zz-mac-setup
security add-generic-password -U -s mac-setup -a "$(whoami)" -w "$PW"
unset PW

# 2. Homebrew + GitHub CLI, then clone the private dotfiles repo
say "Installing Homebrew (takes a few minutes)"
[ -x /opt/homebrew/bin/brew ] ||
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install gh >/dev/null

say "Sign in to Google and GitHub in Safari (approve any 2FA)"
open -a Safari "https://accounts.google.com/"
open -a Safari "https://github.com/login"
ask "Press Enter once both show you signed in..."

say "Connect GitHub (code is copied; paste it on the page and click Continue)"
gh auth status >/dev/null 2>&1 ||
  gh auth login --hostname github.com --git-protocol https --web --clipboard </dev/tty
gh auth setup-git
[ -f "$DIR/Brewfile" ] || gh repo clone "$GITHUB_REPO" "$DIR"

# 3. Claude Code
say "Installing Claude Code (sign in when the browser opens)"
export PATH="$HOME/.local/bin:$PATH"
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
claude auth status 2>/dev/null | grep -q '"loggedIn": true' || claude auth login </dev/tty
mkdir -p "$HOME/.claude"
[ -f "$HOME/.claude/settings.json" ] || echo '{}' > "$HOME/.claude/settings.json"
/usr/bin/python3 - "$HOME/.claude/settings.json" <<'EOF' 2>/dev/null ||
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["skipDangerousModePermissionPrompt"] = True
json.dump(s, open(p, "w"), indent=2)
EOF
  echo '{"skipDangerousModePermissionPrompt": true}' > "$HOME/.claude/settings.json"

# 4. Cua Driver: lets Claude see and control the screen
say "Installing Cua Driver (click Allow on each prompt)"
command -v cua-driver >/dev/null ||
  /bin/bash -c "$(curl -fsSL https://cua.ai/driver/install.sh)" -- --no-modify-path
claude mcp get cua-driver >/dev/null 2>&1 ||
  claude mcp add --scope user --transport stdio cua-driver -- "$HOME/.local/bin/cua-driver" mcp
until "$HOME/.local/bin/cua-driver" permissions grant </dev/tty; do
  ask "Not granted yet. Press Enter to try again..."
done

# 5. Terminal permissions (needed before Terminal restarts)
say "Turn on Terminal in App Management, then in Full Disk Access"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles"
ask "Press Enter when App Management is on..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
ask "Press Enter when Full Disk Access is on..."

say "Part 2 of 2: Claude takes over. You can walk away now."
KICKOFF="Set up this Mac by following ~/gits/dotfiles/SETUP.md end to end, fully unattended."
LAUNCH="$HOME/.mac-setup-launch.command"
cat > "$LAUNCH" <<EOF
#!/bin/zsh
rm -f "$LAUNCH"
export PATH="\$HOME/.local/bin:/opt/homebrew/bin:\$PATH"
cd "$DIR"
caffeinate -dimsu claude --dangerously-skip-permissions "$KICKOFF"
EOF
chmod +x "$LAUNCH"

# Restart Terminal so its new permissions apply, then hand over to Claude.
nohup sh -c "sleep 2; open -a Terminal '$LAUNCH'" >/dev/null 2>&1 &
osascript -e 'tell application "Terminal" to quit' >/dev/null 2>&1 || true
