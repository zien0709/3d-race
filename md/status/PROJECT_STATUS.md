# 專案現況快照

> 本文件記錄目前 Phase 與已知問題，每次架構或狀態變動時直接覆寫更新，不要新增帶日期的報告檔

## Phase 狀態

**目前 Phase：D**（Lobby 重構進行中）
**更新日期：2026-08-26**

## 已知問題快照

| 問題 | 性質 |
|------|------|
| `HLeaderboards NotFound` | EOS 後端排行榜未建置，非腳本錯誤，忽略即可 |
| `NetworkManager.send_chat_message` | placeholder（只 print），EOS party chat 實際傳輸待做 |
| AuthManager | 已改為 NetworkManager 的薄委託層（271 行），勿再塞重複實作 |
| `md/EXPLORATION_REPORT.md`、`md/multiplayer_plan.md` 等 | 其他 AI 的工作產物，**不要動、不要清** |
| Lobby 非房主可修改設定 | Phase D 修復中：需唯讀 + 進階規則灰化 |
| Ready/Start 邏輯耦合 | Phase D 修復中：需解耦 + auto-start 實作 |

## 參考文件

- `md/status/lobby-system-analysis.md` — 大廳系統詳細分析與 Phase D 任務拆解
- `md/status/eos_status.md` — EOS 整合進度與解決方案註記
- `md/logs/lobby-refactor-log.md` — 大廳重構完整工作日誌（含教訓編號 1-26）