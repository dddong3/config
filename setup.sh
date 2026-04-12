#!/bin/bash
set -eo pipefail

# macOS only
[[ "$(uname)" == "Darwin" ]] || { echo "This script requires macOS."; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

STEP=0; TOTAL=9
step() { STEP=$((STEP+1)); echo "[$STEP/$TOTAL] $1"; }

echo "=== macOS Development Environment Setup ==="
echo ""

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
    chsh -s "$BREW_ZSH"
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
brew install --cask squirrel arc visual-studio-code || echo "Warning: some app installs failed (non-critical)"

# ── 7. Oh My Zsh ──
step "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "  Oh My Zsh already installed."
fi

# ── 8. Deploy config files (symlink) ──
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
ln -sf "$DOTFILES_DIR/git/gitconfig" ~/.gitconfig
ln -sf "$DOTFILES_DIR/claude/statusline-command.sh" ~/.claude/statusline-command.sh

# ── 9. Deploy Claude Code settings (template, needs manual token setup) ──
step "Claude Code settings..."
if [ ! -f ~/.claude/settings.json ]; then
  cp "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json
  echo "  Copied settings.json template — edit ~/.claude/settings.json to replace placeholder tokens."
else
  echo "  ~/.claude/settings.json already exists, skipping (compare with claude/settings.json manually)."
fi

# Claude Code (statusline only; settings.json needs manual token setup)
mkdir -p ~/.claude
cp "$DOTFILES_DIR/claude/statusline-command.sh" ~/.claude/statusline-command.sh

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart terminal"
echo "  2. Run 'bw-setup-secrets' to pull secrets from Vaultwarden"
echo "  3. Run 'atuin login' to sync shell history"
echo "  4. mise use -g go terraform terraform-docs gcloud"
echo "  5. Edit ~/.claude/settings.json to replace ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN"
echo "  6. Edit ~/.gitconfig to set user.name and user.email"
