extends PanelContainer
class_name DynamicInspector

## DynamicInspector - 動態檢視器
## 根據選取狀態切換顯示：房間設定 / 自己升級 / 他人詳情

signal customize_requested()
signal expand_requested()

enum Mode { NONE, ROOM_CONFIG, SELF_UPGRADE, OTHER_DETAIL }

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.22, 0.74, 0.97)
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)
const C_PANEL := Color(0.10, 0.12, 0.16)

@onready var content_vbox: VBoxContainer = $ContentVBox
@onready var header_bar: HBoxContainer = $ContentVBox/HeaderBar
@onready var title_label: Label = $ContentVBox/HeaderBar/TitleLabel
@onready var expand_btn: Button = $ContentVBox/HeaderBar/ExpandBtn
@onready var content_stack: VBoxContainer = $ContentVBox/ContentStack

var _ui_animations := UIAnimations
var _current_mode: Mode = Mode.NONE
var _current_player_id: String = ""
var _room_config_panel: Control = null
var _self_upgrade_panel: Control = null
var _other_detail_panel: Control = null
var _placeholder_label: Label = null

func _ready() -> void:
	_ui_animations = UIAnimations
	_setup_style()
	_build_placeholder()
	expand_btn.pressed.connect(_on_expand_pressed)
	
	# Connect signal to clear content when mode changes
	# (handled in set_mode)

func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = C_BORDER
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)

func _build_placeholder() -> void:
	_placeholder_label = Label.new()
	_placeholder_label.text = "請選擇玩家查看資料"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder_label.add_theme_font_size_override("font_size", 14)
	_placeholder_label.add_theme_color_override("font_color", C_MUTED)
	content_stack.add_child(_placeholder_label)

func set_mode(mode: Mode, player_id: String = "") -> void:
	if _current_mode == mode and _current_player_id == player_id:
		return
	
	_current_mode = mode
	_current_player_id = player_id
	
	# Update title
	match mode:
		Mode.NONE:
			title_label.text = "車輛資料"
		Mode.ROOM_CONFIG:
			title_label.text = "房間設定"
		Mode.SELF_UPGRADE:
			title_label.text = "車輛升級"
		Mode.OTHER_DETAIL:
			title_label.text = "玩家詳情"
	
	# Animate transition
	_animate_content_transition()

func _animate_content_transition() -> void:
	# Fade out current content with slide
	if content_stack.get_child_count() > 0:
		var old_content = content_stack.get_child(0)
		if old_content and old_content != _placeholder_label:
			var tween = _ui_animations.create_tween()
			tween.parallel().tween_property(old_content, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(old_content, "position:x", -30, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func(): old_content.queue_free())
			await tween.finished
	
	# Create new content based on mode
	match _current_mode:
		Mode.NONE:
			_show_placeholder()
		Mode.ROOM_CONFIG:
			_show_room_config()
		Mode.SELF_UPGRADE:
			_show_self_upgrade()
		Mode.OTHER_DETAIL:
			_show_other_detail()
	
	# Animate in new content
	if content_stack.get_child_count() > 0:
		var new_content = content_stack.get_child(0)
		if new_content:
			new_content.position.x = 30
			new_content.modulate.a = 0.0
			var tween = _ui_animations.create_tween()
			tween.parallel().tween_property(new_content, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(new_content, "position:x", 0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_placeholder() -> void:
	if _placeholder_label == null:
		_build_placeholder()
	_placeholder_label.visible = true
	_placeholder_label.modulate.a = 0.0
	content_stack.add_child(_placeholder_label)
	var tween = _ui_animations.create_tween()
	tween.tween_property(_placeholder_label, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_room_config() -> void:
	if _room_config_panel == null:
		var panel_scene = load("res://ui/lobby/components/inspector/room_config_panel.tscn")
		if panel_scene:
			_room_config_panel = panel_scene.instantiate()
			content_stack.add_child(_room_config_panel)
	if _room_config_panel:
		_room_config_panel.visible = true
		_room_config_panel.modulate.a = 0.0
		var tween = _ui_animations.create_tween()
		tween.tween_property(_room_config_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_self_upgrade() -> void:
	if _self_upgrade_panel == null:
		var panel_scene = load("res://ui/lobby/components/inspector/self_upgrade_panel.tscn")
		if panel_scene:
			_self_upgrade_panel = panel_scene.instantiate()
			content_stack.add_child(_self_upgrade_panel)
	if _self_upgrade_panel:
		_self_upgrade_panel.visible = true
		_self_upgrade_panel.modulate.a = 0.0
		var tween = _ui_animations.create_tween()
		tween.tween_property(_self_upgrade_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_other_detail() -> void:
	if _other_detail_panel == null:
		var panel_scene = load("res://ui/lobby/components/inspector/other_detail_panel.tscn")
		if panel_scene:
			_other_detail_panel = panel_scene.instantiate()
			content_stack.add_child(_other_detail_panel)
	if _other_detail_panel:
		_other_detail_panel.visible = true
		_other_detail_panel.modulate.a = 0.0
		var tween = _ui_animations.create_tween()
		tween.tween_property(_other_detail_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_expand_pressed() -> void:
	expand_requested.emit()

func update_room_config(config: Dictionary) -> void:
	if _room_config_panel and _room_config_panel.has_method("update_config"):
		_room_config_panel.update_config(config)

func update_self_upgrade(stats: Dictionary, car_data: Dictionary) -> void:
	if _self_upgrade_panel and _self_upgrade_panel.has_method("update_data"):
		_self_upgrade_panel.update_data(stats, car_data)

func update_other_detail(player_data: Dictionary) -> void:
	if _other_detail_panel and _other_detail_panel.has_method("update_data"):
		_other_detail_panel.update_data(player_data)

func get_current_mode() -> Mode:
	return _current_mode

func get_current_player_id() -> String:
	return _current_player_id
