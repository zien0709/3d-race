# 聊天介面完整設計規格書

> **專案**：Z 3D Race — Lobby 聊天系統
> **版本**：2.0（Dock 模式 + 完整聊天面板雙模式）
> **靈感來源**：Discord 2025/2026 redesign、UXPin Chat UI Guide、Muzli
> **最後更新**：2026-09-06

---

## 目錄

1. [設計哲學](#1-設計哲學)
2. [色彩系統](#2-色彩系統)
3. [圓角系統](#3-圓角系統)
4. [動畫系統](#4-動畫系統)
5. [整體佈局](#5-整體佈局)
6. [雙模式架構：Dock + 面板](#6-雙模式架構dock--面板)
7. [元件詳解](#7-元件詳解)
8. [訊息資料模型](#8-訊息資料模型)
9. [完整 Signal 流](#9-完整-signal-流)
10. [使用者互動流程](#10-使用者互動流程)
11. [網路層 API](#11-網路層-api)
12. [快捷短語系統](#12-快捷短語系統)
13. [表情反應系統](#13-表情反應系統)
14. [搜尋系統](#14-搜尋系統)
15. [私訊系統](#15-私訊系統)
16. [Tab 系統](#16-tab-系統)
17. [Speech Bubble（車位氣泡）](#17-speech-bubble車位氣泡)
18. [已知 Bug 與修復](#18-已知-bug-與修復)

---

## 1. 設計哲學

### 核心理念
Dark glass-morphism — 聊天介面像一塊半透明的深色玻璃，浮在 lobby 主畫面上方。
不使用傳統的彈出式對話框，而是以 **底部 Dock 條** + **上滑展開面板** 的方式呈現，
類似手機 App 的底部 Sheet，但帶有遊戲風格的 cyan 發光邊框。

### 設計原則
- **暗色為主**：所有背景都是深色（`#0F1219` 附近），文字用淺色
- **Cyan 點綴**：`#38BDFA` 作為唯一強調色，用於邊框、下劃線、按鈕
- **微光邊框**：hover 時邊框發光（shadow + border_color 變亮）
- **圓角膠囊**：所有可互動元素都是膠囊形（`border-radius: 10-14px`）
- **滑入動畫**：所有狀態切換都有 tween 動畫（fade + slide），不瞬間跳變
- **零彈窗**：不使用 popup/dialog，所有浮動面板都是原地展開

### 語言
- 全介面使用繁體中文
- Tab 名稱：房間 / 隊伍 / 世界 / 系統
- 按鈕文字：送出 / 搜尋 / 聊天

---

## 2. 色彩系統

所有色彩必須使用以下常數，不可自行調配。

### 背景色

| 常數名 | RGBA | 用途 |
|---|---|---|
| `BG_DEEP` | `Color(0.06, 0.08, 0.12)` | 最深背景（Canvas 層） |
| `BG_PANEL` | `Color(0.10, 0.12, 0.16)` | 主面板背景（CarSlot、Inspector） |
| `BG_ELEVATED` | `Color(0.14, 0.17, 0.22)` | Hover / Active 狀態背景 |
| `BG_INPUT` | `Color(0.08, 0.10, 0.14)` | 輸入欄位背景 |
| `BG_CHAT` | `Color(0.08, 0.10, 0.14, 0.96)` | 聊天面板背景（96% 不透明度） |
| `BG_DOCK` | `Color(0.10, 0.13, 0.18)` | Dock 條背景 |
| `BG_MSG_SELF` | `Color(0.12, 0.18, 0.16)` | 自己訊息的背景（微綠） |
| `BG_MSG_OTHER` | `Color(0.10, 0.12, 0.16)` | 他人訊息的背景 |
| `BG_MSG_SYSTEM` | `Color(0.10, 0.14, 0.18)` | 系統訊息的背景（微藍） |
| `BG_AVATAR` | `Color(0.18, 0.22, 0.28)` | 頭像圓形背景 |
| `BG_RIBBON` | `Color(0.08, 0.10, 0.14, 0.95)` | Tab 列 Ribbon 背景 |
| `BG_CHIP` | `Color(0.12, 0.14, 0.18)` | 快捷短語晶片背景 |
| `BG_REACTION` | `Color(0.16, 0.20, 0.26)` | Reaction chip 背景 |
| `BG_EMOJI_PICKER` | `Color(0.12, 0.15, 0.20, 0.98)` | Emoji 選擇器背景 |

### 邊框色

| 常數名 | RGBA | 用途 |
|---|---|---|
| `BORDER_DEFAULT` | `Color(0.22, 0.25, 0.30, 0.4)` | 預設邊框 |
| `BORDER_ACTIVE` | `Color(0.22, 0.74, 0.97, 0.6)` | 選中 / Focus 邊框 |
| `BORDER_HOVER` | `Color(0.22, 0.74, 0.97, 0.3)` | Hover 邊框 |
| `BORDER_CHAT` | `Color(0.22, 0.74, 0.97, 0.5)` | 聊天面板邊框 |
| `BORDER_DOCK_HOVER` | `Color(0.22, 0.74, 0.97, 0.8)` | Dock Hover 邊框（更亮） |
| `BORDER_SELF` | `Color(0.30, 0.85, 0.45, 0.4)` | 自己訊息邊框（綠色） |
| `BORDER_REACTION` | `Color(0.22, 0.74, 0.97, 0.3)` | Reaction chip 邊框 |
| `BORDER_CHIP` | `Color(0.3, 0.85, 0.95, 0.5)` | 快捷短語晶片邊框 |
| `BORDER_CHIP_HOVER` | `Color(0.3, 0.85, 0.95, 0.8)` | 快捷短語晶片 Hover 邊框 |
| `BORDER_MSG_SYSTEM` | `Color(0.22, 0.74, 0.97, 0.3)` | 系統訊息邊框 |

### 文字色

| 常數名 | RGBA | 用途 |
|---|---|---|
| `TEXT_PRIMARY` | `Color(0.90, 0.92, 0.95)` | 主文字 |
| `TEXT_SECONDARY` | `Color(0.55, 0.60, 0.65)` | 次要文字（發送者名稱） |
| `TEXT_MUTED` | `Color(0.40, 0.45, 0.50)` | 淡化文字（時間戳、placeholder） |
| `TEXT_SYSTEM` | `Color(0.22, 0.74, 0.97)` | 系統訊息文字（cyan） |
| `TEXT_HIGHLIGHT` | `Color(1.0, 0.88, 0.30)` | 搜尋高亮文字（金黃色 `#FFE14D`） |

### 強調色

| 常數名 | RGBA | 用途 |
|---|---|---|
| `ACCENT_CYAN` | `Color(0.22, 0.74, 0.97)` | 主強調色（所有 cyan 元素） |
| `ACCENT_CYAN_GLOW` | `Color(0.22, 0.74, 0.97, 0.15)` | Hover 發光（shadow） |
| `ACCENT_CYAN_STRONG` | `Color(0.3, 0.85, 1.0)` | 送按鈕 Hover 背景 |
| `ACCENT_GREEN` | `Color(0.30, 0.85, 0.45)` | 成功 / 已準備 / 自己名稱 |
| `ACCENT_GREEN_FLASH` | `Color(0.30, 0.85, 0.45, 0.9)` | Dock 發送後綠色閃爍 |
| `ACCENT_RED` | `Color(0.95, 0.30, 0.35)` | 未讀 badge 背景 |
| `ACCENT_YELLOW` | `Color(1.00, 0.80, 0.20)` | 搜尋匹配高亮 |

### 陰影色

| 常數名 | RGBA | 用途 |
|---|---|---|
| `SHADOW_CHAT` | `Color(0.22, 0.74, 0.97, 0.15)` | 聊天面板陰影 |
| `SHADOW_CHAT_STRONG` | `Color(0.22, 0.74, 0.97, 0.2)` | 聊天面板 Focus 陰影 |
| `SHADOW_GREEN` | `Color(0.30, 0.85, 0.45, 0.3)` | Dock 發送後綠色陰影 |

---

## 3. 圓角系統

| 常數 | 值 | 用途 |
|---|---|---|
| `RADIUS_SM` | `6` | 按鈕、Tab 背景、badge |
| `RADIUS_MD` | `10` | 訊息氣泡、CarSlot、面板 |
| `RADIUS_LG` | `14` | 主聊天面板、Dock 條 |
| `RADIUS_PILL` | `16` | 快捷短語晶片（完全膠囊） |
| `RADIUS_CIRCLE` | `18`（min_size 的一半） | 頭像（36×36 → radius 18） |
| `RADIUS_BADGE` | `7` | 未讀計數 badge |

---

## 4. 動畫系統

所有動畫使用 Godot `Tween`，透過 `UIAnimations` singleton 或直接 `create_tween()`。
不使用 `AnimationPlayer`（Dock 模式下已移除）。

### 4.1 Hover 動畫

| 元素 | 效果 | 時長 | Easing |
|---|---|---|---|
| 任何按鈕 | `scale → 1.05` | `0.1s` | `TRANS_SINE, EASE_OUT` |
| Tab 按鈕 | `scale → 1.03` | `0.1s` | `TRANS_SINE` |
| Dock 條 | `border → BORDER_DOCK_HOVER` + `shadow_size → 4` | `0.2s` | 立即 |
| Emoji 按鈕 | `scale → 1.15` | `0.12s` | `TRANS_SINE` |
| Reaction chip | `scale → 1.08` | `0.1s` | `TRANS_SINE` |
| 搜尋按鈕 | `scale → 1.1` | `0.1s` | `TRANS_SINE` |

### 4.2 Press 動畫

| 元素 | 效果 | 時長 | Easing |
|---|---|---|---|
| 任何按鈕 | `scale → 0.95` | `0.08s` | `TRANS_QUAD, EASE_OUT` |
| Tab 按鈕 | `scale → 0.95`（透過 `_on_tab_gui_input`） | `0.07s` | `TRANS_SINE` |
| 快捷短語晶片 | `scale → 0.92`（via `scale_press`） | `0.08s` | - |
| Dock ✕ 按鈕 | `scale → 0.9` | `0.07s` | `TRANS_SINE` |

### 4.3 Release 動畫

| 元素 | 效果 | 時長 | Easing |
|---|---|---|---|
| 任何按鈕 | `scale → 1.0`（hovered 時 → 1.05） | `0.12s` | `TRANS_BACK, EASE_OUT` |
| Tab 按鈕 | `scale → 1.05`（hovered）/ `1.0` | `0.12s` | `TRANS_SINE` |
| 快捷短語晶片 | `scale → 1.0`（via `scale_release`） | `0.1s` | - |
| ChatTrigger | `scale → 1.1` 然後 `→ 1.02`(hovered)/`1.0` | `0.15s × 2` | `TRANS_BACK` |

### 4.4 Tab 切換動畫

| 效果 | 詳細 |
|---|---|
| 下劃線出現 | `ColorRect.modulate.a: 0 → 1`，`0.15s, TRANS_SINE` |
| 下劃線消失 | `ColorRect.modulate.a: 1 → 0`，`0.15s, TRANS_SINE` |
| Tab 背景色 | `btn_style.bg_color → C_HOVER_GLOW (active) / TRANSPARENT (inactive)`，`0.15s` |
| Tab 文字色 | `font_color → ACCENT_CYAN (active) / TEXT_MUTED (inactive)` |

### 4.5 訊息出現動畫

| 效果 | 詳細 |
|---|---|
| 新訊息進入 | `position.x: 20 → 0` + `modulate.a: 0 → 1`，`0.2s, TRANS_SINE, EASE_OUT` |
| 同時執行 | `tween.set_parallel(true)` 確保兩屬性同時 tween |

### 4.6 Panel 開關動畫

| 效果 | 詳細 |
|---|---|
| 面板開啟 | `modulate.a: 0 → 1`，`0.2s, TRANS_SINE, EASE_OUT` |
| 面板關閉 | `modulate.a: 1 → 0`，`0.2s, TRANS_SINE, EASE_IN` |
| 開啟前 | Kill 任何進行中的 close_tween |
| 關閉前 | Kill 任何進行中的 open_tween |
| 面板展開 | `offset_bottom: -76 → 0`（覆蓋 BottomBar 區域） |
| 面板收合 | `offset_bottom → -76`（在 close callback 中） |

### 4.7 Dock 動畫

| 效果 | 詳細 |
|---|---|
| Hover 發光 | `border → BORDER_DOCK_HOVER, shadow_size → 4, shadow_color → SHADOW_CHAT` |
| 離開 | `border → BORDER_DEFAULT, shadow_size → 0` |
| 開啟態 | `border → ACCENT_CYAN with 0.8 alpha, shadow_size → 4` |
| 發送後閃爍 | `border → ACCENT_GREEN_FLASH + SHADOW_GREEN`，`0.3s` 後恢復 |

### 4.8 Tab 振動動畫（新訊息提醒）

| 步驟 | 位移 | 時長 |
|---|---|---|
| 1 | `+0.5px X` | `0.05s` |
| 2 | `-0.5px X` | `0.05s` |
| 3 | `+0.5px X` | `0.05s` |
| 4 | `-0.5px X` | `0.05s` |
| 5 | `回到原位` | `0.05s` |

共 3 個來回（6 次位移），總時長 `0.3s`。

---

## 5. 整體佈局

### Lobby 場景樹

```
Lobby (Control, lobby_main.gd)
├── BackgroundGradient
├── Header (user_card + room_card + settings_button)
├── MainContainer (HBoxContainer)
│   ├── LeftPanel (VBoxContainer)
│   │   ├── LeftContent (VBoxContainer)
│   │   │   ├── Inspector (PanelContainer, inspector.gd)
│   │   │   └── FloatingChat (PanelContainer, floating_chat.gd)  ← 舊版聊天面板
│   │   ├── ChatTrigger (Button, chat_trigger.gd)  ← ⚠️ visible=true
│   │   └── ChatAnimationPlayer (AnimationPlayer)
│   └── CenterRightPanel
│       └── Showcase (PanelContainer, showcase.gd)
│           └── GridContainer (2×2)
│               ├── CarSlot 0 (PanelContainer, car_slot.gd)
│               ├── CarSlot 1
│               ├── CarSlot 2
│               └── CarSlot 3
├── BottomBar (HBoxContainer)
│   ├── ChatPreview (PanelContainer, chat_preview.gd)  ← 💬 膠囊
│   ├── Spacer (Control, SIZE_EXPAND_FILL)
│   ├── QuickPhrases (HBoxContainer, quick_phrases.gd)
│   └── ReadyButton (Button, ready_button.gd)
├── RoomOverlay (room_overlay.gd)
├── LobbyBrowser (lobby_browser.gd)
├── CustomizeView (customize_view.gd)
└── Toast (toast.gd)
```

### 尺寸規格

| 元素 | 最小尺寸 | 備註 |
|---|---|---|
| FloatingChat 面板 | `340 × 400` | 固定寬度 340px |
| ChatPreview 膠囊 | `0 × 40` (H × W) | 水平填充 |
| QuickPhrases | `0 × 38` (H) | 水平填充 |
| ChatTrigger 按鈕 | `90 × 32` | 固定 |
| CarSlot 卡片 | `240 × 280` | 固定 |
| 頭像 | `36 × 36` | 圓形 |
| Tab 按鈕 | `56 × 26` | 固定 |
| Badge | 自適應文字寬度 | 圓角 7px |
| 快捷短語晶片 | `56 × 34` | 圓角 12px |

---

## 6. 雙模式架構：Dock + 面板

聊天系統有兩種呈現模式，共用同一個 `lobby_main.gd` 控制器：

### 模式 A：Dock 條模式（chat_dock.gd）

**位置**：BottomBar 最左側（取代 ChatPreview 的位置）
**尺寸**：高度 50px，全寬填充
**外觀**：
- 深色背景 `BG_DOCK`，圓角 14px
- 左側 `💬` emoji + "點擊開啟聊天" 預覽文字
- 中間 4 個快捷短語晶片（膠囊樣式）
- 右側 `▲` 展開按鈕

**互動**：
- 點擊 Dock 條空白處 → 展開聊天面板
- 點擊快捷短語晶片 → 直接發送（帶 scale 動畫 + 綠色閃爍）
- 點擊 `▲` 按鈕 → 展開聊天面板
- Hover → 邊框發光 + shadow 出現
- 無訊息時顯示「點擊開啟聊天」
- 有新訊息時顯示 `[Tab名] 發送者: 訊息內容`，Tab 為系統時文字變 cyan

### 模式 B：完整聊天面板（floating_chat.gd / chat_panel.gd）

**位置**：LeftContent 區域（與 Inspector 同位，互斥顯示）
**尺寸**：寬 340px，高 400px（展開時覆盖 BottomBar）
**外觀**：
- 深色玻璃面板 `BG_CHAT`，圓角 14px，cyan 邊框
- 陰影 `SHADOW_CHAT`，shadow_size 8px
- `z_index = 10`（浮在最上層）

**結構**：
```
聊天面板
├── 頂部列 (HBoxContainer)
│   ├── Tab 按鈕 × 4（房間/隊伍/世界/系統）
│   ├── Spacer
│   └── ✕ 關閉按鈕
├── 搜尋列 (chat_search_bar.gd) ← 預設隱藏
├── 訊息列表 (ScrollContainer → VBoxContainer)
│   └── ChatMessageItem × N
└── 輸入列 (chat_input_bar.gd)
```

**開關動畫**：
1. 開啟：`modulate.a 0→1`（0.2s），同時 `offset_bottom -76→0`
2. 關閉：`modulate.a 1→0`（0.2s），callback 中 `offset_bottom → -76`

---

## 7. 元件詳解

### 7.1 ChatTrigger（聊天觸發按鈕）

**檔案**：`ui/lobby/components/chat/chat_trigger.gd`
**型別**：`extends Button`
**位置**：LeftPanel 底部（LeftContent 下方）
**信號**：`chat_toggled(opened: bool)`

**外觀**：
- 文字：`💬 聊天`
- 最小尺寸：`90 × 32`
- 背景：透明（flat = true）
- 文字色：`TEXT_MUTED`（關閉）/ `ACCENT_CYAN`（開啟）

**互動**：
- Hover → scale 1.02 → 1.0（TRANS_SINE, 0.15s）
- Press → scale 0.95（TRANS_QUAD, 0.08s）
- Release → scale 1.02（hovered）/ 1.0（TRANS_BACK, 0.12s）
- 按下 → `is_open = not is_open` → emit `chat_toggled(is_open)`

**方法**：
```gdscript
func set_chat_open(open_state: bool) -> void
  # 被 lobby_main 呼叫以同步狀態
  # 開啟時播放 scale 彈跳動畫 1.0 → 1.1 → 1.02/1.0
```

### 7.2 ChatPreview（底部預覽膠囊）

**檔案**：`ui/lobby/components/chat/chat_preview.gd`
**型別**：`extends PanelContainer`
**位置**：BottomBar 最左側
**信號**：`chat_toggled(opened: bool)`

**外觀**：
- 圓角膠囊形（radius 12px）
- 背景 `Color(0.1, 0.13, 0.18)`
- 邊框 `ACCENT_CYAN` alpha 0.4
- 左側 `💬` emoji + 右側預覽文字
- 最小高度 40px，水平填充

**互動**：
- Hover → 邊框 alpha 0.4→0.8 + shadow_size 4 + shadow_color
- 離開 → 恢復
- 點擊 → `chat_toggled.emit(true)` → 開啟聊天

**方法**：
```gdscript
func update_preview(sender: String, text: String) -> void
  # 更新預覽文字為 "發送者: 訊息內容"，文字色改為 TEXT_PRIMARY

func clear_preview() -> void
  # 重置為 "等待訊息..."，文字色改為 TEXT_MUTED
```

### 7.3 FloatingChat（聊天面板 — 舊版，仍在使用）

**檔案**：`ui/lobby/components/chat/floating_chat.gd`
**型別**：`extends PanelContainer`
**位置**：LeftContent/Inspector 下方
**信號**：`tab_changed(tab)`, `message_sent(text)`, `closed()`

**外觀**：
- 寬 340px，高 400px
- 深色背景 `C_BG = Color(0.04, 0.06, 0.1, 0.95)`
- Cyan 邊框 0.5 alpha
- 陰影 `shadow_size: 6, shadow_color: cyan 0.15`
- 圓角 12px

**Tab 定義**：`[["room", "房間"], ["team", "隊伍"], ["global", "世界"]]`
（⚠️ 缺少 "system" tab，需升級）

**結構**：
```
PanelContainer
└── VBoxContainer (separation: 8)
    ├── Header (HBoxContainer)
    │   ├── Tab 按鈕 × 3（flat, 56×26, font_size 13）
    │   ├── Spacer
    │   └── ✕ 關閉按鈕（flat, 24×24）
    ├── ScrollContainer
    │   └── VBoxContainer (_message_list, separation: 6)
    └── LineEdit (placeholder: "輸入訊息… (Enter 發送)", height: 36)
```

**Tab 切換**：
- 選中 Tab → 背景色 tween 到 `Color(0.22, 0.74, 0.97, 0.18)`，文字色 → 白
- 未選中 Tab → 背景色 tween 到 `TRANSPARENT`，文字色 → `C_MUTED`
- 每個 Tab 按鈕有 hover scale 動畫（1.05）

**方法**：
```gdscript
func open_chat() -> void
  # visible=true, move_to_front(), z_index=10
  # modulate.a 0→1 (0.2s), focus input

func close_chat() -> void
  # modulate.a 1→0 (0.2s), callback: visible=false

func add_message(sender, text, is_self) -> void
  # 建立 MessageItem, add_child, setup
  # slide-in 動畫 (x: 50→0, a: 0→1, 0.2s)
  # deferred scroll to bottom

func set_active_tab(tab_id) -> void
  # 更新 active_tab, 更新所有 tab 按鈕樣式

func focus_input() -> void
  # LineEdit.grab_focus()

func clear_messages() -> void
  # 移除所有 message list 子節點
```

### 7.4 ChatPanel（聊天面板 — 新版 Dock 模式）

**檔案**：`ui/lobby/components/chat/chat_panel.gd`
**型別**：`extends PanelContainer`
**信號**：`tab_changed`, `message_sent(text, is_private, target_id)`, `private_message_sent`, `reaction_added`, `reaction_removed`, `search_query_changed`, `closed()`

**外觀**：
- 錨定到底部（anchor_top=1.0, anchor_bottom=1.0）
- `offset_top=-476, offset_bottom=-76`（預設位置，高於 BottomBar）
- 開啟時 `offset_bottom=0`（覆蓋 BottomBar）
- 背景 `BG_CHAT`，圓角 14px
- Cyan 邊框 0.5 alpha + shadow 8px

**結構**：
```
PanelContainer
└── VBoxContainer (separation: 8)
    ├── Header (HBoxContainer)
    │   ├── ChatTabs (chat_tabs.gd) ← 4 tabs + 🔍 + badge
    │   └── ✕ 關閉按鈕
    ├── ChatSearchBar ← 預設隱藏
    ├── ScrollContainer
    │   └── VBoxContainer (_message_list)
    └── ChatInputBar (chat_input_bar.gd)
```

**子元件**（全部以 `preload()` + `new()` 動態建立）：
- `ChatTabs` — Tab 列
- `ChatSearchBar` — 搜尋列
- `ChatMessageItem` — 訊息項目
- `ChatInputBar` — 輸入列
- `ChatEmojiPicker` — Emoji 選擇器（float 在面板外）
- `ChatReactions` — Reaction 選擇器（float 在面板外）

### 7.5 ChatTabs（Tab 列）

**檔案**：`ui/lobby/components/chat/chat_tabs.gd`
**型別**：`extends HBoxContainer`
**信號**：`tab_selected(tab_id)`, `search_button_pressed()`

**Tab 定義**：
```gdscript
const TAB_DEFS := [
  ["room", "🏠", "房間"],
  ["team", "👥", "隊伍"],
  ["global", "🌍", "世界"],
  ["system", "⚙️", "系統"],
]
```

**外觀**：
- Ribbon 風格（Office 感），背景 `BG_RIBBON`，圓角 8px
- 最小高度 44px
- 每個 Tab = VBoxContainer（按鈕 + 下劃線 ColorRect）
- 下劃線：高度 3px，顏色 `ACCENT_CYAN`，選中時 `modulate.a=1`，否則 `0`
- Hover 背景：`C_HOVER_GLOW = Color(0.22, 0.74, 0.97, 0.15)`
- Active 背景：`Color(0.22, 0.74, 0.97, 0.2)`

**Badge（未讀計數）**：
- 位置：Tab 按鈕右上角（`anchor = TOP_RIGHT`）
- 圓角 7px，背景 `ACCENT_RED`，文字白色 font_size 9
- `count < 100` 顯示數字，`≥ 100` 顯示 "99+"
- 切換到該 Tab 時清除 badge

**振動動畫**（收到新訊息時）：
- 水平來回位移 0.5px × 3 次，每次 0.05s
- 只在非當前 Tab 時觸發

### 7.6 ChatMessageItem（單則訊息）

**檔案**：`ui/lobby/components/chat/chat_message_item.gd`
**型別**：`extends PanelContainer`
**信號**：`reaction_toggled(message_id, emoji)`, `reaction_panel_requested(message_id, item_rect)`, `sender_clicked(sender_name, sender_id)`

**外觀結構**：
```
PanelContainer (StyleBoxFlat, radius 10, border 1px)
└── HBoxContainer (separation: 8)
    ├── 頭像 (PanelContainer, 36×36, radius 18)
    │   └── Label (首字母, font_size 14)
    └── Content VBox (separation: 2)
        ├── Header HBox (separation: 6)
        │   ├── 發送者 Label (font_size 12)
        │   └── 時間 Label (font_size 10)
        ├── 文字 RichTextLabel (font_size 13, autowrap)
        └── Reaction Bar (HBoxContainer) ← 預設隱藏
```

**訊息類型樣式**：

| 類型 | 背景色 | 邊框色 | 頭像色 | 發送者文字色 |
|---|---|---|---|---|
| 自己 | `BG_MSG_SELF`（微綠） | `BORDER_SELF`（綠） | `ACCENT_GREEN` | `ACCENT_GREEN` |
| 他人 | `BG_MSG_OTHER` | `BORDER_DEFAULT` | `BG_AVATAR`（灰） | `TEXT_PRIMARY` |
| 系統 | `BG_MSG_SYSTEM` | `BORDER_MSG_SYSTEM` | `BG_AVATAR` | `TEXT_SYSTEM` |

**頭像**：顯示發送者名字的第一個字母（大寫），背景為灰色圓形。
系統訊息的頭像文字顯示 `?`。

**時間戳**：格式 `HH:MM`（24 小時制），私訊時後綴 ` 🔒`。

**Reaction chips**：
- 每個 emoji 一個 chip（Button, flat）
- 文字格式：`emoji + 空格 + 數量`（如 `👍 3`）
- 圓角 12px（膠囊），背景 `BG_REACTION`
- Hover → scale 1.08
- 點擊 → toggle reaction（加/移除）

**互動**：
- 右鍵訊息 → 出現 Reaction 選擇器
- 點擊發送者名稱 → 進入私訊模式（系統訊息和自己除外）
- 搜尋時 → 用 BBCode `[color=#FFE14D]...[/color]` 高亮匹配文字

### 7.7 ChatInputBar（輸入列）

**檔案**：`ui/lobby/components/chat/chat_input_bar.gd`
**型別**：`extends HBoxContainer`
**信號**：`message_submitted(text, is_private, target_id)`, `emoji_button_pressed()`, `expand_chat_requested()`, `phrase_selected(phrase)`

**結構**：
```
HBoxContainer (separation: 8, height: 56)
├── Phrase ScrollContainer
│   ├── Phrase Chips × N (Button, pill shape)
│   └── ⋯ Toggle Button
├── 😊 Emoji Button
├── 🔒 私訊 Indicator (Label, 預設隱藏)
├── LineEdit (placeholder: "輸入訊息… (Enter 發送，ESC 取消/關閉)")
├── 送出 Button (cyan background)
└── ⛶ Expand Button
```

**快捷短語晶片**：
- 圓角 16px（完全膠囊）
- 背景 `Color(0.22, 0.74, 0.97, 0.15)` + 邊框 cyan
- Hover → 背景 `Color(0.22, 0.74, 0.97, 0.3)`
- 點擊 → `phrase_selected.emit(phrase)` + 自動送出

**送出按鈕**：
- 背景 `ACCENT_CYAN`，文字深色
- Hover → `Color(0.3, 0.85, 1.0)`

**私訊模式**：
- 顯示 `🔒 → 目標名稱`
- Placeholder 變為 "私訊給 XXX… (ESC 取消)"
- 送出後自動退出私訊模式

**ESC 處理**：
- LineEdit 有 focus → 清空 + 退出私訊模式
- LineEdit 無 focus → 由 lobby_main 處理（關閉聊天）

### 7.8 ChatEmojiPicker（Emoji 選擇器）

**檔案**：`ui/lobby/components/chat/chat_emoji_picker.gd`
**型別**：`extends PanelContainer`
**信號**：`emoji_selected(emoji)`, `close_requested()`

**外觀**：
- 浮動面板（在聊天面板外，absolute position）
- 尺寸 `280 × 260`
- 背景 `BG_EMOJI_PICKER`，圓角 12px
- Cyan 邊框 + shadow

**Emoji 分類**：
```gdscript
EMOJI_CATEGORIES := {
  "常用": ["😀", "😂", "❤️", "👍", "🔥", "🎉", "😎", "🏆"],
  "表情": ["😊", "😍", "😘", "😜", "🤔", "😴", "😭", "😡", "🥳", "😱", "🤯", "😇"],
  "手勢": ["👋", "✌️", "🤙", "👏", "🙌", "🤝", "💪", "👀", "🫡", "🤞"],
  "賽車": ["🏎️", "🚗", "🏁", "🛣️", "⚡", "💨", "🏆", "🥇", "🔧", "⛽"],
  "符號": ["✅", "❌", "⚠️", "❓", "❗", "💯", "🔔", "📢", "⭐", "✨"],
}
```

**結構**：
```
PanelContainer
└── VBoxContainer
    ├── Header (HBoxContainer)
    │   ├── "選擇 Emoji" Label (cyan)
    │   └── ✕ Close Button
    └── ScrollContainer
        └── VBoxContainer
            ├── 分類 Label × 5
            └── GridContainer × 5 (columns: 6)
                └── Emoji Button × N (36×36, font_size 20)
```

**互動**：
- 點擊 Emoji → `emoji_selected.emit(emoji)` → 插入到輸入列
- 點擊 ✕ → 關閉面板
- Emoji 按鈕 Hover → scale 1.2

### 7.9 ChatReactions（Reaction 選擇器）

**檔案**：`ui/lobby/components/chat/chat_reactions.gd`
**型別**：`extends PanelContainer`
**信號**：`reaction_selected(emoji)`, `close_requested()`

**外觀**：
- 浮動面板，尺寸 `220 × 50`
- 同 Emoji Picker 風格

**8 種 Reaction Emoji**：
```gdscript
const REACTION_EMOJIS := ["❤️", "👍", "😂", "🔥", "👀", "💪", "🏆", "✨"]
```

**結構**：GridContainer（columns: 4），每格 40×40 emoji 按鈕。

### 7.10 ChatSearchBar（搜尋列）

**檔案**：`ui/lobby/components/chat/chat_search_bar.gd`
**型別**：`extends HBoxContainer`
**信號**：`search_changed(query)`, `search_closed()`

**結構**：
```
HBoxContainer (height: 40)
├── 🔍 Icon Label
├── LineEdit (placeholder: "搜尋訊息…")
├── Match Count Label ("N 筆")
└── ✕ Close Button
```

**互動**：
- 輸入文字 → 即時搜尋（`text_changed` signal）
- 跨所有 Tab 搜尋
- 匹配文字用黃色 BBCode 高亮
- 顯示匹配數量
- 關閉 → 恢復原本 Tab 的訊息列表

---

## 8. 訊息資料模型

**檔案**：`ui/lobby/components/chat/chat_data.gd`
**型別**：`extends RefCounted`, `class_name ChatData`

### 訊息結構

```gdscript
{
  "id": String,              # "{timestamp_ms}_{random_4digits}"
  "sender": String,          # 發送者暱稱（"System" 為系統訊息）
  "sender_id": String,       # product_user_id
  "text": String,            # 訊息內容
  "tab": String,             # "room" | "team" | "global" | "system"
  "timestamp": float,        # Unix timestamp
  "is_self": bool,           # 是否為本地玩家
  "is_private": bool,        # 是否為私訊
  "target_id": String,       # 私訊目標 ID（非私訊時為空）
  "reactions": Dictionary,   # { emoji: { "count": int, "user_ids": Array } }
}
```

### 靜態方法

| 方法 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `create_message()` | sender, sender_id, text, tab, is_self, is_private, target_id | Dictionary | 建立一般訊息 |
| `create_system_message()` | text | Dictionary | 建立系統訊息（sender="System", tab="system"） |
| `add_reaction()` | msg, emoji, user_id | void | 新增反應（防重複） |
| `remove_reaction()` | msg, emoji, user_id | void | 移除反應（計數歸零則刪除 key） |
| `has_user_reacted()` | msg, emoji, user_id | bool | 檢查是否已反應 |
| `filter_by_tab()` | messages, tab | Array | 按 Tab 過濾（排除私訊） |
| `filter_private_messages()` | messages, self_id | Array | 取得與自己相關的私訊 |
| `search_messages()` | messages, query | Array | 全文搜尋（不分大小寫） |
| `format_timestamp()` | unix_time | String | 格式化為 "HH:MM" |
| `format_timestamp_relative()` | unix_time | String | 相對時間（"剛才"、"N 分鐘前"） |

---

## 9. 完整 Signal 流

### 9.1 開啟聊天（兩條入口）

```
[入口 1：點擊 ChatPreview 膠囊]
  ChatPreview.gui_input → chat_toggled.emit(true)
    → lobby_main._on_chat_preview_clicked(true)
      → lobby_main._on_chat_toggled(true)
        → chat_open = true
        → floating_chat.open_chat()     # 面板 fade-in
        → inspector.visible = false      # 隱藏 Inspector
        → chat_trigger.set_chat_open(true)  # 更新 Trigger 按鈕狀態

[入口 2：點擊 ChatTrigger 按鈕]
  ChatTrigger.pressed → is_open = not is_open → chat_toggled.emit(is_open)
    → lobby_main._on_chat_toggled(opened)
      → 同上

[入口 3：按 T 鍵或 Enter 鍵]
  lobby_main._input → KEY_T/KEY_ENTER → _on_chat_toggled(not chat_open)
    → 同上

[入口 4：點擊 Dock 條（ChatDuck 模式）]
  ChatDock.gui_input → chat_toggled.emit(not _is_open)
    → lobby_main._on_chat_toggled(opened)
      → 同上
```

### 9.2 關閉聊天

```
[入口 1：點擊 ✕ 按鈕]
  FloatingChat.close_btn.pressed → closed.emit()
    → lobby_main._on_chat_closed()
      → chat_open = false
      → floating_chat.close_chat()      # 面板 fade-out
      → inspector.visible = true         # 恢復 Inspector
      → chat_trigger.set_chat_open(false)

[入口 2：按 ESC 鍵]
  lobby_main._input → KEY_ESCAPE → if chat_open: _on_chat_toggled(false)
    → chat_open = false
    → floating_chat.close_chat()
    → inspector.visible = true
    → chat_trigger.set_chat_open(false)

[入口 3：ChatInputBar 的 ESC 處理]
  ChatInputBar._unhandled_input → KEY_ESCAPE
    → if LineEdit 有 focus: 清空 + 退出私訊模式
    → 否則: 不處理（交給 lobby_main）
```

### 9.3 發送訊息

```
[FloatingChat 輸入]
  LineEdit.text_submitted → message_sent.emit(text)
    → lobby_main._on_chat_message_sent(text)
      → NetworkManager.send_chat_message(text, chat_tab)
        → rpc("remote_chat_message", sender, text, tab)
          → 所有 peer 收到
            → NetworkManager.remote_chat_message()
              → emits chat_message_received(sender, sender_id, text, tab)

[ChatPanel 輸入]
  ChatInputBar.message_submitted → lobby_main._on_chat_message_sent(text)
    → 同上

[快捷短語]
  QuickPhrases.phrase_selected → lobby_main._on_quick_phrase_selected(phrase)
    → NetworkManager.send_chat_message(phrase, "room")
    → local echo: _on_chat_message_received(sender_name, phrase, "room")
    → chat_preview.update_preview(sender_name, phrase)
    → showcase.slots[0].show_speech_bubble(phrase, 3.0)
```

### 9.4 接收訊息

```
NetworkManager.chat_message_received(sender, sender_id, text, tab)
  → lobby_main._on_chat_message_received(sender, sender_id, text, tab)
    → chat_messages.append({sender, text, tab})
    → if tab == chat_tab:
        floating_chat.add_message(sender, text, is_self)
    → chat_preview.update_preview(sender, text)
```

⚠️ **Bug**：目前 `lobby_main.gd:331` 的 handler 簽名只有 3 參數 `(sender, text, tab)`，
但 `NetworkManager` 的 signal 有 4 參數 `(sender, sender_id, text, tab)`。
需要修復為 4 參數版本。

### 9.5 切換 Tab

```
Tab 按鈕被點擊
  → ChatTabs.set_active_tab(tab_id) + tab_selected.emit(tab_id)
    → FloatingChat.set_active_tab(tab_id)
      → 更新 active_tab
      → 更新所有 Tab 按鈕樣式（下劃線 + 文字色）
      → _rebuild_message_list()（清除 + 重新載入該 Tab 的訊息）

  → lobby_main._on_chat_tab_changed(tab)
    → chat_tab = tab
    → floating_chat.set_active_tab(tab)
    → _load_chat_history_for_tab(tab)
```

### 9.6 表情反應

```
[點擊 Reaction Chip]
  ChatMessageItem.reaction_toggled.emit(message_id, emoji)
    → ChatPanel._on_item_reaction_toggled(message_id, emoji)
      → ChatPanel._toggle_reaction(message_id, emoji)
        → ChatData.add_reaction() / remove_reaction()
        → reaction_added / reaction_removed.emit()
        → 更新 item.setup(msg) 重新渲染

[右鍵訊息]
  ChatMessageItem.gui_input → reaction_panel_requested.emit(message_id, rect)
    → ChatPanel._on_item_reaction_panel(message_id, rect)
      → ChatReactions.visible = true
      → ChatReactions.position = rect 上方
      → ChatReactions.set_target_message(message_id)

[選擇 Reaction]
  ChatReactions.reaction_selected.emit(emoji)
    → ChatPanel._on_reaction_selected(emoji)
      → _toggle_reaction(target_message_id, emoji)
      → ChatReactions.visible = false
```

### 9.7 點擊發送者名稱（進入私訊）

```
ChatMessageItem._on_sender_input → sender_clicked.emit(sender_name, sender_id)
  → ChatPanel._on_item_sender_clicked(sender_name, sender_id)
    → ChatPanel.set_private_target(sender_name, sender_id)
      → ChatInputBar.set_private_mode(true, "目標名稱", "target_id")
        → 顯示 "🔒 → 目標名稱"
        → Placeholder: "私訊給 目標名稱… (ESC 取消)"
    → ChatPanel.focus_input()
```

---

## 10. 使用者互動流程

### 流程 1：一般聊天

1. 玩家看到底部 Dock 條（💬 + 預覽文字 + 快捷短語）
2. 點擊 Dock 條 → 聊天面板從下方滑入
3. 預設顯示「房間」Tab
4. 輸入訊息 → Enter → 訊息出現在列表（帶 slide-in 動畫）
5. Dock 條預覽文字更新為最新訊息
6. 車位卡上出現 Speech Bubble（3 秒後消失）
7. 按 ESC 或 ✕ → 面板滑出，Inspector 恢復

### 流程 2：切換 Tab

1. 點擊「隊伍」Tab → 下劃線滑到「隊伍」
2. 訊息列表重建，只顯示隊伍訊息
3. 如果隊伍 Tab 有未讀 → badge 消除
4. 非當前 Tab 收到新訊息 → badge +1 + 振動

### 流程 3：私訊

1. 點擊某玩家的發送者名稱
2. 輸入列變為私訊模式（🔒 indicator）
3. 輸入訊息 → 只有目標玩家收到
4. 私訊顯示在「房間」Tab 中（帶 🔒 標記）
5. 按 ESC → 退出私訊模式（不關閉聊天）

### 流程 4：Reaction

1. 右鍵某則訊息
2. 出現 8 種 emoji 選擇器
3. 點擊 emoji → 訊息下方出現 reaction chip
4. 再次點擊同 emoji → 取消 reaction
5. Reaction chip 顯示 emoji + 數量

### 流程 5：搜尋

1. 點擊 🔍 按鈕 → 搜尋列展開
2. 輸入關鍵字 → 跨 Tab 即時搜尋
3. 匹配文字黃色高亮
4. 顯示匹配數量
5. 點擊 ✕ → 恢復原 Tab 訊息列表

### 流程 6：快捷短語

1. 在 Dock 條上點擊快捷短語晶片
2. 晶片 scale 0.92 → 1.0 回彈
3. Dock 條邊框綠色閃爍 0.3s
4. 訊息直接送出（不需要打開聊天面板）
5. Speech Bubble 顯示在車位卡上

---

## 11. 網路層 API

### NetworkManager

```gdscript
# Signals
signal chat_message_received(sender: String, sender_id: String, text: String, tab: String)
signal chat_private_message_received(sender: String, target_id: String, text: String)
signal chat_reaction_received(message_id: String, emoji: String, add: bool, sender: String)

# Methods
func send_chat_message(message: String, tab: String) -> void
  # rpc("remote_chat_message", display_name, product_user_id, message, tab) to all peers

func send_private_message(text: String, target_id: String) -> void
  # rpc("remote_private_message", ...) to all peers

func send_reaction(message_id: String, emoji: String, add: bool) -> void
  # rpc("remote_reaction", ...) to all peers
```

### RPC Handlers

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func remote_chat_message(sender, sender_id, text, tab) -> void
  # → emits chat_message_received(sender, sender_id, text, tab)

@rpc("any_peer", "call_remote", "reliable")
func remote_private_message(sender, sender_id, target_id, text) -> void
  # → emits chat_private_message_received(sender, target_id, text)

@rpc("any_peer", "call_remote", "reliable")
func remote_reaction(message_id, emoji, add, sender) -> void
  # → emits chat_reaction_received(message_id, emoji, add, sender)
```

---

## 12. 快捷短語系統

### Dock 條快捷短語（chat_dock.gd）

```gdscript
_phrases := [
  ["🚀 發車", "發車！"],
  ["⏳ 等我", "等我一下"],
  ["🏁 GG", "GG"],
  ["😄", "😄"],
]
```
- 顯示文字：左側格式（帶 emoji）
- 發送文字：右側格式（純文字）
- 點擊 → 直接發送（不打開聊天面板）
- 圓角 10px，hover 邊框發光 + shadow

### ChatInputBar 快捷短語（chat_input_bar.gd）

```gdscript
const DEFAULT_PHRASES := [
  "準備好了！",
  "好久不見",
  "這張圖不錯",
  "GG",
  "再來一局？",
  "有人要組隊嗎？",
  "車子調校怎麼樣？",
  "我先走了",
]
```
- 圓角 16px（完全膠囊）
- cyan 邊框 + 半透明背景
- 可透過 `⋯` 按鈕收合/展開
- 點擊 → 直接發送

### FloatingChat 快捷短語（quick_phrases.gd）

```gdscript
var _phrases: Array = ["Ready", "GG", "😄"]  # ⚠️ 只有 3 個，需恢復到 4+
```
- 圓角 12px 膠囊
- hover → 背景變亮 + 邊框 cyan
- 點擊 → scale 0.95 → 1.0 回彈
- 透過 `phrase_selected` signal 發送

---

## 13. 表情反應系統

### 8 種 Reaction Emoji

```gdscript
const REACTION_EMOJIS := ["❤️", "👍", "😂", "🔥", "👀", "💪", "🏆", "✨"]
```

### Reaction Chip 視覺

- 格式：`emoji + 空格 + 數量`（如 `👍 3`）
- 圓角 12px 膠囊
- 背景 `BG_REACTION`，邊框 `BORDER_REACTION`
- Hover → scale 1.08
- 已反應的 emoji 顯示為 `ACCENT_CYAN` 背景（區別）

### 資料結構

```gdscript
msg.reactions = {
  "👍": { "count": 2, "user_ids": ["id1", "id2"] },
  "🔥": { "count": 1, "user_ids": ["id3"] },
}
```

---

## 14. 搜尋系統

### 行為

1. 點擊 🔍 → 搜尋列從 Tab 列下方展開
2. 輸入關鍵字 → 即時過濾
3. **跨 Tab 搜尋**：結果不分 Tab，全部顯示
4. 匹配文字用 BBCode 黃色高亮：`[color=#FFE14D]匹配文字[/color]`
5. 顯示匹配數量（如 "3 筆"）
6. 關閉 → 恢復原 Tab 訊息列表

### 實作

```gdscript
# ChatPanel._on_search_changed
_search_query = query
_rebuild_message_list()  # 使用 ChatData.filter_by_tab + search_messages
for msg_id in _message_items:
    _message_items[msg_id].set_highlight(query)
```

---

## 15. 私訊系統

### 觸發方式

點擊訊息中的發送者名稱 → 進入私訊模式

### 私訊模式 UI

- 輸入列顯示 `🔒 → 目標名稱`
- Placeholder：`私訊給 目標名稱… (ESC 取消)`
- 送出後自動退出私訊模式

### 私訊在訊息列表中的顯示

- 顯示在「房間」Tab 中
- 時間戳後綴 ` 🔒`
- 背景與一般訊息相同
- 只有發送者和目標能看到

### 網路

```gdscript
NetworkManager.send_private_message(text, target_id)
  → rpc("remote_private_message", ...) to all peers
  → peer 收到後過濾 target_id → 只有目標處理
```

---

## 16. Tab 系統

### 4 個 Tab

| ID | 圖示 | 名稱 | 用途 |
|---|---|---|---|
| `room` | 🏠 | 房間 | 房間內所有玩家的訊息 + 私訊 |
| `team` | 👥 | 隊伍 | 隊友之間的訊息（組隊模式） |
| `global` | 🌍 | 世界 | 所有房間的廣播訊息 |
| `system` | ⚙️ | 系統 | 系統通知（加入/離開/設定變更） |

### Tab 行為

- 切換 Tab → 重建訊息列表（只顯示該 Tab 的訊息）
- 非當前 Tab 收到新訊息 → badge +1 + 振動
- 切換到該 Tab → badge 清除
- 「房間」Tab 額外顯示與自己相關的私訊

### System Tab 的訊息

自動產生的系統訊息：
- `玩家 {name} 加入房間`（member_joined）
- `玩家 {name} 離開房間`（member_left）
- `房主變更了設定`（room_config_updated）
- `比賽即將開始`（match_started）

---

## 17. Speech Bubble（車位氣泡）

**位置**：CarSlot 頂部浮動覆蓋
**檔案**：`ui/lobby/components/showcase/car_slot.gd`

### 外觀

- PanelContainer，圓角 10px
- 背景 `Color(0.1, 0.13, 0.18)`
- Cyan 邊框 0.7 alpha + shadow
- 距離卡片頂部 -36px（浮在上方）

### 動畫

1. 訊息到達 → `modulate.a 0→1`（0.25s, TRANS_SINE）
2. 停留 duration 秒（預設 3s）
3. `modulate.a 1→0`（0.4s, TRANS_SINE）
4. callback: `visible = false`

### 觸發

```gdscript
# QuickPhrase 發送時
showcase.slots[0].show_speech_bubble(phrase, 3.0)

# 一般訊息時
showcase.slots[0].show_speech_bubble(text, 3.0)
```

---

## 18. 已知 Bug 與修復

| # | Bug | 檔案:行 | 修復 |
|---|---|---|---|
| 1 | `car_slot.gd:5` emit `slot_clicked(is_self)` 但 `showcase.gd:86` bind 加了 `index`，`_on_slot_clicked(index, is_self)` 收到的 `is_self` 其實是 `index` | `showcase.gd:86,107` | `_on_slot_clicked` 參數順序需對調 |
| 2 | `quick_phrases.gd:12` 只有 3 個短語 `["Ready", "GG", "😄"]`，需恢復 4 組 `[display, send]` pair | `quick_phrases.gd:12` | 恢復 4 組 |
| 3 | `room_config_panel.gd:131` `spectator_check.pressed = config["spectator"]` Godot 4 parse error | `room_config_panel.gd:131` | 改為 `set_pressed()` |
| 4 | `NetworkManager` signal 有 4 參數，但 `lobby_main.gd:331` handler 只收 3 參數 | `lobby_main.gd:331` | 改為 4 參數 |
| 5 | `ambient_process_material.tres:13` Godot 3 `Gradient { }` 語法 | `particles/` | 轉 Godot 4 SubResource |
| 6 | `player_roster.tscn` uid mismatch | `player_roster.tscn` | 修正 uid |
| 7 | `ChatTrigger` 在 lobby.tscn 中 `visible = false` | `lobby.tscn` | 改為 `true` |

---

## 附錄 A：常見色彩快速參考

```gdscript
# === 在 .gd 檔案中使用 ===
const C_TEXT   = Color(0.85, 0.88, 0.92)
const C_MUTED  = Color(0.5, 0.55, 0.6)
const C_CYAN   = Color(0.3, 0.85, 0.95)
const C_GREEN  = Color(0.3, 0.9, 0.4)
const C_RED    = Color(0.95, 0.3, 0.35)
const C_YELLOW = Color(1.0, 0.8, 0.2)
const C_BORDER = Color(0.3, 0.35, 0.4, 0.3)
const C_EMPTY  = Color(0.4, 0.45, 0.5, 0.5)
const C_BG     = Color(0.04, 0.06, 0.1, 0.95)
```

## 附錄 B：File Map（grep 用）

```
ui/lobby/components/chat/chat_dock.gd        → Dock 條（底部膠囊 + 快捷短語）
ui/lobby/components/chat/chat_panel.gd       → 新版聊天面板（Dock 展開模式）
ui/lobby/components/chat/chat_tabs.gd        → Tab 列（4 tabs + badge + 振動）
ui/lobby/components/chat/chat_message_item.gd → 單則訊息（頭像 + 時間 + reactions）
ui/lobby/components/chat/chat_input_bar.gd   → 輸入列（短語 + emoji + 輸入 + 送出）
ui/lobby/components/chat/chat_emoji_picker.gd → Emoji 選擇器（5 分類）
ui/lobby/components/chat/chat_reactions.gd    → Reaction 選擇器（8 emoji）
ui/lobby/components/chat/chat_search_bar.gd   → 搜尋列
ui/lobby/components/chat/chat_data.gd         → 訊息資料模型
ui/lobby/components/chat/chat_preview.gd      → 底部預覽膠囊
ui/lobby/components/chat/chat_trigger.gd      → 開關按鈕（💬 聊天）
ui/lobby/components/chat/quick_phrases.gd     → 快捷短語（3 phrases，需修復）
ui/lobby/components/chat/floating_chat.gd     → 舊版聊天面板（3 tabs）
ui/lobby/components/chat/message_item.gd      → 舊版訊息項目
ui/lobby/components/showcase/car_slot.gd      → 車位卡 + Speech Bubble
ui/lobby/lobby_main.gd                        → 主控制器
ui/lobby/lobby.tscn                           → 場景
```
