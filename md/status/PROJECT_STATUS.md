# 專案現況快照

> 本文件記錄目前 Phase 與已知問題，每次架構或狀態變動時直接覆寫更新，不要新增帶日期的報告檔

## Phase 狀態

**目前 Phase：D**（Lobby 重構進行中）
**更新日期：2026-09-10**

## 已知問題快照

| 問題 | 性質 |
|------|------|
| `HLeaderboards NotFound` | EOS 後端排行榜未建置，非腳本錯誤，忽略即可 |
| `NetworkManager.send_chat_message` | placeholder（只 print），EOS party chat 實際傳輸待做 |
| AuthManager | 已改為 NetworkManager 的薄委託層（271 行），勿再塞重複實作 |
| `md/EXPLORATION_REPORT.md`、`md/multiplayer_plan.md` 等 | 其他 AI 的工作產物，**不要動、不要清** |
| Lobby 非房主可修改設定 | Phase D 修復中：需唯讀 + 進階規則灰化 |
| Ready/Start 邏輯耦合 | Phase D 修復中：需解耦 + auto-start 實作 |
| Lobby UI 垂直排版問題 | **已修復**（commit `f3656fe`）：ActionButtons 裁切、RoomCapsule 擠壓、QuickPhrases 突出 |
| 賽道寫死／無護欄／Roadbed面數未量化 | Plan A 完成（見 `md/domain/track_analysis.md` §1）；**B1 解耦完成**（commit `20961fe`）：`TrackConfig`+`tracks/default.tres`+`race_course_setup.gd`/`start_grid.gd` 改吃 cfg；**B2 解耦完成**：`TrackRegistry` Autoload（`race/track_registry.gd`，無 class_name）+ `race_course_setup.gd` 改吃 `TrackRegistry.get_selected_track()`、`lobby_manager.gd` 同步 `map`→`TrackRegistry`，見 `md/logs/track-decoupling-log.md` |
| FloatingChat 聊天窗 | **已退役**（2026-09-10，見下一行 Dock＋Panel 遷移） |
| 聊天雙輸入框（Dock＋Panel 遷移） | **已修復**（2026-09-10）：退役 FloatingChat／ChatPreview／QuickPhrases；BottomBar 換 ChatDock（💬預覽＋4 晶片＋▲），Lobby 根新增 ChatPanel bottom-sheet（4 tabs＋搜尋＋emoji＋reaction＋私訊）；lobby_main 重接線＋4 參接收＋ChatData 主存；快捷短語重複 echo 一併刪除。game_eval 6/6 實測通過，game log 零 error |
| 聊天抽屜化（左欄 28% 滑展） | **已修復**（2026-09-10）：ChatPanel 改抽屜錨點（anchor_right=0.28，底部吸附 BottomBar 上方 -68）；開關改 offset_top -68↔-420 Tween（TRANS_CUBIC 0.25s）；面板層隱藏短語條；送出鈕→➤。get_ui_elements 6/6 通過，車位＋開始鈕零遮擋 |
| 氣泡蓋車／房名遺失／抽屜越界 | **已修復**（2026-09-10）：氣泡改 top_level 浮層＋卡內頂緣定位（VBox 不動）；房名空字串回退＋仿粗；抽屜頂 -360、輸入 14px、送出鈕 48×36。實機截圖逐鈕驗收通過 |
| ChatPreview 點擊無反應 | **已修復**（2026-09-02）：子節點 HBoxContainer/Label mouse_filter=0 消費事件，改為 MOUSE_FILTER_IGNORE |
| `room_config_panel.gd:131` Parse Error | **已修復**（2026-09-04）：`spectator_check.pressed` → `button_pressed`（Godot 4 pressed 為 const） |
| `ambient_process_material.tres` Parse Error | **已修復**（2026-09-04）：Godot 3 內聯 Gradient → Godot 4 sub_resource (Gradient + GradientTexture1D) |
| `lobby_main.gd` signal 簽名不匹配 | **已修復**（2026-09-04）：`_on_auth_succeeded` 改為雙參 `(_display_name, _product_user_id)`，對齊 `AuthManager.login_succeeded` |

## 佈局結構（2026-09-02 確認）

```
Lobby (Control, fullscreen, script: lobby_main.gd)
├── BackgroundGradient (ColorRect)
├── Header (Control, 72px)
├── MainContainer (HBoxContainer)
│   ├── LeftPanel (VBoxContainer, min_width=340)
│   │   ├── LeftContent (VBoxContainer, expand+fill)
│   │   │   └── Inspector (PanelContainer, 車輛資料)
│   │   ├── ChatTrigger (Button, hidden, 已去接線，節點保留)
│   │   └── ChatAnimationPlayer
│   └── CenterRightPanel (Control, expand+fill)
│       └── Showcase (PanelContainer, 2×2 車位)
├── BottomBar (HBoxContainer, 52px)
│   ├── ChatDock (💬 預覽＋4 快捷晶片＋▲)
│   └── ReadyButton
├── ChatPanel (PanelContainer 左欄抽屜 28% 寬，收合隱藏，Dock 觸發向上滑展 -68↔-420)
├── RoomOverlay (全屏彈窗)
├── LobbyBrowser (全屏彈窗)
├── CustomizeView (全屏彈窗)
└── Toast (頂部通知)
```

## 參考文件

- `md/status/lobby-system-analysis.md` — 大廳系統詳細分析與 Phase D 任務拆解
- `md/status/eos_status.md` — EOS 整合進度與解決方案註記
- `md/domain/track_analysis.md` — 賽道 5 觀察 + 載入鏈路審計（寫死／無解耦／無參數化，Plan A 完成）
- `md/domain/vehicle_model_analysis.md` — 車輛模型結構與整合分析
- `md/logs/lobby-refactor-log.md` — 大廳重構完整工作日誌（含教訓編號 1-26）
- `md/domain/multiplayer_match_start_design.md` — 開局 MatchConfig 載體設計（方案 C：LobbyManager.match_config 組裝，race 場景一次讀走）
- `md/status/chat-redesign-notebook.md` — 聊天系統重構工作筆記（含 FloatingChat 修復計畫與驗證紀錄）
- `md/status/CHAT_INTERFACE_DESIGN.md` — 聊天介面完整設計規格書 v2.0（Dock＋Panel 雙模式，2026-09-10 據此遷移完成）
- `.omo/plans/lobby-chat-dock-panel.md` — 本次遷移的 decision-complete 計畫（含 QA 證據鏈）
- `md/logs/lobby-refactor-log.md` — Phase I 聊天遷移＋Phase I2 抽屜化紀錄（教訓 53–57）
- `md/status/CHAT_INTERFACE_DESIGN.md` — 聊天介面完整設計規格書 v2.0（Dock＋Panel 雙模式，2026-09-10 據此遷移完成）
- `.omo/plans/lobby-chat-dock-panel.md` — 本次遷移的 decision-complete 計畫（含 QA 證據鏈）
- `md/logs/lobby-refactor-log.md` — Phase I 聊天遷移紀錄（教訓 53–55）

## 環境/代理現況（2026-10-12，非遊戲邏輯，僅供開工參考）
- OpenCode：npm CLI 1.19.0（`run`/`agent list` 用）+ v2 Desktop 2.0.26；舊 1.18.29 server（:4096）為升級前殘留，重启後退役。
- 13 agents 全數驗證可運作（`build`=primary，12 subagents；model 皆為 `opencode/*-free` 實測可用）。詳見 `md/logs/env-setup-log.md` E4–E9。
- 已知：`oh-my-openagent` plugin 已移除（它覆寫 `build`→subagent，見教訓 78）；`plugin` 陣列現為 4 個 V2 套件，全數實測載入（`pty_spawn/read/write/list/kill` 工具已在 1.19.0 上線；`package/subpath` 寫法兩代 loader 皆不支援，見教訓 79／E10）。
- 本 session 跑在舊 server 上，`build` 的新 model 只對新 session 生效。
---

## GitHub repo 轉移完成 (2026-11-17)
- `Z11430373/3d-race` → `zien0709/3d-race`，已接受並落地（136 commits、v1.04/v1.05）
- `zien0709/3d-race-legacy`：舊 8/03 版保留（4 stars，v1.0.1 / v1.0.2 / v1.03）
- 本機 `D:\Github\3d-race`：remote 已整理為單一 `origin` = `zien0709/3d-race`，upstream = `origin/main`；8 個未推 commit 已推送（`91c36fe..6a50814`）
- 13 個未 commit 修改（main.tscn、ui/lobby/*、md/logs/*、md/status/*）保持原樣
- `AGENTS.md` remote 表已修正；`AI_WORKFLOW.md §3` 仍為舊寫法，待更新
- wild-magic-brawl fork 已刪除，備份在 `D:\Github\_transfer-backups\wild-magic-brawl-fork.git`
- Rocket_Soccer Pages 已修好（https://zien0709.github.io/Rocket_Soccer/ → 200）
- 2 個測試空殼 repo（zz-transfer-probe*）已刪除

