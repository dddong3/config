# dotfiles

macOS 開發環境設定檔備份與新環境建置指南。

## 結構

所有 config 由 chezmoi 管理，source 在 `home/` 下。

| 工具 | Source（`home/` 下） | 部署位置 |
|------|---------------------|----------|
| zsh | `dot_zshrc` | `~/.zshrc` |
| vim | `dot_vimrc` | `~/.vimrc` |
| Starship | `dot_config/starship.toml` | `~/.config/starship.toml` |
| Ghostty | `Library/Application Support/com.mitchellh.ghostty/config` | 同路徑 |
| VS Code | `Library/Application Support/Code/User/settings.json` | 同路徑 |
| RIME 注音 | `Library/Rime/bopomofo.custom.yaml` | `~/Library/Rime/` |
| Git | `dot_gitconfig.tmpl`, `dot_gitconfig-work.tmpl` | `~/.gitconfig`, `~/.gitconfig-work` |
| SSH | `private_dot_ssh/config`, `config.local.tmpl` | `~/.ssh/config` |
| Claude Code | `private_dot_claude/settings.json`, `statusline-command.sh` | `~/.claude/` |
| Secrets | `private_dot_secrets.tmpl` | `~/.secrets`（從 Bitwarden 拉取） |

其他目錄：

| 資料夾 | 用途 |
|--------|------|
| `macos/` | Automator Quick Actions（`OpenInVSCode.workflow`） |
| `scripts/` | 自動化腳本（`bw-auth.sh`, `bw-secrets.sh`） |
| `test/` | E2E 測試（Tart VM） |

## 新環境建置

### Stage 1 — 基礎安裝（不需任何認證）

新 Mac 第一次跑 `git` 會提示安裝 Xcode Command Line Tools，同意安裝後再繼續。

```bash
git clone https://github.com/dddong3/config.git
cd config
./setup.sh
```

安裝 Homebrew、字型、terminal、shell tools、CLI tools、apps、Oh My Zsh，並部署所有 config。

### Stage 2 — Secrets（需要 Bitwarden master password）

重開 terminal 後：

1. 授予 Mos 和 Ghostty Accessibility 權限（setup.sh 會自動開啟設定視窗）
2. `cza`（alias：`export BW_SESSION=$(bw unlock --raw) && chezmoi apply`）

chezmoi 會從 Bitwarden 拉取 `dotfiles-secrets-{profile}` 並部署到 `~/.secrets`。

### Stage 3 — 服務設定（需要 Stage 2 的 secrets/key）

3. 上傳 SSH key 到 GitHub（如果是新 key）：`gh ssh-key add ~/.ssh/personal_ed25519.pub --title "$(hostname)-personal"`
4. `gh auth login` 登入 GitHub CLI（選 SSH protocol）
5. `atuin login`，encryption key 用 `~/.secrets` 裡的 `ATUIN_KEY`
6. 編輯 `~/.gitconfig`，填入 `user.name` 和 `user.email`

### SSH Key

SSH key 在 Stage 1 由 `chezmoi apply` 自動生成（`run_once_before_02-ssh-keygen.sh.tmpl`），每台機器獨立，不備份到 Bitwarden。

| Key | 用途 |
|-----|------|
| `~/.ssh/personal_ed25519` | GitHub, GitLab 等 code 平台（personal，預設） |
| `~/.ssh/work_ed25519` | 工作身份 GitHub（僅工作機需要） |

需要 rotate 時手動執行：

```bash
ssh-keygen -t ed25519 -C "$(hostname)-personal" -f ~/.ssh/personal_ed25519
ssh-add --apple-use-keychain ~/.ssh/personal_ed25519
gh ssh-key add ~/.ssh/personal_ed25519.pub --title "$(hostname)-personal"
```

### Secrets 管理

`~/.secrets` 由 chezmoi template 管理（`private_dot_secrets.tmpl`），`cza` 時自動從 Bitwarden 拉取。手動編輯用 `./scripts/bw-secrets.sh`。

### Bitwarden Secure Notes

| Note 名稱 | 內容 |
|-----------|------|
| `dotfiles-secrets-{home,work}` | 環境變數（API token、BW_SERVER_URL 等） |

### Scripts 一覽

| 腳本 | 用途 | 何時用 |
|------|------|--------|
| `bw-auth.sh` | 共用 Bitwarden 認證 helper（被其他腳本 source）| 不直接執行 |
| `bw-secrets.sh` | 編輯 Bitwarden 中的 secrets | 新增或修改環境變數 |

## 維護 Checklist

新增工具時需同步更新：

1. `setup.sh` — brew install 或 mise use 行
2. `setup.sh` — verify 區塊加入驗證
3. `README.md` — 結構表或說明（如有新設定檔）
4. `test/e2e.sh` — EXPECTED_FAILS（如該工具 Stage 1 不可用）

新增 secret 時：

5. 用 `./scripts/bw-secrets.sh` 編輯 Bitwarden `dotfiles-secrets-{profile}` note

注意：`setup.sh` 會安裝 pre-commit hook 防止意外 commit secrets，僅在執行 `setup.sh` 後生效。

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
- E2E 只測試 Stage 1（不測試 Bitwarden secrets、atuin login、gh auth login）
