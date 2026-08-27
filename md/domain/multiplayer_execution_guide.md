# 無 EOS 多人模式：測試與後續實施指南

> 本文件供後續測試或交由其他 AI 執行時參考，涵蓋從 ENET 本地聯機驗證到 Phase C/D/E 的完整落地步驟。

---

## 1. Phase B2：ENET 本地雙開聯機測試步驟

目標：驗證 `NetworkManager` 的雙模式切換、`player_spawner.gd` 的客戶端權威生成以及 `StartGrid` 格位分配是否正常運作。

### 步驟 1：啟動主機 (Host)
1. 在 Godot 編輯器中打開專案（確保 `network_manager.gd` 中 `transport = Transport.ENET`）。
2. 在程式碼或透過測試按鈕呼叫主機開房：
   ```gdscript
   NetworkManager.host_game()
   ```
3. 確認 Output 視窗無報錯，且 `multiplayer.peer_connected` 準備就緒。

### 步驟 2：啟動客戶端 (Client)
1. 開啟第二個 Godot 實例（或打包後執行第二個視窗）。
2. 呼叫加入遊戲：
   ```gdscript
   NetworkManager.join_game("127.0.0.1", 24565)
   ```
3. 確認雙方 `peer_connected` 訊號觸發，且 `player_spawner.gd` 成功在 `StartGrid` 的對應格位 (`slot 0` 與 `slot 1`) 生成車輛。

### 步驟 3：驗證物理與同步
- 主機與客戶端各自操控自己的車輛（`is_local_player = true`）。
- 遠端車輛應被凍結或只進行位置插值（`is_local_player = false`，不執行本地物理模擬）。

---

## 2. Phase C：檢查點與賽事流程同步步驟

目標：將單人計時賽邏輯改造為多人競速同步。

### 步驟 C1：檢查點多人群組與回報
1. 修改 `res://race/check_point_1.gd`：
   - 檢查進場車輛是否屬於 `player_car` group。
   - 透過 RPC 將檢查點通過事件回報給 Host（peer 1）：
     ```gdscript
     race_manager.report_checkpoint.rpc_id(1, peer_id, checkpoint_index)
     ```
2. 在 `race_manager.gd` 中新增 `report_checkpoint` 接收端，並更新 `race_ranking.update_car()` 與進度。

### 步驟 C2：倒數與比賽開始狀態機
1. 將 `race_manager.gd` 的 `waiting_for_player`、`race_started` 改由 Host 控制。
2. Host 透過 RPC 廣播倒數開始，所有客戶端同步進入倒數與起跑狀態。

### 步驟 C3：衝線與最終結算
1. 客戶端偵測到 Finish 區後，透過 RPC 回報衝線時間至 Host。
2. Host 收集所有完賽時間，排序後廣播最終名次畫面（`show_final_results`）。

### Phase C 實作狀態（已完成 2026-08-25）

採客戶端權威（client authority）模型，Host 為名次權威來源。

**C1 檢查點同步**
- `check_point_1.gd`：改為判斷 `player_car` group + `get_multiplayer_authority() == 本地 id`，僅車主回報；單機走 `register_checkpoint`，多人同時本地推進（供衝線驗證）與 `report_checkpoint.rpc_id(1, ...)` 回報 Host。
- `race_manager.gd`：新增 `@rpc report_checkpoint(peer_id, idx)`，Host 驗證 `next_index+1 == idx` 後 `advance_car` 並 `emit_changed`。
- `player.gd`：`_ready()` 加入 `add_to_group("player_car")`。

**C2 倒數與狀態機**
- `_is_host = multiplayer.is_server() or (not has_multiplayer_peer())`（單機本機即 host）。
- Host 獨佔執行 `update_start_countdown` 與 `race_time` 計時；透過 `start_race_sync` / `race_started_sync` / `set_countdown_sync` RPC 廣播給所有 client，client 不跑本地倒數。

**C3 衝線與結算**
- `finish.gd`：同步改用 `player_car` group + authority 判斷（取代 `body.name == "Player"`）。
- `finish_race()`：單機直接 `show_results`；多人由 Host 統一結算。Client 經 `report_finish.rpc_id(1, ...)` 回報，Host 收齊所有 `_connected_peers`（含斷線自動移除）後 `broadcast_final_results()`。
- 名次權威：client 每 0.15s 經 `report_progress.rpc_id(1, ...)` 回報世界座標，Host `update_car` 後 `apply_ranking_sync` 廣播 `get_ordered()` 給所有 client 即時刷新 `RankPanel`。
- `show_final_results_sync(ordered)` → `time_trial_finish_screen.show_results_multiplayer(ordered)` 顯示完整排名與自己名次。
- 玩家顯示名稱經 `report_player_name.rpc_id(1, ...)` 由 client 回報 Host（修正 Host 端名次名稱為通用名稱的問題）。

**已知限制 / 待辦**
- ✅ Phase B1 已完成：`player.tscn` 已加 `MultiplayerSynchronizer`（root_path=".."，同步 `transform`，sync_mode=ALWAYS）。遠端車輛現可經 client-authority 視覺複製；`player_spawner.gd` 的 `set_multiplayer_authority(peer_id)` 即為其複製來源。
- ✅ 聊天 RPC 已完成（見 Phase D 第 4 點）：`NetworkManager` 的 `send_chat_message` / `remote_chat_message` RPC 已實作，支援 room / team / global 三種 tab 頻道，由 `lobby_main.gd` 路由與顯示。
- 完賽名次同為 `total+1` 時為平手（未依完賽時間細分），必要時可於 `mark_finished` 帶入 `finish_time` 做二級排序。

---

## 待辦（以後做）：Godot 內雙開 ENET 驗證

> 使用者於 2026-08-25 指示：此項先記錄，之後再實作驗證。

目標：在 Godot 編輯器內啟動兩個實例，驗證 Phase A–C 的 ENET 本地聯機是否端到端可玩。

1. `network_manager.gd` 確認 `transport = Transport.ENET`。
2. 實例 A 呼叫 `NetworkManager.host_game()` 開房；實例 B 呼叫 `NetworkManager.join_game("127.0.0.1", 24565)` 加入。
3. 確認雙方車輛經 `player_spawner.gd` 生成、`MultiplayerSynchronizer`（Phase B1）視覺複製正常。
4. 驗證檢查點回報、倒數同步、衝線後 Host 廣播最終名次畫面。
5. 回報任何解析/執行期錯誤至此文件的 Phase C 章節或新建 issue 記錄。

---

## 3. Phase D：大廳自動建立與準備系統

目標：完善大廳流程，支援自動建房與全員準備發車。

1. **自動建房**：在 `lobby_ui.gd` / `lobby_main.gd` 初始化完成且偵測到已登入 EOS 時，若無當前房間，自動呼叫 `create_lobby(room_config)` 以 EOS `display_name` 作為預設房名。（**已完成**，見 `lobby_main.gd:_auto_create_room_if_needed`）
2. **準備系統**：擴充 `set_ready.rpc`，讓各客戶端點擊 Ready 後通知 Host，Host 端收集 ready map，當全員就緒後解鎖房主的「開始比賽」按鈕。（**已完成**，見 `lobby_manager.gd` + `lobby_ui.gd`）
3. **比賽啟動整合**：`match_started` 觸發換場至 `main.tscn` 後，自動生成遠端車輛並啟動多人計時賽。（**已完成**，見 `race_course_setup.gd:_init_multiplayer_race`、`player.gd` authority-based `is_local_player`、移除 `player_spawner.gd` 硬編碼 `is_local_player`）

4. **聊天 RPC 系統**（**已完成**）：
   - `network_manager.gd` 提供 `send_chat_message(message, tab)` 與 `remote_chat_message(sender, text, tab)`，均使用 `@rpc("any_peer", "call_remote", "reliable")` 保證送達。
   - 訊號 `chat_message_received(sender, text, tab)` 於收到遠端訊息時觸發。
   - Tab 系統支援三種頻道：`"room"`（房間內）、`"team"`（隊伍）、`"global"`（全域）。
   - 流程：`lobby_main.gd` 呼叫 `NetworkManager.send_chat_message()` → RPC 傳送 → 對端 `remote_chat_message()` 接收後 `emit` `chat_message_received` → `lobby_main.gd._on_chat_message_received()` 存入聊天紀錄並更新 UI 顯示。

---

## 4. Phase E：切換回 EOS 傳輸層（正式上線）

**已完成**（2026-08-25）：
1. `network_manager.gd`：`var transport: int = Transport.EOS`（預設 EOS，開發時可用 `set_transport(Transport.ENET)` 切回本機測試）
2. 大廳 UI 的建立/加入按鈕已接回 `LobbyManager.create_lobby()` / `LobbyManager.join_lobby()`（內部呼叫 `NetworkManager.host_game/join_game` 自動依 `transport` 選擇 EOSGMultiplayerPeer）
3. 新增 `NetworkManager.set_transport()` 供開發期切換測試

**待驗證**：需在 `res://eos_config.cfg` 填入有效 EOS 憑證（product_id / sandbox_id / deployment_id / client_id / client_secret / encryption_key）並測試 P2P 聯機、好友邀請與 EOS 雲端存檔。
