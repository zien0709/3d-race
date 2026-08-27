# AI 工作流程指南（AI Workflow Guide）

> 本文件給所有在此專案工作的 AI 助手。架構知識請讀 `md/AISTARTREADIT.txt`；
> 本文件講的是「怎麼工作」——流程規範、環境陷阱、發佈 SOP。
> 內容全部來自實戰踩雷，違反者會浪費大量除錯時間。
> **更新日期：2026-08-26**（Phase D Lobby 重構進行中）

---

## 1. 核心工作循環（每個任務都要走）

1. **todowrite 建任務清單**，隨進度即時更新狀態（一次只有一個 in_progress）。
2. **動手前先讀現狀**：read 相關檔案 → 盤點被依賴方的既有 API → 才決定改法。
3. **每完成一個邏輯步驟就 git commit**，Conventional Commits 格式，
   標題一行＋body 列要點（做了什麼、為什麼、關鍵檔案）。不要累積一大包。
4. **修完必須驗證才算完成**，驗證循環：
   ```
   改檔 → project_manage(stop) → filesystem scan（若新增 class_name）
       → project_run → 看 logs_read(source='editor'|'game')
       → game_eval 或 game_manage(get_ui_elements) 取證
   ```
5. **過程與結論寫進對應日誌**（如 `lobby-refactor-log.md`），格式：
   「症狀 → 根因 → 修復策略 → 驗證結果（附證據）→ 教訓編號續接」。
6. 新教訓追加到日誌的教訓區，編號接著上一位作者往下排。

---

## 2. 環境陷阱（此機器 = Windows + PowerShell 5.1）

### Shell
- bash 工具其實是 **PowerShell 5.1**：
  - 沒有 `head` / `tail` / `wc` / `rg` / `cat` / `&&` / `python3`
  - 用 `Select-String`、`Get-Content`、完整 Cmdlet 名稱（`Get-ChildItem` 非 ls）
  - 指令鏈接用 `cmd1; if ($?) { cmd2 }`
- **UTF-8 參數會被系統字碼頁搞成 `??`**（em-dash、中文都可能爛）。
  → 多行／含特殊字元的內容（commit message、tag、release notes）
  **一律先用 Write 工具寫暫存檔，再 `-F <file>` 餵入**，絕不直接放命令列參數。

### Git
- `git tag` 預設 cleanup 會把 `#` 開頭的行當註解刪掉
  → annotated tag 一律加 `--cleanup=verbatim`。
- 推前確認 fast-forward：`git merge-base --is-ancestor <remote_head> main`。

### Godot MCP（godot-ai_* 工具）
- `game_eval` **不支援 `:=` 型別推斷賦值**（EVAL_COMPILE_ERROR）→ 一律 `var x = ...`。
- **消費協程回值必 await**，否則 EVAL_RUNTIME_ERROR
  （例：`PlayerStorage.load_profile()` 是協程）。
- 同步觸發的訊號有 race：不要 `call(); await signal`，
  改「先 connect lambda 捕獲結果 → 呼叫 → 輪詢 process_frame」。
- **截圖無法觀看**（模型不支援圖片輸入）→ 用 `get_ui_elements` 做版面結構驗證。
- 遊戲卡在 debugger break（boot 解析錯誤）時：
  `project_manage(stop)` → 修錯 → 重跑，poll `editor_state` 看 late transition。

### 其他
- **子代理（task 工具）回傳可能是空殼**——重要實作由主 agent 親自做，
  子代理只用來跑可丟棄的探索。
- 中文 console 輸出常亂碼，判斷指令成败看 exit 行為而非亂碼文字。

---

## 3. Git Remotes 與發佈 SOP

| remote | repo | 用途 |
|--------|------|------|
| `origin` | `zien0709/3d-race` | 開發備份 |
| `fork` | `Z11430373/3d-race` | **Release 發佈處**（GitHub Releases 在這） |

### 發新版 vX.YZ 標準流程
1. 確認本地 main 領先且 fast-forward（0 commits behind fork/main）。
2. `git push fork main`
3. Release notes 寫暫存檔，**Keep a Changelog 業界格式**：
   ```markdown
   Changelog

   ### Fixed
   - **scope**: 一句話說明。(commit hash)

   ### Added
   - ...

   ### Notes
   - 已知限制 / 已知問題

   **Full Changelog**: https://github.com/Z11430373/3d-race/compare/v上一版...vX.YZ
   ```
4. `git tag -a vX.YZ --cleanup=verbatim -F <notes檔>`
5. `git push fork vX.YZ`（若改寫舊 tag 加 `--force`）
6. 建 GitHub Release：
   ```powershell
   $gh = "$env:ProgramFiles\GitHub CLI\gh.exe"
   $credInput = "protocol=https`nhost=github.com`n`n"
   $credLines = $credInput | git credential fill
   $token = ($credLines | Where-Object { $_ -like 'password=*' }).Substring(9)
   $env:GH_TOKEN = $token
   & $gh release create vX.YZ --repo Z11430373/3d-race `
       --title "vX.YZ - <短標>" --notes-file "<notes檔>"
   ```
   注意：gh **未正式登入**（儲存的 token 缺 `read:org` scope），
   只能用 `$env:GH_TOKEN` 單次執行；想常駐就手動跑一次 `gh auth login --web`。

---

## 4. 程式碼修改原則（Godot 4.7 + EOSG）

1. **解耦＝委託既有 autoload，不是重寫**。重構前先把被依賴方的公開 API 列出來
   （曾經憑空想像出不存在的 API 導致整條登入鏈壞掉）。
2. **惰性解析 autoload** 是注入式設計的安全網：
   `_ensure_xxx()` 先回傳已注入的，否則 `get_node_or_null("/root/Xxx")`。
3. **UI 元件只發訊號**，協調器（如 `ui/lobby/lobby_main.gd`）轉發到網路層
   （NetworkManager）；顯示邏輯與傳輸邏輯分離，傳輸可先用 print placeholder。
4. GDScript：消費协程回值必 `await`；沒有 `println`（用 `print`）；
   沒有 pipeline `|>` 運算子。
5. 開發階段用 `print()` 驗證訊號鏈路活躍，之後再換真實實作。

---

## 5. 文件地圖與讀取規則

### 5.1 資料夾結構

```
md/
├── core/                     ← 開工必讀，力求精簡
│   ├── AI_WORKFLOW.md        ← 流程規範＋環境陷阱＋發佈 SOP（本檔）
│   └── AISTARTREADIT.txt     ← 架構總覽
├── status/                   ← 「現況真相」，只能覆寫、不能疊加新報告
│   ├── PROJECT_STATUS.md     ← 目前 Phase 與已知問題快照
│   ├── eos_status.md         ← EOS 整合進度
│   └── lobby-system-analysis.md ← 大廳系統分析與 Phase D 任務拆解
├── domain/                   ← 特定任務類型才需要讀
│   ├── vehicle_model_analysis.md
│   ├── multiplayer_execution_guide.md
│   └── login_interface_decoupling.md
├── logs/                     ← 疊加型日誌，教訓編號持續往下接，不覆寫
│   └── lobby-refactor-log.md
├── archive/                  ← 歷史快照，不代表現況，除非被明確指名否則不讀
│   └── EXPLORATION_REPORT.md
└── multiplayer_plan.md       ← 其他 AI 的工作產物，**不要動、不要清**
```

### 5.2 讀取規則

> **開工必讀 core/ 全部 → 讀 status/PROJECT_STATUS.md 確認現況 → 依任務類型讀對應 domain/ 檔案 → archive/ 除非被 status 文件或使用者明確指名，否則不讀**

### 5.3 檔案速查表

| 路徑 | 內容 | 何時讀 |
|------|------|--------|
| `md/core/AI_WORKFLOW.md` | 流程規範、環境陷阱、發佈 SOP | **每次開工必讀** |
| `md/core/AISTARTREADIT.txt` | 專案架構總覽 | **每次開工必讀** |
| `md/status/PROJECT_STATUS.md` | 目前 Phase、已知問題快照 | **每次開工必讀** |
| `md/status/lobby-system-analysis.md` | 大廳架構、訊號、Phase D 任務 | Lobby 相關任務 |
| `md/status/eos_status.md` | EOS 登入/PDS/權限配置詳情 | EOS 相關任務 |
| `md/domain/vehicle_model_analysis.md` | 車模結構、材質、整合細節 | 車輛模型/物理任務 |
| `md/domain/multiplayer_execution_guide.md` | ENET→EOS 多人實施步驟 | 多人聯機任務 |
| `md/domain/login_interface_decoupling.md` | AuthManager 解耦記錄 | 登入/認證任務 |
| `md/logs/lobby-refactor-log.md` | 重構完整日誌＋教訓 1-26 | 需查歷史決策/教訓 |
| `md/archive/EXPLORATION_REPORT.md` | 2026-08-24 探索快照 | **除非被明確指名否則不讀** |
| `md/multiplayer_plan.md` | 無 EOS 多人建置規劃 | **不要動、不要清** |
