#!/bin/bash
set -eo pipefail

# macOS only
[[ "$(uname)" == "Darwin" ]] || { echo "This script requires macOS."; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

STEP=0
step() { STEP=$((STEP+1)); echo "[$STEP] $1"; }

echo "=== macOS Development Environment Setup ==="
echo ""

# Network check
if ! curl -fsS --connect-timeout 5 https://github.com -o /dev/null 2>/dev/null; then
  echo "Error: No network connection. Please connect to the internet and try again."
  exit 1
fi

# ── 1. Homebrew ──
if ! command -v brew &>/dev/null; then
  step "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  step "Homebrew already installed, updating..."
  brew update || echo "Warning: brew update failed, continuing..."
fi

# ── 2. Font ──
step "Installing font (Maple Mono NF CN)..."
brew install --cask font-maple-mono-nf-cn || echo "Warning: font install failed (non-critical)"

# ── 3. Terminal & Shell ──
step "Installing terminal & shell tools..."
brew install --cask ghostty || echo "Warning: ghostty install failed (non-critical)"
brew install zsh zsh-syntax-highlighting zsh-completions zoxide fzf chroma starship || echo "Warning: some shell packages failed to install"

# Set Homebrew zsh as default shell
BREW_ZSH="$(brew --prefix)/bin/zsh"
if [ -x "$BREW_ZSH" ]; then
  if ! grep -q "$BREW_ZSH" /etc/shells; then
    echo "$BREW_ZSH" | sudo tee -a /etc/shells
  fi
  if [ "$SHELL" != "$BREW_ZSH" ]; then
    echo "  Changing default shell to brew zsh (requires login password)..."
    chsh -s "$BREW_ZSH" || echo "Warning: chsh failed (run manually: chsh -s $BREW_ZSH)"
  fi
fi

# ── 4. CLI tools ──
step "Installing CLI tools..."
brew install jq bind helm viddy bitwarden-cli uv ccat gh atuin || echo "Warning: some CLI packages failed to install"

# ── 5. Container & Version manager ──
step "Installing container & version manager..."
brew install colima mise || echo "Warning: some packages failed to install"

# ── 6. IME & Apps ──
step "Installing apps..."
brew install --cask squirrel arc visual-studio-code obsidian bitwarden mos spotify claude claude-code || true

# ── 7. Brew auto-update ──
step "Configuring brew auto-update..."
brew tap homebrew/autoupdate 2>/dev/null || true
brew autoupdate start 43200 --upgrade --cleanup || echo "Warning: brew autoupdate setup failed"

step "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "  Oh My Zsh already installed."
fi

# Deploy config files (symlink)
# Note: must run AFTER Oh My Zsh install, because omz creates a default ~/.zshrc
step "Deploying config files (symlink)..."
mkdir -p ~/.config
mkdir -p ~/Library/Rime
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
mkdir -p ~/Library/Application\ Support/Code/User
mkdir -p ~/.claude

ln -sf "$DOTFILES_DIR/shell/zshrc" ~/.zshrc
ln -sf "$DOTFILES_DIR/shell/vimrc" ~/.vimrc
ln -sf "$DOTFILES_DIR/prompt/starship.toml" ~/.config/starship.toml
ln -sf "$DOTFILES_DIR/terminal/ghostty.conf" ~/Library/Application\ Support/com.mitchellh.ghostty/config
ln -sf "$DOTFILES_DIR/editor/vscode-settings.json" ~/Library/Application\ Support/Code/User/settings.json
ln -sf "$DOTFILES_DIR/ime/rime/bopomofo.custom.yaml" ~/Library/Rime/bopomofo.custom.yaml
# gitconfig uses cp (not symlink) — user edits name/email locally
if [ ! -f ~/.gitconfig ]; then
  cp "$DOTFILES_DIR/git/gitconfig" ~/.gitconfig
else
  echo "  ~/.gitconfig already exists, skipping."
fi
ln -sf "$DOTFILES_DIR/claude/statusline-command.sh" ~/.claude/statusline-command.sh

# ── SSH key ──
step "SSH key..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "$(git config user.email 2>/dev/null || echo 'dotfiles-setup')" -f "$HOME/.ssh/id_ed25519" -N ""
  echo "  SSH key generated. Add to GitHub after setup:"
  echo "    gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$(hostname)\""
else
  echo "  SSH key already exists."
fi

step "Claude Code settings..."
if [ ! -f ~/.claude/settings.json ]; then
  cp "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json
  echo "  Copied settings.json template — edit ~/.claude/settings.json to replace placeholder tokens."
else
  echo "  ~/.claude/settings.json already exists, skipping."
fi

# ── Verification ──
echo ""
echo "=== Verification ==="
PASS=0; FAIL=0
verify() {
  local label="$1"; shift
  if "$@" &>/dev/null; then
    echo "  ✓ $label"
    PASS=$((PASS+1))
  else
    echo "  ✗ $label"
    FAIL=$((FAIL+1))
  fi
}

# Commands
verify "Homebrew"           command -v brew
verify "zsh (brew)"         test -x "$(brew --prefix)/bin/zsh"
verify "Starship"           command -v starship
verify "Ghostty"            test -d /Applications/Ghostty.app
verify "Oh My Zsh"          test -d "$HOME/.oh-my-zsh"
verify "zoxide"             command -v zoxide
verify "fzf"                command -v fzf
verify "jq"                 command -v jq
verify "gh"                 command -v gh
verify "uv"                 command -v uv
verify "mise"               command -v mise
verify "colima"             command -v colima
verify "atuin"              command -v atuin
verify "Bitwarden CLI"      command -v bw
verify "helm"               command -v helm
verify "viddy"              command -v viddy
verify "ccat"               command -v ccat
verify "chroma"             command -v chroma
verify "bind (dig)"         command -v dig
verify "VS Code"            test -d "/Applications/Visual Studio Code.app"
verify "Squirrel (RIME)"    test -d /Applications/Squirrel.app
verify "Arc"                test -d /Applications/Arc.app
verify "Obsidian"           test -d /Applications/Obsidian.app
verify "Bitwarden (GUI)"    test -d /Applications/Bitwarden.app
verify "Mos"                test -d /Applications/Mos.app
verify "Spotify"            test -d /Applications/Spotify.app
verify "Claude"             test -d /Applications/Claude.app
verify "Claude Code"        test -d "/Applications/Claude Code.app"
verify "zsh-syntax-hl"      test -f "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
verify "zsh-completions"    test -d "$(brew --prefix)/share/zsh-completions"

# Config files (symlinks)
verify "~/.zshrc"           test -L "$HOME/.zshrc"
verify "~/.vimrc"           test -L "$HOME/.vimrc"
verify "starship.toml"      test -L "$HOME/.config/starship.toml"
verify "ghostty.conf"       test -L "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
verify "vscode settings"    test -L "$HOME/Library/Application Support/Code/User/settings.json"
verify "rime config"        test -L "$HOME/Library/Rime/bopomofo.custom.yaml"
verify "gitconfig"          test -f "$HOME/.gitconfig"
verify "SSH key"            test -f "$HOME/.ssh/id_ed25519"
verify "statusline script"  test -L "$HOME/.claude/statusline-command.sh"
verify "claude settings"    test -f "$HOME/.claude/settings.json"

# Font (macOS native check)
verify "Maple Mono NF CN"   bash -c 'system_profiler SPFontsDataType 2>/dev/null | grep -q "Maple Mono NF CN"'

echo ""
echo "Result: $PASS passed, $FAIL failed"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart terminal"
echo "  2. Run 'bw-setup-secrets' to pull secrets from Vaultwarden"
echo "  3. Run 'atuin login' to sync shell history"
echo "  4. Run 'gh auth login' to authenticate GitHub CLI"
echo "  5. Run 'gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$(hostname)\"' to add SSH key to GitHub"
echo "  6. mise use -g go terraform terraform-docs gcloud"
echo "  7. Edit ~/.claude/settings.json to replace ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN"
echo "  8. Edit ~/.gitconfig to set user.name and user.email"
