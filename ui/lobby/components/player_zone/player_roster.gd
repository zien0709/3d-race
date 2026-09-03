extends Control
class_name PlayerRoster

## PlayerRoster - Container managing all player zones in the right panel
## Handles dynamic add/remove, selection, and layout

signal zone_selected(player_id: String, is_self: bool)
signal zone_double_clicked(player_id: String, is_self: bool)
signal speech_bubble_requested(player_id: String, text: String)

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var player_list: VBoxContainer = $ScrollContainer/PlayerList

const PlayerZoneScene := preload("res://ui/lobby/components/player_zone/player_zone.tscn")

var _zones: Array = []
var _player_data_map: Dictionary = {}
var _selected_player_id: String = ""
var _local_player_id: String = ""

func _ready() -> void:
	player_list.add_theme_constant_override("separation", 12)
	scroll_container.vertical_scroll_mode = 1  # SCROLL_MODE_ENABLED = 1
	
	# Connect scroll visibility check
	scroll_container.gui_input.connect(_on_scroll_input)
	
	# Periodic visibility check
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_check_visibility)
	add_child(timer)
	timer.start()

func set_players(players: Array, local_player_id: String = "") -> void:
	_local_player_id = local_player_id
	
	# Clear existing zones
	for zone in _zones:
		zone.queue_free()
	_zones.clear()
	_player_data_map.clear()
	
	# Sort: local player first, then host, then others
	var sorted_players = players.duplicate(true)
	sorted_players.sort_custom(_sort_players)
	
	# Create zones
	for i in range(sorted_players.size()):
		var player = sorted_players[i]
		var is_self = str(player.get("id", "")) == _local_player_id
		var is_host = bool(player.get("is_host", false))
		
		# For local player, ensure they"re first
		if is_self and i > 0:
			sorted_players.remove_at(i)
			sorted_players.insert(0, player)
			break
	
	# Re-create with correct order
	for zone in _zones:
		zone.queue_free()
	_zones.clear()
	
	for i in range(sorted_players.size()):
		var player = sorted_players[i]
		var is_self = str(player.get("id", "")) == _local_player_id
		_create_zone(player, is_self, i == 0)
	
	# Select first player by default
	if _zones.size() > 0 and _selected_player_id == "":
		_select_zone(_zones[0])

func _sort_players(a: Dictionary, b: Dictionary) -> int:
	var a_self = str(a.get("id", "")) == _local_player_id
	var b_self = str(b.get("id", "")) == _local_player_id
	var a_host = bool(a.get("is_host", false))
	var b_host = bool(b.get("is_host", false))
	
	if a_self and not b_self: return -1
	if b_self and not a_self: return 1
	if a_host and not b_host: return -1
	if b_host and not a_host: return 1
	return 0

func _create_zone(player_data: Dictionary, is_self: bool, is_first: bool) -> void:
	var zone_instance = PlayerZoneScene.instantiate()
	player_list.add_child(zone_instance)
	
	var player_id = str(player_data.get("id", ""))
	_player_data_map[player_id] = player_data
	
	# Connect signals
	zone_instance.zone_selected.connect(_on_zone_selected.bind(player_id, is_self))
	zone_instance.zone_double_clicked.connect(_on_zone_double_clicked.bind(player_id, is_self))
	zone_instance.speech_bubble_requested.connect(_on_speech_bubble_requested.bind(player_id))
	
	# Update zone data
	zone_instance.update_data(player_data)
	zone_instance.set_zone_type(0 if is_self else 1)  # 0 = SELF_LARGE, 1 = OTHER_SMALL
	
	if is_first or is_self:
		zone_instance.set_selected(true)
		_selected_player_id = player_id
	else:
		zone_instance.set_selected(false)
	
	_zones.append(zone_instance)

func _on_zone_selected(player_id: String, is_self: bool) -> void:
	if _selected_player_id == player_id:
		return
	
	# Deselect previous
	for zone in _zones:
		var pid = zone.get_player_id()
		zone.set_selected(pid == player_id)
	
	_selected_player_id = player_id
	zone_selected.emit(player_id, is_self)

func _on_zone_double_clicked(player_id: String, is_self: bool) -> void:
	zone_double_clicked.emit(player_id, is_self)

func _on_speech_bubble_requested(player_id: String, text: String) -> void:
	speech_bubble_requested.emit(player_id, text)

func _select_zone(zone: Control) -> void:
	zone.set_selected(true)
	_selected_player_id = zone.get_player_id()
	zone_selected.emit(_selected_player_id, zone.get_player_data().get("is_self", false))

func update_player(player_id: String, data: Dictionary) -> void:
	_player_data_map[player_id] = data
	for zone in _zones:
		if zone.get_player_id() == player_id:
			zone.update_data(data)
			break

func add_player(player_data: Dictionary) -> void:
	var player_id = str(player_data.get("id", ""))
	if _player_data_map.has(player_id):
		return
	
	var is_self = player_id == _local_player_id
	var insert_index = 0 if is_self else _zones.size()
	
	var zone_instance = PlayerZoneScene.instantiate()
	if insert_index == 0:
		player_list.add_child(zone_instance)
		player_list.move_child(zone_instance, 0)
	else:
		player_list.add_child(zone_instance)
	
	_player_data_map[player_id] = player_data
	zone_instance.zone_selected.connect(_on_zone_selected.bind(player_id, is_self))
	zone_instance.zone_double_clicked.connect(_on_zone_double_clicked.bind(player_id, is_self))
	zone_instance.speech_bubble_requested.connect(_on_speech_bubble_requested.bind(player_id))
	zone_instance.update_data(player_data)
	zone_instance.set_zone_type(0 if is_self else 1)
	
	if is_self:
		# Deselect current, select new self
		for z in _zones:
			z.set_selected(false)
		zone_instance.set_selected(true)
		_selected_player_id = player_id
	
	_zones.insert(insert_index, zone_instance)

func remove_player(player_id: String) -> void:
	var idx = -1
	for i in range(_zones.size()):
		if _zones[i].get_player_id() == player_id:
			idx = i
			break
	
	if idx >= 0:
		var zone = _zones[idx]
		zone.queue_free()
		_zones.remove_at(idx)
		_player_data_map.erase(player_id)
		
		# Select another if removed was selected
		if _selected_player_id == player_id:
			_selected_player_id = ""
			if _zones.size() > 0:
				_select_zone(_zones[0])

func get_selected_player_id() -> String:
	return _selected_player_id

func get_selected_player_data() -> Dictionary:
	return _player_data_map.get(_selected_player_id, {})

func show_speech_bubble_for_player(player_id: String, text: String) -> void:
	for zone in _zones:
		if zone.get_player_id() == player_id and zone.has_method("show_speech_bubble"):
			zone.show_speech_bubble(text)
			break

func set_all_render_active(active: bool) -> void:
	for zone in _zones:
		if zone.has_method("set_render_active"):
			zone.set_render_active(active)

# Performance optimization: Only render visible car previews
func _check_visibility() -> void:
	var scroll_global = scroll_container.global_position
	var scroll_size = scroll_container.size
	
	for zone in _zones:
		var zone_global = zone.global_position
		var zone_size = zone.get_rect().size
		# Check if zone overlaps with scroll container visible area
		var zone_bottom = zone_global.y + zone_size.y
		var scroll_bottom = scroll_global.y + scroll_size.y
		var is_visible = zone_global.y < scroll_bottom and zone_bottom > scroll_global.y
		if zone.has_method("set_render_active"):
			zone.set_render_active(is_visible)

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		call_deferred("_check_visibility")
