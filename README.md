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
| `macos/` | Automator | `automator.md` | 手動建立 Quick Action |

## 新環境建置

### 一鍵安裝

```bash
git clone https://github.com/<your-username>/config.git
cd config
./setup.sh
```

安裝完後：
1. 重開 terminal
2. 執行 `bw-setup-secrets` 從 Vaultwarden 拉 secrets
3. 執行 `atuin login` 同步 shell 歷史
4. 執行 `mise use -g go terraform terraform-docs gcloud` 安裝語言/工具版本

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
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Shell plugins & tools
brew install zsh-syntax-highlighting zsh-completions zoxide fzf chroma

# Prompt
brew install starship
```

### 4. CLI 工具

```bash
brew install jq bind helm viddy
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

### 6. 歷史紀錄同步 (Atuin)

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
echo 'eval "$(atuin init zsh)"' >> ~/.zshrc
atuin register -u <USERNAME> -e <EMAIL>
atuin key
```

### 7. Bitwarden CLI（Secrets 管理）

```bash
brew install bitwarden-cli

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

zshrc 中會自動從 Bitwarden 載入 secrets（需先 `bw unlock`）。

### 8. 其他

```bash
# IME
brew install --cask squirrel  # RIME 注音

# Git config
# ref: https://github.com/0ghny/gitconfig

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

## 部署設定檔

```bash
# 複製設定檔到對應位置
cp shell/zshrc ~/.zshrc
cp shell/vimrc ~/.vimrc
cp prompt/starship.toml ~/.config/starship.toml
cp terminal/ghostty.conf ~/Library/Application\ Support/com.mitchellh.ghostty/config
cp ime/rime/bopomofo.custom.yaml ~/Library/Rime/bopomofo.custom.yaml

# Secrets (不進 repo，手動建立)
# 放 HISHTORY_S3_SECRET_ACCESS_KEY 等敏感變數
touch ~/.secrets
```

zshrc 中已包含 `eval "$(starship init zsh)"`，部署後 Starship 會自動生效。
