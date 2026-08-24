extends Button

## UserCard - 玩家資料卡（header 左側，點擊觸發登入）

const C_MUTED := Color(0.6, 0.65, 0.7)

var _name_label: Label
var _puid_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(210, 46)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	_name_label = Label.new()
	_name_label.text = "UserName"
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)
	_puid_label = Label.new()
	_puid_label.text = "PUID: 未登入"
	_puid_label.add_theme_font_size_override("font_size", 11)
	_puid_label.add_theme_color_override("font_color", C_MUTED)
	_puid_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_puid_label)

func update_display(display_name: String, lobby_manager: Object) -> void:
	if _name_label == null:
		return
	_name_label.text = display_name if display_name != "" else "UserName"
	if lobby_manager != null and lobby_manager.has_method("puid_text"):
		_puid_label.text = str(lobby_manager.puid_text())
	else:
		_puid_label.text = "PUID: 未登入"
