extends Button

## UserCard - 玩家資料卡（header 左側，點擊觸發登入）

const C_MUTED := Color(0.6, 0.65, 0.7)
@onready var _ui_animations := UIAnimations

var _name_label: Label
var _puid_label: Label
var _copy_btn: Button

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
	
	var puid_hbox := HBoxContainer.new()
	puid_hbox.add_theme_constant_override("separation", 4)
	puid_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(puid_hbox)
	
	_puid_label = Label.new()
	_puid_label.text = "PUID: 未登入"
	_puid_label.add_theme_font_size_override("font_size", 11)
	_puid_label.add_theme_color_override("font_color", C_MUTED)
	_puid_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puid_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_puid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	puid_hbox.add_child(_puid_label)
	
	_copy_btn = Button.new()
	_copy_btn.flat = true
	_copy_btn.text = "📋"
	_copy_btn.tooltip_text = "複製 PUID"
	_copy_btn.custom_minimum_size = Vector2(20, 20)
	_copy_btn.add_theme_font_size_override("font_size", 12)
	_copy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_copy_btn.pressed.connect(_on_copy_pressed)
	puid_hbox.add_child(_copy_btn)

	mouse_entered.connect(func(): _ui_animations.kill_tweens(self); _ui_animations.scale_to(self, 1.05, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	mouse_exited.connect(func(): _ui_animations.kill_tweens(self); _ui_animations.scale_to(self, 1.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	button_down.connect(func(): _ui_animations.kill_tweens(self); _ui_animations.scale_to(self, 0.95, 0.07, Tween.TRANS_SINE, Tween.EASE_OUT))
	button_up.connect(func(): _ui_animations.kill_tweens(self); _ui_animations.scale_to(self, 1.05, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))

func update_display(display_name: String, lobby_manager: Object) -> void:
	if _name_label == null:
		return
	_name_label.text = display_name if display_name != "" else "UserName"
	if lobby_manager != null and lobby_manager.has_method("puid_text"):
		var puid_full: String = str(lobby_manager.puid_text())
		if puid_full.begins_with("PUID: "):
			var raw_id := puid_full.substr(6)
			if raw_id.length() > 16:
				_puid_label.text = "PUID: %s...%s" % [raw_id.substr(0, 8), raw_id.substr(-8)]
			else:
				_puid_label.text = puid_full
		else:
			_puid_label.text = puid_full
	else:
		_puid_label.text = "PUID: 未登入"

func _on_copy_pressed() -> void:
	if _puid_label == null:
		return
	var txt: String = _puid_label.text
	if txt.begins_with("PUID: "):
		txt = txt.substr(6).replace("...", "")
	DisplayServer.clipboard_set(txt)
	var lobby_main = get_parent().get_parent()
	if lobby_main != null and lobby_main.has_method("show_toast"):
		lobby_main.show_toast("已複製 PUID")
