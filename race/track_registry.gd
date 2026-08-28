extends Node

## 賽道註冊與選擇管理 (Autoload: TrackRegistry)
## 負責管理所有可用的 TrackConfig、賽道名稱與 UI 選項對映，
## 以及跨場景 (Lobby -> main.tscn) 暫存當前選中的賽道。

const DEFAULT_TRACK_PATH := "res://tracks/default.tres"

## 已註冊的賽道配置 map: track_id (StringName) -> TrackConfig
var _tracks: Dictionary = {}

## UI 顯示名稱對應表: ui_name (String) -> track_id (StringName)
var _ui_name_map: Dictionary = {}

## 當前選中的賽道 ID
var selected_track_id: StringName = &"default"


func _ready() -> void:
	_register_builtin_tracks()


func _register_builtin_tracks() -> void:
	var default_cfg := load(DEFAULT_TRACK_PATH) as TrackConfig
	if default_cfg != null:
		register_track(default_cfg)
		_ui_name_map["預設賽道"] = default_cfg.track_id
		_ui_name_map["東京灣夜景"] = default_cfg.track_id
		_ui_name_map["阿爾卑斯山道"] = default_cfg.track_id
		_ui_name_map["城市街道"] = default_cfg.track_id


func register_track(cfg: TrackConfig) -> void:
	if cfg == null or cfg.track_id == &"":
		return
	_tracks[cfg.track_id] = cfg
	_ui_name_map[cfg.display_name] = cfg.track_id


func get_selected_track() -> TrackConfig:
	if _tracks.has(selected_track_id):
		return _tracks[selected_track_id] as TrackConfig
	if _tracks.has(&"default"):
		return _tracks[&"default"] as TrackConfig
	return load(DEFAULT_TRACK_PATH) as TrackConfig


func get_track(id: StringName) -> TrackConfig:
	return _tracks.get(id, null) as TrackConfig


func get_track_by_ui_name(ui_name: String) -> TrackConfig:
	if _ui_name_map.has(ui_name):
		var id: StringName = _ui_name_map[ui_name]
		return _tracks.get(id, null) as TrackConfig
	var id_name := StringName(ui_name)
	if _tracks.has(id_name):
		return _tracks[id_name] as TrackConfig
	return get_selected_track()


func select_track_by_ui_name(ui_name: String) -> bool:
	var cfg := get_track_by_ui_name(ui_name)
	if cfg != null:
		selected_track_id = cfg.track_id
		return true
	return false


## 提供給 Lobby UI 的接口：取得所有可選擇的賽道顯示名稱
func get_available_map_names() -> Array[String]:
	var names: Array[String] = []
	for name_key in _ui_name_map.keys():
		var s := String(name_key)
		if not names.has(s):
			names.append(s)
	return names


## 提供給 Lobby UI 的接口：取得指定賽道的預設房規/資訊
func get_track_info(ui_name_or_id: String) -> Dictionary:
	var cfg := get_track_by_ui_name(ui_name_or_id)
	if cfg == null:
		cfg = get_selected_track()
	if cfg == null:
		return {}
	return {
		"id": cfg.track_id,
		"display_name": cfg.display_name,
		"scene_path": cfg.scene_path,
		"total_checkpoints": cfg.total_checkpoints(),
		"gate_size": cfg.gate_size,
		"roadbed_path": cfg.roadbed_path,
	}