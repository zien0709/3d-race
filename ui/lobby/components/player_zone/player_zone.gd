extends Control
class_name PlayerZone

## PlayerZone - Individual player area with 3D car preview, glassmorphism overlay, name/rank, speech bubble
## Supports two modes: SELF_LARGE (detailed, larger) and OTHER_SMALL (compact)

signal zone_selected(player_id: String, is_self: bool)
signal zone_double_clicked(player_id: String, is_self: bool)
signal speech_bubble_requested(player_id: String, text: String)

enum ZoneType { SELF_LARGE, OTHER_SMALL }

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.22, 0.74, 0.97)
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_GOLD := Color(1.0, 0.8, 0.2)

@onready var car_preview: Control = $CarPreview
@onready var glass_panel: PanelContainer = $GlassPanel
@onready var name_label: Label = $NameRankAnchor/NameRankPanel/NameRankVBox/NameLabel
@onready var rank_icon: Label = $NameRankAnchor/NameRankPanel/NameRankVBox/RankContainer/RankIcon
@onready var rank_label: Label = $NameRankAnchor/NameRankPanel/NameRankVBox/RankContainer/RankLabel
@onready var car_name_label: Label = $NameRankAnchor/NameRankPanel/NameRankVBox/CarNameLabel
@onready var speech_bubble_anchor: Control = $SpeechBubbleAnchor
@onready var selection_glow: TextureRect = $SelectionGlow

var _ui_animations := UIAnimations
var _player_data: Dictionary = {}
var _zone_type: ZoneType = ZoneType.OTHER_SMALL
var _is_selected: bool = false
var _is_hovered: bool = false
var _click_time: float = 0.0
var _speech_bubble_instance: Control = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Apply glassmorphism material to glass panel
	var glass_material = load("res://shaders/glassmorphism_material.tres")
	if glass_material:
		glass_panel.material = glass_material.duplicate()
	
	# Setup selection glow (will use a shader or texture)
	selection_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Initialize glass panel style
	_setup_glass_panel()

func _setup_glass_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparent, shader handles visual
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.35, 0.4, 0.3)
	style.set_content_margin_all(0)
	style.shadow_color = Color(0.22, 0.74, 0.97, 0.1)
	style.shadow_size = 8
	glass_panel.add_theme_stylebox_override("panel", style)

func set_zone_type(zone_type: ZoneType) -> void:
	_zone_type = zone_type
	_update_visuals_for_type()

func _update_visuals_for_type() -> void:
	match _zone_type:
		ZoneType.SELF_LARGE:
			custom_minimum_size = Vector2(0, 300)
			name_label.add_theme_font_size_override("font_size", 20)
			rank_label.add_theme_font_size_override("font_size", 16)
			car_name_label.add_theme_font_size_override("font_size", 14)
			# Show car name for self
			car_name_label.visible = true
		ZoneType.OTHER_SMALL:
			custom_minimum_size = Vector2(0, 180)
			name_label.add_theme_font_size_override("font_size", 16)
			rank_label.add_theme_font_size_override("font_size", 12)
			car_name_label.add_theme_font_size_override("font_size", 10)
			# Hide car name for others (or show smaller)
			car_name_label.visible = true

func update_data(data: Dictionary) -> void:
	_player_data = data
	
	var name = data.get("player_name", "Player")
	var car_name = data.get("car_name", "Default Car")
	var rank = data.get("rank", "--")
	var is_host = data.get("is_host", false)
	var ready = data.get("ready", false)
	var is_self = data.get("is_self", false)
	
	name_label.text = name
	car_name_label.text = car_name
	rank_label.text = rank
	
	# Rank icon based on rank text
	rank_icon.text = _get_rank_icon(rank)
	
	# Host crown
	if is_host:
		rank_icon.text = "👑 " + rank_icon.text
	
	# Ready indicator
	if ready:
		rank_label.add_theme_color_override("font_color", C_GREEN)
	else:
		rank_label.add_theme_color_override("font_color", C_CYAN)
	
	# Load car model in SubViewport
	if car_preview.has_method("load_car"):
		var car_id = data.get("car_id", "default")
		car_preview.load_car(car_id)
	
	# Enable/disable car preview interaction based on zone type
	car_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE if _zone_type == ZoneType.OTHER_SMALL else Control.MOUSE_FILTER_STOP

func _get_rank_icon(rank_text: String) -> String:
	match rank_text:
		_ when "大師" in rank_text: return "🏆"
		_ when "鑽石" in rank_text: return "💎"
		_ when "鉑金" in rank_text: return "🥈"
		_ when "黃金" in rank_text: return "🥇"
		_ when "白銀" in rank_text: return "🥈"
		_ when "青銅" in rank_text: return "🥉"
		_: return "🎯"

func set_selected(selected: bool) -> void:
	_is_selected = selected
	selection_glow.visible = selected
	
	if selected:
		# Glowing border animation
		var style = glass_panel.get_theme_stylebox("panel")
		style.border_color = C_CYAN
		style.set_border_width_all(2)
		style.shadow_size = 12
		style.shadow_color = Color(0.22, 0.74, 0.97, 0.4)
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_pop(self, 1.02, 0.15)
	else:
		var style = glass_panel.get_theme_stylebox("panel")
		style.border_color = Color(0.3, 0.35, 0.4, 0.3)
		style.set_border_width_all(1)
		style.shadow_size = 8
		style.shadow_color = Color(0.22, 0.74, 0.97, 0.1)
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_release(self, 0.15)

func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered
	if hovered and not _is_selected:
		var style = glass_panel.get_theme_stylebox("panel")
		style.border_color = Color(0.3, 0.35, 0.4, 0.6)
		style.set_border_width_all(1)
		style.shadow_size = 10
		style.shadow_color = Color(0.22, 0.74, 0.97, 0.2)
	else:
		if not _is_selected:
			var style = glass_panel.get_theme_stylebox("panel")
			style.border_color = Color(0.3, 0.35, 0.4, 0.3)
			style.set_border_width_all(1)
			style.shadow_size = 8
			style.shadow_color = Color(0.22, 0.74, 0.97, 0.1)

func show_speech_bubble(text: String, duration: float = 3.0) -> void:
	# Create speech bubble instance if needed
	if _speech_bubble_instance == null:
		var bubble_scene = load("res://ui/lobby/components/player_zone/speech_bubble.tscn")
		if bubble_scene:
			_speech_bubble_instance = bubble_scene.instantiate()
			speech_bubble_anchor.add_child(_speech_bubble_instance)
	
	if _speech_bubble_instance and _speech_bubble_instance.has_method("show_message"):
		_speech_bubble_instance.show_message(text, duration, Vector2.DOWN)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var now = Time.get_ticks_msec() / 1000.0
			if now - _click_time < 0.3:  # Double click
				zone_double_clicked.emit(_player_data.get("player_id", ""), _player_data.get("is_self", false))
			else:
				zone_selected.emit(_player_data.get("player_id", ""), _player_data.get("is_self", false))
			_click_time = now
			get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion:
		if not _is_hovered:
			set_hovered(true)
	
	# Handle mouse exit
	if event is InputEventMouseMotion and not get_rect().has_point(event.position):
		if _is_hovered:
			set_hovered(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _is_hovered:
			set_hovered(false)

func get_player_id() -> String:
	return _player_data.get("player_id", "")

func get_player_data() -> Dictionary:
	return _player_data.duplicate(true)

func set_render_active(active: bool) -> void:
	car_preview.set_render_active(active)
