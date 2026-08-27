# 缺失 API 設計方案（Missing APIs Design Spec）

> 本文件記錄 Lobby UI 重構（Phase H）所需的尚未實作 API，供後續 AI 接入。
> 所有方案均含 mock data 降級策略，接入前 UI 先用假資料運作。

---

## 1. 等級系統（Level / Rank Tier）

### 現狀
- `LeaderboardManager` 僅追踪 `race_time_ms`（單一 stat）
- 無等級（Level）、段位（Rank Tier）、經驗值（EXP）系統
- Lobby UI 的 `Lv.45 🏆 黃金 II` 為硬編碼 mock data

### 建議方案：PlayerDataStorage 自建等級

#### Profile Schema 建議（存入 `profile.json`）

```json
{
  "display_name": "Z",
  "level": 1,
  "exp": 0,
  "exp_to_next": 100,
  "rank_tier": "bronze",
  "rank_division": 1,
  "total_races": 0,
  "wins": 0,
  "best_lap_ms": null,
  "selected_car": "concept_car",
  "last_updated": "2026-08-27T00:00:00Z"
}
```

#### 等級計算邏輯

```
exp_per_race = base(10) + position_bonus(position) + streak_bonus(consecutive_wins)
level_up_threshold = level * 100 + 50  # Lv.1=150, Lv.2=250, Lv.3=350...
```

#### 段位映射（基於 leaderboard rank 百分比）

| 百分比 | 段位 | emoji |
|--------|------|-------|
| Top 1% | 鑽石 III | 💎 |
| Top 5% | 鑽石 I | 💎 |
| Top 10% | 黃金 III | 🏆 |
| Top 25% | 黃金 I | 🏆 |
| Top 50% | 白銀 III | 🥈 |
| Top 75% | 白銀 I | 🥈 |
| Bottom 25% | 青銅 III | 🥉 |
| Bottom 50% | 青銅 I | 🥉 |

#### API 設計

```gdscript
# leaderboard_manager.gd 新增
func get_my_percentile() -> float:
    # 回傳 0.0~1.0，1.0 = top 1%
    # 用 my_rank / total_players 計算

func get_rank_tier(percentile: float) -> Dictionary:
    # 回傳 {tier: "gold", division: 2, label: "🏆 黃金 II", emoji: "🏆"}
```

```gdscript
# player_storage.gd 新增
func update_profile_level(exp_gained: int) -> void:
    # 載入 profile → 加 exp → 檢查 level up → 存回

func get_level_display() -> String:
    # 回傳 "Lv.45"
```

### 降級策略（Mock Data）
- 等級：硬編碼 `"Lv.1"`
- 段位：硬編碼 `"🥉 青銅 I"`
- 經驗值：不顯示進度條

---

## 2. Ping / 連線延遲

### 現狀
- 完全不存在：無測量、無 UI、無 EOS API 使用
- EOS GDScript wrapper (`hp2p.gd`) 僅暴露 NAT type 和 packet queue info
- 底層 C++ `EOSGMultiplayerPeer` 可能有 internal RTT，但未暴露給 GDScript

### 建議方案 A：RPC 往返計時（推薦）

#### 原理
Client → Host 發送 ping request → Host 回覆 ping response → Client 計算 RTT

#### 實作

```gdscript
# network_manager.gd 新增
var _ping_start: float = 0.0
var _last_ping_ms: int = 0
var _ping_timer: Timer

func _ready() -> void:
    _ping_timer = Timer.new()
    _ping_timer.wait_time = 2.0  # 每 2 秒 ping 一次
    _ping_timer.timeout.connect(_send_ping)
    add_child(_ping_timer)

func start_ping() -> void:
    if mode == MODE.HOST or mode == MODE.CLIENT:
        _ping_timer.start()

func stop_ping() -> void:
    _ping_timer.stop()

func _send_ping() -> void:
    _ping_start = Time.get_ticks_msec()
    rpc("_rpc_ping_response", _ping_start)

remote func _rpc_ping_response(sent_time: float) -> void:
    if mode == MODE.HOST:
        # Host 回覆
        rpc_id(sender_peer_id, "_rpc_ping_response", sent_time)
    elif mode == MODE.CLIENT:
        # Client 收到回覆，計算 RTT
        _last_ping_ms = int(Time.get_ticks_msec() - sent_time)

func get_ping_ms() -> int:
    return _last_ping_ms
```

#### 信號

```gdscript
signal ping_updated(ping_ms: int)
```

### 建議方案 B：EOS Metrics（備選）

- EOS 有 `Metrics` 模組但 GDScript wrapper 未暴露
- 需要擴展 `eos.gd` 加入 `EOS_Metrics_CopyPlayerMetricByUserId`
- 較複雜，不推薦初期使用

### 降級策略（Mock Data）
- 顯示 `"📶 --ms 🟢"`（綠色圓點假裝在線）
- 不顯示真實 ping 數值

---

## 3. 語音 SDK 整合

### 現狀
- EOS 有 `EOS.RTC` 模組（Real-Time Communication），但 GDScript wrapper 未暴露
- `eos.gd` line 139：`# RTC disabled` — 明確標記為停用
- 無任何語音相關程式碼

### 建議方案

#### 方案 A：EOS RTC（與現有 SDK 整合）

```
需要：
1. 在 Epic Developer Portal 開啟 RTC 權限
2. 擴展 eos.gd 加入 EOS_RTC 模組
3. 實作房間內語音頻道（每位玩家一個音頻流）
4. UI：麥克風開關 + 音量控制
```

#### 方案 B：第三方語音 SDK（更靈活）

```
選項：
- Agora SDK（免費額度 10,000 分鐘/月）
- Vivox（Unity 整合佳，Godot 需自行 bridging）
- Discord Voice SDK（已有 Discord OAuth 整合）
```

#### 方案 C：純 UI 佔位（當前降級）

```
- 按鈕顯示 "🎙️ 語音"
- 點擊切換 mute/unmute 圖示
- 不連接真實語音
- 顯示 "語音功能即將推出" toast
```

### 降級策略
- 純 UI 佔位，按鈕可點但無實際功能
- Toast 提示「語音功能即將推出」

---

## 4. 車輛評分系統（Score / Class）

### 現狀
- Inspector 顯示 `SCORE: 1200`, `CLASS: A`, `排名: 10th`
- 全部為 mock data，無 EOS stat 支援

### 建議方案

#### Stats 新增（EOS Stats）

```
需在 Epic Developer Portal 新增 stat：
- race_wins: int (Min aggregation)
- race_completions: int (Sum aggregation)
- total_race_time_ms: int (Sum aggregation)
```

#### Score 計算

```
score = (wins * 100) + (completions * 10) + (top3_finishes * 50)
class = score_to_class(score)
```

#### Class 映射

| Score 區間 | Class |
|-----------|-------|
| 5000+ | S |
| 3000-4999 | A |
| 1500-2999 | B |
| 500-1499 | C |
| 0-499 | D |

### 降級策略
- Score：硬編碼 `1200`
- Class：硬編碼 `"A"`
- Rank：硬編碼 `"10th"`
- Best lap：硬編碼 `"1:30.123"`
- Matches：5 個隨機 dot

---

## 5. 近期勝負記錄

### 現狀
- Inspector 底部 5 dots 顯示近期比賽結果
- 無真實資料來源

### 建議方案

#### PlayerDataStorage 新增

```json
{
  "recent_results": [true, false, true, true, false]
}
```

#### 更新時機
- 每場比賽結束後，由 `RaceManager.finishRace()` 觸發
- 推入新結果，保留最近 5 筆

### 降級策略
- 5 個隨機 boolean dot

---

## 6. 好友系統整合

### 現狀
- EOS `HFriends` 模組已載入但未使用
- 無好友列表 UI

### 建議方案

```
1. 使用 HFriends.get_friends_list_async() 取得好友
2. 在 "邀請好友" 側欄顯示好友列表
3. 點擊好友 → 發送邀請 RPC → 對方收到邀請 toast
```

### 降級策略
- 側欄顯示「好友列表功能即將推出」

---

## 接入優先順序

| 優先 | 項目 | 預估工時 | 備註 |
|------|------|---------|------|
| 1 | 等級系統 (Step 1) | 2-3h | 用 PlayerDataStorage，最獨立 |
| 2 | Ping 機制 (Step 2) | 1-2h | RPC 往返計時，簡單有效 |
| 3 | 車輛評分 (Step 3) | 2-3h | 需在 Portal 新增 stats |
| 4 | 近期勝負 (Step 4) | 0.5h | 存 JSON array，最簡單 |
| 5 | 好友系統 (Step 5) | 3-4h | 需要 UI 側欄 |
| 6 | 語音 SDK (Step 6) | 5-10h | 最複雜，可最後做 |

---

## 相關檔案

| 檔案 | 角色 |
|------|------|
| `network/leaderboard_manager.gd` | 現有排行榜 API，需擴展 |
| `network/player_storage.gd` | 雲端 profile 存取，需定義 schema |
| `network/network_manager.gd` | 網路層，需加入 ping RPC |
| `addons/epic-online-services-godot/heos/hstats.gd` | EOS Stats 低階 API |
| `addons/epic-online-services-godot/heos/hleaderboards.gd` | EOS Leaderboards 低階 API |
| `addons/epic-online-services-godot/heos/hfriends.gd` | EOS Friends API（未使用） |
| `addons/epic-online-services-godot/eos.gd` | EOS 完整 API 定義（含 RTC） |
