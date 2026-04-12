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

# Fix insecure directories for compinit
chmod go-w "$(brew --prefix)/share" 2>/dev/null
chmod -R go-w "$(brew --prefix)/share/zsh" 2>/dev/null

# Set Homebrew zsh as default shell
BREW_ZSH="$(brew --prefix)/bin/zsh"
if [ -x "$BREW_ZSH" ]; then
  if ! grep -q "$BREW_ZSH" /etc/shells; then
    echo "$BREW_ZSH" | sudo tee -a /etc/shells
  fi
  if [ "$SHELL" != "$BREW_ZSH" ]; then
    echo "  Changing default shell to brew zsh..."
    if sudo -n true 2>/dev/null; then
      sudo chsh -s "$BREW_ZSH" "$USER"
    else
      chsh -s "$BREW_ZSH" || echo "  Warning: chsh failed (run manually: chsh -s $BREW_ZSH)"
    fi
  fi
fi

# ── 4. CLI tools ──
step "Installing CLI tools..."
brew install jq bind helm viddy bitwarden-cli uv ccat gh atuin defaultbrowser || echo "Warning: some CLI packages failed to install"

# ── 5. Container & Version manager ──
step "Installing container & version manager..."
brew install colima mise || echo "Warning: some packages failed to install"

# ── 6. IME & Apps ──
step "Installing apps..."
brew install --cask squirrel arc visual-studio-code obsidian bitwarden mos spotify claude claude-code || true

# ── 7. Brew auto-update ──
step "Configuring brew auto-update..."
mkdir -p ~/Library/LaunchAgents
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
mkdir -p ~/.ssh

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
ln -sf "$DOTFILES_DIR/ssh/config" ~/.ssh/config

# ── SSH key (restore from Bitwarden or generate new) ──
step "SSH key..."
restore_ssh_keys() {
  if [ -z "$BW_SESSION" ]; then
    echo "  Bitwarden not unlocked, skipping key restore."
    return 1
  fi
  local notes
  notes=$(BW_SESSION="$BW_SESSION" bw get notes ssh-keys 2>/dev/null) || return 1
  [ -z "$notes" ] && return 1

  echo "$notes" | awk '/BEGIN OPENSSH/{c++} c==1{print; if(/END OPENSSH PRIVATE KEY/)exit}' > "$HOME/.ssh/id_ed25519"
  echo "$notes" | awk '/ssh-ed25519.*dong3-code/{print}' > "$HOME/.ssh/id_ed25519.pub"
  chmod 600 "$HOME/.ssh/id_ed25519"

  echo "$notes" | awk '/BEGIN OPENSSH/{c++} c==2{print; if(/END OPENSSH PRIVATE KEY/)exit}' > "$HOME/.ssh/homelab"
  echo "$notes" | awk '/ssh-ed25519.*dong3-homelab/{print}' > "$HOME/.ssh/homelab.pub"
  chmod 600 "$HOME/.ssh/homelab"

  echo "  SSH keys restored from Bitwarden."
  return 0
}

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  # Try restore from Bitwarden first, fall back to generating new keys
  if ! restore_ssh_keys; then
    echo "  Generating new SSH keys..."
    if [ -n "${SSH_PASSPHRASE_CODE+x}" ]; then
      ssh-keygen -t ed25519 -C "dong3-code" -f "$HOME/.ssh/id_ed25519" -N "$SSH_PASSPHRASE_CODE"
    else
      ssh-keygen -t ed25519 -C "dong3-code" -f "$HOME/.ssh/id_ed25519"
    fi
    if [ -n "${SSH_PASSPHRASE_HOMELAB+x}" ]; then
      ssh-keygen -t ed25519 -C "dong3-homelab" -f "$HOME/.ssh/homelab" -N "$SSH_PASSPHRASE_HOMELAB"
    else
      ssh-keygen -t ed25519 -C "dong3-homelab" -f "$HOME/.ssh/homelab"
    fi
  fi
else
  echo "  SSH keys already exist."
fi
# Add to macOS Keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || echo "  Warning: could not add id_ed25519 to Keychain (run manually: ssh-add --apple-use-keychain ~/.ssh/id_ed25519)"
ssh-add --apple-use-keychain ~/.ssh/homelab 2>/dev/null || echo "  Warning: could not add homelab key to Keychain (run manually: ssh-add --apple-use-keychain ~/.ssh/homelab)"
# Upload to GitHub (requires gh auth login first)
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  KEY_TITLE="$(scutil --get ComputerName 2>/dev/null || hostname)-ed25519"
  if ! gh ssh-key list 2>/dev/null | grep -q "$(cat ~/.ssh/id_ed25519.pub | awk '{print $2}')"; then
    gh ssh-key add ~/.ssh/id_ed25519.pub --title "$KEY_TITLE"
    echo "  SSH key added to GitHub as '$KEY_TITLE'."
  else
    echo "  SSH key already on GitHub."
  fi
else
  echo "  GitHub CLI not authenticated. Run 'gh auth login' then:"
  echo "    gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$(hostname)-ed25519\""
fi

step "Claude Code settings..."
if [ ! -f ~/.claude/settings.json ]; then
  cp "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json
  echo "  Copied settings.json template — edit ~/.claude/settings.json to replace placeholder tokens."
else
  echo "  ~/.claude/settings.json already exists, skipping."
fi

# ── macOS System Preferences ──
step "Configuring macOS system preferences..."

# -- General UI --
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.LaunchServices LSQuarantine -bool false

# -- Dock --
defaults write com.apple.dock tilesize -int 54
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false
# Dock folders (Downloads etc): sort by name, display as stack, view as grid
/usr/libexec/PlistBuddy -c "Set :persistent-others:0:tile-data:arrangement 1" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :persistent-others:0:tile-data:displayas 0" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :persistent-others:0:tile-data:showas 2" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null || true

# -- Finder --
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
chflags nohidden ~/Library 2>/dev/null || true

# -- Keyboard --
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write com.apple.HIToolbox AppleFnUsageType -int 0

# -- Trackpad --
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# -- Window & Appearance --
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
defaults write NSGlobalDomain AppleICUForce24HourTime -bool true


# -- Siri --
defaults write com.apple.Siri StatusMenuVisible -bool false

# -- Screenshots --
mkdir -p ~/Pictures/Screenshot
defaults write com.apple.screencapture location -string "~/Pictures/Screenshot"
defaults write com.apple.screencapture disable-shadow -bool true

# -- Menu bar clock --
defaults write com.apple.menuextra.clock ShowDate -int 0
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock ShowAMPM -bool true
defaults write com.apple.menuextra.clock ShowSeconds -bool false

# -- Menu bar / Control Center --
# Note: macOS Sequoia Control Center visibility cannot be reliably set via defaults write.
# Configure manually: System Settings → Control Center
#   Don't Show: Wi-Fi, Bluetooth, AirDrop, Stage Manager
#   Show When Active: Focus, Screen Mirroring, Display, Sound, Now Playing

# -- Default browser --
if command -v defaultbrowser &>/dev/null; then
  defaultbrowser browser || echo "  Warning: could not set default browser (set manually in System Settings)"
fi

# -- TextEdit --
defaults write com.apple.TextEdit RichText -bool false

# -- Security --
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# -- Display sleep --
sudo pmset -a displaysleep 120 2>/dev/null || true

# -- Language & Region --
defaults write NSGlobalDomain AppleLanguages -array "en-TW" "zh-Hant-TW"
defaults write NSGlobalDomain AppleLocale -string "en_TW"

# -- Timezone --
sudo systemsetup -settimezone "Asia/Taipei" 2>/dev/null || true

# -- Photos --
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# -- Time Machine --
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Restart affected apps
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo "  macOS preferences configured."

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
verify "Squirrel (RIME)"    test -d "/Library/Input Methods/Squirrel.app"
verify "Arc"                test -d /Applications/Arc.app
verify "Obsidian"           test -d /Applications/Obsidian.app
verify "Bitwarden (GUI)"    test -d /Applications/Bitwarden.app
verify "Mos"                test -d /Applications/Mos.app
verify "Spotify"            test -d /Applications/Spotify.app
verify "Claude"             test -d /Applications/Claude.app
verify "Claude Code"        command -v claude
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
verify "ssh config"         test -L "$HOME/.ssh/config"

# Font (macOS native check)
verify "Maple Mono NF CN"   bash -c 'system_profiler SPFontsDataType 2>/dev/null | grep -q "Maple Mono NF CN"'

echo ""
echo "Result: $PASS passed, $FAIL failed"

echo ""
echo "=== Setup complete ==="
echo ""

# Open settings that require manual configuration
echo "Opening settings that require manual setup..."
echo "  1. Accessibility: grant access to Mos and Ghostty"
echo "  2. Passwords: enable Bitwarden as password AutoFill provider"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
open "x-apple.systempreferences:com.apple.Passwords-Settings.extension" 2>/dev/null || true

echo ""
echo "Next steps:"
echo "  1. Restart terminal"
echo "  2. Grant Accessibility permissions to Mos and Ghostty (settings window opened above)"
echo "  3. Run 'bw-setup-secrets' to pull secrets from Vaultwarden"
echo "  4. Run 'atuin login' to sync shell history"
echo "  5. Run 'gh auth login' then rerun ./setup.sh to auto-upload SSH key"
echo "  6. mise use -g go terraform terraform-docs gcloud"
echo "  7. Edit ~/.claude/settings.json to replace ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN"
echo "  8. Edit ~/.gitconfig to set user.name and user.email"
