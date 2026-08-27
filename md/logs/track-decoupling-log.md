# 賽道解耦工作日誌 (Track Decoupling Log)

> 建立日期：2026-08-27（Phase D Lobby 重構同期，另一 AI 負責 Lobby UI 修正，勿動 `ui/lobby.tscn`）
> 目標：將「預設賽道」寫死資料抽成 `TrackConfig` Resource，為未來多賽道 + Lobby 真選圖做準備
> 相關分析：`md/domain/track_analysis.md`（5 觀察 + 載入鏈路審計）

---

## 決策記錄

- **賽道命名**：`default`（顯示名 `預設賽道`）。`room_config["map"]="東京灣夜景"` 需建 `中文→track_id` 映射表（B2/B4 再做）
- **注入點**：`RaceCourseSetup._ready()` 首行讀 config（Plan B 方案）。`main.tscn:147` 靜態 `race_map.glb` 保留作 fallback，不動 `WaterAnimator/GrassManager/EnvironmentManager` 的 `get_node("RaceMap")` 鏈
- **資料層**：新建 `class_name TrackConfig extends Resource` + `res://tracks/default.tres`（1:1 抄現有 7 點/FINISH/GRID，先證明零回歸）
- **Autoload**：B2 新增 `core/game_state.gd` 暫存 `selected_track_id`（`project.godot` Autoload，接在 LobbyManager 之後）
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
- [ ] B2: GameState Autoload + Lobby 選圖寫 `selected_track_id`（待使用者確認中文映射）
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
