extends Node
class_name DynamicLayoutManager

## DynamicLayoutManager - Manages organic/freeform layout of player zones
## Handles player join/leave, zone resizing, and animated transitions

signal layout_changed(zones: Array)

enum ZoneType { SELF_LARGE, OTHER_SMALL, EMPTY }

var _zones: Array[Dictionary] = []
var _container: Control = null
var _animation_duration: float = 0.3
var _is_arranging: bool = false

## Configuration
@export var max_players: int = 8
@export var self_zone_ratio: float = 0.5  # Self zone takes 50% of space
@export var min_zone_height: float = 200.0
@export var zone_spacing: float = 16.0

func bind_container(container: Control) -> void:
	_container = container

func add_player(player_data: Dictionary, is_self: bool = false) -> int:
	var zone_data = {
		"player_id": player_data.get("id", ""),
		"player_name": player_data.get("name", "Player"),
		"car_name": player_data.get("car_name", "Default Car"),
		"rank": player_data.get("rank", "--"),
		"is_self": is_self,
		"is_host": player_data.get("is_host", false),
		"ready": player_data.get("ready", false),
		"zone_node": null,
		"zone_type": ZoneType.SELF_LARGE if is_self else ZoneType.OTHER_SMALL
	}
	
	_zones.append(zone_data)
	_arrange_zones()
	return _zones.size() - 1

func remove_player(player_id: String) -> void:
	var idx = -1
	for i in range(_zones.size()):
		if _zones[i].player_id == player_id:
			idx = i
			break
	if idx >= 0:
		_zones.remove_at(idx)
		_arrange_zones()

func update_player(player_id: String, data: Dictionary) -> void:
	for zone in _zones:
		if zone.player_id == player_id:
			zone.player_name = data.get("name", zone.player_name)
			zone.car_name = data.get("car_name", zone.car_name)
			zone.rank = data.get("rank", zone.rank)
			zone.ready = data.get("ready", zone.ready)
			zone.is_host = data.get("is_host", zone.is_host)
			if zone.zone_node and zone.zone_node.has_method("update_data"):
				zone.zone_node.update_data(zone)
			break

func set_self_player(player_id: String) -> void:
	# Move self player to first position and mark as self
	var self_idx = -1
	for i in range(_zones.size()):
		if _zones[i].player_id == player_id:
			self_idx = i
			break
	if self_idx > 0:
		var self_zone = _zones[self_idx]
		_zones.remove_at(self_idx)
		_zones.insert(0, self_zone)
	
	# Update all zone types
	for i in range(_zones.size()):
		var zone = _zones[i]
		zone.is_self = (i == 0)
		zone.zone_type = ZoneType.SELF_LARGE if zone.is_self else ZoneType.OTHER_SMALL
		if zone.zone_node and zone.zone_node.has_method("set_zone_type"):
			zone.zone_node.set_zone_type(zone.zone_type)
	
	_arrange_zones()

func _arrange_zones() -> void:
	if _container == null or _is_arranging:
		return
	
	_is_arranging = true
	
	# Clear container
	for child in _container.get_children():
		if child != _container.find_child("*"):  # Keep any permanent children
			child.queue_free()
	
	# Calculate layout
	var total_height = _container.get_rect().size.y
	var self_count = 0
	var other_count = 0
	
	for zone in _zones:
		if zone.is_self:
			self_count += 1
		else:
			other_count += 1
	
	# Calculate space allocation
	var spacing_total = zone_spacing * max(0, _zones.size() - 1)
	var available_height = total_height - spacing_total
	
	var self_height = 0.0
	var other_height = 0.0
	
	if self_count > 0:
		self_height = (available_height * self_zone_ratio) / self_count
		self_height = max(self_height, min_zone_height)
	
	if other_count > 0:
		other_height = (available_height * (1.0 - self_zone_ratio)) / other_count
		other_height = max(other_height, min_zone_height * 0.6)
	
	# Create/position zones
	var current_y = 0.0
	for i in range(_zones.size()):
		var zone = _zones[i]
		var zone_height = self_height if zone.is_self else other_height
		_create_or_update_zone(zone, current_y, zone_height)
		current_y += zone_height + zone_spacing
	
	_is_arranging = false
	layout_changed.emit(_zones.duplicate(true))

func _create_or_update_zone(zone_data: Dictionary, y_pos: float, height: float) -> void:
	# This will be called by the container to instantiate actual zone scenes
	# The container should connect to layout_changed and instantiate zones
	pass

func get_zone_data(player_id: String) -> Dictionary:
	for zone in _zones:
		if zone.player_id == player_id:
			return zone.duplicate(true)
	return {}

func get_all_zones() -> Array:
	return _zones.duplicate(true)

func clear() -> void:
	_zones.clear()
	if _container != null:
		for child in _container.get_children():
			child.queue_free()
