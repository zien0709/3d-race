extends Control

## 主頁大廳 UI — 移植自 lobby_v4.html 的互動邏輯。
## 純單人時：左側改車/車庫、聊天、房間設定皆為本機互動；
## 已透過 EOS 開房/入房時：玩家名單、就緒狀態、開始比賽接到 LobbyManager。

const REF := Vector2(1280, 720)

const C_BG := Color("#0f131c")
const C_PANEL := Color("#151c2b")
const C_PANEL_A := Color(0.059, 0.086, 0.133, 0.75)
const C_ACCENT := Color("#38bdf8")
const C_SELF := Color("#10b981")
const C_AMBER := Color("#f59e0b")
const C_MUTED := Color("#8b9bb4")
const C_WHITE := Color("#ffffff")
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)
const C_WIN := Color("#4ade80")
const C_LOSS := Color("#475569")

var selected_id := ""
var chat_open := false
var chat_tab := "room"
var room_overlay_open := false
var customize_view := false
var is_ready := false
# Lobby 狀態
var browser_open := false
var browser_busy := false
var browser_results: Array = []

var room_config := {
	"name": "abc's room",
	"map": "東京灣夜景",
	"mode": "經典競速",
	"privacy": "public",
	"max_players": 3,
	"car_restriction": "全開放",
	"damage_mode": "輕度",
	"auto_start": "倒數10秒",
	"spectator": true,
	"invite_code": "XKQR-7721",
}

var players: Array = []
var chat_messages: Array = []
var slot_buttons: Array = []

var user_card_btn: Button
var user_card_name: Label
var user_card_puid: Label
var room_btn: Button
var room_name_label: Label
var room_count_label: Label
var chat_trigger_btn: Button
var ready_btn: Button
var ready_sub: Label
var search_btn: Button
var leave_lobby_btn: Button

var insp_selected: Label
var insp_car: Label
var insp_score: Label
var insp_class: Label
var customize_btn: Button
var insp_rank: Label
var insp_lap: Label
var insp_dots: Array = []
var insp_bars: Array = []

var chat_root: Control
var chat_msgs_root: Control
var chat_input: LineEdit
var tab_btns: Dictionary = {}

var overlay_root: Control
var overlay_panel: Panel
var overlay_input: LineEdit
var overlay_invite: Label
var chips: Array = []
var spectator_btn: Button
var create_room_btn: Button
var leave_room_btn: Button

# Browser
var browser_root: Control
var browser_list: Control
var browser_status: Label

var customize_root: Control

var toast_panel: Panel
var toast_label: Label
var toast_tween: Tween


func _net() -> Variant:
	return get_node_or_null("/root/NetworkManager")


func _lobby() -> Variant:
	return get_node_or_null("/root/LobbyManager")


# ==========================================================================
# 生命週期
# ==========================================================================

func _ready() -> void:
	_build_header()
	_build_inspector()
	_build_chat_trigger()
	_build_showcase()
	_build_start_button()
	_build_chat_window()
	_build_overlay()
	_build_customize()
	_build_hint()
	_build_toast()
	_connect_network()
	_sync_players()
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, REF), C_BG, true)
	# 透視背景線（沿用 HTML 的消失點做法）
	var vx := REF.x * 0.65
	var vy := REF.y * 0.4
	var grid := Color(0.545, 0.608, 0.706, 0.04)
	for i in range(-400, 1700, 70):
		draw_line(Vector2(i, REF.y), Vector2(vx + (i - vx) * 0.15, vy), grid, 1.0)
	if not customize_view and not room_overlay_open:
		for i in players.size():
			_draw_slot(_slot_cx(i), 420.0, players[i])
	if customize_view:
		_draw_customize_decor()


func _draw_slot(cx: float, cy: float, p: Dictionary) -> void:
	var sel: bool = selected_id == str(p["id"])
	var accent: Color = C_SELF if p["is_self"] else C_ACCENT
	var n := 64
	var pts := PackedVector2Array()
	for a in range(n):
		var ang := TAU * float(a) / float(n)
		pts.append(Vector2(cx + 140.0 * cos(ang), cy + 45.0 * sin(ang)))
	var fill: Color = Color(0.082, 0.125, 0.196, 0.6) if not p["is_self"] else Color(0.062, 0.724, 0.508, 0.12)
	draw_polygon(pts, PackedColorArray([fill]))
	draw_polyline(pts, accent, 2.0 if not sel else 3.5)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.059, 0.086, 0.133, 0.88)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1 if not sel else 2)
	sb.border_color = accent
	draw_style_box(sb, Rect2(cx - 90, cy - 95, 180, 85))

	var font := get_theme_default_font()
	var car_text := "Car"
	var car_size := font.get_string_size(car_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	draw_string(font, Vector2(cx - car_size.x * 0.5, cy - 44), car_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, C_WHITE)

	draw_line(Vector2(cx - 100, cy + 68), Vector2(cx + 100, cy + 68), accent, 2.0)

	var name_text: String = "You" if p["is_self"] else str(p["name"])
	var ns := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(cx - ns.x * 0.5, cy + 102), name_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, accent)


func _draw_customize_decor() -> void:
	var n := 64
	var pts := PackedVector2Array()
	for a in range(n):
		var ang := TAU * float(a) / float(n)
		pts.append(Vector2(640.0 + 260.0 * cos(ang), 440.0 + 80.0 * sin(ang)))
	draw_polygon(pts, PackedColorArray([Color(0.062, 0.724, 0.508, 0.08)]))
	draw_polyline(pts, C_SELF, 2.0)


# ==========================================================================
# 建構 UI
# ==========================================================================

func _build_header() -> void:
	# 左上玩家卡（可點擊 → 登入 / 顯示登入狀態）
	user_card_btn = _btn(self, "", Rect2(30, 20, 230, 65), 1, C_WHITE,
			Color(0.082, 0.11, 0.169, 0.65), C_BORDER, 10, 1)
	user_card_btn.pressed.connect(_on_user_card_pressed)
	user_card_name = _label(user_card_btn, _display_name(), Vector2(20, 10), 18, C_WHITE)
	user_card_puid = _label(user_card_btn, _puid_text(), Vector2(20, 36), 12, C_MUTED)

	# 中央房間卡（點擊開房間設定）
	var c2w := 360.0
	var c2x := REF.x / 2.0 - c2w / 2.0
	room_btn = _btn(self, "", Rect2(c2x, 20, c2w, 65), 1, C_WHITE,
			Color(0.082, 0.11, 0.169, 0.65), C_ACCENT, 10, 1.3)
	room_btn.pressed.connect(_on_room_pressed)
	_label(room_btn, "ROOM", Vector2(24, 4), 10, C_MUTED)
	room_name_label = _label(room_btn, room_config["name"], Vector2(24, 24), 17, C_WHITE)
	room_count_label = _label(room_btn, " · 2/3", Vector2(24, 25), 15, C_ACCENT)
	var gear := _btn(room_btn, "⚙", Rect2(c2w - 40, 18, 26, 26), 13, C_ACCENT,
			Color(0.06, 0.2, 0.31, 0.5), Color(0.55, 0.75, 1, 0.3), 6, 1)
	gear.pressed.connect(_on_room_pressed)

	# 右側：搜尋房間 / 離開房間
	search_btn = _btn(self, "🔍 搜尋", Rect2(880, 28, 100, 34), 14, C_ACCENT,
			Color(0.22, 0.74, 0.97, 0.15), C_ACCENT, 8, 1)
	search_btn.pressed.connect(_on_search_pressed)
	leave_lobby_btn = _btn(self, "✕ 離開", Rect2(990, 28, 100, 34), 14, C_MUTED,
			Color(1, 1, 1, 0.04), C_BORDER, 8, 1)
	leave_lobby_btn.pressed.connect(_on_leave_lobby_pressed)
	leave_lobby_btn.visible = false


func _build_inspector() -> void:
	var p := _panel(self, Rect2(30, 100, 320, 480), C_PANEL_A, C_BORDER, 12, 1)
	insp_selected = _label(p, "SELECTED CAR", Vector2(24, 22), 11, C_MUTED)
	insp_car = _label(p, "…", Vector2(24, 46), 22, C_WHITE)

	_panel(p, Rect2(24, 78, 60, 24), Color(0.22, 0.74, 0.97, 0.2), Color.TRANSPARENT, 5, 0)
	insp_score = _label(p, "1520", Vector2(24, 78), 13, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 60)
	_panel(p, Rect2(90, 78, 30, 24), Color(0.96, 0.62, 0.04, 0.25), Color.TRANSPARENT, 5, 0)
	insp_class = _label(p, "S", Vector2(90, 78), 13, C_AMBER, HORIZONTAL_ALIGNMENT_CENTER, 30)
	customize_btn = _btn(p, "🛠 改車 / 車庫 →", Rect2(130, 78, 150, 24), 12, C_SELF,
			Color(0.062, 0.724, 0.508, 0.25), C_SELF, 5, 1)
	customize_btn.pressed.connect(_on_customize_pressed)

	_panel(p, Rect2(24, 114, 272, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(p, "段位", Vector2(24, 136), 13, C_MUTED)
	insp_rank = _label(p, "…", Vector2(105, 136), 14, C_WHITE)
	_label(p, "最佳單圈", Vector2(24, 162), 13, C_MUTED)
	insp_lap = _label(p, "…", Vector2(105, 162), 14, C_ACCENT)
	_label(p, "近5場", Vector2(24, 188), 13, C_MUTED)
	for i in range(5):
		insp_dots.append(_dot(p, Vector2(105 + i * 18, 184), 5, C_LOSS))

	_panel(p, Rect2(24, 208, 272, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(p, "車輛性能概要", Vector2(24, 230), 11, C_MUTED)
	var rows := ["極速", "操控", "加速"]
	for i in rows.size():
		var y := 252.0 + i * 22.0
		_label(p, rows[i], Vector2(24, y - 4), 12, C_MUTED)
		insp_bars.append(_bar(p, Vector2(70, y), 200, 8, 0.0, C_ACCENT))

	_panel(p, Rect2(24, 322, 272, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(p, "⋮ 詳細戰績（總場次 / 排名 / 歷史成績）", Vector2(24, 344), 11, C_MUTED)


func _build_chat_trigger() -> void:
	chat_trigger_btn = _btn(self, "💬 點擊輸入訊息…", Rect2(30, 596, 320, 56), 13, C_MUTED,
			Color(0.059, 0.086, 0.133, 0.75), C_BORDER, 10, 1, 18.0)
	chat_trigger_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chat_trigger_btn.pressed.connect(_on_chat_trigger_pressed)


func _build_showcase() -> void:
	var layer := Control.new()
	layer.name = "SlotLayer"
	layer.position = Vector2.ZERO
	layer.size = REF
	add_child(layer)
	_rebuild_slot_buttons(layer)


func _rebuild_slot_buttons(layer: Control) -> void:
	for b in slot_buttons:
		if is_instance_valid(b):
			b.queue_free()
	slot_buttons.clear()
	for i in players.size():
		var b := _btn(layer, "", _slot_rect(i), 1, Color.TRANSPARENT,
				Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
		b.pressed.connect(_on_slot_pressed.bind(i))
		slot_buttons.append(b)


func _slot_cx(i: int) -> float:
	var positions := [660.0, 1000.0, 400.0, 820.0]
	return positions[i % positions.size()]


func _slot_rect(i: int) -> Rect2:
	return Rect2(_slot_cx(i) - 100, 315, 200, 280)


func _build_start_button() -> void:
	ready_btn = _btn(self, "▶  開始計時賽", Rect2(1030, 620, 220, 60), 20, C_WHITE,
			Color(0.062, 0.724, 0.508, 0.95), C_SELF, 12, 2)
	ready_btn.pressed.connect(_on_start_pressed)
	ready_sub = _label(ready_btn, "單人模式 · 進入賽道", Vector2(0, 36), 11,
			Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 220)


func _build_chat_window() -> void:
	chat_root = Control.new()
	chat_root.name = "FloatingChat"
	chat_root.position = Vector2(30, 146)
	chat_root.size = Vector2(380, 440)
	chat_root.visible = false
	add_child(chat_root)

	_panel(chat_root, Rect2(0, 0, 380, 440), Color(0.04, 0.06, 0.1, 0.98), C_ACCENT, 14, 1.5)
	_label(chat_root, "聊天", Vector2(20, 10), 15, C_WHITE)
	var close := _btn(chat_root, "✕", Rect2(380 - 38, 14, 26, 26), 16, C_MUTED,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	close.pressed.connect(_on_chat_close_pressed)

	var tabs := [["room", "房間"], ["team", "隊伍"], ["global", "全域"]]
	var tw := (380.0 - 40.0) / 3.0
	for i in tabs.size():
		var b := _btn(chat_root, tabs[i][1], Rect2(20 + i * tw, 46, tw - 6, 28), 12,
				C_MUTED, Color(1, 1, 1, 0.04), Color(0.545, 0.608, 0.706, 0.18), 6, 1)
		b.pressed.connect(_on_tab_pressed.bind(tabs[i][0]))
		tab_btns[tabs[i][0]] = b

	chat_msgs_root = Control.new()
	chat_msgs_root.position = Vector2(20, 92)
	chat_msgs_root.size = Vector2(340, 250)
	chat_root.add_child(chat_msgs_root)

	chat_input = LineEdit.new()
	chat_input.position = Vector2(16, 440 - 52)
	chat_input.size = Vector2(348, 36)
	chat_input.placeholder_text = "輸入訊息…"
	chat_input.text_submitted.connect(_on_chat_sent)
	chat_root.add_child(chat_input)


func _build_overlay() -> void:
	overlay_root = Control.new()
	overlay_root.name = "RoomOverlay"
	overlay_root.position = Vector2.ZERO
	overlay_root.size = REF
	overlay_root.visible = false
	add_child(overlay_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.031, 0.059, 0.85)
	dim.position = Vector2.ZERO
	dim.size = REF
	overlay_root.add_child(dim)

	overlay_panel = _panel(overlay_root, Rect2(320, 30, 640, 660), Color("#131b29"), C_ACCENT, 12, 1.5)
	_label(overlay_panel, "房間設定", Vector2(0, 26), 20, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 640)

	# 房間名稱
	_label(overlay_panel, "房間名稱", Vector2(36, 74), 13, C_MUTED)
	overlay_input = LineEdit.new()
	overlay_input.position = Vector2(150, 66)
	overlay_input.size = Vector2(300, 30)
	overlay_input.placeholder_text = "輸入房間名稱…"
	overlay_panel.add_child(overlay_input)

	# 比賽設定
	_ov_divider(overlay_panel, 116, "比賽設定")
	_ov_chip_row(overlay_panel, "地圖", "map", 158, ["東京灣夜景", "阿爾卑斯山道", "城市街道"], 120)
	_ov_chip_row(overlay_panel, "模式", "mode", 200, ["經典競速", "淘汰賽", "計時挑戰"], 110)
	_ov_chip_row(overlay_panel, "最大人數", "maxp", 242, ["2人", "3人", "4人"], 60)
	_ov_chip_row(overlay_panel, "隱私設定", "privacy", 284, ["公開", "私人", "好友"], 80)

	# 進階規則
	_ov_divider(overlay_panel, 328, "進階規則")
	_ov_chip_row(overlay_panel, "車輛限制", "carr", 370, ["全開放", "僅S級", "僅A級"], 80)
	_ov_chip_row(overlay_panel, "傷害模式", "dmg", 412, ["關閉", "輕度", "完整"], 80)
	_ov_chip_row(overlay_panel, "自動開始", "auto", 454, ["立即開始", "倒數10秒"], 120)

	# 觀戰席
	_label(overlay_panel, "觀戰席", Vector2(36, 502), 13, C_MUTED)
	spectator_btn = _btn(overlay_panel, "● 開啟", Rect2(150, 494, 64, 28), 12, C_SELF,
			Color(0.062, 0.724, 0.508, 0.25), C_SELF, 13, 1)
	spectator_btn.pressed.connect(_on_spectator_pressed)

	# 邀請
	_ov_divider(overlay_panel, 540, "邀請")
	_label(overlay_panel, "邀請碼", Vector2(36, 586), 13, C_MUTED)
	var code_box := _panel(overlay_panel, Rect2(150, 578, 160, 28), Color(0, 0, 0, 0.3), C_BORDER, 6, 1)
	overlay_invite = _label(code_box, room_config["invite_code"], Vector2(14, 0), 13, C_ACCENT,
			HORIZONTAL_ALIGNMENT_LEFT, 160)
	var copy := _btn(overlay_panel, "📋 複製", Rect2(320, 578, 80, 28), 12, C_WHITE,
			Color(1, 1, 1, 0.04), C_BORDER, 6, 1)
	copy.pressed.connect(_on_copy_invite_pressed)

	# 取消 / 儲存
	var cancel := _btn(overlay_panel, "取消", Rect2(640 - 190, 616, 70, 34), 14, C_MUTED,
			Color(1, 1, 1, 0.04), C_BORDER, 6, 1)
	cancel.pressed.connect(_on_cancel_overlay)
	var save := _btn(overlay_panel, "儲存", Rect2(640 - 105, 616, 70, 34), 14, Color("#0f172a"),
			C_ACCENT, Color.TRANSPARENT, 6, 1)
	save.pressed.connect(_on_save_overlay)

	# 開房 / 離開房間（依 lobby 狀態顯示）
	create_room_btn = _btn(overlay_panel, "開房", Rect2(640 - 280, 616, 70, 34), 14, Color("#0f172a"),
			C_ACCENT, Color.TRANSPARENT, 6, 1)
	create_room_btn.pressed.connect(_on_create_room_pressed)
	leave_room_btn = _btn(overlay_panel, "離開", Rect2(640 - 190, 616, 70, 34), 14, C_MUTED,
			Color(1, 1, 1, 0.04), C_BORDER, 6, 1)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)


func _build_browser() -> void:
	browser_root = Control.new()
	browser_root.name = "LobbyBrowser"
	browser_root.position = Vector2.ZERO
	browser_root.size = REF
	browser_root.visible = false
	add_child(browser_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.031, 0.059, 0.85)
	dim.position = Vector2.ZERO
	dim.size = REF
	browser_root.add_child(dim)

	var panel := _panel(browser_root, Rect2(320, 40, 640, 640), Color("#131b29"), C_ACCENT, 12, 1.5)
	_label(panel, "搜尋房間", Vector2(0, 26), 20, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 640)
	var close := _btn(panel, "✕", Rect2(640 - 40, 14, 26, 26), 16, C_MUTED,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	close.pressed.connect(func(): _open_browser(false))

	var refresh := _btn(panel, "⟳ 重新搜尋", Rect2(36, 60, 120, 30), 12, C_ACCENT,
			Color(0.22, 0.74, 0.97, 0.15), C_ACCENT, 6, 1)
	refresh.pressed.connect(_on_search_pressed)

	browser_list = Control.new()
	browser_list.position = Vector2(36, 104)
	browser_list.size = Vector2(568, 520)
	panel.add_child(browser_list)

	browser_status = _label(panel, "點擊「重新搜尋」尋找公開房間", Vector2(36, 400), 14, C_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER, 568)


func _ov_divider(parent: Node, y: float, label: String) -> void:
	_panel(parent, Rect2(36, y, 568, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(parent, label, Vector2(36, y + 18), 11, C_ACCENT)


func _ov_chip_row(parent: Node, label: String, row: String, y: float, values: Array, chip_w: float) -> void:
	_label(parent, label, Vector2(36, y + 8), 13, C_MUTED)
	for i in values.size():
		var pos := Vector2(150 + i * (chip_w + 8), y)
		var b := _btn(parent, values[i], Rect2(pos, Vector2(chip_w, 28)), 12, C_MUTED,
				Color(1, 1, 1, 0.03), C_BORDER, 6, 1)
		b.pressed.connect(_on_chip_pressed.bind(row, values[i]))
		chips.append({"btn": b, "row": row, "value": values[i]})


func _build_customize() -> void:
	customize_root = Control.new()
	customize_root.name = "CustomizeView"
	customize_root.position = Vector2.ZERO
	customize_root.size = REF
	customize_root.visible = false
	add_child(customize_root)

	var bg := ColorRect.new()
	bg.color = Color("#0a0d14")
	bg.position = Vector2.ZERO
	bg.size = REF
	customize_root.add_child(bg)

	var back := _btn(customize_root, "← 返回大廳", Rect2(30, 25, 120, 36), 14, C_ACCENT,
			Color(0.22, 0.74, 0.97, 0.15), C_ACCENT, 18, 1)
	back.pressed.connect(_on_back_lobby_pressed)
	_label(customize_root, "🛠 車輛改裝與個人化", Vector2(170, 30), 22, C_WHITE)

	var card := _panel(customize_root, Rect2(460, 280, 360, 160), Color(0.024, 0.172, 0.125, 0.9),
			C_SELF, 16, 2)
	_label(card, "YOUR CAR 3D", Vector2(0, 40), 32, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 360)
	_label(card, "改裝預覽（3D 車庫占位）", Vector2(0, 96), 14, C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 360)


func _build_hint() -> void:
	_label(self, "點車位切換左側面板顯示對象 · 再點一次「自己的車」進入改車 · 點輸入框展開聊天",
			Vector2(340, 700), 12, Color(0.39, 0.45, 0.52, 1), HORIZONTAL_ALIGNMENT_CENTER, 600)


func _build_toast() -> void:
	toast_panel = _panel(self, Rect2(0, 20, 0, 40), Color(0.06, 0.09, 0.16, 0.96), C_ACCENT, 20, 1.5)
	toast_panel.visible = false
	toast_label = _label(toast_panel, "", Vector2(0, 0), 14, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0)


# ==========================================================================
# 網路
# ==========================================================================

func _connect_network() -> void:
	var nm = _net()
	var lm = _lobby()
	if nm and "mode_changed" in nm:
		nm.mode_changed.connect(func(_m): _on_network_update())
	if nm and "login_succeeded" in nm:
		nm.login_succeeded.connect(_on_network_update)
	if nm and "logged_out" in nm:
		nm.logged_out.connect(_on_network_update)
	if lm and "member_joined" in lm:
		lm.member_joined.connect(func(_id): _on_network_update())
	if lm and "member_left" in lm:
		lm.member_left.connect(func(_id): _on_network_update())
	if lm and "ready_state_changed" in lm:
		lm.ready_state_changed.connect(func(_m): _on_network_update())
	if lm and "match_started" in lm:
		lm.match_started.connect(_on_match_started)
	if lm and "lobby_created" in lm:
		lm.lobby_created.connect(func(info): _on_lobby_result("created", info))
	if lm and "lobby_joined" in lm:
		lm.lobby_joined.connect(func(info): _on_lobby_result("joined", info))


func _on_network_update() -> void:
	_sync_players()
	_refresh()


func _on_match_started(_order: Array) -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _sync_players() -> void:
	var lm = _lobby()
	var nm = _net()
	if not _in_lobby():
		players = _default_players()
	else:
		players = []
		for i in lm.players.size():
			var lp: Dictionary = lm.players[i]
			var d := _mock_for(i)
			players.append({
				"id": "p%d" % i,
				"name": lp.get("name", "玩家%d" % (i + 1)),
				"car_name": d["car_name"], "score": d["score"], "cls": d["cls"],
				"rank": d["rank"], "best_lap": d["best_lap"],
				"matches": d["matches"], "stats": d["stats"],
				"is_self": (nm and "LOCAL_PEER_ID" in nm) and lp.get("peer_id", 0) == nm.LOCAL_PEER_ID,
			})
	if selected_id == "" or not _player_exists(selected_id):
		selected_id = _self_id()
	if selected_id == "" and not players.is_empty():
		selected_id = players[0]["id"]
	if _in_lobby():
		if nm and "LOCAL_PEER_ID" in nm and lm.has_method("get_ready_map"):
			is_ready = lm.get_ready_map().get(nm.LOCAL_PEER_ID, false)
	_rebuild_slot_buttons(_slot_layer())


func _in_lobby() -> bool:
	var lm = _lobby()
	return lm != null and not lm.current_lobby.is_empty()


func _slot_layer() -> Control:
	for c in get_children():
		if c.name == "SlotLayer":
			return c
	return null


func _default_players() -> Array:
	var me: Dictionary = _mock_for(0).duplicate(true)
	me["id"] = "you"
	me["name"] = _display_name()
	me["is_self"] = true
	var other: Dictionary = _mock_for(1).duplicate(true)
	other["id"] = "abc"
	other["name"] = "abc"
	other["is_self"] = false
	return [me, other]


func _mock_for(i: int) -> Dictionary:
	var specs := [
		{"car_name": "Ferrari F8 Tributo", "score": 1520, "cls": "S", "rank": "🥇 黃金 III",
			"best_lap": "1:09.4", "matches": [true, true, false, true, false],
			"stats": {"speed": 0.88, "handling": 0.72, "accel": 0.85}},
		{"car_name": "Porsche GT3 RS", "score": 1485, "cls": "S", "rank": "🥈 白銀 I",
			"best_lap": "1:11.2", "matches": [false, true, true, false, true],
			"stats": {"speed": 0.82, "handling": 0.85, "accel": 0.70}},
		{"car_name": "Nissan GT-R", "score": 1390, "cls": "A", "rank": "🥉 黃金 IV",
			"best_lap": "1:14.8", "matches": [true, true, true, false, false],
			"stats": {"speed": 0.80, "handling": 0.78, "accel": 0.88}},
	]
	return specs[i % specs.size()]


func _display_name() -> String:
	var nm = _net()
	if nm and "is_logged_in" in nm and nm.is_logged_in and "display_name" in nm and nm.display_name != "":
		return nm.display_name
	return "UserName"


func _puid_text() -> String:
	var nm = _net()
	if nm and "is_logged_in" in nm and nm.is_logged_in and "product_user_id" in nm and nm.product_user_id != "":
		return "PUID: %s" % nm.product_user_id.substr(0, 8)
	return "PUID: 未登入"


# ==========================================================================
# 互動
# ==========================================================================

func _on_user_card_pressed() -> void:
	var nm = _net()
	if nm == null:
		toast("網路模組尚未載入")
		return
	if "is_logged_in" in nm and nm.is_logged_in:
		toast("已登入：%s" % nm.display_name)
		return
	toast("正在初始化 EOS…")
	if nm.has_method("init_eos") and nm.has_method("login"):
		if not ("is_eos_ready" in nm and nm.is_eos_ready):
			nm.init_eos()
			var cb := func(ok: bool, _msg: String) -> void:
				if ok:
					nm.login()
			nm.eos_initialized.connect(cb, CONNECT_ONE_SHOT)
		else:
			nm.login()
	else:
		toast("網路模組未就緒（EOS 待設定）")


func _on_room_pressed() -> void:
	room_overlay_open = true
	overlay_input.text = room_config["name"]
	_refresh()


func _on_slot_pressed(i: int) -> void:
	if i >= players.size():
		return
	var p: Dictionary = players[i]
	if selected_id == p["id"] and p["is_self"]:
		customize_view = true
	else:
		selected_id = p["id"]
	_refresh()


func _on_customize_pressed() -> void:
	customize_view = true
	_refresh()


func _on_back_lobby_pressed() -> void:
	customize_view = false
	_refresh()


func _on_chat_trigger_pressed() -> void:
	chat_open = not chat_open
	_refresh()


func _on_chat_close_pressed() -> void:
	chat_open = false
	_refresh()


func _on_tab_pressed(id: String) -> void:
	chat_tab = id
	_refresh_chat()


func _on_chat_sent(new_text: String) -> void:
	var t := new_text.strip_edges()
	if t == "":
		return
	chat_messages.append(["You", t])
	chat_input.clear()
	_refresh_chat()


func _on_start_pressed() -> void:
	var nm = _net()
	var lm = _lobby()
	var online: bool = nm != null and nm.has_method("is_online") and nm.is_online()
	if not online:
		get_tree().change_scene_to_file("res://main.tscn")
		return
	is_ready = not is_ready
	if lm != null and lm.has_method("set_ready"):
		await lm.set_ready(is_ready)
		if lm.is_host and _all_lobby_ready():
			await lm.start_match()
	_refresh()


func _on_spectator_pressed() -> void:
	room_config["spectator"] = not room_config["spectator"]
	_refresh_overlay()


func _on_chip_pressed(row: String, value: String) -> void:
	match row:
		"map":
			room_config["map"] = value
		"mode":
			room_config["mode"] = value
		"maxp":
			room_config["max_players"] = int(value.replace("人", ""))
		"privacy":
			room_config["privacy"] = {"公開": "public", "私人": "private", "好友": "friends"}[value]
		"carr":
			room_config["car_restriction"] = value
		"dmg":
			room_config["damage_mode"] = value
		"auto":
			room_config["auto_start"] = value
	_refresh_overlay()
	_refresh()


func _on_copy_invite_pressed() -> void:
	DisplayServer.clipboard_set(room_config["invite_code"])
	toast("已複製邀請連結")


func _on_save_overlay() -> void:
	var new_name := overlay_input.text.strip_edges()
	if new_name != "":
		room_config["name"] = new_name
		room_overlay_open = false
		var lm = _lobby()
		if lm != null and lm.is_host and not lm.current_lobby.is_empty():
			await lm.update_lobby_settings(room_config)
		toast("設定已儲存")
		_refresh()


func _on_cancel_overlay() -> void:
	room_overlay_open = false
	_refresh()


# ==========================================================================
# Lobby 操作：開房 / 搜房 / 加入 / 離開
# ==========================================================================

func _on_search_pressed() -> void:
	_open_browser(true)
	if not browser_busy:
		call_deferred("_do_search")

func _do_search() -> void:
	var nm = _net()
	if nm == null or not nm.is_logged_in:
		toast("請先登入（點左上玩家卡）")
		_open_browser(false)
		return
	var lm = _lobby()
	if lm == null:
		toast("房間模組未就緒")
		_open_browser(false)
		return
	browser_busy = true
	browser_status.text = "搜尋中…"
	_render_browser_list()
	var results: Array = await lm.search_lobbies()
	browser_busy = false
	browser_results = results
	_render_browser_list()

func _render_browser_list() -> void:
	for c in browser_list.get_children():
		c.queue_free()
	if browser_results.is_empty():
		if browser_busy:
			browser_status.text = "搜尋中…"
		else:
			browser_status.text = "找不到公開房間（確認 host 已開房且設為公開）"
		return
	browser_status.text = "找到 %d 間房間" % browser_results.size()
	var y := 0.0
	for i in browser_results.size():
		var lb = browser_results[i]
		var host := _lobby_attr(lb, "host_name", "Host")
		var room := _lobby_attr(lb, "room_name", host + " 的房間")
		var max_p: int = int(lb.max_members)
		var avail: int = int(lb.available_slots)
		var count: int = max_p - avail
		var row := _panel(browser_list, Rect2(0, y, 568, 64), Color(1, 1, 1, 0.03), C_BORDER, 8, 1)
		_label(row, room, Vector2(16, 10), 16, C_WHITE)
		_label(row, "%s  ·  %d/%d" % [host, count, max_p], Vector2(16, 36), 12, C_MUTED)
		var join := _btn(row, "加入", Rect2(568 - 90, 16, 70, 30), 13, Color("#0f172a"), C_ACCENT, Color.TRANSPARENT, 6, 1)
		join.pressed.connect(_on_join_pressed.bind(lb))
		if count >= max_p:
			join.disabled = true
			join.text = "已滿"
		y += 72.0

func _lobby_attr(lb, key: String, fallback: String = "") -> String:
	if lb == null:
		return fallback
	var attr = lb.get_attribute(key)
	if attr is Dictionary and not attr.is_empty() and attr.has("value"):
		return str(attr["value"])
	return fallback

func _on_join_pressed(lb) -> void:
	var lm = _lobby()
	if lm == null:
		toast("房間模組未就緒")
		return
	browser_busy = true
	toast("正在加入房間…")
	await lm.join_lobby(lb)
	# 結果透過 lobby_joined signal 處理

func _on_create_room_pressed() -> void:
	var nm = _net()
	if nm == null:
		toast("網路模組尚未載入")
		return
	if not nm.is_logged_in:
		toast("請先登入（點左上玩家卡）")
		return
	var lm = _lobby()
	if lm == null:
		toast("房間模組未就緒")
		return
	if not lm.current_lobby.is_empty():
		toast("已在房間中")
		return
	room_overlay_open = false
	toast("正在建立房間…")
	await lm.create_lobby(room_config)

func _on_leave_room_pressed() -> void:
	room_overlay_open = false
	var lm = _lobby()
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
	toast("已離開房間")
	_sync_players()
	_refresh()

func _on_leave_lobby_pressed() -> void:
	var lm = _lobby()
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
	toast("已離開房間")
	_sync_players()
	_refresh()

func _on_lobby_result(kind: String, info: Dictionary) -> void:
	browser_busy = false
	if info.is_empty():
		toast("失敗：%s 失敗" % ("開房" if kind == "created" else "加入"))
		return
	_open_browser(false)
	room_overlay_open = false
	# invite code 用 lobby_id 前段
	room_config["invite_code"] = str(info.get("lobby_id", "")).substr(0, 12).to_upper()
	if info.get("is_host", false):
		toast("已開房，等待其他玩家加入")
	else:
		toast("已加入房間")
	_sync_players()
	_refresh()

func _open_browser(open: bool) -> void:
	browser_open = open
	browser_root.visible = open
	if open:
		call_deferred("_do_search")
	_refresh()


func _all_lobby_ready() -> bool:
	var lm = _lobby()
	if lm == null:
		return false
	var lp: Array = lm.players if "players" in lm else []
	for p in lp:
		if p is Dictionary and not p.get("ready", false):
			return false
	return true


# ==========================================================================
# 刷新
# ==========================================================================

func _refresh() -> void:
	# header
	user_card_name.text = _display_name()
	user_card_puid.text = _puid_text()

	# room
	room_name_label.text = room_config["name"]
	var font := room_name_label.get_theme_font("font")
	var nw := font.get_string_size(room_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	room_count_label.text = "  ·  %d/%d" % [players.size(), room_config["max_players"]]
	room_count_label.position = Vector2(24 + nw, 25)

	# inspector
	var p := _selected_player()
	if not p.is_empty():
		insp_selected.text = "SELECTED CAR" if p["is_self"] else "SELECTED CAR  ·  檢視 %s" % p["name"]
		insp_car.text = p["car_name"]
		insp_score.text = str(p["score"])
		insp_class.text = p["cls"]
		customize_btn.visible = p["is_self"]
		insp_rank.text = p["rank"]
		insp_lap.text = p["best_lap"]
		for i in insp_dots.size():
			var win: bool = p["matches"][i]
			_set_dot_color(insp_dots[i], C_WIN if win else C_LOSS)
		var bar_color: Color = C_SELF if p["is_self"] else C_ACCENT
		var names := ["speed", "handling", "accel"]
		for i in insp_bars.size():
			insp_bars[i].value = float(p["stats"][names[i]]) * 100.0
			_set_bar_color(insp_bars[i], bar_color)

	# chat trigger + window
	_style_button(chat_trigger_btn,
			Color(0.059, 0.086, 0.133, 0.75),
			C_ACCENT if chat_open else C_BORDER, 10, 1.5 if chat_open else 1.0, 18.0)
	chat_root.visible = chat_open
	_refresh_chat()

	# overlay / customize / ready
	overlay_root.visible = room_overlay_open
	customize_root.visible = customize_view
	_refresh_overlay()
	_refresh_ready_button()

	queue_redraw()


func _refresh_chat() -> void:
	for c in chat_msgs_root.get_children():
		c.queue_free()
	var y := 0.0
	for m in chat_messages:
		_label(chat_msgs_root, m[0] + ":", Vector2(0, y), 13, _chat_color(m[0]))
		_label(chat_msgs_root, m[1], Vector2(0, y + 16), 13, C_MUTED)
		y += 42.0
	for id in tab_btns:
		var b: Button = tab_btns[id]
		var active: bool = chat_tab == str(id)
		_style_button(b, Color(0.22, 0.74, 0.97, 0.25) if active else Color(1, 1, 1, 0.04),
				C_ACCENT if active else Color(0.545, 0.608, 0.706, 0.18), 6, 1)
		b.add_theme_color_override("font_color", C_ACCENT if active else C_MUTED)
		b.add_theme_color_override("font_hover_color", C_ACCENT)


func _refresh_overlay() -> void:
	for c in chips:
		var active: bool = _is_active(c["row"], c["value"])
		_style_button(c["btn"], Color(0.22, 0.74, 0.97, 0.2) if active else Color(1, 1, 1, 0.03),
				C_ACCENT if active else C_BORDER, 6, 1)
		c["btn"].add_theme_color_override("font_color", C_ACCENT if active else C_MUTED)
		c["btn"].add_theme_color_override("font_hover_color", C_ACCENT if active else C_WHITE)
	var on: bool = room_config["spectator"]
	_style_button(spectator_btn, Color(0.062, 0.724, 0.508, 0.25) if on else Color(1, 1, 1, 0.05),
			C_SELF if on else C_BORDER, 13, 1)
	spectator_btn.text = "● 開啟" if on else "○ 關閉"
	spectator_btn.add_theme_color_override("font_color", C_SELF if on else C_MUTED)
	overlay_invite.text = room_config["invite_code"]
	# 依房間狀態顯示 / 隱藏按鈕
	var in_lobby: bool = _in_lobby()
	leave_room_btn.visible = in_lobby
	create_room_btn.visible = not in_lobby
	# 離開 btn 顯示狀態
	leave_lobby_btn.visible = in_lobby
	if in_lobby:
		var lm = _lobby()
		if lm and lm.is_host:
			leave_room_btn.text = "離開房間"
		else:
			leave_room_btn.text = "離開"
	create_room_btn.text = _display_name() + " 的房間"
	# 房間名稱與人數
	var lm = _lobby()
	if in_lobby and lm and lm.current_lobby is Dictionary:
		room_name_label.text = _lobby_attr(lm.get_attribute("room_name") if "get_attribute" in lm else null, "", room_config["name"])
		room_count_label.text = "  ·  %d/%d" % [lm.players.size(), lm.max_members]


func _is_active(row: String, value: String) -> bool:
	match row:
		"map":
			return room_config["map"] == value
		"mode":
			return room_config["mode"] == value
		"maxp":
			return room_config["max_players"] == int(value.replace("人", ""))
		"privacy":
			return room_config["privacy"] == {"公開": "public", "私人": "private", "好友": "friends"}[value]
		"carr":
			return room_config["car_restriction"] == value
		"dmg":
			return room_config["damage_mode"] == value
		"auto":
			return room_config["auto_start"] == value
	return false


func _refresh_ready_button() -> void:
	var nm = _net()
	var lm = _lobby()
	var online: bool = nm != null and nm.has_method("is_online") and nm.is_online()
	if not online:
		_style_button(ready_btn, Color(0.062, 0.724, 0.508, 0.95), C_SELF, 12, 2)
		ready_btn.text = "▶  開始計時賽"
		ready_sub.text = "單人模式 · 進入賽道"
		return
	if lm != null and lm.is_host and _all_lobby_ready():
		_style_button(ready_btn, Color(0.95, 0.55, 0.13, 1.0), Color(1, 0.7, 0.2, 1), 12, 2)
		ready_btn.text = "🏁  開始比賽"
		ready_sub.text = "所有人已就緒"
		return
	if is_ready:
		_style_button(ready_btn, Color(0.1, 0.5, 0.4, 0.95), C_SELF, 12, 2)
		ready_btn.text = "✔  已準備 (READY)"
		ready_sub.text = "點擊取消準備"
	else:
		_style_button(ready_btn, Color(0.062, 0.724, 0.508, 0.95), C_SELF, 12, 2)
		ready_btn.text = "READY"
		ready_sub.text = "等待房主發車…"


func _chat_color(who: String) -> Color:
	if who == "System":
		return C_ACCENT
	if who == "You":
		return C_SELF
	return C_WHITE


func toast(msg: String) -> void:
	toast_label.text = msg
	var w := toast_label.get_theme_font("font").get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 40.0
	toast_label.size = Vector2(w, 40)
	toast_panel.size = Vector2(w, 40)
	toast_panel.position = Vector2((REF.x - w) / 2.0, 20)
	toast_panel.visible = true
	toast_panel.modulate = Color.WHITE
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.4)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.tween_callback(func(): toast_panel.visible = false)


func _selected_player() -> Dictionary:
	for p in players:
		if p["id"] == selected_id:
			return p
	if players.is_empty():
		return {}
	return players[0]


func _self_id() -> String:
	for p in players:
		if p["is_self"]:
			return p["id"]
	return ""


func _player_exists(id: String) -> bool:
	for p in players:
		if p["id"] == id:
			return true
	return false


# ==========================================================================
# 元件小工具
# ==========================================================================

func _panel(parent: Node, rect: Rect2, bg: Color, border: Color, radius: float, bw: float) -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(int(bw))
	sb.border_color = border
	sb.set_corner_radius_all(int(radius))
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(parent: Node, text: String, pos: Vector2, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.horizontal_alignment = align
	if w > 0:
		l.size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, rect: Rect2, font_size: int, color: Color, bg: Color,
		border: Color, radius: float, bw: float, cm_left := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", color)
	b.add_theme_color_override("font_focus_color", color)
	_style_button(b, bg, border, radius, bw, cm_left)
	parent.add_child(b)
	return b


func _style_button(b: Button, bg: Color, border: Color, radius: float, bw: float, cm_left := 0.0) -> void:
	b.add_theme_stylebox_override("normal", _sb(bg, border, radius, bw, cm_left))
	var hbg: Color = bg.lightened(0.15) if bg.a > 0.05 else bg
	b.add_theme_stylebox_override("hover", _sb(hbg, border, radius, bw, cm_left))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.15), border, radius, bw, cm_left))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _sb(bg_c: Color, border_c: Color, radius: float, bw: float, cm_left: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_c
	sb.set_corner_radius_all(int(radius))
	if bw > 0:
		sb.set_border_width_all(int(bw))
		sb.border_color = border_c
	if cm_left > 0:
		sb.content_margin_left = cm_left
	return sb


func _bar(parent: Node, pos: Vector2, w: float, h: float, value: float, color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.position = pos
	pb.size = Vector2(w, h)
	pb.min_value = 0.0
	pb.max_value = 100.0
	pb.value = value
	pb.show_percentage = false
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(1, 1, 1, 0.08)
	bg_sb.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("background", bg_sb)
	_set_bar_color(pb, color)
	parent.add_child(pb)
	return pb


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = color
	fill_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_sb)


func _dot(parent: Node, pos: Vector2, r: float, color: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(r * 2, r * 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	_set_dot_color(p, color)
	return p


func _set_dot_color(p: Panel, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(5)
	p.add_theme_stylebox_override("panel", sb)
