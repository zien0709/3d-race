# 賽道分析 (Track Analysis)

> 建立日期：2026-08-27  
> 狀態：Plan A 已完成（只記錄現況，未改碼）  
> 關聯：`main.tscn` / `race_map.glb` / `race_course_setup.gd` / `race/start_grid.gd` / `player.gd` / `race/race_ranking.gd`  
> Plan B 解耦待議：需更多賽道候選資料後再定案，避免反覆重構

---

## 1. 現況問題／觀察（使用者提出 5 點，原樣封存 + 補證據）

### 1.1 邏輯門與 GLB 視覺條紋未完全對齊（微偏移）
- **證據**：`race_course_setup.gd:12` 7 個 `CHECKPOINTS` vs `race_map.glb` 內建 `CP1~CP7_Stripe_00~09 + Sign/Text`（pygltflib 解析 904 nodes）
- **量測**（中心對中心，單位 m）：
  | CP | 邏輯門 (`race_course_setup.gd`) | 視覺條紋均值 (GLB) | 偏差 |
  |----|-------------------------------|-------------------|------|
  | 1 | (-79.42, -86.00) | (-79.42, -85.99) | ~0.02 |
  | 2 | (92.43, -72.30) | (92.44, -72.30) | ~0.01 |
  | 3 | (-2.67, 49.54) | (-2.67, 49.55) | ~0.01 |
  | 4 | (94.54, 81.50) | (94.55, 81.50) | ~0.01 |
  | 5 | (-37.86, 49.27) | (-37.86, 48.70) | **~0.57 Z** |
  | 6 | (-58.48, 38.23) | (-58.47, 38.23) | ~0.01 |
  | 7 | (-97.88, 59.57) | (-97.92, 59.58) | ~0.04 |
- **判定**：CP5 偏移最明顯，其餘近乎一致；是否故意需美術確認。視覺條紋僅裝飾，實際觸發以 `race_course_setup.gd:87` `GATE_SIZE=Vector3(14,3,4)` 的 `Area3D+BoxShape3D` 為準。

### 1.2 無物理護欄，高速易衝出
- **證據**：`main.tscn:171` `Track/Walls` 8 面牆（`Wall1~8`）在 `race_course_setup.gd:38` `_remove_test_course()` 直接 `free()`；GLB 僅剩 `Sparse_Fence_Run_01~06-col`（木籬，`Sparse_Fence_Wood`）與樹/岩石作軟邊界，無連續碰撞牆
- **影響**：`Asphalt_Main-col → Roadbed_Shoulder-col → Runoff_Zone-col(Soil) → Grass_Mound_* → Landscape_Island-col` 僅高差過渡，無阻擋；`player.gd` 僅做草地摩擦衰減，未有撞牆反彈

### 1.3 `Roadbed_Shoulder` 三角面未量化，`_build_road_surface_lookup` 有精度／效能風險
- **證據**：`player.gd:190` `_build_road_surface_lookup()` 取 `Roadbed_Shoulder` 的 `mesh.get_faces()`（`race_map.glb:23` mesh23 `Track_Shoulder`），逐面轉 `global_transform * faces` 建 `road_triangles: Array[PackedVector2Array]` + `ROAD_GRID_CELL_SIZE=4.0` 的 `road_triangle_grid: Dictionary`
- **風險**：
  - 面數 = `mesh23` 的 `get_faces().size()/3`（895 meshes 之一，未在本次解析中直接讀取，需進編輯器 `Mesh.get_faces()` 量化，估 5k~20k 面級別）
  - 每幀 `player.gd:158` 對 4 輪各做一次 `_is_point_on_road` 查格 → 4 次 Dictionary + `point_in_triangle` 遍歷，`ROAD_GRID_CELL_SIZE=4.0` 若賽道狹長會命中多格
  - `global_transform` 在 `_ready` 時已 bake，若賽道日後可位移/旋轉會失效；目前因 `RaceMap` 無位移所以安全
  - 建議：補 `print("road_triangles=%d grid_cells=%d" % [...])` 埋點，或改用 `NavigationPolygon` / `CollisionPolygon` 離線烘焙

### 1.4 `total_checkpoints=7` 一致性與廢棄節點
- **證據**：`race_course_setup.gd:3` `TOTAL_CHECKPOINTS=7` 與 `main.tscn:312` `RaceManager total_checkpoints=7` 一致；`main.tscn:267` 遺留 `CheckPoints/CheckPoint1(level1)/CheckPoint2(level2)` 兩個 `visible=false` 舊節點已被 `_remove_test_course` 清除，無殘留影響
- **注意**：`race_manager.gd:179` `finish_race()` 會檢查 `next_checkpoint <= total_checkpoints` 才放行，7 與動態生成的 `CHECKPOINTS.size()` 必須同步，否則會永遠無法衝線

### 1.5 起點／終點 yaw 與 GLB 棋盤格一致（逆時針賽道）
- **證據**：
  - `StartGrid.GRID_CENTER = Vector3(-115.07,1.35,10.5) yaw 0.0`（`race/start_grid.gd:12`）
  - `race_course_setup.gd:5` `FINISH (-115.07,1.5,6.50) yaw 3.105`（≈ -178°）
  - GLB 起點 `Start_Checker_0_0~1_9`（20 塊，node 840~861）中心約 (-115.08, 6.5) yaw `0.694` 四元數（約 88°，與賽道切線一致）
  - `Fountain_*` 噴泉在 (0,2~6) 是賽道中段廣場，非終點
- **判定**：起點與終點在同一直道前後 4m，符合逆時針繞圈賽道設計

---

## 2. 賽道何時／怎樣載入（審計結論：**寫死、無解耦、無參數化**）

### 2.1 何時載入
| 入口 | 檔案:行號 | 行為 |
|------|-----------|------|
| 啟動 | `project.godot:14` `run/main_scene="res://main.tscn"` | 直接進 `Main` |
| 單人開始 | `ui/lobby_ui.gd:686` / `race_manager.gd:433` `change_scene_to_file("res://main.tscn")` | 硬編碼，無參數 |
| 多人開始 | `ui/lobby_ui.gd:520` `lobby_main.gd:194` `match_started → change_scene_to_file("res://main.tscn")` | 僅 `peer_order` 經 lobby attribute 廣播，`map` 未傳遞 |

### 2.2 怎樣載入
- `main.tscn:31` `RaceMap instance=ExtResource("race_map.glb")` **靜態實例化**，單一全量地形（含 904 nodes / 895 meshes / 45 materials）
- `race_course_setup.gd:23` `_ready()` 硬編碼重建：`GATE_SIZE=14×3×4` 的 `Area3D+BoxShape3D` 7 門 + 1 終點，`StartGrid` 12 格出發位（單人只用 slot 0）
- 強耦合點：`player.gd:192` 寫死 `RaceMap/Roadbed_Shoulder` 路徑；`scripts/water_animator.gd:30` 寫死 5 個水面節點名 (`Ocean_Base`, `Garden_Pond_*`, `Fountain_Water`)；`scripts/grass_manager.gd:347` `GrassField` 定點放置

### 2.3 是否解耦／能否傳參
- **已解耦（B1/B2 完成）**。已新增 `TrackRegistry` Autoload（`race/track_registry.gd`，無 class_name）+ `TrackConfig` Resource（`race/track_config.gd` + `tracks/default.tres`）。`network/lobby_manager.gd` 的 `ATTR_MAP` 現經 `_on_lobby_updated()` / `update_lobby_settings()` → `TrackRegistry.select_track_by_ui_name()` 同步；`race_course_setup.gd` 改吃 `TrackRegistry.get_selected_track()`（回退 default.tres → 硬編碼 const）。**ATTR_MAP 不再是 UI 假選項，已接線生效**。見 `md/logs/track-decoupling-log.md`。
- `change_scene_to_file` 在 Godot 4 無原生參數傳遞，但 `TrackRegistry` Autoload 現暫存 `selected_track_id` 跨場景（Lobby → main.tscn），解決傳參問題。

### 2.4 賽道有哪些模式（現況真實模式 vs 假選項）

| 類別 | 選項（UI） | 真實生效 | 來源 |
|------|-----------|---------|------|
| 地圖 | `東京灣夜景` / `阿爾卑斯山道` / `城市街道` | **單地圖**（`race_map.glb`）；`ATTR_MAP` 已接 `TrackRegistry`（目前全解析至 `default`，待 B3 多賽道素材） | `lobby_ui.gd:359` `lobby_main.gd:406` chip_row 寫 `room_config["map"]` → `lobby_manager.gd` → `TrackRegistry` |
| 玩法 | `經典競速` / `淘汰賽` / `計時挑戰` | **計時賽** 唯一 | 同上，`room_config["mode"]` 未被 `RaceManager` 讀 |
| 進階 | `car_restriction` / `damage_mode` / `auto_start` | 僅 `auto_start` 在大廳有倒數邏輯，其餘未消費 | `lobby_manager.gd:304` `update_lobby_settings` 寫 attribute 但無 gameplay 分支 |
| 真實賽制 | `total_checkpoints=7` 的 Time Attack | ✅ `RaceManager:32` `waiting→countdown(3s)→racing→finish`，`RaceRanking` 按 `progress` 排序 | `race_course_setup.gd:3` + `race/race_ranking.gd:1` |

> **B3/B4 前置需求**：`TrackRegistry + TrackConfig` 設計已完成（B1/B2），可傳參機制就緒。若要「多賽道切換」，需先確定「第二、第三賽道清單與每條的 `checkpoints + finish + roadbed_path + grass_area` 配置來源」（即真實 glb 素材），再擴充 `TrackRegistry.register_track()`，避免寫了又改。

---

## 3. 關聯檔案索引

| 檔案 | 行號 | 職責 |
|------|------|------|
| `race_course_setup.gd` | 3,5,12,23,34,38 | TOTAL_CHECKPOINTS / FINISH / CHECKPOINTS / _ready鏈 / 動態建門／清舊 Track |
| `race/start_grid.gd` | 12,17 | GRID_CENTER / GRID_YAW / 12格佈局 |
| `player.gd` | 55,78,190,158,441 | WHEEL_SETTINGS / CONCEPT_WHEEL_MAP / _build_road_surface_lookup / _update_surface_response / respawn |
| `race/race_ranking.gd` | 20,40,72 | setup / update_car(progress) / advance_car |
| `race_manager.gd` | 14,179,121,55 | total_checkpoints / finish_race檢查 / setup_ranking / _process 排名 |
| `main.tscn` | 31,147,167,171,312 | RaceMap實例 / WaterAnimator / GrassField / 舊Track(已廢棄) / RaceManager |
| `race_map.glb` | — | 904 nodes, 895 meshes, 45 mats; Roadbed_Shoulder-col / Asphalt_Main-col / CP1~7_Stripe / Start_Checker |
| `project.godot` | 14 | run/main_scene |
| `network/lobby_manager.gd` | 23,304,325 | ATTR_MAP / update_lobby_settings / start_match(peer_order) |
| `ui/lobby_ui.gd` | 32,359,520,686 | room_config map 3選 / chip_row / 兩處 change_scene |
| `ui/lobby/lobby_main.gd` | 32,194,403 | 同上，新版協調器 |

---

## 4. 後續建議（Plan B 待議）

- 本文件為 **Plan A 完成物**；**B1/B2 解耦已完成**（TrackConfig + TrackRegistry，單賽道零回歸、ATTR_MAP 已接線）。B3（動態 load glb 替換 RaceMap）/ B4（`room_overlay` chip 改吃 TrackRegistry）仍待「第二賽道」素材確定後再啟動，避免過度抽象。
- 下次改動前必讀：`md/core/AI_WORKFLOW.md` + `md/status/PROJECT_STATUS.md` + 本文。

---

## 5. 提供的接口（TrackRegistry / TrackConfig API）

> B1/B2 實作產出。供 Lobby UI、比賽場景、網路層消費。

### 5.1 TrackRegistry Autoload（`race/track_registry.gd`，**無 class_name** 以免與 singleton 名撞名）

跨場景（Lobby → main.tscn）暫存當前選中賽道並提供查詢。

| 成員 | 簽章 | 說明 / 消費方 |
|------|------|--------------|
| `selected_track_id` | `StringName`（預設 `&"default"`） | 當前選中賽道 id |
| `get_selected_track() -> TrackConfig` | — | 比賽場景 `race_course_setup.gd` 開局讀取 |
| `get_track(id: StringName) -> TrackConfig` | — | 按 id 查 |
| `get_track_by_ui_name(ui_name: String) -> TrackConfig` | — | 顯示名（含中文 map 名）→ TrackConfig |
| `select_track_by_ui_name(ui_name: String) -> bool` | — | 由 lobby/UI 的 map 名設定選中賽道；`lobby_manager.gd` 已接 |
| `get_available_map_names() -> Array[String]` | — | 給 Lobby UI chip 列出可選賽道名 |
| `get_track_info(ui_name_or_id: String) -> Dictionary` | — | UI 用賽道資訊（id / display_name / scene_path / total_checkpoints / gate_size / roadbed_path） |
| `register_track(cfg: TrackConfig)` | — | 註冊新賽道（B3/B4 多賽道用） |

### 5.2 TrackConfig Resource（`race/track_config.gd`，`class_name TrackConfig extends Resource`）

賽道欄位單一來源（見 §上表 TrackConfig 欄位清單）。衍生方法：
- `total_checkpoints() -> int`
- `checkpoint_transforms() -> Array[Transform3D]`
- `finish_transform() -> Transform3D`

### 5.3 Lobby UI 接線契約（待 B4）

- 填充 chip：`TrackRegistry.get_available_map_names()` + `TrackRegistry.get_track_info(name)`
- 選擇後寫入：`lobby_manager.update_lobby_settings({"map": name})`（已自動同步進 TrackRegistry）
- 比賽開局：`race_course_setup.gd` 讀 `TrackRegistry.get_selected_track()`

### 5.4 中文 map 名映射

`預設賽道 / 東京灣夜景 / 阿爾卑斯山道 / 城市街道` 目前全指向 `default`（僅一份素材）。多賽道到位後 `register_track` 即自動解析，無需改其他邏輯。

