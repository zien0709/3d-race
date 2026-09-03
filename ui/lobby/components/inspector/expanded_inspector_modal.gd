extends Control
class_name ExpandedInspectorModal

## ExpandedInspectorModal - 中央展開 Modal
## 從 DynamicInspector 雙擊標題/點擊展開鈕/雙擊玩家區域觸發
## 全螢幕 Scrim + 居中 PanelContainer (毛玻璃)

signal closed()

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.22, 0.74, 0.97)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)

@onready var scrim: ColorRect = $Scrim
@onready var modal_panel: PanelContainer = $ModalPanel
@onready var title_label: Label = $ModalPanel/ContentVBox/HeaderBar/TitleLabel
@onready var content_stack: VBoxContainer = $ModalPanel/ContentVBox/ContentStack

var _ui_animations := UIAnimations
var _current_mode: int = 0  # 0=NONE, 1=ROOM_CONFIG, 2=SELF_UPGRADE, 3=OTHER_DETAIL
var _current_player_id: String = ""
var _room_config_panel: Control = null
var _self_upgrade_panel: Control = null
var _other_detail_panel: Control = null
var _placeholder_label: Label = null

func _ready() -> void:
	_ui_animations = UIAnimations
	_setup_style()
	_build_placeholder()
	var close_btn = $ModalPanel/ContentVBox/HeaderBar/CloseBtn
	close_btn.pressed.connect(_on_close_pressed)
	scrim.gui_input.connect(_on_scrim_input)

func _setup_style() -> void:
	# Scrim style
	var scrim_style = StyleBoxFlat.new()
	scrim_style.bg_color = Color(0, 0, 0, 0.6)
	scrim.add_theme_stylebox_override("panel", scrim_style)
	
	# Modal panel style (glassmorphism)
	var glass_material = load("res://shaders/glassmorphism_material.tres")
	if glass_material:
		modal_panel.material = glass_material.duplicate()
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.set_corner_radius_all(16)
	panel_style.set_border_width_all(1)
	panel_style.border_color = C_BORDER
	panel_style.shadow_color = Color(0.22, 0.74, 0.97, 0.15)
	panel_style.shadow_size = 16
	modal_panel.add_theme_stylebox_override("panel", panel_style)

func _build_placeholder() -> void:
	_placeholder_label = Label.new()
	_placeholder_label.text = "請選擇玩家查看詳細資料"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder_label.add_theme_font_size_override("font_size", 16)
	_placeholder_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	content_stack.add_child(_placeholder_label)

func open(mode: int = 0, player_id: String = "") -> void:
	# mode: 0=NONE, 1=ROOM_CONFIG, 2=SELF_UPGRADE, 3=OTHER_DETAIL
	_current_mode = mode
	_current_player_id = player_id
	
	# Update title
	match mode:
		0: title_label.text = "詳細資料"
		1: title_label.text = "房間設定"
		2: title_label.text = "車輛升級"
		3: title_label.text = "玩家詳情"
	
	# Animate in
	visible = true
	modulate.a = 0.0
	scrim.modulate.a = 0.0
	modal_panel.modulate.a = 0.0
	modal_panel.scale = Vector2(0.95, 0.95)
	
	var tween = _ui_animations.create_tween()
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(scrim, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(modal_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(modal_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Load content after animation starts
	call_deferred("_animate_content_transition")

func close() -> void:
	if not visible:
		return
	var tween = _ui_animations.create_tween()
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(scrim, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(modal_panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(modal_panel, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): 
		visible = false
		closed.emit()
		_clear_content()
	)

func _on_close_pressed() -> void:
	close()

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if visible:
			close()
			get_viewport().set_input_as_handled()

func _animate_content_transition() -> void:
	# Clear old content
	if content_stack.get_child_count() > 0:
		var old_content = content_stack.get_child(0)
		if old_content and old_content != _placeholder_label:
			var tween = _ui_animations.create_tween()
			tween.tween_property(old_content, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func(): old_content.queue_free())
			await tween.finished
	
	# Create new content based on mode
	match _current_mode:
		0: _show_placeholder()
		1: _show_room_config()
		2: _show_self_upgrade()
		3: _show_other_detail()

func _show_placeholder() -> void:
	if _placeholder_label == null:
		_placeholder_label = Label.new()
		_placeholder_label.text = "請選擇玩家查看詳細資料"
		_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_placeholder_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_placeholder_label.add_theme_font_size_override("font_size", 16)
		_placeholder_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		content_stack.add_child(_placeholder_label)
	
	_placeholder_label.visible = true
	_placeholder_label.modulate.a = 0.0
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

func _clear_content() -> void:
	for child in content_stack.get_children():
		if child != _placeholder_label:
			child.queue_free()
	if _placeholder_label:
		_placeholder_label.visible = false
		_placeholder_label.modulate.a = 0.0

func update_room_config(config: Dictionary) -> void:
	if _room_config_panel and _room_config_panel.has_method("update_config"):
		_room_config_panel.update_config(config)

func update_self_upgrade(stats: Dictionary, car_data: Dictionary) -> void:
	if _self_upgrade_panel and _self_upgrade_panel.has_method("update_data"):
		_self_upgrade_panel.update_data(stats, car_data)

func update_other_detail(player_data: Dictionary) -> void:
	if _other_detail_panel and _other_detail_panel.has_method("update_data"):
		_other_detail_panel.update_data(player_data)

func get_current_mode() -> int:
	return _current_mode

func get_current_player_id() -> String:
	return _current_player_id
