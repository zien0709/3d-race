extends Node

## WaterAnimator.gd
## Assigns the Gerstner water shader materials to all water surfaces at startup
## (the map is a GLB import, so its water nodes cannot be edited in main.tscn),
## then drives the shared `anim_time` parameter every frame.

@export var ocean_material: ShaderMaterial = null
@export var pond_material: ShaderMaterial = null

var _time: float = 0.0
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_apply_materials_to_water_nodes()


func _process(delta: float) -> void:
	_time += delta
	for mat in _materials:
		if mat != null:
			mat.set_shader_parameter("anim_time", _time)


func _apply_materials_to_water_nodes() -> void:
	var root := get_tree().current_scene if get_tree() != null else null
	if root == null:
		return
	var race_map := root.get_node_or_null("RaceMap")
	if race_map == null:
		push_warning("WaterAnimator: RaceMap not found; water materials not applied")
		return

	## Direct water surfaces by node name.
	var ocean := race_map.get_node_or_null("Ocean_Base") as MeshInstance3D
	var pond_large := race_map.get_node_or_null("Garden_Pond_Large") as MeshInstance3D
	var pond_small := race_map.get_node_or_null("Garden_Pond_Small") as MeshInstance3D
	var pond_deep := race_map.get_node_or_null("Pond_Water_Detail_Deep") as MeshInstance3D
	var fountain := race_map.get_node_or_null("BLDG_01_Central_Fountain_ROOT/Fountain_Water") as MeshInstance3D

	if ocean_material == null:
		ocean_material = load("res://materials/water_ocean.tres") as ShaderMaterial
	if pond_material == null:
		pond_material = load("res://materials/water_pond.tres") as ShaderMaterial

	_assign(ocean, ocean_material)
	_assign(pond_large, pond_material)
	_assign(pond_small, pond_material)
	_assign(pond_deep, pond_material)
	_assign(fountain, pond_material)


func _assign(mi: MeshInstance3D, mat: ShaderMaterial) -> void:
	if mi == null or mat == null:
		return
	mi.material_override = mat
	if not _materials.has(mat):
		_materials.append(mat)
