extends Resource
class_name VehicleLoader

## VehicleLoader - Utility for loading vehicle models and managing vehicle data
## Supports both placeholder models and actual .glb/.tscn vehicle scenes

static var _vehicle_cache: Dictionary = {}
static var _vehicle_config: Dictionary = {}

## Vehicle configuration structure:
# {
#     "car_id": {
#         "display_name": "Vehicle Name",
#         "scene_path": "res://vehicles/sports_car.tscn",
#         "thumbnail": "res://ui/icons/car_sports.png",
#         "stats": {"speed": 0.8, "handling": 0.7, "accel": 0.9},
#         "tier": 3,
#         "unlock_requirement": ""
#     }
# }

func _init() -> void:
	_load_vehicle_config()

func _load_vehicle_config() -> void:
	# Try to load from config file
	var config_path = "res://data/vehicles/vehicle_config.tres"
	if ResourceLoader.exists(config_path):
		var config = ResourceLoader.load(config_path)
		if config:
			_vehicle_config = config
			return
	
	# Default fallback config
	_vehicle_config = {
		"default": {
			"display_name": "Default Racer",
			"scene_path": "",
			"thumbnail": "",
			"stats": {"speed": 0.5, "handling": 0.5, "accel": 0.5},
			"tier": 1,
			"unlock_requirement": ""
		},
		"sports_car": {
			"display_name": "Aether Sprint",
			"scene_path": "res://vehicles/sports_car.tscn",
			"thumbnail": "res://ui/icons/car_sports.png",
			"stats": {"speed": 0.85, "handling": 0.7, "accel": 0.8},
			"tier": 2,
			"unlock_requirement": "Level 5"
		},
		"hyper_car": {
			"display_name": "Void Runner",
			"scene_path": "res://vehicles/hyper_car.tscn",
			"thumbnail": "res://ui/icons/car_hyper.png",
			"stats": {"speed": 0.95, "handling": 0.6, "accel": 0.95},
			"tier": 3,
			"unlock_requirement": "Level 15"
		},
		"drift_car": {
			"display_name": "Phantom Drift",
			"scene_path": "res://vehicles/drift_car.tscn",
			"thumbnail": "res://ui/icons/car_drift.png",
			"stats": {"speed": 0.7, "handling": 0.95, "accel": 0.65},
			"tier": 2,
			"unlock_requirement": "Level 10"
		}
	}

static func get_vehicle_config(car_id: String) -> Dictionary:
	if _vehicle_config.is_empty():
		VehicleLoader.new()  # Trigger init
	return _vehicle_config.get(car_id, _vehicle_config["default"]).duplicate(true)

static func get_all_vehicles() -> Array:
	if _vehicle_config.is_empty():
		VehicleLoader.new()
	return _vehicle_config.keys()

static func load_vehicle_model(car_id: String, target_node: Node3D) -> Node3D:
	var config = get_vehicle_config(car_id)
	var scene_path = config.get("scene_path", "")
	
	# Clear existing children
	for child in target_node.get_children():
		child.queue_free()
	
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var scene = ResourceLoader.load(scene_path)
		if scene:
			var instance = scene.instantiate()
			target_node.add_child(instance)
			
			# Apply customizations if any
			_apply_vehicle_customization(instance, car_id)
			
			_vehicle_cache[car_id] = instance
			return instance
	
	# Fallback: create placeholder
	return _create_placeholder_model(target_node, config)

static func _create_placeholder_model(parent: Node3D, config: Dictionary) -> Node3D:
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.0, 0.8, 4.0)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.74, 0.97)
	material.metallic = 0.3
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission_color = Color(0.22, 0.74, 0.97, 0.3)
	material.emission_energy = 0.5
	mesh_instance.material_override = material
	
	parent.add_child(mesh_instance)
	return mesh_instance

static func _apply_vehicle_customization(vehicle_node: Node3D, car_id: String) -> void:
	# Apply paint, decals, upgrades visual representation
	# This would be expanded based on player"s customization data
	pass

static func get_vehicle_stats(car_id: String) -> Dictionary:
	var config = get_vehicle_config(car_id)
	return config.get("stats", {"speed": 0.5, "handling": 0.5, "accel": 0.5}).duplicate(true)

static func get_vehicle_display_name(car_id: String) -> String:
	var config = get_vehicle_config(car_id)
	return config.get("display_name", car_id)

static func preload_vehicle(car_id: String) -> void:
	if _vehicle_cache.has(car_id):
		return
	var config = get_vehicle_config(car_id)
	var scene_path = config.get("scene_path", "")
	if scene_path != "" and ResourceLoader.exists(scene_path):
		ResourceLoader.load_threaded_get(scene_path)  # Preload in background
