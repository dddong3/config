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

# ── chezmoi ──
brew install chezmoi
chezmoi init --apply dddong3/config
