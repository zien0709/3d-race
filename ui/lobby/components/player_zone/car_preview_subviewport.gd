extends SubViewportContainer
class_name CarPreviewSubViewport

## CarPreviewSubViewport - 3D vehicle preview embedded in 2D UI
## Uses SubViewport to render a 3D car model that can be rotated via mouse drag

signal model_loaded(car_id: String)

@onready var subviewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var light: DirectionalLight3D = $SubViewport/DirectionalLight3D
@onready var car_root: Node3D = $SubViewport/CarModelRoot

var current_car_id: String = ""
var current_model: Node3D = null
var is_dragging: bool = false
var drag_sensitivity: float = 0.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func load_car(car_id: String, car_scene_path: String = "") -> void:
	# Clear existing model
	if current_model != null:
		current_model.queue_free()
		current_model = null
	
	current_car_id = car_id
	
	if car_scene_path == "" or not ResourceLoader.exists(car_scene_path):
		# Create placeholder box mesh
		_create_placeholder_model()
	else:
		# Load actual car model
		var scene = ResourceLoader.load(car_scene_path)
		if scene:
			current_model = scene.instantiate()
			car_root.add_child(current_model)
			_fit_camera_to_model()
		else:
			_create_placeholder_model()
	
	model_loaded.emit(car_id)

func _create_placeholder_model() -> void:
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.0, 0.8, 4.0)
	mesh_instance.mesh = box_mesh
	
	# Create a simple material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.74, 0.97)
	material.metallic = 0.3
	material.roughness = 0.4
	mesh_instance.material_override = material
	
	current_model = mesh_instance
	car_root.add_child(current_model)
	_fit_camera_to_model()

func _fit_camera_to_model() -> void:
	if current_model == null:
		return
	# Calculate bounding box and fit camera
	var aabb = current_model.get_aabb()
	var max_dim = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	var distance = max_dim * 1.5
	camera.position = Vector3(0, aabb.size.y * 0.5, distance)
	camera.look_at(Vector3(0, aabb.size.y * 0.5, 0))

func set_car_transform(position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> void:
	if current_model != null:
		current_model.position = position
		current_model.rotation = rotation
		current_model.scale = scale

func rotate_y(angle: float) -> void:
	if current_model != null:
		current_model.rotate_y(angle)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if event.pressed:
				get_viewport().gui_grab_focus()
	
	if event is InputEventMouseMotion and is_dragging:
		var delta_x = event.relative.x
		rotate_y(deg_to_rad(-delta_x * drag_sensitivity))

func set_render_active(active: bool) -> void:
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func get_viewport_texture() -> ViewportTexture:
	return subviewport.get_texture()
