# dotfiles

macOS 開發環境設定檔備份與新環境建置指南。

## 結構

| 資料夾 | 工具 | 設定檔 | 部署位置 |
|--------|------|--------|----------|
| `shell/` | zsh | `zshrc` | `~/.zshrc` |
| `shell/` | vim | `vimrc` | `~/.vimrc` |
| `prompt/` | Starship | `starship.toml` | `~/.config/starship.toml` |
| `terminal/` | Ghostty | `ghostty.conf` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `editor/` | VS Code / Cursor | `vscode-settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `ime/rime/` | RIME 注音 | `bopomofo.custom.yaml` | `~/Library/Rime/bopomofo.custom.yaml` |
| `git/` | Git | `gitconfig` | `~/.gitconfig` |
| `macos/` | Automator | `automator.md` | 手動建立 Quick Action |
| `claude/` | Claude Code | `settings.json`, `statusline-command.sh` | `~/.claude/` |

## 新環境建置

### 一鍵安裝

```bash
git clone https://github.com/dddong3/config.git
cd config
./setup.sh
```

安裝完後：
1. 重開 terminal
2. 執行 `bw-setup-secrets` 從 Vaultwarden 拉 secrets
3. 執行 `atuin login` 同步 shell 歷史
4. 執行 `mise use -g go terraform terraform-docs gcloud` 安裝語言/工具版本
5. 編輯 `~/.claude/settings.json`，替換 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN`
6. 編輯 `~/.gitconfig`，填入 `user.name` 和 `user.email`

### 手動安裝（分步驟）

### 1. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. 字型

```bash
brew install --cask font-maple-mono-nf-cn
```

Maple Mono NF CN：中英文 2:1 等寬 + Nerd Font icons + 中文字形，一個字型全包。

### 3. Terminal & Shell

```bash
# Terminal
brew install --cask ghostty

# Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Shell plugins & tools
brew install zsh-syntax-highlighting zsh-completions zoxide fzf chroma

# Prompt
brew install starship

# 安裝 Homebrew 版 zsh 並設為預設 shell
brew install zsh
BREW_ZSH="$(brew --prefix)/bin/zsh"
echo "$BREW_ZSH" | sudo tee -a /etc/shells
chsh -s "$BREW_ZSH"
```

### 4. CLI 工具

```bash
brew install jq bind helm viddy uv ccat bitwarden-cli gh atuin
```

### 5. 容器 & 版本管理

```bash
# Container runtime (Docker alternative)
brew install colima

# Version manager
brew install mise

# mise plugins
mise use -g go
mise use -g terraform
mise use -g terraform-docs
mise use -g gcloud
```

### 6. Bitwarden CLI（Secrets 管理）

```bash
# bitwarden-cli 已在步驟 4 安裝

# 設定 self-hosted Vaultwarden
bw config server https://***REMOVED***

# 登入
bw login

# 驗證連線
bw status
```

在 Bitwarden 建一個 **Secure Note**（名稱：`dotfiles-secrets`），內容放環境變數：
```bash
export HISHTORY_S3_SECRET_ACCESS_KEY='your-key-here'
```

zshrc 中提供 `bw-setup-secrets` 指令，執行一次即可從 Vaultwarden 拉取 secrets 並存入 `~/.secrets`。

### 7. 其他

```bash
# IME
brew install --cask squirrel  # RIME 注音

# Arc browser
brew install --cask arc
```

## Oh My Zsh Plugins

zshrc 中啟用的 plugins：

```bash
plugins=(git colorize command-not-found zoxide)
```

### colorize

依賴 chroma，在 zshrc 中設定：

```bash
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_CHROMA_FORMATTER=terminal256
```

### zoxide

`z` 取代 `cd`，`zi` 進入互動模式。

## 手動部署設定檔

如果不使用 `setup.sh`，可手動建立 symlink：

```bash
mkdir -p ~/.config ~/.claude ~/Library/Rime ~/Library/Application\ Support/com.mitchellh.ghostty ~/Library/Application\ Support/Code/User

ln -sf "$(pwd)/shell/zshrc" ~/.zshrc
ln -sf "$(pwd)/shell/vimrc" ~/.vimrc
ln -sf "$(pwd)/prompt/starship.toml" ~/.config/starship.toml
ln -sf "$(pwd)/terminal/ghostty.conf" ~/Library/Application\ Support/com.mitchellh.ghostty/config
ln -sf "$(pwd)/editor/vscode-settings.json" ~/Library/Application\ Support/Code/User/settings.json
ln -sf "$(pwd)/ime/rime/bopomofo.custom.yaml" ~/Library/Rime/bopomofo.custom.yaml
ln -sf "$(pwd)/git/gitconfig" ~/.gitconfig
ln -sf "$(pwd)/claude/statusline-command.sh" ~/.claude/statusline-command.sh

# Claude Code settings (需手動替換 placeholder token)
cp claude/settings.json ~/.claude/settings.json
```
