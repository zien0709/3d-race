# Lobby System Analysis

## Current State (2026-08-26)

### Architecture Overview

The lobby system consists of:
- **LobbyMain** (`res://ui/lobby/lobby_main.gd`) - Thin coordinator managing component communication and LobbyManager integration (590 lines)
- **Lobby Components** (`res://ui/lobby/components/`) - Self-building UI components (programmatic, no .tscn required)
- **LobbyManager** (`res://network/lobby_manager.gd`) - EOS Lobby management singleton
- **NetworkManager** (`res://network/network_manager.gd`) - EOS P2P networking singleton  
- **AuthManager** (`res://scripts/auth_manager.gd`) - Thin delegation layer for NetworkManager
- **Theme** (`res://ui/race_theme.tres`) - Dark cyberpunk theme

### LobbyMain Structure (Thin Controller)

The controller connects signals between components and the LobbyManager:
1. **Header** (`header.gd`) - User card, Room card, action buttons (create/leave/browser)
2. **Inspector** (`inspector.gd`) - Left panel showing selected player's car info, stats, rank
3. **Chat Trigger** (`chat_trigger.gd`) - Button to open floating chat
4. **Showcase** (`showcase.gd`) - Two car display slots with slot selection
5. **Ready Button** (`ready_button.gd`) - Bottom right, shows different states based on role
6. **Floating Chat** (`floating_chat.gd`) - Tabbed chat (room/team/global) with input
7. **Room Overlay** (`room_overlay.gd`) - Modal for room settings with chip-row selectors
8. **Lobby Browser** (`lobby_browser.gd`) - Modal for searching/joining public lobbies
9. **Customize View** (`customize_view.gd`) - Car customization placeholder
10. **Toast** (`toast.gd`) - Temporary notifications

All components are **self-building** - they create their own child nodes programmatically. No .tscn files needed for components.

### Data Model

```gdscript
# Player entry
{
    "id": String,           # product_user_id
    "name": String,         # display name
    "car_name": String,     # vehicle name
    "score": int,           # ranking score
    "cls": String,          # rank class (S, A, B...)
    "rank": String,         # rank title
    "best_lap": String,     # best lap time
    "matches": Array[bool], # last 5 match results
    "stats": {              # performance bars
        "speed": float,
        "handling": float,
        "accel": float
    },
    "is_self": bool
}

# Room config
{
    "name": String,
    "map": String,
    "mode": String,
    "privacy": "public"|"private"|"friends",
    "max_players": int,
    "car_restriction": String,
    "damage_mode": String,
    "auto_start": String,
    "spectator": bool,
    "invite_code": String,
    "host_name": String,    # host's display name
}
```

### Signals (LobbyManager → LobbyMain)

| Signal | Payload | Purpose |
|--------|---------|---------|
| `lobby_created` | lobby_info: Dictionary | Room created successfully |
| `lobby_joined` | lobby_info: Dictionary | Joined room successfully |
| `member_joined` | member_id: String | Player joined lobby |
| `member_left` | member_id: String | Player left lobby |
| `ready_state_changed` | ready_map: Dictionary | Ready states updated |
| `match_started` | peer_order: Array | Race starting |
| `lobby_updated` | (via lobby attributes) | Room config changed (host only) |

### Signals (NetworkManager)

| Signal | Payload | Purpose |
|--------|---------|---------|
| `mode_changed` | mode: int | Transport mode changed |
| `peer_connected` | peer_id: int | Peer connected |
| `peer_disconnected` | peer_id: int | Peer disconnected |
| `eos_initialized` | success: bool, message: String | EOS init result |
| `login_succeeded` | | Login successful |
| `login_failed` | message: String | Login failed |
| `logged_out` | | Logged out |
| `discord_oauth_started` | | Discord OAuth started |
| `discord_oauth_completed` | code: String, error: String | OAuth callback result |

### Component Signals (to LobbyMain)

| Component | Signal | Payload |
|-----------|--------|---------|
| Header | `room_settings_requested` | |
| Header | `create_room_requested` | |
| Header | `leave_room_requested` | |
| Header | `leave_lobby_requested` | |
| Header | `browser_requested` | |
| Inspector | `customize_requested` | |
| Chat Trigger | `chat_toggled` | opened: bool |
| Floating Chat | `tab_changed` | tab: String |
| Floating Chat | `message_sent` | text: String |
| Floating Chat | `closed` | |
| Showcase | `slot_selected` | index: int, is_self: bool |
| Ready Button | `pressed` | |
| Room Overlay | `config_changed` | row: String, value: String |
| Room Overlay | `saved` | |
| Room Overlay | `cancelled` | |
| Lobby Browser | `search_requested` | |
| Lobby Browser | `join_requested` | lobby_info: Dictionary |
| Lobby Browser | `closed` | |
| Customize View | `back_requested` | |

### LobbyManager Public API

| Method | Description |
|--------|-------------|
| `create_lobby(room_config)` | Create lobby with config, returns lobby info |
| `join_lobby(lobby_info)` | Join existing lobby |
| `leave_lobby()` | Leave current lobby |
| `update_lobby_settings(room_config)` | Host updates lobby attributes |
| `set_ready(is_ready)` | Set local player ready state |
| `get_ready_map()` | Get all players' ready states |
| `start_match(auto_start)` | Host starts match |
| `search_lobbies()` | Search public lobbies |
| `get_display_name()` | Get local player display name |
| `get_local_player_id()` | Get local player product_user_id |
| `is_online()` | Check if in online mode |
| `max_members` | Property: max members in current lobby |

### Refactoring Goals (Completed)

1. ✅ **Component-Based Architecture** - Self-building components in `ui/lobby/components/`
2. ✅ **Theme-Driven Styling** - Uses `race_theme.tres` properly
3. ✅ **Data Binding** - Room config centralized in `lobby_main.gd`
4. ✅ **Signal-Based Communication** - Components emit signals, LobbyMain coordinates
5. ✅ **Responsive Layout** - Uses Containers (HBox/VBox/Grid) instead of absolute positioning

### Current Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Lobby create/join/leave | ✅ Working | EOS Lobbies integration |
| Room settings sync | ✅ Working | Host writes, clients sync via `lobby_updated` |
| Ready state sync | ✅ Working | Member attributes via EOS |
| Player list display | ✅ Working | Inspector + Showcase |
| Chat | ✅ Working | P2P via NetworkManager |
| Auto-create room on login | ✅ Working | Phase C implementation |
| Local room identification | ✅ Working | `owner_product_user_id` comparison |

### Issues Identified (To Be Addressed in Phase D)

1. **Non-host read-only** - Non-host can currently modify all room settings
2. **Advanced rules not grayed** - "Damage mode" and "Vehicle restriction" editable by all
3. **Ready/Start coupling** - Ready button logic not properly decoupled from start race
4. **Auto-start not implemented** - `auto_start` config value stored but not processed
5. **Fixed max_players** - Hardcoded default of 3, should be dynamic
6. **Player slots not dynamic** - UI doesn't adjust based on `max_players`

### File Structure (Actual)

```
res://ui/lobby/
├── lobby.tscn                 # Main scene (Control root "Lobby" with lobby_main.gd)
├── lobby_main.gd              # Thin controller
├── lobby_ui.gd                # Legacy (to be removed)
├── components/
│   ├── header/
│   │   ├── header.gd
│   │   ├── user_card.gd
│   │   ├── room_card.gd
│   │   └── settings_button.gd
│   ├── inspector/
│   │   ├── inspector.gd
│   │   ├── stat_bar.gd
│   │   └── match_dots.gd
│   ├── chat/
│   │   ├── chat_trigger.gd
│   │   ├── floating_chat.gd
│   │   └── message_list.gd
│   ├── showcase/
│   │   ├── showcase.gd
│   │   └── car_slot.gd
│   ├── ready_button/
│   │   └── ready_button.gd
│   ├── room_overlay/
│   │   ├── room_overlay.gd
│   │   └── chip_row.gd
│   ├── lobby_browser/
│   │   ├── lobby_browser.gd
│   │   └── lobby_row.gd
│   ├── customize/
│   │   └── customize_view.gd
│   └── toast/
│       └── toast.gd
└── resources/
    └── (uses race_theme.tres from root)
```