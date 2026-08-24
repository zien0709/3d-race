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
