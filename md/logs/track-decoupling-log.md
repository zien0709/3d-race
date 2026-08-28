# 賽道解耦工作日誌 (Track Decoupling Log)

> 建立日期：2026-08-27（Phase D Lobby 重構同期，另一 AI 負責 Lobby UI 修正，勿動 `ui/lobby.tscn`）
> 目標：將「預設賽道」寫死資料抽成 `TrackConfig` Resource，為未來多賽道 + Lobby 真選圖做準備
> 相關分析：`md/domain/track_analysis.md`（5 觀察 + 載入鏈路審計）

---

## 決策記錄

- **賽道命名**：`default`（顯示名 `預設賽道`）。`room_config["map"]="東京灣夜景"` 需建 `中文→track_id` 映射表（B2/B4 再做）
- **注入點**：`RaceCourseSetup._ready()` 首行讀 config（Plan B 方案）。`main.tscn:147` 靜態 `race_map.glb` 保留作 fallback，不動 `WaterAnimator/GrassManager/EnvironmentManager` 的 `get_node("RaceMap")` 鏈
- **資料層**：新建 `class_name TrackConfig extends Resource` + `res://tracks/default.tres`（1:1 抄現有 7 點/FINISH/GRID，先證明零回歸）
- **Autoload**：B2 新增 `race/track_registry.gd` 作為 `TrackRegistry` Autoload（**無 class_name**，否則與 `project.godot` 預註冊的 singleton 名撞名報 "Class hides autoload singleton"）。負責註冊 TrackConfig、`selected_track_id` 暫存、中文 map 名↔track_id 映射、`get_available_map_names()`/`get_track_info()` 給 Lobby UI 消費
- **PS 版本**：環境已升 PowerShell 7+，舊 AI_WORKFLOW 寫的 5.1 陷阱多數不再適用（head/tail/&& 回來了），但 UTF-8 寫暫存檔習慣仍保留
- **MCP 約束**：編輯 Godot 專案/節點/腳本/資源一律用 godot-ai MCP（script_create / resource_manage / scene 工具），不直接手改 .gd/.tscn

## TrackConfig 欄位清單（單一來源）

| 欄位 | 型別 | 預設值（default 賽道） |
|------|------|----------------------|
| `track_id` | StringName | `&"default"` |
| `display_name` | String | `預設賽道` |
| `scene_path` | String | `res://race_map.glb` |
| `gate_size` | Vector3 | `(14,3,4)` |
| `checkpoint_positions` | Array[Vector3] | 7 點 (y=1.5) |
| `checkpoint_yaws` | Array[float] | 7 yaw |
| `finish_position` | Vector3 | `(-115.077791,1.5,6.507477)` |
| `finish_yaw` | float | `3.105172` |
| `start_grid_center` | Vector3 | `(-115.077791,1.35,10.5)` |
| `start_grid_yaw` | float | `0.0` |
| `grid_cols/rows` | int | `4 / 3` |
| `col_spacing/row_spacing` | float | `4.0 / 7.0` |
| `roadbed_path` | String | `RaceMap/Roadbed_Shoulder` |

> 衍生方法：`total_checkpoints()`、`checkpoint_transforms()`、`finish_transform()`（用 `Basis.from_euler` 組 Transform3D）

## 待辦（與 todowrite 同步）

- [x] B1: TrackConfig + default.tres + RaceCourseSetup/StartGrid 改吃 cfg（fallback 硬編碼）
- [x] B1 驗證（靜態）: 兩腳本 0 parse error；default.tres 數值 1:1 回歸；行為等價（cfg 派生的 transform/position 與舊 const 完全相同）
- [ ] B1 驗證（動態）: 環境無法 foreground 遊戲視窗 → game_eval 回 EVAL_GAME_NOT_READY，無法跑 frame loop。**待人工 playtest**：單人進場/重生/衝線
- [x] B2: `TrackRegistry` Autoload（`race/track_registry.gd`，無 class_name）+ `race_course_setup.gd` 改用 `TrackRegistry.get_selected_track()`；`lobby_manager.gd` 在 `_on_lobby_updated` / `update_lobby_settings` 同步 `map` attribute → `TrackRegistry.select_track_by_ui_name()`（編譯通過、Autoload 運行期 live、無 track 相關錯誤）
- [ ] B3: `_ready` 條件替換 RaceMap（動態 load glb）—— 需第二賽道素材
- [ ] B4: `room_overlay` chip 改吃 `TrackRegistry` + `lobby_manager.validate` —— 需第二賽道素材

## B1 實作摘要（2026-08-27）

新增檔案：
- `res://race/track_config.gd` — `class_name TrackConfig extends Resource`，欄位見上表 + 衍生方法 `total_checkpoints()/checkpoint_transforms()/finish_transform()`
- `res://tracks/default.tres` — 1:1 抄 race_course_setup.gd 舊 7 點/FINISH/GRID（用 filesystem_manage write_text 寫，因 resource_manage create 要求 @tool 才能編輯器內建實例）
- 改 `res://race/start_grid.gd` — 新增 `static var _overrides` + `apply_config(cfg)` + `_center/_yaw/_cols/_rows/_col_spacing/_row_spacing` 讀 override（無 override 回退原 const，舊 API 不變）
- 改 `res://race_course_setup.gd` — `_ready` 首行 `_apply_track_config()`：`load(TRACK_CONFIG_PATH) as TrackConfig`；成功則 `_track=cfg` + `StartGrid.apply_config(cfg)`；所有門/排名/起點改吃 `_track` 衍生（無 cfg 時回退原 const）。`_ready` 順序不變

踩雷：
- race_course_setup.gd 初版誤寫 `float(Vector3(t.basis.get_euler().y))` → 應為 `float(t.basis.get_euler().y)`（已修）
- start_grid.gd 初版因 TrackConfig 未註冊報 error 43，scan 後解決
- resource_manage create 報 WRONG_TYPE（需 @tool）；改寫 .tres 文本繞過
- game_eval 在本機無法跑（遊戲視窗無法 foreground，EVAL_GAME_NOT_READY）

## 已知風險（切換賽道才會爆）

- `player.gd:192` 寫死 `../RaceMap/Roadbed_Shoulder` → 改吃 `cfg.roadbed_path`（B3）
- `scripts/water_animator.gd:36-40` 寫死 5 水面節點名 → 改吃 `cfg.water_node_names`（B3）
- `main.tscn:326` GrassField 定點 → 改吃 `cfg.grass_field`（B3）
- 中文 `room_config["map"]`（東京灣夜景/阿爾卑斯山道/城市街道）→ 需映射 `track_id`

## 教訓

- T001: Resource 的 `Array[Transform3D]` 在 .tres 難手寫，改存 `Array[Vector3]+Array[float]` 再於 Resource 內組 Transform3D，.tres 好維護且 MCP 易建
- T002: 解耦第一步「先 1:1 抄值、行為不變」最能證明零回歸；別一上來就抽抽象
- T003: `race_course_setup.gd` 是 `Main` 的 script 且同時是賽道/排名/玩家注入總入口，改它等於改整條比賽初始化鏈，必須 `_ready` 順序不動

## B2 實作摘要（2026-08-28）

新增/修改檔案：
- `res://race/track_registry.gd` — `TrackRegistry` Autoload（**無 class_name**）。`_ready` 註冊 `default.tres` 進 `_tracks`，並建 `中文 map 名 → track_id` 映射表（`預設賽道/東京灣夜景/阿爾卑斯山道/城市街道` 目前全指向 `default`）。方法：`get_selected_track()/get_track()/get_track_by_ui_name()/select_track_by_ui_name(ui_name)->bool/get_available_map_names()/get_track_info()`
- 改 `res://race_course_setup.gd` — `_apply_track_config()` 改用 `TrackRegistry.get_selected_track()`（回退 `load(default.tres)` → 硬編碼 const），其他邏輯不變
- 改 `res://network/lobby_manager.gd` — `_on_lobby_updated()` 讀 `lobby_attr(ATTR_MAP)` 呼叫 `TrackRegistry.select_track_by_ui_name()`（host/client 共用）；`update_lobby_settings()` 設 `map` attribute 時同步呼叫（防 host 端 `lobby_updated` 不發本地信號）。**未碰任何 UI 檔**（另一 AI 在做 Lobby UI 修正）

驗證（編譯 + 運行期，無法 foreground 視窗故不跑 frame loop）：
- `editor_reload_plugin` 後重連，`race_course_setup.gd` 與 `lobby_manager.gd` 的 `Identifier "TrackRegistry" not declared` 編譯錯誤消失（見 T004）
- 遊戲運行期 `get_node_info("/root/TrackRegistry")` 回 `found=true, type=Node`（Autoload live）
- 遊戲 log 僅有 EOS 良性警告（`HLeaderboards NotFound`、`HLobbies InvalidParameters`）與舊 race 訊息，無任何 track/registry 相關錯誤
- 賽道選擇 → TrackRegistry 的真正生效需開局（match start 後 `race_course_setup` 讀 registry），目前被另一 AI 的 `lobby_main.gd::_on_auth_succeeded` signal 簽名不符錯誤擋住互動 playtest（非本任務範圍）

踩雷：
- `race_course_setup.gd` 初版改吃 `TrackRegistry` 後報 `Identifier "TrackRegistry" not declared` → 因 GDScript parser 的全域名稱表未含新 Autoload，需 `editor_reload_plugin` 重新整理（T004）
- 同錯誤在 `lobby_manager.gd` 編輯後再現，`editor_reload_plugin` 重連後消失
- `game_eval` 在本環境仍回 `EVAL_GAME_NOT_READY`（遊戲視窗無法 foreground，main loop 不前進）；改用 `get_node_info` 確認 Autoload 存在

## 教訓

- T004: 新增/引用 Autoload 全域識別字（如 `TrackRegistry`）後，若腳本編譯報 `Identifier not declared`，不是程式碼錯，而是 GDScript parser 的全域名稱表尚未刷新——呼叫 `editor_reload_plugin` 重連 session 即可。MCP 的 `script_patch` 即時 diagnostics 會因此誤報，以重連後 `project_run` + 讀 log 為準
