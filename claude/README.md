# Claude Code 設定筆記

## 認證方式

Claude Code 支援兩種認證，**不可混用**：

| 認證方式 | Header | 設定方式 | 適用場景 |
|----------|--------|----------|----------|
| `ANTHROPIC_API_KEY` | `X-Api-Key: sk-...` | env 或 `apiKeyHelper` | 直接用 Anthropic API |
| `ANTHROPIC_AUTH_TOKEN` | `Authorization: Bearer eyJ...` | **只能用 env** | 公司 API proxy / OAuth |

目前使用 `ANTHROPIC_AUTH_TOKEN`（Bearer token），所以 **`apiKeyHelper` 不適用**。

## settings.json 結構

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": { ... },
  "hooks": { ... },
  "permissions": { ... },
  "enabledPlugins": { ... },
  "statusLine": { ... }
}
```

### `$schema`

加上後 VS Code / Cursor 編輯 settings.json 時會有 key 自動補全和驗證。

### env 常用變數

| 變數 | 說明 |
|------|------|
| `ANTHROPIC_BASE_URL` | API endpoint |
| `ANTHROPIC_AUTH_TOKEN` | Bearer token |
| `ANTHROPIC_MODEL` | 主模型 |
| `ANTHROPIC_SMALL_FAST_MODEL` | 輕量模型（subagent 用） |
| `CLAUDE_CODE_EFFORT_LEVEL` | `low` / `medium` / `max` |
| `CLAUDE_CODE_SUBAGENT_MODEL` | subagent 模型 |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | 啟用 agent teams |

`DISABLE_NON_ESSENTIAL_MODEL_CALLS` 已移除 — 開啟後會自動生成對話標題，方便搜尋歷史對話。

### permissions

deny 優先於 allow。`Bash(ls *)` 的空格是 word boundary，不會 match `lsof`。

注意：`Read`/`Edit` deny rules 只擋 Claude 內建工具，**不擋 `Bash(cat .env)`** — 需要 sandbox 才能做到 OS 層級阻擋。

### hooks

可用的 hook 事件：

| 事件 | 觸發時機 | 用法 |
|------|----------|------|
| `PreToolUse` | 執行工具前 | 攔截危險操作（exit 2 = 阻擋） |
| `PostToolUse` | 執行工具後 | 自動 lint/format |
| `Notification` | 需要使用者注意時 | macOS 通知 |
| `Stop` | agent 停止時 | 跑測試確認沒壞 |
| `SessionStart` | session 開始 | 初始化環境 |
| `UserPromptSubmit` | 使用者送出 prompt 時 | 注入額外 context |

目前啟用的 hooks：
- **Notification** — macOS 桌面通知
- **PostToolUse** — JS/TS 檔案編輯後自動 `eslint --fix`

### statusLine

自訂底部狀態列，執行 shell 腳本輸出文字：

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

## 踩坑記錄

### 1. apiKeyHelper 不支援 AUTH_TOKEN

`apiKeyHelper` 只能提供 `X-Api-Key` header 的值，不能提供 Bearer token。
如果你用的是 `ANTHROPIC_AUTH_TOKEN`，必須放在 `settings.json` 的 `env` 裡。

### 2. settings.json 用 cp 不用 symlink

`settings.json` 包含實際 token 值（由 `bw-setup.sh` sed 替換 placeholder），
所以用 `cp` 而不是 `ln -sf`，避免 token 寫回 repo。

### 3. statusLine ANSI 色碼

status line 腳本用 `echo -e` 輸出 ANSI 色碼。`printf` 會把 `%` 當格式符導致錯誤。
256-color ANSI（`\033[38;5;NNm`）在 Claude Code 中可能不渲染。

### 4. settings.json 分層

Claude Code 的 settings 有三層，由上到下合併：

| 層級 | 位置 | 用途 |
|------|------|------|
| Enterprise | MDM 或管理平台 | 公司級強制策略 |
| User | `~/.claude/settings.json` | 個人全域設定 |
| Project | `.claude/settings.json`（repo 內） | 專案級設定 |
