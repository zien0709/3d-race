# 房間葉面重構工作日誌（2026-08-24）

## 本輪目標
穩定專案中前次工作階段遺留的壞檔（GDScript 解析錯誤），並為元件化大廳 UI 打好基礎。

## 已完成的修復

### 1. `scripts/auth_manager.gd`（前次 AuthManager 解耦重構的半成品）
修復內容：
- 屬性賦值 `:=` 誤用（`opts.filename := ...` 等）全部改為 `=`
- `var x := null` 推斷錯誤（`_network_manager` / `_player_storage` / `_environment_manager` / `_oauth_server` / `_discord_http`）改為無型別或具型別宣告
- L419 混用空白縮排 → Tab
- C# 泛型語法 `func _get_node<T>(...)` 不存在於 GDScript → 改為普通函式
- 補回被刪掉的函式：`_init_network_signals()`（接 NM 的 eos_initialized/login_succeeded/login_failed/logged_out）、`_init_storage_signals()`、`_init_environment_signals()`、`_on_write_file_data()`、`_on_read_file_data()`、`_login_anonymous()`
- 補宣告缺失訊號：`discord_oauth_started()`、`discord_oauth_completed(code, error)`
- OAuth callback server 原本存到局部變數導致成員永遠 null → 改存成員變數
- state 變數不一致（`_discord_state` vs `_oauth_state`）→ 同步兩者
- storage 區段動態呼叫鏈（`_player_storage.get_class(...)`）的 `:=` 全部改 `=`；`await` 結果與 `.get()` 結果的推斷錯誤同批修正

### 2. `ui/time_trial_start_screen.gd`
- L85 `saved_name := str(...)` 重複宣告 → `=`
- 移除 else 區塊內重複的 `var auth`
- 補回 `_on_start_pressed()`（從 git HEAD 還原：emit start_requested）
- `_set_auth_controls()` / `_set_auth_status()` 原本錯誤呼叫 AuthManager 不存在的方法 → 還原為本地 UI 控制（從 git HEAD 還原）
- 補回 6 個按鈕動畫函式（setup_button_animations 等，從 git HEAD 還原）
- `var cloud := await auth.load_profile()` → `=`

### 3. `ui/lobby_ui.gd`
- 未提交的改寫含 6 個 C-style 三元、大量 `:=` 屬性誤用、型別推斷錯誤
- **決策**：`git checkout --` 還原到最後已知良好版本（commit 0b698ff），因新元件化大廳將取代它

### 4. `network/lobby_manager.gd`（Task1 + Task2）
新增：
- `get_display_name()` / `get_local_player_id()` / `is_online()` / `puid_text()` — UI 查詢輔助
- `max_members` property getter、`lobby_attr(key, default, lobby=null)`、`result_info(lb)`
- `var browser_busy` / `var browser_results` — 大廳瀏覽器狀態
- `update_lobby_settings(room_config)` — host 把房名/地圖/模式/傷害/車輛限制/自動開始寫回 EOS lobby attributes（Task2）
- 新常數 ATTR_MAP/MODE/DAMAGE/CAR_RESTRICTION/AUTO_START

### 5. 新元件化大廳腳本群（`ui/lobby/`）
架構決策：**所有元件腳本自建子節點（self-building）**，場景只需掛空節點＋腳本。
好處：MCP 建場景時只需扁平結構、無深層路徑依賴、無缺失 .tres 問題。
沿用專案既有模式（舊 lobby_ui.gd 即程式化建構）。

元件清單（皆自建 UI）：
| 元件 | 公開 API | 訊號 |
|---|---|---|
| header | update_user_card / update_room_card | room_settings_requested, create_room_requested, leave_room_requested, leave_lobby_requested, browser_requested |
| inspector | update_player(p) | customize_requested |
| showcase | update_slots(players, selected_id) | slot_selected(index, is_self) |
| car_slot | update_player(p, sel) / set_empty() | slot_clicked(is_self) |
| ready_button | set_offline/waiting/ready/host_ready_mode, update_ready_state | pressed |
| chat_trigger | set_chat_open(bool) | chat_toggled(bool) ※勿用 toggled（撞 BaseButton） |
| floating_chat | set_active_tab / add_message / focus_input | tab_changed, message_sent, closed |
| room_overlay | open(config) / get_room_name() / update_chips() | config_changed(row,value), saved, cancelled |
| chip_row | setup(key,text,opts,init) / set_value / get_value | value_changed(row,value) |
| lobby_browser | open/close/set_status/set_results/set_busy/is_busy | search_requested, join_requested(lb), closed |
| customize_view | open/close | back_requested |
| toast | show_message(msg) | - |

已刪除：手寫 .tscn（引用不存在的 .tres、假 uid）、chat_tab.gd（floating_chat 內建分頁）

### 6. `ui/lobby/lobby_main.gd`
- 14 處 `toast.show("...")`（Control.show() 不吃參數）→ 新增 `show_toast(msg)` helper
- `new_name` / `lp` 型別推斷錯誤 → 顯式型別
- `_on_room_overlay_saved` 接上 Task2：host 存設定時呼叫 `lobby_manager.update_lobby_settings(room_config)`
- chat_trigger 訊號改名同步（chat_toggled / set_chat_open）、floating_chat.focus_input()

## 驗證結果
- `project_run` 成功啟動，helper live，game log 無錯誤
- editor log 無解析錯誤（Debugger Errors 分頁已清）

## 待辦（下一輪）
1. ~~用 Godot MCP 編輯器工具重建 `res://ui/lobby.tscn`~~ ✅（見下方 Phase B）
2. Task3：`_refresh_players()` 接真實資料（LeaderboardManager Stats / PlayerStorage）
3. Task4：房間聊天接 P2P
4. 整合測試（開房→搜尋→加入→就緒→開始）

---

## Phase B：MCP 編輯器工具重建大廳場景（2026-08-24 同日完成）

### 場景結構（res://ui/lobby.tscn，root Control「Lobby」掛 lobby_main.gd）
```
Lobby (Control, theme=race_theme.tres, full rect, script=lobby_main.gd)
├─ Header (PanelContainer + header.gd)          offset 12/12/10/116
├─ MainContainer (HBoxContainer)                offset 12/-12/124/-14, sep 12
│  ├─ LeftPanel (VBox, min 320x0, sep 10)
│  │  ├─ Inspector (PanelContainer + inspector.gd, expand V)
│  │  └─ ChatTrigger (Button + chat_trigger.gd, min h48)
│  └─ CenterRightPanel (VBox, expand both, sep 10)
│     ├─ Showcase (PanelContainer + showcase.gd, expand both)
│     └─ ReadyButton (Button + ready_button.gd, min h76)
├─ FloatingChat (PanelContainer + floating_chat.gd) 右下角錨點, 預設隱藏
├─ RoomOverlay (Control + room_overlay.gd)      full rect（_ready 自隱藏）
├─ LobbyBrowser (Control + lobby_browser.gd)    full rect（同上）
├─ CustomizeView (Control + customize_view.gd)  full rect（同上）
└─ Toast (Control + toast.gd)                   y=124 橫條, mouse_filter ignore
```
以單次 `batch_execute`（69 個子指令，原子回滾）建立。

### 建置過程中發現並修復的 bug
| 檔案 | 問題 | 修法 |
|---|---|---|
| header.gd | 多個子節點直接加在 PanelContainer 上互相疊合拉伸 | 包一層 HBoxContainer |
| room_card.gd | ⚙按鈕直接加在自身 → 被拉伸成全卡大小吃掉點擊 | 移進 hbox 尾端 |
| showcase.gd | 兩個車位疊在同一位置 | 包 HBox，雙欄 expand |
| car_slot.gd | 4 個子節點全部疊合 | 包 VBox＋spacer |
| inspector.gd | PanelContainer.new() 掛 HBox 系腳本（StatBar/MatchDots）→ 斷點崩潰 | 改 HBoxContainer.new() |
| lobby_browser.gd | `_make_row` 區域變數 info 與參數撞名 | 刪除無用的重複宣告 |
| lobby_main.gd | @onready 路徑 $CenterRightPanel/... 與場景不符 | 改 $MainContainer/CenterRightPanel/... |
| lobby_main.gd | L319 `x = get_display_name() or ""` — GDScript 的 or 回傳 bool | 改 str(...) |

### 重要教訓
1. **編輯器 stale buffer 覆蓋**：外部（PowerShell/Edit 工具）改完 .gd 後，若直接 `project_run(autosave=true)`，編輯器會把記憶體裡的舊腳本刷回磁碟，覆蓋已提交的修復。對策：外部修改後先 `filesystem_manage(scan)`；跑遊戲一律 `autosave=false`；持久化明確用 `scene_save`。
2. **PanelContainer 會把每個子節點拉伸填滿自身**——自建 UI 元件的根若是 PanelContainer，永遠只放一個 wrapper container。
3. **set_script 型別必須與物件原生類別一致**（HBox 系腳本不能掛在 PanelContainer.new() 上，否則載入即斷點）。
4. **GDScript `or` 回傳 bool**，不是 Python 的「回傳其中一個運算元」。
5. 建場景時 root 的腳本最容易漏掛（batch 裡只有子節點的 attach_script）。
6. 背景（未聚焦）遊戲視窗收不到 input_mouse；互動測試改用 `game_eval` 直接呼叫 handler。

### Phase B 驗證結果
- `project_run(custom: res://ui/lobby.tscn)` 啟動零錯誤、helper live（run_token 22）
- `get_ui_elements` 確認：Header 三區塊並排不重疊、Inspector 完整（車輛資料/ stat rows/近期比賽/前往改裝）、Showcase 雙車位、ReadyButton 預設「▶ 開始計時賽／單人模式 · 進入賽道」
- game_eval 實測互動鏈：chat_toggled(true)→FloatingChat 可見✓、message_sent 不炸✓、browser_requested→LobbyBrowser 開啟✓
- game log 互動期間零 runtime error

## Phase B2：登入系統修復（NetworkManager not set）

### 症狀與根因
使用者手動按下登入按鈕，畫面顯示「NetworkManager not set」。

排查發現前次「AuthManager 解耦重構」是半成品：
1. AuthManager 設計上要求外部呼叫 `set_network_manager()` 注入節點，但**全 repo 無人呼叫**——接線在重構時遺失。
2. 更嚴重：`init_eos()` 重寫了一整份 EOS 初始化（讀 config、組 HCredentials），卻呼叫了**不存在的 API** `_network_manager.setup_eos_async(creds)`——NetworkManager 從來沒有這個方法（它自己內部才有 setup_eos_async 呼叫 HPlatform）。
3. 同檔還殘留一整套與 NetworkManager 重複的 Discord OAuth 機器（TCPServer 輪詢 `_process`、state 檢查、token exchange），以及兩份重複的 `_login_anonymous`/`login_anonymous`。

### 修復策略：委託而非重寫
NetworkManager 已有完整正確的實作（`init_eos`/`login(provider)`/`try_persistent_login` + 四訊號），AuthManager 改為薄委託層：
- 新增 `_ensure_network_manager()` / `_ensure_player_storage()` 惰性解析 `/root/<Name>` autoload（保留 setter 注入 API 相容）
- `init_eos()` → `nm.init_eos()`；`login()` → `nm.login(provider)`；`try_persistent_login()` → `await nm.try_persistent_login()`
- `_on_nm_eos_initialized` 補上 `_is_eos_ready = true` 同步
- 刪除全部重複實作：488 行 → 271 行
- storage 函式（save/load/has_profile、logout 的 delete_persistent_auth）guard 前加 `_ensure_player_storage()`

### 連鎖修復（真實啟動路徑才暴露）
- `auth_manager.gd:94`：`return bool(nm.try_persistent_login())` 少 await → 「Trying to call an async function without await」+ debugger break。**教訓 7：GDScript 協程的回值被消費時必須 await；語句級 fire-and-forget 才可免。**
- `time_trial_start_screen.gd _do_auto_login()`：同樣消費了協程回值 → 改 `if await auth.try_persistent_login():`

### 驗證結果（run_token 26）
- 遊戲日誌：`[HAuth] Logged into Epic Account Services with Epic Account ID: 600d9dc7…`＋`Logged into Epic Games Services with Product User ID: 00021873…`
- game_eval：`eos_ready=true, logged_in=true, uid=0002187333224d279f9aa50517a084d7, scene=res://ui/lobby.tscn`
- **自動登入鏈完整走通**：boot → init_eos(委託NM) → eos_initialized(true) 轉發 → _do_auto_login → persistent login 成功 → 自動切換至大廳場景
- `get_ui_elements`：Header 使用者卡顯示真實 PUID；全版面無重疊
- 本次 run 零腳本錯誤（僅 HLeaderboards NotFound＝EOS 後端排行榜未建置，既有問題與本次無關）

### 教訓補充
8. **解耦重構時先盤點被依賴方的既有 API**——本次重構憑空想像出 `setup_eos_async(creds)` 公開方法，導致呼叫必然失敗。
9. 惰性解析 autoload（`get_node_or_null("/root/X")`）是注入式設計的安全網：保留注入 API、fallback 解析單例，兩者不衝突。

---

## Phase C：房名預設暱稱＋登入自動開房＋搜尋列表本地標記

### 症狀
1. 進大廳後正上方房名預設寫死 "abc's room"。
2. 開房需要手動點擊才會建立並廣播。
3. 搜尋房間列表永遠顯示「Host 的房間 Host . 1/3」，無法辨識哪間是自己剛開的房。

### 根因
1. `lobby_main.gd` 的 `room_config["name"]` 硬編碼字串；`LobbyManager.create_lobby()` 雖有 `%s 的房間 % display_name` fallback，但 UI 層先塞了寫死值蓋掉。
2. 建房只掛在 `_on_create_room_requested()`（按鈕事件），登入成功訊號沒有接開房動作。
3. `lobby_browser.gd` 只顯示 lobby attribute 的 room_name/host_name，未比對 `owner_product_user_id` 與本機 PUID。

### 修復策略
- `room_config["name"]` 改空字串；新增 `_update_default_room_name()` 以 AuthManager.display_name() 填「<暱稱>的房間」（`_refresh_all()` 前也補一次）。
- 新增 `_auto_create_room_if_needed()` / `_do_auto_create_room()`：掛在 `login_succeeded` 與 `eos_initialized(true)` 後，guard：已登入、不在房中、設定彈窗未開 → `await lobby_manager.create_lobby(room_config)`（PublicAdvertised 即廣播）。
- `lobby_browser.set_results()` 對每筆結果加 `info["is_local"] = (lb.owner_product_user_id == 本機 PUID)`；`_make_row()` 為真時前綴「[本地]」。

### 附帶修復
- `ui/lobby_ui.gd:731`（舊版 UI 遺留檔，場景已改用 lobby_main.gd）誤用未宣告的 `lobby_manager` → parse error 阻擋整個專案載入。改用既有 `_lobby()` helper。**此錯誤曾因編輯器 stale buffer 在 project_run 時反覆回報（教訓 1 重現），reload plugin 後消失。**

### 驗證結果
- `project_run(custom: res://ui/lobby.tscn)` 啟動、helper live。
- game log：EOS 登入成功（Product User ID 00021873…），零 parse/runtime error。
- editor log 僅剩既有 shadowing 警告，與本次改動無關。

### 教訓補充
10. **UI 層不要硬編碼業務預設值**——房名這類會被上傳到 EOS attribute 的欄位，預設值應由資料層（LobbyManager/AuthManager）提供或 UI 於登入後填入；寫死在 UI 初始化字典裡會蓋掉下層的合理 fallback。
11. **搜尋列表辨識「自己的房」用 owner_product_user_id 對比本機 PUID**，不要比對 host_name 字串（暱稱可重複、可改）。

---

## Phase C2：修復登入循環卡死與加入房間循環（2026-08-25）

### 症狀（使用者截圖）
1. 每次登入後卡在 `auth_manager.gd:125` → 報錯「Trying to call an async function without await」並在 Debugger 堆疊顯示 11 次重複錯誤，無法進入 Lobby。
2. 修復後仍會卡在「加入房間」循環：已在房間中再次點擊加入，或點擊自己的房間導致無限 busy。

### 根因
1. `scripts/auth_manager.gd` 的 `save_profile / load_profile / has_profile` 在前次重構時被簡化為直接委派 `return _player_storage.save_profile(...)`，但 `PlayerStorage` 的三個方法皆為協程（`await IEOS...callback`），委派端未加 `await`，GDScript 4.3 視為「未等待的協程呼叫」直接報錯並中斷登入流程；上層 `time_trial_start_screen.gd:77` 的 `await auth.load_profile()` 因此永遠拿不到結果，導致登入成功訊號後卡死。
2. `ui/lobby_ui.gd` 的舊版搜尋列表用 `_lobby_attr(lb, \"host_id\")` 判斷本地房，但 EOS HLobby 並無該 attribute，實際應比對 `lb.owner_product_user_id`（如 `lobby_browser.gd` 已正確實作）。舊版永遠判斷為非本地，[本地] 標記失效，使用者誤點自己房間觸發加入自己房間的無效操作。
3. `ui/lobby/lobby_main.gd` 與 `ui/lobby_ui.gd` 的 `_on_join_pressed / _on_lobby_join_requested` 未處理「已在房間中」與「加入自己房間」兩種情況，導致已在房間時再次 join 造成 LobbyManager 狀態混亂與 busy 旗標卡死。

### 修復策略
- `scripts/auth_manager.gd`：三個委派函式改為 `return await _player_storage.xxx(...)`（檔案內含 `await` 即自動成為協程，呼叫端已正確 `await`，符合 Godot 4 協程規則）。
- `ui/lobby_ui.gd`：`_render_browser_list()` 改為優先讀 `lb.owner_product_user_id`，fallback 才讀 `host_id` attribute；同時禁用本地房的「加入」按鈕（顯示「本地」且 disabled）。
- `ui/lobby/lobby_main.gd` 與 `ui/lobby_ui.gd` 的加入處理：先檢查 `owner_product_user_id == get_local_player_id()` → 提示「這是你的房間」直接返回；若 `current_lobby` 非空，先 `await leave_lobby()` 再執行 `join_lobby`，並在失敗時清除 `browser_busy` 與提示「加入失敗」。
- `ui/lobby/components/lobby_browser/lobby_browser.gd`：本地房的加入按鈕改為 disabled 並顯示「本地」，避免誤觸。

### 驗證方式
- `filesystem_manage(scan)` 後單檔 `write_text` 診斷皆為 clean（`diagnostics: []`）。
- `editor logs` 需重新 `logs_clear` 後再掃描；若仍見舊錯誤，需重啟 Godot 編輯器使 stale buffer 失效（教訓 1、教訓 12）。
- `git diff` 確認 `auth_manager.gd` 三處皆含 `await`，`lobby_ui.gd` / `lobby_browser.gd` / `lobby_main.gd` 皆含 `owner_product_user_id` 比對與離開再加入邏輯。

### 教訓補充
12. **委派協程必須透傳 await**——`PlayerStorage.save/load/has_profile` 皆為協程，薄委派層若寫 `return _player_storage.save_profile(...)` 會回傳 `GDScriptFunctionState` 而非 `bool/Dictionary`，呼叫端 `await` 也拿不到正確結果；必須寫 `return await _player_storage.save_profile(...)`。
13. **加入房間前先處理既有房間狀態**——EOS 同一時間只能在一個 Lobby，已在房間時必須先 `leave_async` 再 `join_async`，否則 `join_async` 回傳 null 並使 UI 的 `browser_busy` 永久為 true。
14. **本地房判斷用 owner_product_user_id 而非 attribute**——HLobby 的 owner 是屬性而非 attribute，`get_attribute("host_id")` 永遠取不到；正確做法如 `lobby_browser.gd` 已示範。

---

## Phase D：Lobby 系統 9 項功能重構（2026-08-26 進行中）

### 背景
使用者回報 AI 修改 Lobby 設定介面導致錯誤且未 Commit，需依 9 項詳細需求重構：

1. **非房主唯讀**：非房主點擊設定時為唯讀檢視
2. **即時同步**：非房主開啟設定面板，收到 `lobby_updated` 自動重載配置
3. **準備與開始解耦**：函數模組化與解耦
4. **地圖預設**：新增預設地圖選項
5. **地圖載入解耦**：修正地圖載入跳回登入介面問題
6. **進階規則灰化**：「傷害模式」與「車輛限制」變灰色（禁用但保留介面）
7. **人數介面調整**：依據房間人數限制動態調整介面
8. **開始按鈕真啟動**：開始按鈕可按並真正啟動比賽
9. **開始按鈕邏輯**：非房主 [已準備] 切換、房主 [開始比賽]、支援自動開始

### Phase D1：資料流同步修復（需求 2、5）

#### 症狀
1. 客戶端加入房間後，room_config 停留在預設值，看不到房主設定
2. 地圖屬性同步可能干擾登入狀態，導致跳回登入介面

#### 根因
1. `lobby_manager.gd:_on_lobby_updated()` 只同步 members/peer_order，**遺漏 room_config 同步**
2. `join_lobby()` 中 map sync 時機可能過早，干擾 authentication state

#### 修復策略
- `lobby_manager.gd` 新增 `room_config_updated(room_config: Dictionary)` 信號
- `_on_lobby_updated()` 非房主時從 lobby attributes 同步：map、mode、car_restriction、damage_mode、max_players、auto_start
- 發射 `room_config_updated` 讓 `lobby_main.gd` 更新 UI

#### 驗證結果
- [待驗證] 客戶端加入後 room_config.map 顯示房主選擇的地圖
- [待驗證] room_config.mode、car_restriction、damage_mode、max_players、auto_start 均同步
- [待驗證] 地圖載入不再導致跳回登入介面

#### 關鍵檔案
- `network/lobby_manager.gd` - 新增信號與同步邏輯
- `ui/lobby/lobby_main.gd` - 監聽 `room_config_updated` 呼叫 `_refresh_all()`

### Phase D2：UI 唯讀與進階規則灰化（需求 1、6）

#### 症狀
- 非房主開啟設定面板可修改所有項目，包括進階規則

#### 修復策略
- `room_overlay.gd:open(config, host: bool = false)` 新增 host 參數
- `_on_chip_changed()` 對 `carr`/`dmg` 檢查 `is_host`，非房主跳過
- `_toggle_host_controls()` 實作：carr/dmg chips 禁用、灰色、tooltip 提示「高級規則 - 仅房主開放 (Future feature)」

#### 關鍵檔案
- `ui/lobby/components/room_overlay/room_overlay.gd`

### Phase D3：Ready/Start 解耦與自動開始（需求 3、8、9）

#### 症狀
- `_on_ready_pressed()` 僅 emit `start_requested`，**未切換 ready 狀態**
- Ready 與 Start 邏輯耦合，無法正確處理 host/non-host 差異
- `auto_start` 選項儲存但未處理

#### 修復策略
- `_on_ready_pressed()`：非房主呼叫 `lobby_manager.set_ready()` 切換；房主檢查 `_all_lobby_ready()` 後啟動比賽
- `_on_ready_state_changed()` 增加 `check_auto_start()`：檢查 `room_config.auto_start` 處理「立即開始」或「倒數10秒」
- `start_race()` 獨立函式：僅房主可呼叫，檢查全員準備後 `lobby_manager.start_match()`

#### 關鍵檔案
- `ui/lobby/lobby_main.gd` - 重寫 `_on_ready_pressed()`、新增 `check_auto_start()`、`start_race()`

### Phase D4：動態玩家介面（需求 4、7）

#### 症狀
- `max_players` 預設硬編碼 3，介面不隨人數調整
- 地圖選項只有 3 種，可能需擴充

#### 修復策略
- 移除 `room_config` 硬編碼 `"max_players": 3`
- `room_card.gd` 動態顯示 `%d/%d` 基於 `room_config.max_players`
- 依據 `max_players` 顯示/隱藏額外車位
- `room_overlay.gd CHIP_DEFS` 檢查地圖選項是否需擴充

#### 關鍵檔案
- `ui/lobby/lobby_main.gd` - 移除硬編碼預設
- `ui/lobby/components/header/room_card.gd` - 動態顯示
- `ui/lobby/components/room_overlay/room_overlay.gd` - 地圖選項

### Phase D5：開始按鈕完整邏輯（需求 8、9）

#### 修復策略
- 非房主：按鈕顯示 [已準備]，點擊切換 ready 狀態
- 房主：當 `_all_lobby_ready()` 時顯示 [開始比賽]，點擊啟動
- `auto_start="立即開始"`：全員準備後直接開始
- `auto_start="倒數10秒"`：全員準備後倒數 10 秒自動開始

#### 關鍵檔案
- `ui/lobby/lobby_main.gd` - 完整 _on_ready_pressed、check_auto_start
- `ui/lobby/components/ready_button/ready_button.gd` - 新增倒數顯示模式

### 實作進度

| 任務 | 狀態 | Commit |
|------|------|--------|
| D1: room_config sync + join_lobby decoupling | ✅ 已修改 lobby_manager.gd，待 commit/驗證 | `feat(lobby): room_config sync from attributes` |
| D2: room_overlay host read-only + grayscale | 待實作 | |
| D3: ready/start decouple + auto-start | 待實作 | |
| D4: dynamic player interface + map options | 待實作 | |
| D5: start button complete logic | 待實作 | |

### 教訓補充
15. **lobby_updated 時必須同步 room_config**——非房主加入時無法取得房主設定，導致 UI 顯示預設值而非實際值
16. **join_lobby 解耦 map 載入**——避免在 lobby state 不穩定時處理 map attributes，防止干擾 authentication state
17. **Phase 內部每一步都要 commit**——避免累積大量未提交修改（本次 AI 錯誤的根本原因）
18. **非房主 UI 必須有視覺回饋**——唯讀/禁用狀態需有明確灰化與 tooltip，不能只有邏輯攔截
19. **auto_start 需在 ready_state_changed 觸發**——不能放在 ready_pressed，因為可能是其他玩家準備觸發

---

## Phase E：聊天 RPC + 面板切換（2026-08-26）

### 目標
1. 實作 Godot RPC 聊天：透過 NetworkManager 發送/接收訊息
2. FloatingChat 從右下角懸浮改為取代 Inspector 面板位置

### 修復策略
1. **network_manager.gd**：
   - 新增 `signal chat_message_received(sender, text, tab)`
   - `send_chat_message(message, tab)` 改用 `rpc("remote_chat_message", ...)` 發送
   - 新增 `@rpc("any_peer","call_remote","reliable") func remote_chat_message(...)` 接收端

2. **lobby_main.gd**：
   - `_on_chat_toggled(opened)` 切換時同時控制 `inspector.visible = not opened`
   - `_on_chat_closed()` 恢復 Inspector
   - `_on_chat_message_received()` 接收 NetworkManager 訊號，存入 `chat_messages`
   - `_load_chat_history_for_tab(tab)` 切換分頁時重新顯示歷史訊息
   - `_on_chat_message_sent()` 改指向 NetworkManager（非 AuthManager）

3. **floating_chat.gd**：
   - 新增 `clear_messages()` 清空訊息列表
   - `custom_minimum_size` 從 300×360 縮為 280×200

4. **lobby.tscn**：
   - FloatingChat 從 root `.` 移到 `MainContainer/LeftPanel`
   - 設定 `size_flags_horizontal=3, size_flags_vertical=3`（expand+fill）
   - 調整 Inspector 為 `size_flags_vertical=3`

5. **lobby_ui.gd:782**：`var lm := _lobby()` → `var lm: Variant = _lobby()` 修正 Variant 推斷

### @onready 路徑修正
- `$FloatingChat` → `$MainContainer/LeftPanel/FloatingChat`（移動後路徑失效）

### 驗證結果
- `project_run` 啟動零 parse error
- ChatTrigger 點擊後：Inspector 隱藏、FloatingChat 顯示（320×659）
- 輸入 "hello world" → 訊息 "Player: hello world" 正確顯示
- 再次點擊 ChatTrigger：Inspector 恢復、FloatingChat 隱藏
- lobby_manager.gd:149 的 "Standalone lambdas" parse error 已不存在（僅剩 warnings）

### 教訓補充
20. **節點移動後 @onready 路徑必須同步更新**——scene 中移動 FloatingChat 後，@onready 讀到 null instance，導致 pressed.emit() 時 crash
21. **game_eval 不支援 `:=` 型別推斷**——需用 `var x = value` 或 `var x: Type = value`
22. **RPC 函式名與 signal 不可同名**——signal `chat_message_received` 與 func `chat_message_received` 衝突，func 改名 `remote_chat_message`

---

## Phase F：UI 動畫系統優化（2026-08-26）

### 目標
建立現代化、可複用的 UI 動畫系統，提升使用者體驗（Juice）。

### 實作內容
1. **UIAnimations.gd 自動載入單例** — 13 個可複用動畫輔助函式：
   - 進場/離場：`fade_in/out`、`slide_in/out_from_top`、`slide_in/out_from_right`、`panel_open/close`
   - 互動回饋：`scale_pop`、`scale_press`、`scale_release`、`scale_to`
   - 數值動畫：`animate_progress_bar`
   - 工具：`kill_tweens`（防連點）

2. **元件動畫更新**：
   | 元件 | 動畫 |
   |------|------|
   | Toast | 滑入/出 + 淡入/出 (0.25s/0.3s) |
   | ReadyButton | 懸停 1.02x、按下 0.96x、釋放彈回 |
   | ChipRow | 懸停 1.03x、按下 0.95x、TRANS_BACK 彈回 |
   | ChatTrigger | 懸停/按下 + 開啟脈衝 1.1x |
   | RoomOverlay/LobbyBrowser/CustomizeView | 面板開關：縮放 0.9→1.0 + 淡入/出 |
   | FloatingChat | 分頁顏色漸變 0.15s、訊息右滑入 0.2s |
   | StatBar (Inspector/CustomizeView) | 進度條數值動畫 0.5s (TRANS_QUAD) |
   | Header 按鈕 | 懸停 1.03x、按下 0.95x |
   | CarSlot | 選取邊框色漸變 + 1.02x 彈跳 |
   | RoomOverlay 旁觀切換 | 縮放 + 背景色動畫 |
   | Showcase 空車位 | 懸停 1.02x |

3. **緩動標準化**：
   - 入場：`TRANS_SINE` + `EASE_OUT`（快進慢出，自然）
   - 彈跳：`TRANS_BACK` + `EASE_OUT`（超調回彈，有手感）
   - 進度條：`TRANS_QUAD` + `EASE_IN_OUT`（S 曲線平滑）
   - 離場：`TRANS_SINE` + `EASE_IN`（慢進快出）

4. **防連點保護**：所有互動元件在動畫前呼叫 `kill_tweens()`

### 驗證結果
- `project_run` 零 parse error，helper live
- 所有按鈕懸停/按下有明確視覺回饋
- 面板開關平滑過渡，無瞬間閃爍
- 進度條數值變化平滑動畫
- 聊天訊息右滑入，分頁切換平滑漸變

### 教訓補充
23. **@onready 需顯式型別**——`@onready var x: Type = Autoload`，否則 GDScript 無法推斷 autoload 型別
24. **類別本體不能有可執行陳述式**——如 `_select_button = Button.new()` 必須在 `_ready()` 內
25. **編輯器錯誤快取會誤導**——修正後需 `filesystem_manage(scan)` 或重啟插件才能看到真實狀態
26. **集中式動畫單例優於分散式 Tween**——統一緩動標準、易維護、防衝突
27. **`Node.get_tweens()` 在 Godot 4.7 不存在**——用 Dictionary 自行追蹤活躍 Tween，或用 `SceneTree.get_processed_tweens()` 全域查詢
28. **Lambda 捕獲 Tween 物件會在 kill 後變 null**——不要在 lambda 內 capture tween，改用 Dictionary 清理或 await
29. **`StyleBoxFlat.bg_color` 預設為 null**——必須手動 `sb.bg_color = Color.TRANSPARENT` 後才能 tween，否則 Nil→Color 類型不匹配
30. **`theme_override_colors/font_color` 無法 tween**——theme override 不是真實屬性，用 `add_theme_color_override()` 直接設定
31. **`Tween.TRANS_SINE` 需完整路徑**——GDScript 不支援裸枚舉 `TRANS_SINE`，必須寫 `Tween.TRANS_SINE`

---

## Phase G：Lobby UI 全面動畫優化與佈局修復（2026-08-27）

### 目標
解決所有剩餘的 UI 體驗問題：人數顯示錯誤、卡槽數量/排版錯誤、文字溢出、底部按鈕被切斷、空位視覺混淆、按鈕層級衝突、host 未自動填入 Slot 1、準備按鈕狀態不當。

### 實作內容
1. **UIAnimations.gd 自動載入單例** —— 13 個可複用動畫輔助函數，統一緩動標準
2. **動態網格排版** (`showcase.gd`)：
   - 2 人：1×2 (HBoxContainer)
   - 3 人：1×3 (HBoxContainer)  
   - 4 人：2×2 (GridContainer, columns=2)
   - 移除固定 4 槽、固定 2 列的硬編碼
2. **Host 自動佔用 Slot 1** (`lobby_main.gd`)：
   - `_refresh_players()` 依 `owner_product_user_id` 排序，host 優先
   - `players[0]` 固定為房主，Inspector 自動連結其車輛資料
3. **人數顯示修正** (`room_card.gd`)：
   - 房間內時用 `players.size()` 而非 `lobby_manager.players.size()`
   - 正確顯示 `1/X` 而非 `0/X`
4. **空位視覺語言** (`car_slot.gd`)：
   - 移除彩色 🏎 emoji，改用灰色虛線車輛剪影 + 灰色 "+" 圖示
   - 使用 `_draw()` + `CanvasItem.draw_line()` 繪製虛線剪影
   - 非空位才顯示 emoji + 車名
5. **PUID 截斷與複製** (`user_card.gd`)：
   - 超過 16 字元時顯示 `PUID: 0002...50517`
   - 旁加 📋 複製按鈕，點擊複製完整 ID 並 Toast 提示
6. **Sticky Footer 佈局** (`lobby.tscn`)：
   - `ReadyButton`、`ChatTrigger` 改用 `anchor_bottom=1.0` 固定底部
   - `Showcase`、`Inspector` 填滿剩餘空間，不再推擠底部按鈕
7. **按鈕層級修正** (`header.gd`)：
   - `set_in_room(in_room)`：進入房間隱藏「離開大廳」，顯示「離開房間」
8. **準備按鈕狀態機** (`ready_button.gd`)：
   - `set_waiting_mode(all_ready)`：未全員就緒時灰色禁用樣式
   - 全員就緒時房主見高亮綠色「開始比賽」
9. **Drawing API 修正**：
   - `_draw()` 內直接用 `draw_line()` 等 CanvasItem 方法
   - 移除 `get_canvas_item()` RID 誤用
   - 移除動態建立 CanvasLayer/Control 的錯誤模式

### 驗證結果
- `project_run` 零 parse error，helper live
- 房間人數正確顯示 `1/3`、`2/4` 等
- 3 人房呈 1×3 水平排列，無缺角
- 空位顯示灰色虛線剪影，不再誤導
- 底部按鈕固定螢幕底部，不再被切斷
- 進房時自動隱藏「離開大廳」
- Host 自動佔用 Slot 1，Inspector 同步顯示
- 未全員就緒時 ReadyButton 灰色禁用，全員就緒高亮綠色

### 教訓補充
32. **`get_canvas_item()` 回傳 RID，不可當 Object 傳遞**——`_draw()` 內直接呼叫 `draw_line()` 等 CanvasItem 方法
33. **`_draw()` 不能動態指派**——不可對動態建立的 Control 指派 `_draw`，需在腳本定義 `_draw()` 函式
34. **`draw_line()` 等繪圖方法在 `_draw()` 內直接呼叫**——不需 `gc.draw_line()`，直接 `draw_line()`
35. **型別標註在 GDScript 4.x 需謹慎**——`var x: Type = value` 有時會報錯，改用 `var x = value` 讓類型推斷較保險
36. **`const` 物件實例化後不可再修改**——`var x = Obj.new()` 而非 `const x := Obj.new()` 若後續需修改屬性
37. **動態排版優於硬編碼**——HBoxContainer/GridContainer 組合可輕鬆支援 2/3/4 人房自適應
38. **自動載入單例需顯式型別**——`@onready var x: Type = Autoload`，否則類型推斷失敗

---

## Phase H：Lobby UI 全面重構——規格驅動（2026-08-27 進行中）

### 目標
依據完整 UI 規格重構大廳，涵蓋：頂部導航列（Profile + Room Capsule + Action Buttons）、左側車輛檢視器、中央卡槽網格（2×2 / 不對稱 3 人）、底部操作列（聊天預覽 + 快捷短語 + Ready 按鈕）。

### 規格需求摘要
1. **頂部導航列 64px**：ProfileBox（頭像+等級+PUID+連線）、RoomCapsule（badges+人數+gear）、ActionButtons（邀請+設定+離開）
2. **左側面板**：車輛資料（score/class/rank/best_lap/matches）+ 三維進度條 + 車庫入口
3. **卡槽網格**：4 人=2×2、3 人=上方 1 大欄+下方 2 欄、2 人=1×2；Active Glow Border、皇冠、speech bubble
4. **底部欄**：聊天預覽條、快捷短語（Ready/GG/表情）、Ready 按鈕（房主🚀/隊員✅）
5. **語音 SDK**：需整合，當前用純 UI 佔位降級
6. **等級/ping**：無真實 API，用 mock data 降級

### 缺失 API 降級策略
- 等級 `Lv.1`：硬編碼，待 PlayerDataStorage schema 定義後接入
- 段位 `🥉 青銅 I`：硬編碼，待 leaderboard percentile 計算
- Score/Class：硬編碼，待 EOS Stats 新增
- Ping：`"--ms 🟢"`，待 RPC 往返計時實作
- 語音：純 UI 佔位，待 EOS RTC 或第三方 SDK
- 詳見 `md/status/missing-apis.md`

### 實作步驟（14 步）
1. `md/status/missing-apis.md` — API 設計方案文檔 ✅
2. `md/logs/lobby-refactor-log.md` — Phase H 計畫 + lessons 39-40
3. `ui/lobby.tscn` — 三段式佈局骨架
4. `header.gd` — ProfileBox + RoomCapsule + ActionButtons
5. `user_card.gd` + `room_card.gd` — 合併/刪除
6. `inspector.gd` — 車輛資料 + 車庫入口
7. `car_slot.gd` — Active Glow + 皇冠 + Bubble + 空位
8. `showcase.gd` — 3 人房不對稱排版
9. `quick_phrases.gd` — 快捷短語列
10. `chat_preview.gd` — 聊天預覽條
11. `ready_button.gd` — 房主/隊員按鈕
12. `lobby_main.gd` — 信號整合
13. `room_overlay.gd` — badges 格式對齊
14. 全面驗證

### 實作注意事項
- **Node 路徑異動防護**：Step 3 改寫 .tscn 時，需確保佔位節點名稱與舊 @onready 相容，避免中途 null instance
- **Glow 邊框裁切**：Step 7 的 StyleBoxFlat 外發光需確認父層未勾選 Clip Contents
- **3 人房比例**：Step 8 大卡槽的車輛模型縮放需注意 Aspect Ratio

### 教訓補充
39. **Mock data 降級策略**——缺失 API 時 UI 先用假資料運作，定義清楚的接入點與 fallback 分支，避免阻塞 UI 開發
40. **Node 路徑異動防護**——重寫 .tscn 前先盤點所有 @onready 路徑，確保新結構的葉節點名稱與舊腳本相容，或在同一步驟更新腳本
41. **Plugin reload 清 stale cache**——parse error 重現時，執行 `editor_reload_plugin` 清除 Godot 的腳本緩存，避免 stale cache 誤判
42. **命名衝突遮蔽**——GDScript 中 `var pressed :=` 會遮蔽 Button 的 `pressed` 信號，`var disabled :=` 會遮蔽 Button 的 `disabled` 屬性，導致後續賦值型別錯誤。使用 `style_pressed` / `style_disabled` 前綴避免衝突

### Phase H 完成狀態（2026-08-27）
- Step 1-14 全部完成，Git commits: `7aa4893` `fd8a8c2` `725fc69` `635fc49` `fb7b88e` `c1ebe78` `d071927` `b87aab5` `88dac5f` `77b8c7d` `31403bd`
- 遊戲運行零 errors，所有元件正常渲染

---

## Phase H2：Header 垂直居中與 UI 修復（2026-08-28）

### 目標
修復 Phase H 遺留的 UI 問題：Header 右側按鈕（⚙️ 🔗）垂直裁切、RoomCapsule 資料綁定、背景漸層、邀請按鈕 stub。

### 修復內容
1. **Header 垂直居中**（`header.gd`）：
   - Header 從 `PanelContainer` 改為 `Control`，用 `_draw()` 繪製背景
   - VBoxContainer 包裝 row，`PRESET_FULL_RECT` + `ALIGNMENT_CENTER` 垂直居中
   - **關鍵修復**：row HBoxContainer 加 `size_flags_vertical = SIZE_SHRINK_CENTER`
   - ProfileBox、RoomCapsule、ActionButtons 各加 `size_flags_vertical = SIZE_SHRINK_CENTER`
   - HBoxContainer 不會自動垂直居中子元件——必須用 SIZE_SHRINK_CENTER 讓 row 收縮至內容高度

2. **移除未使用變數**：`_ui_animations` 警告消除

### 教訓補充
43. **HBoxContainer 不垂直居中子元件**——`ALIGNMENT_CENTER` 只控制水平對齊；垂直對齊需子元件設 `SIZE_SHRINK_CENTER`，且 row 本身也要設，讓 VBoxContainer 的 `ALIGNMENT_CENTER` 生效
44. **Control 容器不尊重子元件 size_flags**——只有 Container 父節點才會根據子元件的 size_flags 決定佈局；Control 父節點的子元件必須用 anchors 或手動計算位置

---

## Phase H3：大廳 UI 垂直排版三大問題修復（2026-08-28）

### 目標
修復實機截圖發現的三個垂直排版問題：ActionButtons 裁切、RoomCapsule 擠壓、QuickPhrases 突出。

### 修復內容
1. **ActionButtons 被頂部裁切**（`header.gd`）：
   - Header 最小高度從 64px 增加到 72px
   - 確保按鈕組有足夠空間垂直置中

2. **RoomCapsule 內部標籤與人數往上擠壓破圖**（`header.gd`）：
   - 調整膠囊 StyleBoxFlat 內邊距：top/bottom=10px, left/right=16px
   - 內部 HBoxContainer 改用 SIZE_SHRINK_CENTER 垂直置中
   - 所有 Label 加入 vertical_alignment = VERTICAL_ALIGNMENT_CENTER

3. **BottomBar 的 QuickPhrases 向下突出產生黑底凹陷**（`quick_phrases.gd` + `lobby.tscn`）：
   - QuickPhrases: size_flags_vertical 改為 SIZE_SHRINK_CENTER
   - QuickPhrases: 加入 custom_minimum_size.y = 44
   - QuickPhrases: 加入 alignment = ALIGNMENT_CENTER
   - BottomBar: alignment = 1 (CENTER)
   - ChatPreview/ReadyButton: size_flags_vertical 改為 SIZE_SHRINK_CENTER

### 變更檔案
- `ui/lobby/components/header/header.gd`
- `ui/lobby/components/chat/quick_phrases.gd`
- `ui/lobby.tscn`

### 驗證
- 截圖確認：ActionButtons 完整可見、RoomCapsule 內容對齊、QuickPhrases 不再突出
- 遊戲日誌無 UI 相關錯誤

### 教訓補充
45. **PanelContainer content_margin 需分開設定**——`set_content_margin_all()` 會同時設定四邊，但左右邊距通常需要比上下邊距大，以避免文字貼邊
46. **BoxContainer alignment 控制主軸對齊**——HBoxContainer 的 alignment=1 (CENTER) 會水平置中子元件；VBoxContainer 的 alignment=1 會垂直置中子元件

---

## FloatingChat 修復（2026-09-02）

### 症狀
1. ChatPreview 點擊無反應，FloatingChat 不開啟
2. FloatingChat 位置偏移（y=-380，僅底部 20px 可見）
3. 動畫路徑失效（AnimationPlayer 找不到節點）

### 根因
1. **ChatPreview 子節點 mouse_filter=0（STOP）**：HBoxContainer 和 Label 子節點預設 mouse_filter=0，在父 PanelContainer 之前消費了點擊事件，導致 `gui_input` 信號不觸發
2. **FloatingChat position 殘留**：場景中 position=(16,260) 是舊佈局遺留值，與 open_chat() 的 offset 設定衝突
3. **AnimationPlayer 路徑失效**：FloatingChat 從 LeftPanel 移到 LeftContent 子目錄後，動畫 NodePath 未同步更新
4. **open_chat() 不改 visible**：`chat_open` 動畫只改 modulate.a 和 position，不改 visible 屬性；FloatingChat 從 visible=false 開始，動畫無效

### 修復策略
1. **chat_preview.gd**：HBoxContainer、icon Label、preview Label 加 `mouse_filter = MOUSE_FILTER_IGNORE`，讓點擊事件穿透到 PanelContainer
2. **lobby.tscn**：FloatingChat 動畫路徑加 `LeftContent/` 前綴（`FloatingChat:modulate:a` → `LeftContent/FloatingChat:modulate:a`）
3. **lobby_main.gd**：`_on_chat_toggled` 改用 `floating_chat.open_chat()` / `close_chat()`（不依賴 AnimationPlayer，因為動畫不改 visible）
4. **floating_chat.gd**：`open_chat()` 改為設定 offset_top/bottom/left/right 正確定位，移除舊的 offset 動畫
5. **MCP 修正**：用 `godot-ai_node_set_property` 將 FloatingChat position 重設為 (0,0)

### 驗證結果（game_eval + get_ui_elements）
- ChatPreview 點擊 → FloatingChat visible=true, modulate.a=1.0 ✓
- FloatingChat ✕ → visible=false, Inspector visible=true ✓
- ESC 鍵 → visible=false ✓
- Inspector 車輛資料完整顯示（Score 850, Class S, 大師 I）✓
- 4 車位 GridContainer + SpeechBubble 存在 ✓
- 遊戲零 script errors ✓

### 教訓補充
47. **子節點 mouse_filter=0 會消費父容器的 gui_input**——PanelContainer 的 `gui_input` 信號在子節點有 STOP 時不觸發；需將子節點設為 MOUSE_FILTERIGNORE
48. **AnimationPlayer 動畫不改 visible 屬性**——需在腳本中先設 visible=true 再播放動畫，或改用 open_chat()/close_chat() 內建的 visible 控制
49. **節點移動後所有引用路徑必須同步**——tscn 動畫 NodePath、@onready 引用、game_eval 路徑全部需更新

---

## 三個 Parse Error 修復（2026-09-04）

### 症狀
1. `room_config_panel.gd:131` - `Parse Error: Cannot assign a new value to a constant` — `spectator_check.pressed = config["spectator"]` 撞到 `CheckButton.pressed` 是 const alias
2. `ambient_process_material.tres:13` - `Parse Error: Unexpected identifier 'Gradient'` — Godot 3 內聯 `Gradient { ... }` 語法在 Godot 4 不支援
3. `auth_manager.gd:186 @ _on_nm_login_succeeded()` - `Error calling from signal 'login_succeeded' to callable: 'Control(lobby_main.gd)::_on_auth_succeeded': Method expected 1 argument(s), but called with 2` — signal 簽名不匹配

### 根因
1. **Godot 4 `CheckButton.pressed` 是 const alias** — 唯讀，只能用 `button_pressed = ...` 或 `set_pressed(...)`
2. **Godot 4 `ParticleProcessMaterial.color_ramp` 期待 `GradientTexture1D`** — 必須用 `[sub_resource type="Gradient"]` + `[sub_resource type="GradientTexture1D"]` 兩層 sub_resource
3. **Signal/Handler 簽名不一致** — `AuthManager.login_succeeded(display_name, product_user_id)` 兩參，但 `lobby_main.gd::_on_auth_succeeded` 只接一參；`time_trial_start_screen.gd` 已是正確雙參

### 修復策略
1. `room_config_panel.gd:131` — `spectator_check.pressed = ...` → `spectator_check.button_pressed = ...`
2. `ambient_process_material.tres` — 整檔重寫為 Godot 4 sub_resource 格式（Gradient → GradientTexture1D → color_ramp）
3. `lobby_main.gd:66` + `:154` — call site 與 handler 同步改為雙參 `(_display_name, _product_user_id)`，參數加底線前綴表示 unused

### 驗證結果
- 三個 parse error 均消失
- `godot-ai_project_run` → `status: live`、`helper_live: true`
- `godot-ai_logs_read source=game` → 只有 game_helper 註冊訊息，零 runtime error
- `godot-ai_logs_read source=editor` → error log cursor 停在 10（pre-fix stale entries），無新增 error

### 教訓補充
50. **Godot 4 `Button.pressed` / `CheckButton.pressed` 是 const** — 寫入需用 `button_pressed` 或 `set_pressed()`，直接賦值會 parse error
51. **Resource 內聯 Gradient → sub_resource 兩層** — Godot 4 `GradientTexture1D` 持有 `Gradient`，`.tres` 需展開為三段：Gradient sub_resource → GradientTexture1D sub_resource → resource 引用
52. **Signal handler 簽名必須精確匹配 emit 參數數** — 參數數不符會在 runtime 觸發 "Method expected N argument(s), but called with M"，阻擋登入鏈路；新增 handler 時直接參考同專案既有同類 handler（如 `time_trial_start_screen.gd`）

