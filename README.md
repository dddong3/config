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
2. 執行 `bw-setup-secrets` 從 Vaultwarden 拉 secrets
3. 執行 `atuin login` 同步 shell 歷史
4. 執行 `gh auth login` 登入 GitHub CLI
5. 執行 `gh ssh-key add ~/.ssh/id_ed25519.pub` 上傳 SSH key
6. 執行 `mise use -g go terraform terraform-docs gcloud` 安裝語言/工具版本
7. 編輯 `~/.claude/settings.json`，替換 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN`
8. 編輯 `~/.gitconfig`，填入 `user.name` 和 `user.email`

### Secrets 管理

zshrc 中提供 `bw-setup-secrets` 指令，從 Vaultwarden 的 Secure Note（`dotfiles-secrets`）拉取環境變數並存入 `~/.secrets`。

首次執行會互動式詢問 Vaultwarden URL，之後自動從 `~/.secrets` 讀取。
