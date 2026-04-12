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
| `ssh/` | SSH | `config` | `~/.ssh/config` |
| `claude/` | Claude Code | `settings.json`, `statusline-command.sh` | `~/.claude/` |

## 新環境建置

### Stage 1 — 基礎安裝（不需任何認證）

```bash
git clone https://github.com/dddong3/config.git
cd config
./setup.sh
```

安裝 Homebrew、字型、terminal、shell tools、CLI tools、apps、Oh My Zsh，並部署所有 config。

### Stage 2 — Secrets（需要 Bitwarden master password）

重開 terminal 後：

1. 授予 Mos 和 Ghostty Accessibility 權限（setup.sh 會自動開啟設定視窗）
2. 執行 `./scripts/bw-setup.sh` 從 Bitwarden 還原 secrets + SSH key

### Stage 3 — 服務設定（需要 Stage 2 的 secrets/key）

3. 執行 `atuin login` 同步 shell 歷史
4. 執行 `gh auth login` 登入 GitHub CLI
5. 編輯 `~/.gitconfig`，填入 `user.name` 和 `user.email`

### SSH Key

setup.sh 會自動處理 SSH key：
1. 嘗試從 Bitwarden Secure Note（`ssh-keys`）還原已有的 key pair
2. 如果 Bitwarden 沒有或未 unlock，則生成新的 ED25519 key
3. 自動加入 macOS Keychain
4. 如果 `gh` 已登入，自動上傳 public key 到 GitHub

兩把 key 的用途：

| Key | 用途 |
|-----|------|
| `~/.ssh/id_ed25519` | GitHub, GitLab 等 code 平台 |
| `~/.ssh/homelab` | Proxmox, VM 等 homelab 機器（`172.30.10.*`） |

#### 手動重新生成並同步

```bash
ssh-keygen -t ed25519 -C "dong3-code" -f ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -C "dong3-homelab" -f ~/.ssh/homelab
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/homelab
```

上傳到 Bitwarden（使用腳本避免複製空白問題）：

```bash
cat << 'SCRIPT' > /tmp/upload-ssh.sh
#!/bin/bash
NOTES=$(jq -rn \
  --rawfile code_key "$HOME/.ssh/id_ed25519" \
  --rawfile code_pub "$HOME/.ssh/id_ed25519.pub" \
  --rawfile lab_key "$HOME/.ssh/homelab" \
  --rawfile lab_pub "$HOME/.ssh/homelab.pub" \
  '"--- id_ed25519 (code) ---\n" + $code_key + "\n--- id_ed25519.pub ---\n" + $code_pub + "\n--- homelab (private) ---\n" + $lab_key + "\n--- homelab.pub ---\n" + $lab_pub')
ITEM_ID=$(bw get item ssh-keys | jq -r '.id')
bw get item ssh-keys | jq --arg notes "$NOTES" '.notes = $notes' | bw encode | bw edit item "$ITEM_ID" > /dev/null && echo "Bitwarden updated."
SCRIPT
export BW_SESSION=$(bw unlock --raw)
bash /tmp/upload-ssh.sh
```

上傳到 GitHub：

```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --title "dong3-mbp-ed25519"
```

### Secrets 管理

zshrc 中提供 `bw-setup-secrets` 指令，從 Vaultwarden 的 Secure Note（`dotfiles-secrets`）拉取環境變數並存入 `~/.secrets`。

首次執行會互動式詢問 Vaultwarden URL，之後自動從 `~/.secrets` 讀取。

### Bitwarden Secure Notes

| Note 名稱 | 內容 |
|-----------|------|
| `dotfiles-secrets` | 環境變數（API token、BW_SERVER_URL 等） |
| `ssh-keys` | SSH private/public key pairs |

### Secret Rotation

| Secret | 如何 rotate | 更新步驟 |
|--------|------------|----------|
| `ANTHROPIC_AUTH_TOKEN` | 從平台重新申請 token | 1. 更新 Bitwarden `dotfiles-secrets` 2. 重跑 `./scripts/bw-setup.sh` |
| `ATUIN_KEY` | 重新註冊 atuin 帳號 | 1. `atuin account logout` 2. 重新 register 3. 更新 Bitwarden `dotfiles-secrets` |
| SSH key (`id_ed25519`) | 重新生成 | 1. `ssh-keygen -t ed25519 -C "dong3-code" -f ~/.ssh/id_ed25519` 2. 上傳到 Bitwarden（見上方腳本）3. `gh ssh-key add` |
| SSH key (`homelab`) | 重新生成 | 1. `ssh-keygen -t ed25519 -C "dong3-homelab" -f ~/.ssh/homelab` 2. 上傳到 Bitwarden 3. `ssh-copy-id` 到各 server |

統一流程：

```
1. 在來源處 rotate（申請新 token / 生成新 key）
2. 更新 Bitwarden（Vaultwarden 網頁編輯 or 上傳腳本）
3. 本機重新拉取：./scripts/bw-setup.sh
```

## E2E 測試

用 [Tart](https://github.com/cirruslabs/tart) 在乾淨的 macOS VM 中自動測試完整 setup 流程。

### 前置需求

```bash
brew install cirruslabs/cli/tart
brew install sshpass
```

### 執行

```bash
./test/e2e.sh
```

### 流程

1. 下載乾淨的 macOS Sequoia VM image
2. 建立 VM 並啟動（headless）
3. 等待 SSH 連線
4. 設定 passwordless sudo
5. 在 VM 中 `git clone` repo（public repo，不需認證）
6. 執行 `setup.sh`（SSH key 使用空 passphrase 以避免互動）
7. 驗證所有安裝項目和 config symlink
8. 輸出結果並清理 VM

### 注意事項

- 首次執行需要下載 VM image（~20GB），之後會使用 cache
- 整體耗時約 10-15 分鐘（主要是 brew install）
- E2E 不測試需要互動的步驟（bw-setup-secrets、atuin login、gh auth login）
- SSH key 使用空 passphrase（`SSH_PASSPHRASE_CODE=''`），僅用於測試
