# 3D Race 项目探索报告

**探索时间**: 2026-08-24  
**Godot版本**: 4.7.1-stable  
**项目名称**: Z 3D Race  
**物理引擎**: Jolt Physics  
**多人框架**: Epic Online Services (EOS) + EOSGMultiplayerPeer

---

## 1. 核心场景结构

### 1.1 主游戏场景 (`res://main.tscn`)
```
/Main (Node3D)
├── /Main/RaceMap (Node3D) - 赛道地图，765个子节点
│   ├── Roadbed_Shoulder (MeshInstance3D) - 赛道路肩，含碰撞体
│   ├── Asphalt_Main (MeshInstance3D) - 主沥青路面，含碰撞体
│   ├── Curb_Left_0/1, Curb_Right_0/1 - 路缘石
│   ├── Center_Dashes_0 - 中央虚线
│   ├── Ocean_Base, Landscape_Island, Grass_Mound_* - 环境装饰
│   └── BLDG_01_Central_Fountain_ROOT - 中央喷泉建筑群
├── /Main/Players (Node3D) - 玩家容器
│   └── PlayerSpawner (MultiplayerSpawner) - 多人同步生成器
├── /Main/UI (CanvasLayer, layer=1) - UI层
│   ├── Dashboard (Control) - 仪表盘
│   ├── StartCenter (Control) - 开始界面
│   ├── CountdownCenter (CenterContainer) - 倒计时
│   ├── FinishCenter (CenterContainer) - 终点界面
│   ├── LeaderboardPanel (PanelContainer) - 排行榜
│   ├── RankPanel (PanelContainer) - 排名面板
│   └── HUD (PanelContainer) - HUD面板
```

### 1.2 大厅场景 (`res://ui/lobby.tscn`)
```
/Lobby (Control)
├── Header (PanelContainer) - 顶部栏
├── MainContainer (HBoxContainer)
│   ├── LeftPanel (VBoxContainer)
│   │   ├── FloatingChat (PanelContainer) - 聊天面板（預設隱藏，開啟時取代 Inspector）
│   │   ├── Inspector (PanelContainer) - 玩家查看面板
│   │   └── ChatTrigger (Button) - 聊天触发器
│   └── CenterRightPanel (VBoxContainer)
│       ├── Showcase (PanelContainer) - 车辆/玩家展示
│       └── ReadyButton (Button) - 准备按钮
├── RoomOverlay (Control) - 房间设置覆盖层
├── LobbyBrowser (Control) - 大厅浏览器
├── CustomizeView (Control) - 自定义视图
└── Toast (Control) - 提示消息
```

---

## 2. 核心游戏逻辑脚本

### 2.1 `player.gd` (459行) - 车辆物理控制
**继承**: `VehicleBody3D`  
**关键特性**:
- 5挡自动变速箱 (UPSHIFT/DOWNSHIFT_SPEEDS, GEAR_FORCE_MULTIPLIERS)
- 轮胎抓地力系统：路面 vs 草地 (`road_tire_grip` vs `grass_tire_grip`)
- 草地检测：基于 `Roadbed_Shoulder` 网格的空间索引 (`_build_road_surface_lookup`)
- 天气影响：`update_weather_effects(intensity)` 接收 EnvironmentManager 的天气强度
- 直立稳定系统：扭矩修正 roll/pitch，保留 yaw
- 重生系统：`respawn_car()` 使用 PhysicsServer3D 强制重置状态
- 支持两种车模：ConceptCar 和 AE86_2

**导出属性**: engine_power, brake_power, max_speed, max_steer_angle_degrees, downforce, upright_strength 等

### 2.2 `race_manager.gd` (254行) - 单人计时赛管理
**继承**: `Node`  
**信号**: `race_active_changed(active: bool)`  
**功能**:
- 7个检查点 (`TOTAL_CHECKPOINTS = 7`)
- 3-2-1-GO 倒计时
- 排名系统 (`RaceRanking` 类)
- 本地最佳成绩存储 (`user://race_scores.cfg`)
- EOS 公开排行榜提交 (`leaderboard_ui.submit_public`)
- UI 协调：HUD、倒计时、开始/结束界面、排行榜、排名面板

### 2.3 `race_course_setup.gd` (113行) - 赛道动态生成
**继承**: `Node3D`  
**常量**:
- `TOTAL_CHECKPOINTS = 7`
- 7个检查点位置和旋转 (CHECKPOINTS 数组)
- 终点位置: `Vector3(-115.077791, 1.5, 6.507477)`
- 生成位置: `StartGrid.get_single_player_slot()`

**生成内容**: Finish Area3D + 7个 CheckPoint Area3D + 碰撞体

### 2.4 `check_point_1.gd` / `finish.gd` - 触发器
简单的 Area3D，body_entered 触发 race_manager.register_checkpoint/finish_race

### 2.5 `dashboard.gd` (177行) - 仪表盘绘制
**继承**: `Control`  
**使用 `_draw()` 自绘**:
- 速度表 (0-160 km/h)
- RPM 表 (红线闪烁效果)
- 挡位显示 (1-5, R)
- 最高速度、当前RPM 数值

---

## 3. 多人游戏架构 (Autoloads)

### 3.1 `NetworkManager` (`res://network/network_manager.gd`) - 核心网络层
**模式枚举**: `SINGLEPLAYER`, `HOST`, `CLIENT`  
**关键方法**:
- `init_eos()` - 读取 `eos_config.cfg` 初始化 EOS SDK
- `login(provider)` - 统一登入入口 (epic/discord/anonymous/devtool)
- `host_game()` - 创建 EOSGMultiplayerPeer listen server (peer_id=1)
- `join_game(host_user_id)` - 连接到 host 的 P2P 会话
- `disconnect_from_game()` - 断开连接回单人模式
- `send_chat_message(message, tab)` - 发送聊天消息到指定标签页
- `remote_chat_message(sender, text, tab)` - RPC 接收远端聊天消息

**信号**: `chat_message_received(sender, text, tab)` - 聊天消息收到

**EOS配置文件** (`res://eos_config.cfg`):
```
[eos]
product_name, product_version, product_id, sandbox_id, deployment_id, client_id, client_secret, encryption_key
[login]
method, devtool_server_url, devtool_credential_name
[discord]
client_id, client_secret
```

### 3.2 `LobbyManager` (`res://network/lobby_manager.gd`) - 大厅管理
**EOS Lobby 属性键**:
- `ready` (私有，玩家就绪状态)
- `peer_order` (开场顺序 JSON)
- `display_name`, `room_name`, `host_name`
- `game="3d_race"`, `map`, `mode`, `damage_mode`, `car_restriction`, `auto_start`

**流程**:
1. `create_lobby(room_config)` - 开房，建立 lobby + 启动 host_game()
2. `search_lobbies()` - 按 bucket_id 搜索公开房
3. `join_lobby(lobby)` - 加入，写入 display_name attribute，连接到 host
4. `set_ready(bool)` - 写入自己的 ready attribute
5. `start_match()` (仅host) - 验证全员就绪，写入 peer_order，广播 match_started

**玩家同步**: `_sync_members()` 将 lobby members 转为 players 数组，包含 `peer_id`, `product_user_id`, `name`, `ready`

### 3.3 `PlayerStorage` (`res://network/player_storage.gd`) - 云端存档
- 使用 EOS PlayerDataStorage 读写 `profile.json`
- 分块读写 (4096 bytes)

### 3.4 `AuthManager` (`res://scripts/auth_manager.gd`) - 认证门面
- 代理 NetworkManager 的登入/登出/EOS初始化
- 环境同步接口 `sync_environment_from_network(data)`
- 信号转发：login_succeeded, login_failed, logout, eos_initialized

### 3.5 `LeaderboardManager` (`res://network/leaderboard_manager.gd`) - 排行榜
- Stat: `race_time_ms` (毫秒，Min 聚合)
- Leaderboard ID: `race_time_battle`
- 提交成绩 + 查询排名

### 3.6 `EnvironmentManager` (`res://EnvironmentManager.gd`) - 环境同步
**同步字段**: weather_intensity, time_of_day, wind_direction, wind_speed
- 雨/雪粒子系统控制
- 程序化天空 + 太阳角度
- 车辆物理天气影响 (`car_player.update_weather_effects`)
- `get_environment_state()` / `set_environment_state()` 用于网络同步

---

## 4. EOS 插件结构 (`res://addons/epic-online-services-godot/`)

### 4.1 核心类 (heos/)
| 文件 | 功能 |
|------|------|
| `hauth.gd` | 认证 (EAS + Connect)，支持 DevTool/AccountPortal/Discord/匿名 |
| `hlobbies.gd` | 大厅搜索/创建/加入高层封装 |
| `hlobby.gd` | 大厅实例包装 (属性、成员、RTC、数据通道) |
| `hp2p.gd` | P2P 网络 (NAT类型、中继控制、端口范围) |
| `hstats.gd` | 统计数据上报 |
| `hleaderboards.gd` | 排行榜查询 |
| `hplatform.gd` | 平台初始化 |
| `hfriends.gd` | 好友系统 |
| `hachievements.gd` | 成就系统 |
| `hsessions.gd` | 会话管理 |

### 4.2 Runtime
- `runtime.gd` - `EOSGRuntime` autoload，每帧 `IEOS.tick()`，维护本地账号ID

---

## 5. 关键多人游戏数据流

```
大厅流程:
LobbyBrowser.search_requested
    → LobbyManager.search_lobbies() → HLobbies.search_by_bucket_id_async()
    → LobbyBrowser.set_results() → UI显示房间列表
    
用户点击加入:
LobbyBrowser.join_requested(lb)
    → LobbyManager.join_lobby(lb) → HLobbies.join_async()
    → 写入 display_name attribute → _sync_members()
    → NetworkManager.join_game(host_user_id) → EOSGMultiplayerPeer.create_client()
    → peer_connected 信号 → 游戏场景加载

准备/开始:
ReadyButton.pressed → LobbyManager.set_ready(true) → lobby.update_async()
    → LobbyManager._on_lobby_updated() → _sync_members() → ready_state_changed
    → Host点击开始 → LobbyManager.start_match() → 写入 peer_order → match_started
    → 所有客户端收到 match_started → 切换到 main.tscn → 比赛开始
```

---

## 6. 现有问题/待完善项

### 6.1 玩家生成同步
- `main.tscn` 中只有 `PlayerSpawner` (MultiplayerSpawner)
- `player.tscn` 需要作为可实例化场景
- 当前 `race_course_setup.gd` 直接配置 `/Main/Player`，多人时需改为 spawner 实例化

### 6.2 环境同步
- `EnvironmentManager.sync_from_network(data)` 已存在
- 需要在 NetworkManager 或 LobbyManager 中添加 RPC 调用同步 host 的环境状态

### 6.3 比赛状态同步
- 当前 `race_manager.gd` 仅单人模式
- 多人模式需要：检查点同步、比赛开始/结束同步、排名同步

### 6.4 车辆状态同步
- `player.gd` 物理状态 (position, rotation, velocity, gear, rpm)
- 需要添加 `@rpc` 方法或使用 MultiplayerSynchronizer

---

## 7. 下一步建议 (多人模式实施顺序)

1. **PlayerSpawner 配置** - 设置 `player.tscn` 为 spawn 场景，配置 spawn 函数
2. **玩家脚本网络化** - 添加 `@rpc("authority", "call_remote")` 同步输入/状态
3. **RaceManager 多人适配** - 分离单人/多人逻辑，添加网络同步
4. **环境同步** - Host 定期 RPC 广播 EnvironmentManager 状态
5. **大厅→游戏场景切换** - 确保 LobbyManager.match_started 正确触发场景切换
6. **测试验证** - 双开测试连接、同步、重连

---

## 8. 相关文件清单

| 类别 | 文件 |
|------|------|
| 核心场景 | `main.tscn`, `ui/lobby.tscn`, `player.tscn` |
| 车辆物理 | `player.gd`, `dashboard.gd` |
| 比赛逻辑 | `race_manager.gd`, `race_course_setup.gd`, `check_point_1.gd`, `finish.gd` |
| 网络核心 | `network/network_manager.gd`, `network/lobby_manager.gd` |
| 数据/认证 | `network/player_storage.gd`, `scripts/auth_manager.gd` |
| 排行榜 | `network/leaderboard_manager.gd` |
| 环境 | `EnvironmentManager.gd` |
| EOS插件 | `addons/epic-online-services-godot/heos/*.gd` |
| 配置 | `project.godot`, `eos_config.cfg` (需创建) |

---

*报告生成完成。待会处理多人部分时可参考此文档。*