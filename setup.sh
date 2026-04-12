#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== macOS Development Environment Setup ==="
echo ""

# ── 1. Homebrew ──
if ! command -v brew &>/dev/null; then
  echo "[1/8] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "[1/8] Homebrew already installed, updating..."
  brew update
fi

# ── 2. Font ──
echo "[2/8] Installing font (Maple Mono NF CN)..."
brew install --cask font-maple-mono-nf-cn || true

# ── 3. Terminal & Shell ──
echo "[3/8] Installing terminal & shell tools..."
brew install --cask ghostty || true
brew install zsh zsh-syntax-highlighting zsh-completions zoxide fzf chroma starship

# Set Homebrew zsh as default shell
BREW_ZSH="$(brew --prefix)/bin/zsh"
if ! grep -q "$BREW_ZSH" /etc/shells; then
  echo "$BREW_ZSH" | sudo tee -a /etc/shells
fi
if [ "$SHELL" != "$BREW_ZSH" ]; then
  chsh -s "$BREW_ZSH"
fi

# ── 4. CLI tools ──
echo "[4/8] Installing CLI tools..."
brew install jq bind helm viddy bitwarden-cli uv ccat

# ── 5. Container & Version manager ──
echo "[5/8] Installing container & version manager..."
brew install colima mise

# ── 6. IME & Apps ──
echo "[6/8] Installing apps..."
brew install --cask squirrel arc || true

# ── 7. Oh My Zsh & Atuin ──
echo "[7/8] Installing Oh My Zsh & Atuin..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "  Oh My Zsh already installed."
fi

if ! command -v atuin &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
else
  echo "  Atuin already installed."
fi

# ── 8. Deploy config files ──
# Note: must run AFTER Oh My Zsh install, because omz creates a default ~/.zshrc
echo "[8/8] Deploying config files..."
mkdir -p ~/.config
mkdir -p ~/Library/Rime
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
mkdir -p ~/Library/Application\ Support/Code/User

cp "$DOTFILES_DIR/shell/zshrc" ~/.zshrc
cp "$DOTFILES_DIR/shell/vimrc" ~/.vimrc
cp "$DOTFILES_DIR/prompt/starship.toml" ~/.config/starship.toml
cp "$DOTFILES_DIR/terminal/ghostty.conf" ~/Library/Application\ Support/com.mitchellh.ghostty/config
cp "$DOTFILES_DIR/editor/vscode-settings.json" ~/Library/Application\ Support/Code/User/settings.json
cp "$DOTFILES_DIR/ime/rime/bopomofo.custom.yaml" ~/Library/Rime/bopomofo.custom.yaml

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart terminal"
echo "  2. Run 'bw-setup-secrets' to pull secrets from Vaultwarden"
echo "  3. Run 'atuin login' to sync shell history"
echo "  4. mise use -g go terraform terraform-docs gcloud"
