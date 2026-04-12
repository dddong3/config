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

### 一鍵安裝

```bash
git clone https://github.com/dddong3/config.git
cd config
./setup.sh
```

安裝完後：
1. 重開 terminal
2. 執行 `bw-setup-secrets` 從 Vaultwarden 拉 secrets（含 SSH key 自動還原）
3. 執行 `atuin login` 同步 shell 歷史
4. 執行 `gh auth login` 登入 GitHub CLI（SSH key 會自動上傳）
5. 執行 `mise use -g go terraform terraform-docs gcloud` 安裝語言/工具版本
6. 編輯 `~/.claude/settings.json`，替換 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN`
7. 編輯 `~/.gitconfig`，填入 `user.name` 和 `user.email`

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
