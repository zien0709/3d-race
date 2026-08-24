extends Node

## 玩家資料雲端儲存（EOS PlayerDataStorage）。
## 用低階 EOS.PlayerDataStorage API 讀寫單一 profile.json，
## 存放公開暱稱等輕量玩家資料。
## 注意：所有操作都是非同步的，請用 await 取得結果。

signal profile_saved(ok: bool)

const PROFILE_FILENAME := "profile.json"
const CHUNK_LENGTH_BYTES := 4096

var _read_buffer := PackedByteArray()


func is_available() -> bool:
	return NetworkManager.is_eos_ready and not NetworkManager.product_user_id.is_empty()


## 檢查雲端是否已有 profile。回傳 true 代表已存在。
func has_profile() -> bool:
	var eos := _eos()
	if eos == null or not is_available():
		return false
	var opts = eos.PlayerDataStorage.QueryFileOptions.new()
	opts.local_user_id = NetworkManager.product_user_id
	opts.filename = PROFILE_FILENAME
	eos.PlayerDataStorage.PlayerDataStorageInterface.query_file(opts)
	var ret: Dictionary = await IEOS.playerdatastorage_interface_query_file_callback
	return bool(eos.is_success(ret))


## 從雲端讀取 profile。回傳 Dictionary，失敗時為空字典。
func load_profile() -> Dictionary:
	var eos := _eos()
	if eos == null or not is_available():
		return {}
	var opts = eos.PlayerDataStorage.ReadFileOptions.new()
	opts.local_user_id = NetworkManager.product_user_id
	opts.filename = PROFILE_FILENAME
	opts.read_chunk_length_bytes = CHUNK_LENGTH_BYTES
	_read_buffer = PackedByteArray()
	IEOS.playerdatastorage_interface_read_file_data_callback.connect(_on_read_file_data)
	eos.PlayerDataStorage.PlayerDataStorageInterface.read_file(opts)
	var ret: Dictionary = await IEOS.playerdatastorage_interface_read_file_callback
	IEOS.playerdatastorage_interface_read_file_data_callback.disconnect(_on_read_file_data)
	if not bool(eos.is_success(ret)):
		return {}
	var json_text := _read_buffer.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	return parsed as Dictionary if parsed is Dictionary else {}


## 上傳 profile 到雲端。回傳是否成功。
func save_profile(profile: Dictionary) -> bool:
	var eos := _eos()
	if eos == null or not is_available():
		return false
	var json_text := JSON.stringify(profile)
	var opts = eos.PlayerDataStorage.WriteFileOptions.new()
	opts.local_user_id = NetworkManager.product_user_id
	opts.filename = PROFILE_FILENAME
	opts.data = json_text.to_utf8_buffer()
	opts.chunk_length_bytes = CHUNK_LENGTH_BYTES
	eos.PlayerDataStorage.PlayerDataStorageInterface.write_file(opts)
	var ret: Dictionary = await IEOS.playerdatastorage_interface_write_file_callback
	var ok: bool = bool(eos.is_success(ret))
	profile_saved.emit(ok)
	return ok


func _on_read_file_data(data: Dictionary) -> void:
	var chunk: PackedByteArray = data.get("data_chunk", PackedByteArray())
	_read_buffer.append_array(chunk)


func _eos() -> GDScript:
	return load("res://addons/epic-online-services-godot/eos.gd")