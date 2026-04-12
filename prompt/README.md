# Starship Prompt 設定筆記

## 主題

基於 Starship 內建的 **Tokyo Night** preset，再自行擴充語言模組、docker、cmd_duration 等。

## 安裝

```bash
# 安裝 starship
brew install starship

# 套用 Tokyo Night preset 作為基底
starship preset tokyo-night -o ~/.config/starship.toml
```

在 `~/.zshrc` 加入：
```bash
eval "$(starship init zsh)"
```

## 前置需求

- 字型：**Maple Mono NF CN**（中英文 2:1 等寬 + Nerd Font icons + 中文字形）
- Terminal：Ghostty

## 設定檔位置

`~/.config/starship.toml`

## Tokyo Night 配色漸層

```
亮灰藍 #a3aed2 → 藍 #769ff0 → 深藍灰 #394260 → 深藍黑 #212736 → #1d2230 → #15161e
```

| 區段 | 背景色 | 前景色 | 內容 |
|------|--------|--------|------|
| 開頭 | - | #a3aed2 | `░▒▓` 漸入效果 |
| OS + Apple logo | #a3aed2 | #090c0c | ` ` |
| Directory | #769ff0 | #e3e5e5 | 路徑 |
| Git branch/status | #394260 | #769ff0 | branch 名稱 + 狀態 |
| Languages | #212736 | #769ff0 | node/python/rust 等版本 |
| Docker/Conda | #1d2230 | #769ff0 | container context |
| Duration + Time | #15161e | #a0a9cb | 執行時間 + 時鐘 |

## 在原版 Tokyo Night 基礎上的自訂擴充

原版只有 node/rust/go/php 四個語言模組，擴充了：
- 語言：python, java, kotlin, lua, ruby, swift, dart, perl, c, cpp, zig, scala, elixir, elm, haskell, julia, nim, bun, deno
- 新增 docker_context, conda 區段（背景 #1d2230）
- 新增 cmd_duration 區段（超過 2 秒顯示，背景 #15161e）
- 新增 character 模組（成功 `❯` 藍色，失敗 `❯` 紅色）
- 關閉 gcloud 模組
- Directory 設定完整路徑顯示（`truncation_length = 0`, `truncate_to_repo = false`），從 `/` 根目錄開始顯示

## 踩坑記錄

### 1. gcloud 模組自動顯示 GCP 帳號

Starship 的 gcloud 模組預設啟用，會讀取 `~/.config/gcloud/` 設定檔，即使 `gcloud` CLI 不在 PATH 中也會顯示。
在 prompt 出現 `[☁️  user@domain(region)]`。

**解法**：在 starship.toml 中加 `[gcloud] disabled = true`，或直接刪除 `~/.config/gcloud/` 目錄。

### 2. Nerd Font 圓角分隔符 (U+E0B4) 被替換成方塊字元

用文字編輯器或工具寫入 `starship.toml` 時，Powerline 圓角分隔符 `` (U+E0B4, hex `ee 82 b4`) 容易被替換成其他 Unicode 字元（如普通的三角形 `` U+25B6 之類），導致分隔符從圓角變成方塊或尖角。

**症狀**：prompt 的 segment 之間本來應該是圓弧過渡，變成了方塊或直角。

**解法**：用 `starship preset tokyo-night` 指令輸出的檔案作為基底（它包含正確的 hex 編碼），或用 Python 直接寫入正確的 codepoint：
```python
separator = '\ue0b4'  # 圓角右箭頭
```

用 `hexdump -C ~/.config/starship.toml` 驗證分隔符應該是 `ee 82 b4`。

### 3. git_status 的 `?` 符號

prompt 出現 `?` 表示 git repo 中有 untracked files（未被 git 追蹤的檔案）。
這是 git_status 模組的正常行為，不是設定問題。

**解法**：`git add` 追蹤檔案、加到 `.gitignore`、或在 starship.toml 設定 `[git_status] untracked = ""`。
