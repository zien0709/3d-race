# Phase H 執行笔记（主代理用）

## Node 路徑異動追蹤

### Step 3: ReadyButton 路徑異動
- **舊路徑**: `$MainContainer/CenterRightPanel/ReadyButton`
- **新路徑**: `$MainContainer/CenterRightPanel/BottomBar/ReadyButton`
- **影響**: lobby_main.gd @onready 需同步更新
- **策略**: Step 3 寫 .tscn 時同時更新 lobby_main.gd 的 @onready
- **動畫軌道**: 不影響（動畫軌道用 FloatingChat/Inspector 相對路徑，不涉及 ReadyButton）

### Step 9-10: 新增節點路徑（Step 12 整合）
- `$MainContainer/CenterRightPanel/BottomBar/ChatPreview`（新）
- `$MainContainer/CenterRightPanel/BottomBar/QuickPhrases`（新）
- `BottomBar` 需為 Control/PanelContainer，內含 HBoxContainer 排列子元素

### Step 12: lobby_main.gd @onready 更新
- 新增: `chat_preview`, `quick_phrases` 的 @onready
- 更新: `ready_button` 路徑

## 動畫軌道相容性
- chat_open/chat_close 動畫軌道目標: `FloatingChat:modulate:a`, `Inspector:modulate:a`, `FloatingChat:position:x`, `Inspector:position:x`
- 這些節點在新結構中保持在 `LeftContent` 內，路徑不變 ✅
