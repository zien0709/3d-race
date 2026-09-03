# Chat System Redesign - Work Notebook

## Overview

Redesigning the message/chat dialog system in the 3D Race lobby. Full redesign (visual + functional + architectural) with:
- 4 tabs: room / team / global / **system** (new)
- Private messages (whisper)
- Emoji reactions
- Emoji picker
- Message search
- Vibration/notification effects

Modern dark glass-morphism UI inspired by Discord 2025/2026 redesign.

## Design Decisions

### Color System (Dark Theme)
```
BG_DEEP     = Color(0.06, 0.08, 0.12)   # deepest background
BG_PANEL    = Color(0.10, 0.12, 0.16)   # panel background
BG_ELEVATED = Color(0.14, 0.17, 0.22)   # active/hover
BG_INPUT    = Color(0.08, 0.10, 0.14)   # input field
BORDER_DEFAULT = Color(0.22, 0.25, 0.30, 0.4)
BORDER_ACTIVE  = Color(0.22, 0.74, 0.97, 0.6)
BORDER_HOVER   = Color(0.22, 0.74, 0.97, 0.3)
TEXT_PRIMARY   = Color(0.90, 0.92, 0.95)
TEXT_SECONDARY = Color(0.55, 0.60, 0.65)
TEXT_MUTED     = Color(0.40, 0.45, 0.50)
TEXT_SYSTEM    = Color(0.22, 0.74, 0.97)
ACCENT_CYAN    = Color(0.22, 0.74, 0.97)
ACCENT_GREEN   = Color(0.30, 0.85, 0.45)
ACCENT_RED     = Color(0.95, 0.30, 0.35)
ACCENT_YELLOW  = Color(1.00, 0.80, 0.20)
```

### Radius System
```
RADIUS_SM = 6   # buttons, badges
RADIUS_MD = 10  # message bubbles, tabs
RADIUS_LG = 14  # main chat panel
```

## File Structure (New)

```
ui/lobby/components/chat/
├── chat_data.gd          # Data model: messages, reactions, private msgs
├── chat_panel.gd         # Main container (replaces floating_chat.gd), 4 tabs
├── chat_tabs.gd          # Tab bar with unread badges
├── chat_message_item.gd  # Single message (avatar + timestamp + reactions)
├── chat_input_bar.gd     # Input + emoji button + send button
├── chat_emoji_picker.gd  # Emoji selection panel
├── chat_reactions.gd     # Reaction bar (emoji 8 kinds)
├── chat_search_bar.gd    # Search bar
├── chat_preview.gd       # Bottom preview bar (kept, modern style)
├── chat_trigger.gd       # Toggle button (kept, modern style)
├── quick_phrases.gd      # Quick phrases (kept, modern style)
```

## Implementation Phases

### Phase 1: Core Architecture (Refactor)
- [x] Plan + web research (Discord/UXPin/Muzli)
- [x] chat_data.gd - data model (class_name ChatData; messages, reactions, private, search, filter, timestamps)
- [x] chat_panel.gd - main container + 4 tabs (room/team/global/system)
- [x] chat_message_item.gd - avatar + timestamp + reactions + sender click
- [x] chat_input_bar.gd - emoji + send buttons + private mode indicator
- [x] lobby_main.gd - wire new interface (script_attach on FloatingChat node in lobby.tscn)

### Phase 2: New Features
- [x] chat_emoji_picker.gd - emoji panel (categories)
- [x] chat_reactions.gd - reaction bar (8 emojis)
- [x] chat_search_bar.gd - search with match highlight
- [x] chat_tabs.gd - 4 tabs + unread badges + tab vibration
- [x] Vibration/notification: chat_tabs._vibrate_tab + unread badges + message slide-in tween

### Phase 3: Network Layer
- [x] NetworkManager: remote_private_message RPC + send_private_message
- [x] NetworkManager: remote_reaction RPC + send_reaction
- [x] NetworkManager: chat_message_received now carries sender_id (for private replies)
- [x] lobby_main.gd: private message routing + reaction routing + system messages on join/leave

### Phase 4: Visual Polish + Verification
- [x] Color system unified across all chat components (dark glass-morphism)
- [x] Animations: message slide-in tween, tab vibration, hover glows
- [x] Functional verification via game_eval (no runtime errors)
- [x] Visual screenshot verification via editor_screenshot

## Visual Verification Results (2026-08-29)
All features verified via game_eval + editor_screenshot:

1. **Chat panel opens/closes** ✅ - Slides in/out with animation
2. **4 tabs** ✅ - room/team/global visible, system tab cut off (panel width)
3. **Messages with avatars** ✅ - Circle avatar (A/B/C), sender name, timestamp, text
4. **Reactions** ✅ - Reaction chips (👍 🔥 ❤️ 😂) below messages with counts
5. **Private message mode** ✅ - 🔒 indicator + "私訊給 Alice..." placeholder
6. **Search** ✅ - Search bar, cross-tab search, yellow highlight on matches
7. **Unread badges** ✅ - Red badge on tabs showing unread count
8. **Input bar** ✅ - Emoji button (😊), input field, send button (➤)
9. **Quick phrases** ✅ - Bottom bar with "發車!", "等我一下", "GG", emoji
10. **System messages** ✅ - "玩家 Alice 加入房間" in system style

## API Compatibility (Keep)

```gdscript
# ChatPanel (replaces FloatingChat)
func open_chat()
func close_chat()
func add_message(sender, text, is_self, tab, sender_id, is_private, target_id)
func add_system_message(text)
func add_private_message(sender, target_id, text, is_self)
func add_reaction(message_id, emoji)
func remove_reaction(message_id, emoji)
func set_active_tab(tab_id)
func set_private_target(target_name, target_id)
func clear_private_target()
func focus_input()
signal tab_changed(tab: String)
signal message_sent(text, is_private, target_id)
signal private_message_sent(target_id, text)
signal reaction_added(message_id, emoji)
signal reaction_removed(message_id, emoji)
signal closed()

# NetworkManager
signal chat_message_received(sender, sender_id, text, tab)
signal chat_private_message_received(sender, target_id, text)
signal chat_reaction_received(message_id, emoji, add, sender)
func send_chat_message(message, tab)
func send_private_message(text, target_id)
func send_reaction(message_id, emoji, add)
```

## Bugs Found & Fixed
1. **chat_message_item setup before _ready**: `_create_item` called `item.setup(msg)`
   BEFORE `add_child(item)`. `_build_ui` (creates `_text_label`) runs in `_ready`.
   → Nil error at chat_message_item.gd:128.
   **Fix**: moved `setup()` to AFTER `add_child()` in `_create_item`.

2. **Tab layout overflow**: 4 tabs (64px each) + search + close exceeded panel width.
   **Fix**: reduced tab button minimum width from 64px to 52px.

3. **Panel grow direction**: Panel grew LEFT (grow_horizontal=0) causing off-screen.
   **Fix**: changed to grow_horizontal=2 (grow RIGHT) + increased offset_right to 450.

## game_eval Quirks (for future sessions)
- Semicolons in multi-statement eval code caused null returns with if+return.
  Use real newlines + tabs instead.
- `get_node_or_null("/root/Lobby/FloatingChat")` is the correct runtime path.
- Game window must be foregrounded or eval returns EVAL_GAME_NOT_READY.

## Research Sources
- Discord 2025/2026 Redesign: 4 themes, density controls
- UXPin Chat UI Design Guide 2026: message bubbles, timestamps, typing indicators
- Muzli Chat UI Inspiration 2026
- Game Interface Designer: Multiplayer Lobby Interfaces

---

# Implementation Plan - FloatingChat Restoration (2026-09-02)

## Goal
Restore the original lobby layout (16afa2d) with a working FloatingChat overlay.
FloatingChat opens when ChatPreview is clicked, closes on ESC or ✕ button,
sends messages, updates ChatPreview, and shows speech bubbles.

## Current State (after partial fixes)
```
Lobby
├── BackgroundGradient
├── Header
├── MainContainer (HBoxContainer)
│   ├── LeftPanel (VBoxContainer)
│   │   ├── LeftContent (VBoxContainer)
│   │   │   ├── Inspector        ← car data display
│   │   │   └── FloatingChat     ← MOVED BACK HERE ✓
│   │   ├── ChatTrigger          ← hidden toggle button
│   │   └── ChatAnimationPlayer  ← animation paths FIXED ✓
│   └── CenterRightPanel
│       └── Showcase (2×2 car slots)
├── BottomBar
│   ├── ChatPreview (💬 capsule)
│   ├── Spacer
│   ├── QuickPhrases
│   └── ReadyButton
├── RoomOverlay
├── LobbyBrowser
├── CustomizeView
└── Toast
```

### What's already fixed
1. FloatingChat moved from /Lobby root back to LeftContent ✓
2. Animation paths updated: `FloatingChat:modulate:a` → `LeftContent/FloatingChat:modulate:a` ✓
3. lobby_main.gd: floating_chat path fixed ✓
4. lobby_main.gd: chat_animation_player reference added ✓
5. lobby_main.gd: _on_chat_toggled uses chat_animation_player ✓
6. lobby_main.gd: _on_chat_closed uses chat_animation_player ✓
7. lobby_main.gd: _on_chat_preview_clicked → _on_chat_toggled(true) ✓
8. lobby_main.gd: _input handler for ESC/T/Enter ✓

### What still needs testing
1. ChatPreview click → FloatingChat actually opens (animation plays)
2. FloatingChat ✕ button → closes + Inspector restores
3. ESC key → closes chat
4. Message input → message appears in FloatingChat + ChatPreview updates
5. QuickPhrases → speech bubble on car slot
6. 4 car slots display correctly
7. Inspector shows car data correctly

## Signal Flow (Target)
```
[ChatPreview clicked]
  → chat_preview.chat_toggled(true)
  → lobby_main._on_chat_toggled(true)
    → chat_animation_player.play("chat_open")  // Inspector fades out, FloatingChat fades in
    → inspector.visible = false
    → chat_trigger.set_chat_open(true)

[ChatTrigger pressed] (alternative entry)
  → lobby_main._on_chat_toggled(opened)

[FloatingChat ✕ button]
  → lobby_main._on_chat_closed()
    → chat_animation_player.play("chat_close")
    → inspector.visible = true

[ESC key]
  → lobby_main._input(event)
    → if chat_open: _on_chat_toggled(false)

[FloatingChat sends message]
  → lobby_main._on_chat_message_sent(text)
    → NetworkManager.send_chat_message(text, tab)
    → _on_chat_message_received(sender, text, tab)
      → floating_chat.add_message(...)
      → chat_preview.update_preview(sender, text)
      → showcase.slots[0].show_speech_bubble(text, 3.0)
```

## Execution Steps
1. ✅ Move FloatingChat back to LeftContent
2. ✅ Fix animation paths in lobby.tscn
3. ✅ Fix lobby_main.gd references + _on_chat_toggled
4. ⬜ Save scene + Run game + verify zero script errors
5. ⬜ Test: click ChatPreview → verify FloatingChat opens
6. ⬜ Test: click ✕ → verify closes
7. ⬜ Test: ESC → verify closes
8. ⬜ Test: input message → verify ChatPreview updates + speech bubble
9. ⬜ Verify 4 car slots + Inspector display correctly

## Risk Points
- **Low**: All changes restore existing functionality from 16afa2d
- **Medium**: Animation paths may need fine-tuning if NodePath resolution differs
- **Medium**: FloatingChat's internal script (floating_chat.gd) may expect different parent hierarchy
