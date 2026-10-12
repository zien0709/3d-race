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

# 附錄：OpenCode 模型重映射 + Agent 全驗證（2026-10-12）

## 背景
v2 Desktop 升級後進行健康檢查，發現 13 個 agent 的 model 全部指向不存在的模型 ID（P2），6 個 plugin 全掛（P1），且存在 3 個重疊設定檔（P3）。

## 完成的動作

### E4：13 個 agent 模型重映射（2026-10-12）
- 所有舊 model ID（`hy3-free`、`deepseek-v4-flash-free`、`nemotron-3-Ultra-free`、`mimo-v2.5-free`、`nemotron-3-5-lightning-free`、`opencode/gemini-3.7-flash` 等）經 `opencode models` 驗證不存在，全數替換為 registry 存在之 `opencode/*-free`。
- 更新位置：10 個 `agents/*.md` frontmatter + 現役 `~/.config/opencode/opencode.json`（13 agents）+ legacy `~/.config/opencode.json`（10 agents）。
- **驗證**：`opencode models` 逐一確認存在；`agent list`（--pure 與正常模式）確認 13 個 agent 全部註冊。

### E5：config schema 限制 —— agent.model 不允許陣列（2026-10-12）
- 症狀：`opencode run` 報 `Expected string | undefined, got [array]`（`ui-operator-strong`、`network-explorer-hard` 原本用 fallback array）。
- 根因：1.19.0 CLI 的 AgentConfig schema 只允許 `model` 為字串；fallback 陣列形式不被接受。
- 修復：改回單一字串主選（`ui-operator-strong` → `opencode/muse-spark-1.3-contributor-free`；`network-explorer-hard` → `opencode/muse-spark-1.3-contributor-free`）。
- **教訓 E5**：此環境 config 的 `agent.<name>.model` 只吃單一字串，不要寫 fallback 陣列；「主選/備用」由使用者表格記錄即可，config 只放主選。

### E6：OMO plugin 覆寫 build → subagent，導致 run 全掛（2026-10-12）★最關鍵
- 症狀：`opencode run --agent <任何>` 全部失敗：`Error: default agent "build" is a subagent`（`Unexpected server error`）。
- 診斷過程：
  1. `build.md` frontmatter 與 config 都是 `mode: primary`，但 server 判 build 是 subagent。
  2. `opencode agent list` 正常模式：`build (subagent)` + OMO 全家（librarian/Metis/Momus/oracle/Sisyphus-Junior/Sisyphus-ultraworker…）。
  3. `opencode agent list --pure`：`build (primary)`，且 OMO agents 全部消失。
- 根因：`oh-my-openagent@latest` plugin 的 `.agents` 目錄被掃描合併，OMO 的 build 定義（無 mode 或 subagent）覆寫/遮蔽了我們的 `mode: primary`；OMO 載入本身失敗（V1-only、v2 loader 拒絕），但 .agents 掃描仍發生。
- 修復：從 `~/.config/opencode/opencode.jsonc` 與 `~/.config/opencode/tui.json` 移除 `"plugin": ["oh-my-openagent@latest"]`（備份：`*.bak-omo-removal`）。
- **教訓 E6**：plugin 自帶的 `.agents` 目錄即使 plugin 載入失敗也會被掃描並覆寫同 id 的 agent 定義；疑難時 `agent list` vs `agent list --pure` 對比是關鍵診斷手段。

### E7：`run --agent` 只接受 primary —— 驗證 subagent 需繞道（2026-10-12）
- 症狀：`run --agent ui-explorer` 報 `agent "ui-explorer" is a subagent, not a primary agent. Falling back to default agent`。
- 原因：CLI run 的非互動模式只允許 primary agent 作為 session 主角；md 檔 frontmatter 的 `mode: subagent` 優先於 config（即使 config 寫 `mode: all` 也被 md 覆寫）。
- 驗證方案：a) `agent list` 確認註冊；b) 對每個綁定 model 用 `run --model <id>` 實測可回應；c) config-only agent（無 md）在臨時 config 設 `mode: all` 後可直接 `run --agent` 呼叫。
- **教訓 E7**：驗證 subagent「能被呼叫」的本質 = ① 定義註冊成功（agent list）+ ② 綁定 model 真的可回應（run --model）。CLI run 無法直接驅動 subagent 本身是平台限制，非配置錯誤；真實派遣需在 TUI/互動中由主代理 task 呼叫。

### E8：`opencode/ling-3.0-flash-fin-free` registry 有列但實際不可用（2026-10-12）
- 症狀：`run --model opencode/ling-3.0-flash-fin-free` → `Error: Upstream request failed: Model is unavailable.`
- 影響 agent：`network-operator`、`physics-explorer`（md + 兩份 json 共 6 處）。
- 修復：全數換成已實測可用的 `opencode/ling-3.1-flash-free`。
- **教訓 E8**：registry 上「存在」≠「可用」；免費模型可能上游暫時關閉。模型重映射後務必實測呼叫一次，不能只驗證 registry 存在。

## 全代理驗證結果（2026-10-12）

| Agent | 驗證方式 | 結果 |
|---|---|---|
| build | `run --agent build`（現役 config） | ✅ muse-spark-1.3-contributor-free |
| ui-explorer | `run --model ling-3.1-flash-free`（綁定 model 實測） | ✅ |
| ui-operator | `run --model muse-spark`（與 build 同 model，已測） | ✅（model 同 build） |
| ui-operator-strong | 臨時 config `mode: all` 直接 `run --agent` | ✅ muse-spark |
| ui-visual-checker | `run --model mimo-v2.6-flash-free` | ✅ |
| ui-visual-reviewer | `run --model step-5-preview-free` | ✅ |
| network-explorer | `run --model nemotron-3.5-lightning-free` | ✅ |
| network-operator | 替換後 `run --model ling-3.1-flash-free` | ✅ |
| network-operator-simple | 臨時 config `mode: all` 直接 `run --agent` | ✅ nemotron-3.5-lightning-free |
| network-explorer-hard | 臨時 config `mode: all` 直接 `run --agent` | ✅ muse-spark |
| physics-explorer | 替換後 `run --model ling-3.1-flash-free` | ✅ |
| physics-operator | `run --model space-bunny-free` | ✅ |
| git-committer | `run --model nemotron-3.5-lightning-free` | ✅ |

全 13 agent：定義註冊 ✅（`agent list`，無 Error）+ 綁定 model 實測 ✅。

## 待辦 / 風險
- **plugin 修復尚未完成**（E 系列之外）：6 個 plugin 仍未替換/移除（opencode-pty/v2、@p4r4d0xb0x/opencode-dcp、@opeoginni/opencode-copilot-auto、@mohak34/opencode-notifier 等替代方案已研究，未寫入 config）。
- `build` model 變更對「新 session」生效，本 session 仍為舊 big-pickle（預期行為）。
- 臨時驗證用 config：`C:\Users\Zien1079\AppData\Local\Temp\opencode\agent-verify\opencode.json`（可刪）。

---

### E9：5 個壞 plugin 替換為 V2 版（2026-10-12）
- 症狀：現役 `opencode.json` 的 `plugin` 陣列 5 個全掛（`opencode-github-copilot-auto-model`、`opencode-dynamic-context-pruning`、`opencode-vibeguard`、`opencode-pty`、`opencode-notifier`；之前 log 皆為載入 WARN）。
- 根因：全部是 V1-only 或已下架套件；`opencode-dynamic-context-pruning` 在 npm 回 404；`opencode-notifier` 已下架；`opencode-vibeguard` 古老無 V2 版。
- 修復（`npm view` 逐一驗證版本存在後寫入，現役 + root legacy 兩份 `opencode.json` 同步，備份 `*.bak-plugin-fix`）：
  - `opencode-github-copilot-auto-model` → `@opeoginni/opencode-copilot-auto`（1.1.0，V2）
  - `opencode-dynamic-context-pruning` → `@p4r4d0xb0x/opencode-dcp`（4.0.2，V2）
  - `opencode-pty` → `opencode-pty/v2`（0.4.0 有 `./v2` export，`npm view exports` 確認）
  - `opencode-notifier` → `@mohak34/opencode-notifier`（0.8.1）
  - `opencode-vibeguard` → 直接移除（無替代）
- 驗證：
  - 官方 schema 確認 key 只能用單數 `plugin`（無 `plugins`）。
  - `agent list`（正常模式，1.19.0 ephemeral server）：13 agents 全在、`build (primary)`、stdout 零錯誤。
  - 現役 1.18.29 server 熱重載後 log：3 個 scoped 套件 `loading plugin` 成功；`opencode-pty/v2` 在舊 loader 失敗（`NpmInstallFailedError ... unknown git error`——舊 loader 把 `pkg/subpath` 誤判為 github 簡寫去 git clone）。
- **教訓 E9**：舊 1.18.29 loader 不支援 `package/subpath` 寫法；`opencode-pty/v2` 是寫給 1.19.0/v2 Desktop 的正確入口（此判斷後續被 E10 推翻）；plugin 替換後務必看 server log 的 `loading plugin` 行確認，不能只看 CLI stdout（`agent list` 的 stdout 對 plugin 完全靜默）。

### E10：`opencode-pty/v2` 子路徑入口兩個 loader 都不吃，改回裸包名（2026-10-12）
- E9 寫完後實測：1.19.0 ephemeral `run`（Default Project，全域 config）工具清單 59 個全是 `default.*`，無 pty 工具；且 `~/.cache/opencode/npm` 無任何新 pty 安裝目錄——`/v2` 在 1.19.0 上靜默失敗（1.18.29 則是顯性 `NpmInstallFailedError ... unknown git error`， loader 把 `pkg/subpath` 誤判為 github 簡寫去 git clone）。
- 對照實驗（隔離 temp config，一次只掛一個 plugin）：`plugin: ["opencode-pty/v2"]` → 無 pty 工具；`plugin: ["opencode-pty"]` → `default.pty_spawn/read/write/list/kill` 全出現。證明 ephemeral `run` 會載 project config 的 plugin（positive control 成立），問題只在子路徑寫法。
- 結論：兩份 `opencode.json` 的 `opencode-pty/v2` 全部改回裸 `opencode-pty`（0.4.0 root 內含 v1+v2 adapter，loader 可協商；tarball 完整，`./v2`→`dist/src/v2/index.js` 存在，之前是 loader 不支援寫法，不是套件壞）。
- **教訓 E10**：opencode 的 `plugin` 條目只支援裸包名（`name` 或 `@scope/name`），`package/subpath` 在 1.18.29 報 git 錯、在 1.19.0 靜默跳過。驗證 plugin 是否載入的唯一可靠方法是叫 model 列出工具（`run` 請它報 tool 名單），`agent list` stdout 與 ephemeral log 都看不出來。

---

## 待辦 / 風險
- 尚未在 Zen TUI 實測 `build` → `@ui-explorer` 自動路由（需使用者手動驗證；若不自動路由則改用手動 `@ui-explorer` 指名）。
- 未建立專案層級 `res://your-project/.opencode/agents/`（可選，僅用來覆蓋全域設定）。
