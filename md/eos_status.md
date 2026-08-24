# EOS 多人連線進度與解決方案註記

## 目標
將 EOS 多人連線接入 3D 賽車遊戲：`NetworkManager` 與 `LobbyManager` 實作。
支援 Epic Account Services (登入) + Lobbies (12 人房)，並以 `EOSGMultiplayerPeer` 作為傳輸層，且維持單人模式不受影響。

---

## 登入失敗原因分析與【正確觀念澄清】

經過針對 EOS SDK 機制與 Epic Developer Portal 配置的深入分析，以下為先前測試失敗的真正原因及澄清：

### 1. Anonymous (DeviceID) 登入回報 `EOS_AccessDenied`
*   **【誤區澄清】**：官方文件與實際機制表明，**Device ID 匿名登入完全可以在 Dev/Stage 等任何私有沙盒 (Sandbox) 中使用**，不限於 Live 沙盒。
*   **【正確觀念修正（2026-08-20，依官方 Client Policy Reference）】**：
	*   Client Policy 的 **User Required 必須保持勾選**。官方指引：「Select the **User required** checkbox, **unless the client is a trusted server**」。遊戲客戶端（含 anonymous Device ID、account_portal）都屬於非受信任客戶端，必須勾選。
	*   **「Connect」服務開關是專用伺服器（Trusted Server）用的**，對應 `queryExternalAccountsForAnyUser` / `queryProductUsersForAnyUser` 等「For Any User」權限（官方標註 Requires a trusted server）。**遊戲客戶端不要開 Connect 開關**，否則與 User Required 衝突（也會是資安風險：「Never ship a client ID tied to a trusted server policy with a public game build」）。
	*   Anonymous 登入真正需要的是：保持 **User Required 勾選** + 在 Policy 中勾選 **Player Data Storage（PDS）** 權限（`access`/`delete`/`copy`，官方標註 Requires an authenticated player）。不需要另外找 `authenticate`/`createDeviceId` 開關。
	*   *先前把 AccessDenied 歸因於「未勾選 Connect」的紀錄是錯的，已以此修正取代。*

### 2. DevAuthTool 登入回報 `EOS_InvalidRequest`
*   **【真正原因】**：DevAuthTool（`devtool` 模式）本質上是透過 Epic 帳號登入（Epic Account Services, 簡稱 EAS）。如果未將您的 Client 綁定到 EAS，或兩端設定的 Scope 權限不吻合，Epic 伺服器就會拒絕該請求，返回 `EOS_InvalidRequest`。
*   **【解決方案】**：必須在 Dev Portal 的 **Epic Account Services** 頁面，將您的 Client ID 進行關聯，並勾選對應的 Scopes。

---

## Epic Developer Portal 解決步驟指引

請依照以下兩個部分的步驟，在 [Epic Developer Portal](https://dev.epicgames.com/portal/) 中進行設定調整：

### 第一部分：修正 Client Policy 權限（遊戲客戶端：anonymous / account_portal / PDS）

> ⚠️ 注意：以下針對**遊戲客戶端**的 Client Policy。**「Connect」服務開關請勿開啟**——那是專用伺服器（TrustedServer）查詢玩家資料用的，會與 User Required 衝突。

1.  登入 **Epic Developer Portal**。
2.  進入您的 Product，在左側選單點擊 **Product Settings** (產品設定)。
3.  切換到上方的 **Clients** (用戶端) 標籤。
4.  在您目前使用的 Client 右側，查看它所使用的 **Client Policy** 名稱。點擊 **Manage Policies** (管理策略) 或直接點擊 Policy 名稱進行編輯。
5.  在 Policy 編輯頁面中：
	*   **確認「User Required」為勾選狀態**（遊戲客戶端必須勾選；只有專用伺服器才取消）。
	*   下拉到 **Features** (功能權限) 列表，勾選需要的服務：
		*   **Player Data Storage（雲端暱稱/存檔必備）**：勾選 `access`（上傳/下載自己的私有檔案）、需要時加 `delete`/`copy`。
		*   **Lobby 服務 (開房必備)**：勾選 `createLobby`、`joinLobby`、`updateLobby`、`connect`（Lobby RTC）。
		*   **P2P 服務 (傳輸連線)**：勾選 `createSession`/`joinSession` 等（或該 policy 類型預設已含）。
		*   **Stats / Leaderboards（排行榜）**：勾選對應權限。
		*   **請勿**勾選 Connect 服務下的 `queryExternalAccountsForAnyUser` / `queryProductUsersForAnyUser`（Trusted Server 限定）。
6.  儲存 Policy 設定。
7.  **驗證**：在 `eos_config.cfg` 中將 `method` 改為 `"anonymous"`，啟動遊戲點擊登入。Device ID 匿名登入應能成功（PDS 也可測）。

---

### 第二部分：配置 Epic Account Services 關聯（解決 `devtool` 與 `account_portal` 登入）

1.  在左側導覽列中，點擊 **Epic Account Services** (EAS)。
2.  若尚未配置 Application，請點擊 **Configure** 建立一個新的測試用 Application（「品牌設定 / Brand Settings」填寫本地測試資訊即可，暫不需提交給 Epic 審查）。
3.  進入該 Application 設定：
	*   **Permissions (權限) 標籤**：
		*   在權限列表中，務必勾選並啟用 **Basic Profile**、**Friends** 與 **Presence**。
		*   *原因*：GDScript 程式端代碼中預設請求了 `BasicProfile | Presence | FriendsList` 三個 Scopes，如果 EAS portal 中沒有一致啟用，登入即會回報錯誤。
		*   ⚠️ **必須「剛好」這三項，不能多開**：EOS 不支援增量 scope，後端設定的 scopes 必須與 SDK 請求的完全一致。多開 `Country`/`Email` 或漏開任一項，登入都會回報 `EOS_AuthScopeNotFound`(1016)（「requested consent 不存在於後端」）。
		*   *實例（2026-08-20）*：EAS Application 誤多開了 **Country** scope，導致 Account Portal 登入回報 `AuthScopeNotFound`；在 Permissions 關閉 Country、僅保留 Basic Profile / Friends / Presence 後即排除。
	*   **Clients (用戶端) 標籤**：
		*   點擊 **Associate Client** (關聯用戶端)。
		*   選擇您的用戶端 `TestP2P`，將其綁定到此 EAS 應用程式中。**（此步驟不可遺漏，是 InvalidRequest 的主要根源）**。
4.  **確保測試帳號權限**：
	*   在 EAS 審查通過前，只有您的 Epic 組織成員（Organization Members）能進行登入授權。
	*   請確認您在 DevAuthTool 中登入的 Epic 帳號（Z 所對應的帳號），已被邀請並加入到您的 Epic 組織成員中，且接受了邀請信。

---

## 程式碼優化

為了解決原先 UI 上「點擊一次初始化，必須再點擊第二次才能登入」的 UX 問題，我們已將 `res://ui/eos_login_button.gd` 優化：
*   **調整後**：玩家點擊「登入」時，若 EOS 尚未初始化，會顯示「登入中...」並在背景自動完成 `init_eos()`。初始化成功後，**程式會自動直接觸發登入流程**，玩家僅需點擊一次，即可一步到位完成連線。

## PlayerDataStorage（雲端暱稱）實作註記（B1-B4）

> 需求：註冊後將暱稱上傳到 EOS PlayerDataStorage；帳號本質仍是外部 provider（Epic/Discord），但要連結到使用者的 EOS 並自動建立 PUID。

### 重要觀念（勿再踩坑）
* **PUID 是插件自動建立的**：`HAuth.login_game_services_async()` 在 Connect 登入回傳 `InvalidUser` 時，會自動呼叫 `_create_user_async()` 建立 PUID（`hauth.gd:539`）。**不需要自己實作 create_user**。
* **PlayerDataStorage 不需要特殊 Platform flag**：插件 `PlatformFlags`（eos.gd:741）沒有 `EnablePlayerDataStorage` 是正常的。只要 `CreateOptions.encryption_key`（eos_config.cfg `[eos] encryption_key`）+ `cache_directory`（hplatform.gd 預設 `user://eosg-cache`）有設，`EOS_Platform_GetPlayerDataStorageInterface` 就會回傳非 null。
* 所有 PDS 操作都是**非同步**：用 `await IEOS.playerdatastorage_interface_*_callback` 等結果。

### 低階 API 用法（對應 `src/playerdatastorage_interface.cpp`）
| 操作 | 呼叫 | 完成訊號 | 回傳字典 key |
|---|---|---|---|
| 查檔 | `EOS.PlayerDataStorage.PlayerDataStorageInterface.query_file(opts)` | `playerdatastorage_interface_query_file_callback` | `result_code` |
| 寫檔 | `...write_file(opts)` | `playerdatastorage_interface_write_file_callback` | `result_code`（SDK 自動切 chunk） |
| 讀檔 | `...read_file(opts)` | chunk: `playerdatastorage_interface_read_file_data_callback` → 完成: `playerdatastorage_interface_read_file_callback` | chunk 有 `data_chunk`(PackedByteArray)/`is_last_chunk`；完成有 `result_code` |
* options：`local_user_id`（用 `NetworkManager.product_user_id`）、`filename`、`read_chunk_length_bytes`/`chunk_length_bytes`（4096）、`data`(PackedByteArray)。
* 結果用 `EOS.is_success(dict)` 判斷（eos.gd:38 接受含 `result_code` 的 Dictionary）。

### 專案實作（`network/player_storage.gd`，autoload `PlayerStorage`）
* `has_profile()` / `load_profile()` / `save_profile(profile)` / `is_available()`，檔名固定 `profile.json`。
* `ui/time_trial_start_screen.gd`：
  * B3 登入成功後 `_restore_display_name()`：先雲端、後本地快取 `user://player_profile.cfg`（B4 fallback）。
  * B2 註冊按下「建立帳號」時 `save_profile()` 上傳暱稱，仍保留本地快取；雲端失敗不阻擋進 lobby，只提示。
* PDS 測試帳號：可用 `login_anonymous_async()` 產生 device-id PUID 做 PDS 端到端測試，測試檔可事後 `delete_file` 清除。

### 驗證狀態（2026-08-20）
* ✅ 專案啟動乾淨（0 parse/compile error）；`PlayerStorage` autoload 正常註冊（`/root/PlayerStorage` 存在）。
* ✅ B3/B4 回退邏輯已用模擬登入狀態驗證：雲端 `read_file` 失敗（假 PUID）→ 正確回退 `user://player_profile.cfg` 本地快取並設定 `NetworkManager.display_name`。
* ✅ C1 login 統一分派：`login("bogus")` → 正確 emit「未知登入方式」；`login("epic")` → account_portal。
* ✅ D1 自動登入：無 token 啟動時靜默失敗（`_suppress_login_error` 抑制錯誤記錄），不干擾 UI。
* ⛔ **B1 live PDS 讀寫尚未驗證**：需要一個真實登入（account_portal）。
  * `anonymous` → 本次不做（已定案改走 account_portal；後續才做 Device ID 訪客登入）。*過往「AccessDenied 是 Client Policy 未開 Connect」的紀錄是錯的，已於上方「登入失敗原因分析」修正：User Required 需保持勾選、Connect 開關僅限 Trusted Server、匿名登入只需 PDS 權限。*
  * `devtool` → DevAuthTool 未執行（localhost:4545 無服務），暫不使用。
  * `discord` → 使用者明確排除，且 client_id 未填，UI 按鈕 disabled。
  * `account_portal` → **登入錯誤已修復（2026-08-20）**：
	* 遊戲 log 曾回報 `InvalidAuth`(4)（persistent auth 的失效 token，啟動時靜默）與 `AuthScopeNotFound`(1016)（手動登入失敗）。
	* 根因：EAS Application Permissions 多開了 **Country** scope，與 SDK 請求的 `BasicProfile|Presence|FriendsList` 不一致（EOS 不支援增量 scope，需完全一致）。
	* 處置：Dev Portal → Epic Account Services → Application → Permissions，關閉 Country，僅保留 Basic Profile / Friends / Presence 三項，已儲存。**`AuthScopeNotFound` 已排除。**
  * **待辦（下一步）**：重啟遊戲走 **account_portal** 瀏覽器登入；成功後執行
	`PlayerStorage.save_profile()/has_profile()/load_profile()` 三連驗證，並更新本節狀態。
  * 後續再做：**Device ID 訪客匿名登入** + 之後引導綁定 EAS（Epic 帳號）。屆時 Client Policy 需保持 User Required 勾選並開 PDS 權限。

---

## 多人連線測試流程（登入成功後）

1.  **本機雙開測試**：
	*   可以使用 Godot 編輯器的多人遊戲測試（Debug > Run Multiple Instances），或匯出兩個遊戲執行檔。
	*   **Player 1 (Host)**：登入後，點選「建立房間」。這會透過 `HLobbies.create_lobby_async()` 建立 lobby 並同步開啟 listen server (`EOSGMultiplayerPeer.create_server`)。
	*   **Player 2 (Client)**：登入後，呼叫 `search_lobbies()` 搜尋到剛才建立的 lobby，點選加入。這會透過 `HLobbies.join_async()` 加入大廳，並自動利用主辦方的 `owner_product_user_id` 呼叫 `NetworkManager.join_game()` 建立 P2P 連線。
