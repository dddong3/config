#!/bin/bash
set -eo pipefail

[[ "$(uname)" == "Darwin" ]] || { echo "This script requires macOS."; exit 1; }

# ── Homebrew ──
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# ── chezmoi (clone only — apply after bw auth) ──
brew install chezmoi
chezmoi init dddong3/config

# ── Bitwarden auth (chezmoi templates need BW_SESSION to resolve secrets) ──
DOTFILES_DIR="$(chezmoi source-path | sed 's|/home$||')"
brew install bitwarden-cli

if [[ "${SKIP_BW_AUTH:-}" != "1" ]]; then
  echo ""
  echo "=== Bitwarden Login ==="
  echo "chezmoi needs Bitwarden to resolve secrets in templates."
  echo ""
  source "$DOTFILES_DIR/scripts/bw-auth.sh"
  export BW_SESSION
fi

# ── Apply ──
if [[ -n "${BW_SESSION:-}" ]]; then
  chezmoi apply
else
  chezmoi apply --keep-going || true
fi
