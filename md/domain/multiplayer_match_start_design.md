# 開局 MatchConfig 載體設計（Multiplayer Match-Start Payload）

> 建立日期：2026-08-28
> 狀態：**設計草稿**（方案 C 已決定；剩餘待決項目見 §6）
> 關聯：`md/domain/track_analysis.md`（賽道解耦 B1/B2）、`md/multiplayer_plan.md`（多人同步架構）、`network/lobby_manager.gd`、`race_course_setup.gd`、`player.gd`
> 約束：本文件僅記錄設計與現況盤點，**不實作任何程式碼**。

---

## 1. 背景

房間 host 按下「開始」時，比賽場景（`main.tscn` / `race_course_setup.gd`）需要一次性取得「這場比賽是什麼樣子」的完整資訊：誰參加、每人資料、房間特殊設定、每人選的車、哪個地圖、哪種模式……

目前的實作把這些資訊散落在三處（信號參數、`LobbyManager` 成員、EOS lobby attribute），比賽場景要東拼西湊，且大部分設定根本沒被賽事邏輯消費。本設計在 Start 當下組成一包 `MatchConfig`，讓比賽場景一次讀走。

---

## 2. 現況盤點（只讀程式碼確認，2026-08-28）

### 2.1 Start 觸發鏈

- `network/lobby_manager.gd::start_match()`（**僅 host**）：
  - 組 `peer_order: Array[int]`（`_build_peer_order()`，對 `players` 的 `peer_id` 排序）
  - 寫 EOS lobby attribute `ATTR_PEER_ORDER = JSON.stringify(peer_order)` → `update_async()`
  - emit `match_started(peer_order)`
- client 路徑：`_on_lobby_updated()` 讀到 `ATTR_PEER_ORDER` → 也 emit `match_started(order)`
- UI 端：`ui/lobby_ui.gd::_on_match_started(_order)` → `get_tree().change_scene_to_file("res://main.tscn")`
  - ⚠️ `_order` 參數**被忽略**，`change_scene_to_file` 不轉傳任何資料 → 比賽場景必須自己從 autoload 讀

### 2.2 跨場景「現在」實際帶得走的資料

| 來源 | 內容 | 比賽場景能否讀到 |
|------|------|------------------|
| `match_started` 信號參數 | `peer_order: Array[int]` | 被 UI 忽略，需改從 autoload 讀 |
| `LobbyManager.players[]` | `{peer_id, product_user_id, name, ready}` | ✅ autoload 跨場景保留 |
| EOS lobby attribute `ATTR_MAP` | 中文 map 名（東京灣夜景…） | ✅ 經 `lobby_manager` → `TrackRegistry.select_track_by_ui_name()` 同步（B2 已接），race 讀 `TrackRegistry.get_selected_track()` |
| EOS lobby attribute `ATTR_MODE` | 經典競速/淘汰賽/計時挑戰 | ⚠️ 寫入但未消費 |
| EOS lobby attribute `ATTR_DAMAGE` | damage_mode | ⚠️ 寫入但未消費 |
| EOS lobby attribute `ATTR_CAR_RESTRICTION` | 全開放/僅S級/僅A級 | ⚠️ 寫入但未消費（僅房間規則） |
| EOS lobby attribute `ATTR_AUTO_START` / `ATTR_ROOM_NAME` / `ATTR_MAX_PLAYERS` | 各種房設 | 部分用於大廳 UI，race 未讀 |

### 2.3 比賽場景現狀

`race_course_setup.gd::_ready()`：
- `_apply_track_config()` 讀 `TrackRegistry.get_selected_track()`（✅ 地圖已接）
- `_configure_player()` 用 `StartGrid.get_single_player_slot()` → **只做單人**生成
- 完全**沒有**讀 `peer_order` / `players` / `mode` / `car` 來生成多人車

`player.gd`：
- `add_to_group("player_car")`
- 車型來自場景節點 `ConceptCar` / `AE86_2`（`player.gd:369`），**不是**由「每人選的車」決定

> 備註：`md/domain/multiplayer_execution_guide.md` 提到 `race_course_setup.gd:_init_multiplayer_race` 負責遠端車輛生成，但**目前檔案內不存在此函式**——多人車輛生成點可能已被重構，實作前需先確認（見 §6.4）。

---

## 3. 缺口分析（你提的項目逐條對照）

| 項目 | 現狀 | 缺口 |
|------|------|------|
| 玩家數 | `peer_order.size()` / `players.size()` | ✅ OK |
| 每位玩家資料 | `peer_id` / `PUID` / `name` / `ready` | 缺 `car_id`（見下） |
| 房間特殊設定 | `mode`/`damage_mode`/`car_restriction`/`auto_start`/`name`/`max` 都寫進 attribute | `mode`/`damage`/`car_restriction` 沒被賽事邏輯讀取（假選項） |
| 每位玩家的車 | **不存在** | 無「每人選車」機制；只有房間級 `car_restriction` 規則；場景車寫死 |
| 哪個地圖 | TrackRegistry 已接（B2） | ✅ OK（目前全解析 `default`） |
| 地圖模式 | `mode` attribute 有 | `RaceManager` 沒讀 → 淘汰賽/計時挑戰不生效 |

> 單人端已有 `car_id` 概念：`ui/time_trial_finish_screen.gd:69` 用 `ordered[i].get("car_id", -1)` 排序結果——說明「每人有車」在 time-trial 端存在，但**多人 lobby 端沒有對應的選車 / 同步 attribute**。

---

## 4. 決定方案：C — `LobbyManager.match_config` 載體

**不**擴充 `TrackRegistry`（職責混淆：track ≠ match 規則）；**不**新增獨立 Autoload。直接在現有 `LobbyManager` autoload 上掛一個 `match_config` 欄位：

- host 在 `start_match()` 組裝 `match_config` 並 assign
- client 在 `_on_lobby_updated()` 偵測到 `ATTR_PEER_ORDER` 後，同樣從 attributes + `players` 組裝 `match_config`
- `LobbyManager` 是 autoload，`change_scene_to_file` 不會銷毀它 → 比賽場景 `race_course_setup.gd._ready()` 直接 `LobbyManager.match_config` 一次讀走

### 4.1 建議的 `MatchConfig` 結構

```gdscript
# 概念結構（Dictionary 或日後抽 MatchConfig Resource）
{
  "track_id": StringName,        # 來自 TrackRegistry（map → track_id）
  "mode": String,                # 經典競速 / 淘汰賽 / 計時挑戰
  "damage_mode": String,         # 房設 damage_mode
  "car_restriction": String,     # 全開放 / 僅S級 / 僅A級
  "auto_start": bool,
  "room_name": String,
  "max_players": int,
  "host_peer_id": int,
  "peer_order": Array[int],      # 開場順序
  "players": [                   # 每人一筆
    {
      "peer_id": int,
      "puid": String,
      "name": String,
      "is_host": bool,
      "car_id": String,          # 新增欄位（見 §6.2）
      "ready": bool
    }
  ]
}
```

### 4.2 組裝時機（規劃，不實作）

- `start_match()`（host）：在 emit `match_started` 前，先 `match_config = _build_match_config(peer_order)` 並 assign 到 `LobbyManager.match_config`
- `_on_lobby_updated()`（client）：偵測 `ATTR_PEER_ORDER` 存在時，`match_config = _build_match_config(order)` assign
- `players[].car_id`：由 `_sync_members()` 時從每位 member 的 `ATTR_CAR` attribute 填入（需新增，見 §6.2）

---

## 5. 比賽場景消費點（規劃，不實作）

`race_course_setup.gd._ready()` 現有 `_apply_track_config()` 已讀 TrackRegistry；擴充為讀 `LobbyManager.match_config`：

- `track_id` / 地圖 → 已由 TrackRegistry 處理（保持）
- `peer_order` + `players` → 驅動多人車輛生成（取代目前單人 `_configure_player`）
- `mode` / `damage_mode` / `car_restriction` → 傳給 `RaceManager` 做賽制分支與傷害/車輛限制
- `players[].car_id` → 每位玩家生成對應車型場景

> 注意：`_init_multiplayer_race` 目前不存在（見 §2.3 備註），多人生成邏輯落點需先確認。

---

## 6. 待決定 / 開放問題

方案 C 已定。以下仍未決，實作前需與使用者確認：

1. **（已決）載體 = `LobbyManager.match_config`** ✅
2. **每人選車是否本輪就做？** 要做需：
   - 新增 `ATTR_CAR` member attribute（寫入/讀取）
   - Lobby UI 選車並寫入 member attribute
   - `_sync_members()` 把 `car_id` 帶進 `players[]`
   - race spawner 按 `car_id` 換車場景
   - 若暫不做：先保留 `car_id` 欄位、預設同一台車
3. **`mode` / `damage` 是否本輪就實作「消費邏輯」？** 還是只先組好 MatchConfig 並傳遞，賽制分支（淘汰賽/計時挑戰）與傷害應用之後再做？
4. **多人車輛生成現狀確認**：`race_course_setup.gd` 目前只有單人 `_configure_player`，舊文件提到的 `_init_multiplayer_race` 已不存在。實作前先確認 spawner 現在接在哪（避免重複造輪子）。

---

## 7. 相關文件

- `md/domain/track_analysis.md` — 賽道解耦 B1/B2，含 `TrackRegistry` / `TrackConfig` API（§5）
- `md/multiplayer_plan.md` — 多人同步架構（§2.2 賽道同步已補 TrackRegistry 說明）
- `md/status/PROJECT_STATUS.md` — 現況快照
- `network/lobby_manager.gd` — `start_match` / `_on_lobby_updated` / `update_lobby_settings` / `players`
- `race_course_setup.gd` — 比賽場景 `_ready` 入口
- `player.gd` — 車輛群組 / 車型節點
