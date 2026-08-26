extends Button

## ReadyButton - 主行動按鈕（開始計時賽 / READY / 開始比賽）
## 自建子節點（副標籤），場景只需掛一個空的 Button 加此腳本。

const C_SELF := Color(0.062, 0.724, 0.508)
const C_ACCENT := Color(0.22, 0.74, 0.97)

var _sub_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(320, 64)
	add_theme_font_size_override("font_size", 22)
	_sub_label = Label.new()
	_sub_label.text = ""
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 12)
	_sub_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sub_label.offset_top = -22
	_sub_label.offset_bottom = -6
	add_child(_sub_label)
	set_offline_mode()

func set_offline_mode() -> void:
	text = "▶  開始計時賽"
	_sub_label.text = "單人模式 · 進入賽道"
	_set_style(Color(0.062, 0.724, 0.508, 0.95), C_SELF)

func set_waiting_mode() -> void:
	text = "READY"
	_sub_label.text = "等待所有玩家就緒…"
	_set_style(Color(0.062, 0.724, 0.508, 0.95), C_SELF)

func set_ready_mode() -> void:
	text = "✔  已準備"
	_sub_label.text = "點擊取消準備"
	_set_style(Color(0.1, 0.5, 0.4, 0.95), C_SELF)

func set_host_ready_mode() -> void:
	text = "🏁  開始比賽"
	_sub_label.text = "所有人已就緒"
	_set_style(Color(0.95, 0.55, 0.13, 1.0), Color(1, 0.7, 0.2))

func set_auto_start_mode(countdown: int) -> void:
	text = "⏳  自動開始"
	_sub_label.text = "%d 秒後自動開始比賽" % countdown
	_set_style(Color(0.95, 0.55, 0.13, 1.0), Color(1, 0.7, 0.2))

func update_ready_state(is_ready: bool, lobby_manager: Object, auto_start_countdown: int = 0) -> void:
	var online: bool = lobby_manager != null and lobby_manager.has_method("is_online") and lobby_manager.is_online()

	if not online:
		set_offline_mode()
		return
	if lobby_manager != null and lobby_manager.is_host:
		if auto_start_countdown > 0:
			set_auto_start_mode(auto_start_countdown)
			return
		if _all_lobby_ready(lobby_manager):
			set_host_ready_mode()
			return
	if is_ready:
		set_ready_mode()
	else:
		set_waiting_mode()

func _all_lobby_ready(lm) -> bool:
	var lp: Array = lm.players if "players" in lm else []
	for p in lp:
		if p is Dictionary and not bool(p.get("ready", false)):
			return false
	return true

func _set_style(bg_color: Color, border_color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_border_width_all(2)
	sb.border_color = border_color
	sb.set_corner_radius_all(12)
	add_theme_stylebox_override("normal", sb)

	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = bg_color.lightened(0.15)
	add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb: StyleBoxFlat = sb.duplicate()
	pressed_sb.bg_color = bg_color.darkened(0.15)
	add_theme_stylebox_override("pressed", pressed_sb)
