# SSH 設定筆記

## Key 架構

| Key | 演算法 | 用途 | 存放位置 |
|-----|--------|------|----------|
| `id_ed25519` | ED25519 | GitHub, GitLab 等 code 平台 | `~/.ssh/id_ed25519` |
| `homelab` | ED25519 | Proxmox, VM 等 homelab 機器 | `~/.ssh/homelab` |

## 為什麼選 ED25519

| 演算法 | 建議 | 說明 |
|--------|------|------|
| **ED25519** | 首選 | 256-bit，安全性等同 RSA-3072，key 只有 68 字元 |
| RSA 4096 | 可接受 | 向下相容舊系統，但 key 很長 |
| RSA 2048 | 淘汰中 | 不建議使用 |
| ECDSA | 不推薦 | 實作上容易出隨機數漏洞 |

## Passphrase

Private key 用 AES-256 + bcrypt 加密。即使檔案被複製，沒有 passphrase 無法使用。

搭配 macOS Keychain 只需輸入一次：

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

## 備份與還原

SSH key 備份在 Bitwarden Secure Note（`ssh-keys`）。

### 還原（新電腦 Stage 2）

`scripts/bw-setup.sh` 自動處理。

### 手動重新生成

```bash
ssh-keygen -t ed25519 -C "dong3-code" -f ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -C "dong3-homelab" -f ~/.ssh/homelab
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/homelab
```

上傳到 Bitwarden：`./scripts/rotate-ssh-keys.sh`

### Bitwarden note 格式

```
--- id_ed25519 (code) ---
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----

--- id_ed25519.pub ---
ssh-ed25519 AAAA... dong3-code

--- homelab (private) ---
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----

--- homelab.pub ---
ssh-ed25519 AAAA... dong3-homelab
```

還原時用 awk 按 `BEGIN OPENSSH` 出現次數（c==1 第一把，c==2 第二把）解析。

## 踩坑記錄

### 1. Bitwarden note 空白問題

用 shell 變數組合 note 內容時，heredoc 或 `echo` 可能在每行前加空白。
用 `jq --rawfile` 直接讀取檔案內容可避免：

```bash
NOTES=$(jq -rn \
  --rawfile code_key "$HOME/.ssh/id_ed25519" \
  --rawfile code_pub "$HOME/.ssh/id_ed25519.pub" \
  ...)
```

### 2. macOS sed 語法不同

macOS 的 `sed -i` 需要空字串參數：`sed -i '' 's/old/new/'`（GNU sed 不需要）。
`sed` 的正則不支援某些 GNU 擴展，建議用 `awk` 處理複雜的文字擷取。

### 3. 有 MDM 的公司 Mac

MDM 管理者技術上可以推送腳本讀取 `~/.ssh/` 下的檔案。
設 passphrase 後即使檔案被讀取也無法使用（AES-256 + bcrypt 加密）。

建議：公司 Mac 只放 code key，不放 homelab key。

### 4. GitHub SSH key "Never used"

GitHub SSH key 的 "Last used" 只追蹤 push 操作，不追蹤 `git clone` 或 `ssh -T`。
顯示 "Never used" 不代表沒被用過。
