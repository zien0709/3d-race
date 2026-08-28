# 專案現況快照

> 本文件記錄目前 Phase 與已知問題，每次架構或狀態變動時直接覆寫更新，不要新增帶日期的報告檔

## Phase 狀態

**目前 Phase：D**（Lobby 重構進行中）
**更新日期：2026-08-28**

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

## 參考文件

- `md/status/lobby-system-analysis.md` — 大廳系統詳細分析與 Phase D 任務拆解
- `md/status/eos_status.md` — EOS 整合進度與解決方案註記
- `md/domain/track_analysis.md` — 賽道 5 觀察 + 載入鏈路審計（寫死／無解耦／無參數化，Plan A 完成）
- `md/domain/vehicle_model_analysis.md` — 車輛模型結構與整合分析
- `md/logs/lobby-refactor-log.md` — 大廳重構完整工作日誌（含教訓編號 1-26）