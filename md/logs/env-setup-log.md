# 環境設定日誌：Node/npm 安裝與 OpenCode 代理部屬（2026-08-27）

> 依使用者要求，本機所有環境設定變更 / 安裝行為均記錄於此。
> 格式參考 `md/logs/lobby-refactor-log.md`：症狀 → 根因 → 修復策略 → 驗證結果（附證據）→ 教訓編號續接。

---

## 本輪目標
1. 解決本機缺少 Node.js / npm 的問題（影響 `opencode` CLI 與任何 npm 工具鏈）。
2. 記錄本機環境變更與安裝行為。

---

## 已完成的動作

### 1. OpenCode 代理與設定部屬（先前步驟，屬本機環境/設定變更）
- 解壓 `C:\Users\Zien1079\Downloads\files.zip`，複製 10 個 agent `.md` 到
  `C:\Users\Zien1079\.config\opencode\agents\`：
  `build`、`git-committer`、`ui-explorer`、`ui-operator`、`ui-visual-checker`、
  `ui-visual-reviewer`、`network-explorer`、`network-operator`、`physics-explorer`、`physics-operator`。
- 複製 `opencode_config_complete.json` → `C:\Users\Zien1079\.config\opencode.json`
  （原本無舊檔，無需智慧合併）。

### 2. Node.js / npm 安裝（本輪重點）
**症狀**：執行 `opencode --version` 報 "not recognized"；`where node/npm/npx` 全找不到；
檢查常見路徑（`Program Files`、`nvm`、`fnm`、`volta`、`scoop`、registry 解除安裝鍵）均無 node。

**根因**：本機從未安裝 Node.js，也無任何版本管理器；`winget` / `choco` / `scoop` 皆不存在。

**修復策略**：
- 不使用需管理者權限的 MSI 安裝；改用官方 **免安裝 zip（win-x64）** 以避免權限卡關。
- 下載 `https://nodejs.org/dist/v24.20.0/node-v24.20.0-win-x64.zip`，
  解壓到 `C:\Users\Zien1079\AppData\Local\Programs\nodejs`（展平內層資料夾，使 `node.exe` 直接在該目錄）。
- 加入到 **User** PATH（非系統 PATH，免 admin）。

**驗證結果（證據）**：
- 新安 shell 中：`node --version` → `v24.20.0`；`npm --version` → `11.19.0`；`npx --version` → `11.19.0`。
- 安裝前確認網路可用（`https://nodejs.org` 回傳 200）。

### 3. OpenCode CLI 嘗試（選用，未成功）
- 因步驟 3 要求 `opencode --version` 能在 shell 中執行，試圖 `npm install -g opencode`。
- 結果：npm 回 **404**（`registry.npmjs.org` 上 `opencode` 套件不存在，可能走私有 registry 或官方安裝腳本）。
- 結論：CLI 無法經公開 npm 安裝；但桌面版 `OpenCode.exe` 已是 **v1.18.23**，
  滿足 ≥1.18.23 要求，無功能缺口。若日後需要 shell CLI，應改用官方安裝腳本或私有源。

---

## 教訓（接續 lobby-refactor-log 編號）
- **教訓 E1**：本機缺 Node 時，優先用官方免安裝 zip + User PATH，避免 MSI 的管理者權限卡關。
- **教訓 E2**：`opencode` 在公開 npm registry 不存在；版本驗證以桌面 `OpenCode.exe` 的 ProductVersion 為準。
- **教訓 E3**：安裝/設定後，變更只對「新開」的 shell 生效；已開終端需重開才抓得到新 PATH。

---

## 待辦 / 風險
- 尚未在 Zen TUI 實測 `build` → `@ui-explorer` 自動路由（需使用者手動驗證；若不自動路由則改用手動 `@ui-explorer` 指名）。
- 未建立專案層級 `res://your-project/.opencode/agents/`（可選，僅用來覆蓋全域設定）。
