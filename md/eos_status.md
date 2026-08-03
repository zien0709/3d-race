# EOS 多人連線進度與解決方案註記

## 目標
將 EOS 多人連線接入 3D 賽車遊戲：`NetworkManager` 與 `LobbyManager` 實作。
支援 Epic Account Services (登入) + Lobbies (12 人房)，並以 `EOSGMultiplayerPeer` 作為傳輸層，且維持單人模式不受影響。

---

## 登入失敗原因分析與【正確觀念澄清】

經過針對 EOS SDK 機制與 Epic Developer Portal 配置的深入分析，以下為先前測試失敗的真正原因及澄清：

### 1. Anonymous (DeviceID) 登入回報 `EOS_AccessDenied`
*   **【誤區澄清】**：官方文件與實際機制表明，**Device ID 匿名登入完全可以在 Dev/Stage 等任何私有沙盒 (Sandbox) 中使用**，不限於 Live 沙盒。
*   **【真正原因】**：會拿到 `Access Denied` 是因為您在 Dev Portal 建立的 **Client Policy（用戶端策略）中，沒有勾選並啟用 `Connect` 的相關權限**（如 `createDeviceId` 或 `authenticate`）。
*   **【解決方案】**：在 Client Policy 中勾選 Connect 服務，即可立刻成功使用 `anonymous` 模式登入！

### 2. DevAuthTool 登入回報 `EOS_InvalidRequest`
*   **【真正原因】**：DevAuthTool（`devtool` 模式）本質上是透過 Epic 帳號登入（Epic Account Services, 簡稱 EAS）。如果未將您的 Client 綁定到 EAS，或兩端設定的 Scope 權限不吻合，Epic 伺服器就會拒絕該請求，返回 `EOS_InvalidRequest`。
*   **【解決方案】**：必須在 Dev Portal 的 **Epic Account Services** 頁面，將您的 Client ID 進行關聯，並勾選對應的 Scopes。

---

## Epic Developer Portal 解決步驟指引

請依照以下兩個部分的步驟，在 [Epic Developer Portal](https://dev.epicgames.com/portal/) 中進行設定調整：

### 第一部分：修正 Client Policy 權限（解決 `anonymous` 登入與多人連線功能）

1.  登入 **Epic Developer Portal**。
2.  進入您的 Product，在左側選單點擊 **Product Settings** (產品設定)。
3.  切換到上方的 **Clients** (用戶端) 標籤。
4.  在您目前使用的 Client (如 `TestP2P`) 右側，查看它所使用的 **Client Policy** 名稱。點擊 **Manage Policies** (管理策略) 或直接點擊 Policy 名稱進行編輯。
5.  在 Policy 編輯頁面中，下拉到 **Features** (功能權限) 列表：
    *   **Connect 服務 (至關重要)**：尋找 `Connect` 欄位並啟用它。務必勾選以下子項目：
        *   `authenticate` (認證)
        *   `createDeviceId` (建立裝置識別碼)
        *   `findProductUserIdMap`
        *   `queryProductUserIdMappings`
    *   **Lobby 服務 (開房必備)**：尋找 `Lobby` 欄位並啟用它，務必勾選：
        *   `createLobby` (建立大廳)
        *   `joinLobby` (加入大廳)
        *   `updateLobby` (更新大廳屬性/成員狀態)
        *   `connect` (連接大廳 RTC)
    *   **P2P 服務 (傳輸連線)**：尋找 `P2P` 欄位並啟用，勾選或直接全開。
6.  儲存 Policy 設定。
7.  **驗證**：在 `eos_config.cfg` 中將 `method` 改為 `"anonymous"`，啟動遊戲點擊登入。此時 Device ID 匿名登入應能秒速成功！

---

### 第二部分：配置 Epic Account Services 關聯（解決 `devtool` 與 `account_portal` 登入）

1.  在左側導覽列中，點擊 **Epic Account Services** (EAS)。
2.  若尚未配置 Application，請點擊 **Configure** 建立一個新的測試用 Application（「品牌設定 / Brand Settings」填寫本地測試資訊即可，暫不需提交給 Epic 審查）。
3.  進入該 Application 設定：
    *   **Permissions (權限) 標籤**：
        *   在權限列表中，務必勾選並啟用 **Basic Profile**、**Friends** 與 **Presence**。
        *   *原因*：GDScript 程式端代碼中預設請求了 `BasicProfile | Presence | FriendsList` 三個 Scopes，如果 EAS portal 中沒有一致啟用，登入即會回報錯誤。
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

## 多人連線測試流程（登入成功後）

1.  **本機雙開測試**：
    *   可以使用 Godot 編輯器的多人遊戲測試（Debug > Run Multiple Instances），或匯出兩個遊戲執行檔。
    *   **Player 1 (Host)**：登入後，點選「建立房間」。這會透過 `HLobbies.create_lobby_async()` 建立 lobby 並同步開啟 listen server (`EOSGMultiplayerPeer.create_server`)。
    *   **Player 2 (Client)**：登入後，呼叫 `search_lobbies()` 搜尋到剛才建立的 lobby，點選加入。這會透過 `HLobbies.join_async()` 加入大廳，並自動利用主辦方的 `owner_product_user_id` 呼叫 `NetworkManager.join_game()` 建立 P2P 連線。
