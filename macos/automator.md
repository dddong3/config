macOS Automator Quick Action：用 Cursor 開啟選取檔案

1. Workflow 設定

項目	設定值	說明
Workflow type	Quick Action	建立 Finder 右鍵快速動作
Receives current	files or folders	接收 Finder 選取的檔案或資料夾
In	Finder.app	僅在 Finder 中顯示
Image	Action	右鍵圖示樣式
Color	Black	圖示顏色


⸻

2. Run Shell Script 設定

項目	設定值
Shell	/bin/bash
Pass input	as arguments

為什麼選 as arguments？

Finder 會將選取的項目以參數形式傳入 shell：

"$@"

這表示：
	•	每個選取項目都是一個獨立參數
	•	可正確處理包含空白的檔名

⸻

3. Shell Script 內容

```sh
open -a "/Applications/Visual Studio Code.app" "$@"
```
or

```sh
for f in "$@"
do
  open -a "/Applications/Visual Studio Code.app" "$f"
done
```
