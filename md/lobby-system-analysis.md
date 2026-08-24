# Lobby System Analysis

## Current State (2026-08-24)

### Architecture Overview

The lobby system consists of:
- **LobbyUI** (`res://ui/lobby_ui.gd`) - Main UI controller (972 lines, programmatic UI construction)
- **LobbyManager** (`res://network/lobby_manager.gd`) - EOS Lobby management singleton
- **NetworkManager** (`res://network/network_manager.gd`) - EOS P2P networking singleton
- **Theme** (`res://ui/race_theme.tres`) - Dark cyberpunk theme

### LobbyUI Structure (Programmatic)

The UI is built entirely in code via `_build_ui()` method creating:
1. **Header** - User card (left), Room card (center), Room settings button
2. **Inspector** - Left panel showing selected player's car info, stats, rank
3. **Chat Trigger** - Button to open floating chat
4. **Showcase/Slots** - Two car display slots (positions 660, 1000)
5. **Start/Ready Button** - Bottom right
6. **Floating Chat** - Tabbed chat (room/team/global) with input
7. **Room Overlay** - Modal for room settings (map, mode, privacy, etc.)
8. **Lobby Browser** - Modal for searching/joining public lobbies
9. **Customize View** - Car customization placeholder
10. **Toast System** - Temporary notifications

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
    "invite_code": String
}
```

### Signals (LobbyManager → LobbyUI)

| Signal | Payload | Purpose |
|--------|---------|---------|
| `lobby_created` | lobby_info: Dictionary | Room created successfully |
| `lobby_joined` | lobby_info: Dictionary | Joined room successfully |
| `member_joined` | member_id: String | Player joined lobby |
| `member_left` | member_id: String | Player left lobby |
| `ready_state_changed` | ready_map: Dictionary | Ready states updated |
| `match_started` | peer_order: Array | Race starting |

### Issues Identified

1. **Monolithic UI Code** - 972 lines in single file, all UI built programmatically
2. **Hardcoded Positions** - All Rect2 positions hardcoded (660, 1000, 315, etc.)
3. **No Reusable Components** - Each UI section rebuilt from scratch
4. **State/UI Coupling** - Business logic mixed with rendering
5. **Missing Features from HTML Prototype**:
   - Proper room browser with list view
   - Better chat message rendering
   - Player cards with avatars
   - Responsive layout
6. **No Theme Integration** - Uses custom StyleBoxFlat creation instead of theme
7. **No Accessibility** - No focus management, screen reader support

### HTML Prototype Reference (lobby_v4.html)

Key differences from current implementation:
- Uses Canvas 2D rendering (not applicable to Godot)
- Component-based render functions
- Hitbox-based interaction system
- Floating chat with upward expansion
- Room overlay with chip-row selectors
- Better visual hierarchy

### Refactoring Goals

1. **Component-Based Architecture** - Separate .tscn scenes for each UI component
2. **Theme-Driven Styling** - Use race_theme.tres properly
3. **Data Binding** - Separate model from view
4. **Signal-Based Communication** - Decouple components
5. **Responsive Layout** - Use Containers (HBox/VBox/Grid) instead of absolute positioning
6. **Accessibility** - Proper focus order, tooltips, high contrast

### File Structure Target

```
res://ui/lobby/
├── lobby.tscn                 # Main scene (Control root)
├── lobby_main.gd              # Main controller (thin)
├── components/
│   ├── header/
│   │   ├── header.tscn
│   │   ├── header.gd
│   │   ├── user_card.tscn
│   │   ├── user_card.gd
│   │   ├── room_card.tscn
│   │   └── room_card.gd
│   ├── inspector/
│   │   ├── inspector.tscn
│   │   ├── inspector.gd
│   │   ├── stat_bar.tscn
│   │   └── stat_bar.gd
│   ├── chat/
│   │   ├── chat_trigger.tscn
│   │   ├── chat_trigger.gd
│   │   ├── floating_chat.tscn
│   │   ├── floating_chat.gd
│   │   ├── chat_tab.tscn
│   │   ├── chat_tab.gd
│   │   ├── message_list.tscn
│   │   └── message_list.gd
│   ├── showcase/
│   │   ├── showcase.tscn
│   │   ├── showcase.gd
│   │   ├── car_slot.tscn
│   │   └── car_slot.gd
│   ├── ready_button/
│   │   ├── ready_button.tscn
│   │   └── ready_button.gd
│   ├── room_overlay/
│   │   ├── room_overlay.tscn
│   │   ├── room_overlay.gd
│   │   ├── chip_row.tscn
│   │   └── chip_row.gd
│   ├── lobby_browser/
│   │   ├── lobby_browser.tscn
│   │   ├── lobby_browser.gd
│   │   ├── lobby_row.tscn
│   │   └── lobby_row.gd
│   ├── customize/
│   │   ├── customize_view.tscn
│   │   └── customize_view.gd
│   └── toast/
│       ├── toast.tscn
│       └── toast.gd
└── resources/
    └── lobby_theme.tres       # Lobby-specific theme extensions
```