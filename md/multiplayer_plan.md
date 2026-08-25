# 無 EOS 多人模式建置規劃（傳輸層可切換架構）

> 核心策略：**先不弄 EOS**，用 Godot 原生 `ENetMultiplayerPeer`（IP 直連）把多人架構全部驗證通，
> 之後把傳輸層換成 `EOSGMultiplayerPeer`，**遊戲邏輯層零改動**。

---

## 0. 架構總覽：傳輸層抽象

Godot 的 `MultiplayerAPI` 是**傳輸無關**的。`ENetMultiplayerPeer` 和 `EOSGMultiplayerPeer`
都是 `MultiplayerPeer` 的子類，上層的 RPC / MultiplayerSynchronizer / MultiplayerSpawner
完全不知道底層用的是誰。

```
┌────────────────────────────────────────────┐
│ 遊戲邏輯層（與傳輸傳輸層無關，寫一次就好）        │
│  ├ player.gd          車輛物理 + 同步宣告    │
│  ├ race_manager.gd    比賽流程狀態機         │
│  ├ race_ranking.gd    即時名次 + 最終結算    │
│  ├ check_point_1.gd   檢查點偵測            │
│  └ player_spawner.gd  遠端車生成            │
├────────────────────────────────────────────┤
│ MultiplayerAPI（傳輸無關）                   │
│  multiplayer.multiplayer_peer = ?           │
│  RPC / Synchronizer / Spawner 都吃這個介面   │
├──────────────────┬─────────────────────────┤
│ ENetMultiplayer  │ EOSGMultiplayerPeer     │
│ Peer（開發期）    │ （正式版）               │
│ IP:Port 直連     │ Epic P2P + Lobby 搜房    │
│ localhost 測試   │ NAT 穿透 / 好友邀請      │
└──────────────────┴─────────────────────────┘
```

唯一需要雙模式的只有 `NetworkManager.host_game() / join_game()` 兩個函數，
用 `Transport` 列舉切換。其餘所有程式碼只依賴 `multiplayer` 單例。

---

## 1. 既有佔位碼盤點（重要發現）

專案裡已經埋好多人模式的設計意圖，方向是 **客戶端權威（client authority）**：

| 檔案 | 現況 | 設計意圖 |
|------|------|----------|
| `race/player_spawner.gd` | 佔位完成 | `spawn_function` 已掛；生成遠端車、`is_local_player=false`、**`set_multiplayer_authority(peer_id)`** — 每輛車由它的主人模擬 |
| `race/start_grid.gd` | 完成 | 12 格出發位（3排×4台）、`assign_slots(peer_ids)` 按連線順序分配 |
| `race/race_ranking.gd` | 完成（單機用） | 註解明載：「每台車由各自 client 回報位置，host 用這份邏輯統一排序」— car_id 已參數化，可直接複用 |
| `player.gd` | 就緒 | `is_local_player` 旗標已有：非本地車 `_physics_process` 直接 return（不施加任何力），攝影機自動關閉 |

**結論**：不需要推翻任何東西，是在既有軌道上鋪路。

### 為什麼客戶端權威適合這款遊戲
- 每台車主人本地跑完整物理 → **零輸入延遲**，手感與單機完全一致
- `VehicleBody3D` 物理不用拆成「輸入模擬 / 狀態重放」兩套
- 朋友間聯機無作弊疑慮；日後要防作弊再升級 host 權威即可
- 缺點（可接受）：碰撞判定以被撞方的本地模擬為準，高速擦撞可能輕微不一致

---

## 2. 各系統同步規劃

### 2.1 車輛物理同步（核心）

**方向**：每輛車的 authority = 車主的 peer_id。

```
車主客戶端                          其他所有端
┌─────────────────┐               ┌──────────────────┐
│ 完整物理模擬      │  Transform3D │ 提線木偶模式       │
│ (現有邏輯不動)    │ ──────────►  │ freeze 物理        │
│ _physics_process │  + velocity  │ 只收狀態做插值顯示  │
│ 讀 Input         │  + gear/rpm  │ 不讀 Input         │
└─────────────────┘  每網路幀一次   └──────────────────┘
```

**同步內容**（MultiplayerSynchronizer 屬性清單）：

| 屬性 | 類型 | 必要性 |
|------|------|--------|
| `transform` | Transform3D | 必要（位置+旋轉一次打包） |
| `linear_velocity` | Vector3 | 必要（插值外推用） |
| `steering` | float | 建議（前輪視覺轉向） |
| `current_gear` | int | 建議（儀表板顯示） |
| `engine_rpm` | float | 建議（儀表板顯示） |

**關鍵細節 — 遠端車必須凍結物理**：
`VehicleBody3D` 在遠端也會跑引擎積分（重力、懸吊），會跟同步進來的 transform 打架。
遠端車（`get_multiplayer_authority() != multiplayer.get_unique_id()`）要：
- `freeze = true`（或 `process_mode = PROCESS_MODE_DISABLED`）
- 純靠 Synchronizer 收值 + `physics_interpolation` 平滑顯示

車主端在 `_enter_tree()` 就設好 authority（spawner 生成時已帶入 peer_id，
`_enter_tree` 比 `_ready` 早，確保 Synchronizer 初始化前 authority 正確）。

### 2.2 賽道同步

**靜態賽道不需要同步**。所有人載入同一份 `main.tscn`，RaceMap 一模一樣。
只需保證：
- 場景載入完成後 spawner 才開始 spawn（`MultiplayerSpawner` 天生如此）
- Host 先進場、Client 後進場時，Host 端既有玩家會透過 spawner 自動補生成給新來的

### 2.3 檢查點同步

現況問題：`check_point_1.gd` 寫死 `body.name != "Player"` 就 return，
多人下每輛車都叫 `Player_<peer_id>`，全部會被擋掉。

改法：
```gdscript
# check_point_1.gd 改造方向
func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player_car"):   # player.gd _ready 加 group
        return
    var peer_id := body.get_multiplayer_authority()
    # 只有「這台車的主人」回報，避免重複觸發
    if peer_id != multiplayer.get_unique_id():
        return
    race_manager.report_checkpoint.rpc_id(1, peer_id, checkpoint_index)
```

- 車主客戶端偵測 → RPC 回報 host（peer 1）
- Host 驗證順序（`checkpoint_index == next_checkpoint[peer_id]`）後廣播
- `race_manager.register_checkpoint()` 參數化 `car_id`（現在硬編 `ranking.advance_car(1)`）

### 2.4 結算方式

**每人獨立計時 + Host 統一結算**：

```
1. Host 發起倒數（RPC 廣播 countdown_start，含 server_time 對齊）
2. GO! 後各端本地 race_time += delta（各自計時，精確到毫秒夠用）
3. 衝線：該車主人的客戶端偵測 finish Area3D
   → rpc_id(1, report_finish(peer_id, race_time))
4. Host 收集 {peer_id: finish_time}，全員到齊（或超時 30s）後：
   → 按時間排序 = 最終名次
   → rpc 廣播 show_final_results(sorted_results) 給所有人
5. 未完賽者按 RaceRanking 進度排序墊後
```

- 本地最佳紀錄（`user://race_scores.cfg`）保留，多人成績另外顯示
- `leaderboard_ui.submit_public(race_time)`（EOS 排行榜）**留著不改**，
  只是多人模式下照樣提交自己的成績，EOS 未接好前它自己會靜默失敗，不影響流程

### 2.5 比賽流程狀態機

```
WAITING ──start_match──► COUNTDOWN ──3-2-1-GO──► RACING ──全員衝線/超時──► FINISHED
                            ▲                                        │
                            └────────── restart_match ◄──────────────┘
```

- 狀態轉換**只有 Host 能觸發**，透過 RPC 廣播
- `race_manager.gd` 現有的單人變數（`waiting_for_player`, `race_started`,
  `race_finished`, `countdown_time`）全部保留，只是改為由 RPC 驅動而非本地輸入驅動
- 單人模式 = 狀態機跑在同一台上，行為不變（向下相容）

### 2.6 大廳簡化版（ENET 階段）

EOS 大廳（HLobbies 搜房）**先整組跳過**，用最土的方式：

```
Host 端：                      Client 端：
[輸入房間名]                    [輸入 IP]
[建立遊戲] ──► host_game()     [加入遊戲] ──► join_game(ip)
   │                              │
   ▼                              ▼
等待畫面（玩家列表即時更新）◄── peer_connected/disconnected
   │
全員 [準備] → Host [開始比賽] → 所有人 load main.tscn → spawner 生效
```

- 玩家列表直接吃 `multiplayer.peer_connected` / `peer_disconnected`
- 準備狀態先用一個簡單的 `set_ready.rpc()`（host 存 Dictionary），**不用** EOS member attribute
- 名字用 `peer_connected` 時 handshake RPC 互報（之後 EOS 版改成 product_user_id 對應）

---

## 3. NetworkManager 雙模式改造（唯一的 EOS 邊界）

```gdscript
enum Transport { ENET, EOS }

## 開發階段預設 ENET；EOS 架構接好後改 EOS 或由設定檔決定
@export var transport: Transport = Transport.ENET

func host_game(port := 24565) -> int:
    match transport:
        Transport.ENET:
            var peer := ENetMultiplayerPeer.new()
            var err := peer.create_server(port, MAX_PLAYERS)
            if err != OK: return err
            _attach_peer(peer)
        Transport.EOS:
            # ↓ 現有 EOSGMultiplayerPeer 邏輯原封不動搬進來
            if not is_logged_in: return ERR_UNAUTHORIZED
            var peer = ClassDB.instantiate("EOSGMultiplayerPeer")
            var err: int = peer.create_server(EOS_SOCKET_ID)
            if err != OK: return err
            peer.set_auto_accept_connection_requests(true)
            _attach_peer(peer)
    set_mode(Mode.HOST)
    return OK

func join_game(target := "127.0.0.1", port := 24565) -> int:
    match transport:
        Transport.ENET:
            var peer := ENetMultiplayerPeer.new()
            var err := peer.create_client(target, port)   # target = IP
            if err != OK: return err
            _attach_peer(peer)
        Transport.EOS:
            # target = host 的 product_user_id，現有邏輯原封不動
            ...
    set_mode(Mode.CLIENT)
    return OK
```

- EOS 初始化 / 各種登入 / Discord OAuth 全部**保留現狀**，一行都不刪
- ENET 模式跳過登入：`is_online()` 改看 `mode != SINGLEPLAYER`（已經是），
  大廳 UI 的「請先登入」檢查在 ENET 模式下放行並使用本地暱稱
- `LobbyManager` 整支**不動**，ENET 階段大廳 UI 直接呼叫 NetworkManager；
  切 EOS 時把 UI 接回 LobbyManager 即可

---

## 4. 實施順序與 Commit 劃分

每一步都是可編譯、可測試、可回滾的獨立 commit。

### Phase A — 傳輸層雙模式
| Commit | 內容 | 驗收 |
|--------|------|------|
| A1 | `NetworkManager` 加 `Transport` 列舉 + ENET 版 `host_game/join_game`（EOS 分支保留原樣） | 雙開實例：host(24565) + client(127.0.0.1) 可互連，`peer_connected` 觸發 |
| A2 | 大廳加最小測試入口（IP 輸入框 + 建立/加入按鈕，繞過 EOS 登入檢查） | 兩台可互連進等待畫面 |

### Phase B — 玩家生成與車輛同步
| Commit | 內容 | 驗收 |
|--------|------|------|
| B1 | `player.tscn` 掛 `MultiplayerSynchronizer`（transform/velocity/gear/rpm）；`player.gd` 加 `_enter_tree` authority 設定 + `player_car` group | — |
| B2 | 遠端車凍結物理（`freeze=true` 分支）；Spawner 補 `spawn_path=/Main/Players` 與 spawnable scene | 雙開：互相看得到對方車子在跑，位置平滑 |
| B3 | 出發格位接入：host 按 `assign_slots` 分配，spawn data 帶 slot index | 兩台車停在不同格位 |

### Phase C — 檢查點與比賽流程
| Commit | 內容 | 驗收 |
|--------|------|------|
| C1 | `check_point_1.gd` 多人化（group 判斷 + 車主回報 RPC）；`register_checkpoint(car_id)` | 雙方各自過檢查點，RankPanel 顯示兩台車 |
| C2 | `race_manager` 狀態機 RPC 化（countdown/race_started 由 host 廣播驅動） | host 按開始後，兩端同時倒數同時 GO |
| C3 | 衝線結算：`report_finish` RPC + host 收集排序 + `show_final_results` 廣播 | 兩台先後衝線，兩端正確顯示相同名次 |

### Phase D — 大廳整合
| Commit | 內容 | 驗收 |
|--------|------|------|
| D1 | 準備系統（`set_ready.rpc` + host 端 ready map + ReadyButton 接線） | 全員準備後 host 的開始鈕才亮 |
| D2 | match_started → 載入 main.tscn → spawner 啟動；離開/斷線清理（車子消失、回到大廳） | 完整流程：建房→加入→準備→比賽→結算→回大廳 |

### Phase E — 切換 EOS（架構驗證後）
| Commit | 內容 |
|--------|------|
| E1 | `transport = EOS`；大廳接回 `LobbyManager.create_lobby/join_lobby`（現有 UI 幾乎不用改） |
| E2 | peer↔product_user_id 對應補齊（`get_peer_user_id` 已有）、名字改從 lobby attribute 取 |

---

## 5. 技術風險與對策

| 風險 | 對策 |
|------|------|
| 遠端車物理打架（引擎積分覆蓋同步值） | B2 的 `freeze=true` 是硬需求，不是優化項 |
| 高速下同步間隔造成視覺抖動 | Synchronizer 開 physics interpolation；同步率 ≥20Hz |
| 碰撞不一致（雙方各算各的） | 接受（客戶端權威固有）；牆壁等靜態體一致所以體感差異小 |
| Client 中途加入正在跑的比賽 | 第一版禁止：racing 狀態中拒絕 spawn，等下一場（D2 一併處理） |
| Host 離場 = 房間關閉 | 第一版接受（EOS 版有 host migration 再說） |
| 單人模式回歸測試 | 每個 Phase 完成都要跑一次單機計時賽確認沒弄壞 |

---

## 6. 明確不做的事（本輪範圍外）

- ❌ 不移除任何 EOS 程式碼（init_eos / login 系列 / Discord OAuth / LobbyManager / LeaderboardManager 全保留）
- ❌ 不做輸入預測回滾（client authority 用不到）
- ❌ 不做 host migration / 斷線重連
- ❌ 不做專用伺服器（listen server 模式即可）

---

## 7. 本次聯機大廳細部修正備忘錄

### 7.1 房間名称同步问题
**现象**：玩家通过大厅 UI 修改房间名称（`room_overlay.gd` 或 `lobby_ui.gd`），局部 `room_config["name"]` 更新，但未同步到 EOS 大厅 attribute，其他玩家看不到变更。

**根因**：
- `ui/lobby_ui.gd:_on_save_overlay()`（line 726-732）仅写入局部 `room_config`，未调用 `lobby_manager.update_lobby_settings(room_config)`。
- 虽然 `ui/lobby/lobby_main.gd:_on_room_overlay_saved()`（line 256-264）已正确调用 `update_lobby_settings`，但另一入口（`lobby_ui.gd` 直接保存）遗漏了此步骤。

**修正**：
在 `ui/lobby_ui.gd:_on_save_overlay()` 中添加 EOS 同步调用（已在前文修正）。同样地，确保所有房间配置变更均经由 `lobby_manager.update_lobby_settings` 或直接 `lobby.add_attribute(ATTR_ROOM_NAME, ...)` 后再 `await lobby.update_async()`。

### 7.2 默认房间名称来源
**机制**：`network/lobby_manager.gd:create_lobby()`（line 108）的默认名称规则：
```
room_name = str(room_config.get("name", "%s 的房間" % _nm().display_name))
```
- 若 `room_config` 有 `name` 键则使用之；否则使用 `display_name`（来自 EOS login）拼接 "的房間"。
- **重要**：玩家必须先完成 EOS login（`init_eos()` → `login()`）才能取得 `_nm().display_name`；若未登录，`display_name` 可能为空，此时名称会退回字面字串 `" %s 的房間" % ""` 即 `" 的房間"`，建议在 UI 层予以提醒或设定 fallback `"abc's room"`。

### 7.3 已修复之文件列表
- `ui/lobby_ui.gd:_on_save_overlay()` - 同步房间名称到 EOS
- `ui/lobby/lobby_main.gd:_on_room_overlay_saved()` - 已有正确同步（供参考）
- `network/lobby_manager.gd:create_lobby()` - 已使用 display_name 作为默认名称

---
