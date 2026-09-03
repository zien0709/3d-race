# 專案現況快照

> 本文件記錄目前 Phase 與已知問題，每次架構或狀態變動時直接覆寫更新，不要新增帶日期的報告檔

## Phase 狀態

**目前 Phase：D**（Lobby 重構進行中）
**更新日期：2026-09-02**

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
| FloatingChat 聊天窗 | **已修復**（2026-09-02）：ChatPreview 點擊 → FloatingChat 開啟 + Inspector 隱藏，✕/ESC 關閉 + Inspector 恢復。修正項目：(1) 動畫路徑 LeftContent 前綴、(2) floating_chat.gd open_chat() offset 定位、(3) chat_preview.gd 子節點 mouse_filter=IGNORE |
| ChatPreview 點擊無反應 | **已修復**（2026-09-02）：子節點 HBoxContainer/Label mouse_filter=0 消費事件，改為 MOUSE_FILTER_IGNORE |

## 佈局結構（2026-09-02 確認）

```
Lobby (Control, fullscreen, script: lobby_main.gd)
├── BackgroundGradient (ColorRect)
├── Header (Control, 72px)
├── MainContainer (HBoxContainer)
│   ├── LeftPanel (VBoxContainer, min_width=340)
│   │   ├── LeftContent (VBoxContainer, expand+fill)
│   │   │   ├── Inspector (PanelContainer, 車輛資料)
│   │   │   └── FloatingChat (PanelContainer, 聊天窗)
│   │   ├── ChatTrigger (Button, hidden)
│   │   └── ChatAnimationPlayer
│   └── CenterRightPanel (Control, expand+fill)
│       └── Showcase (PanelContainer, 2×2 車位)
├── FloatingChat ← 不在此處，已移回 LeftContent
├── BottomBar (HBoxContainer, 52px)
│   ├── ChatPreview (💬 膠囊)
│   ├── Spacer
│   ├── QuickPhrases
│   └── ReadyButton
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