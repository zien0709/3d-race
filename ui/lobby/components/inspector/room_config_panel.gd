extends VBoxContainer
class_name RoomConfigPanel

## RoomConfigPanel - 房間設定面板
## 顯示並編輯房間配置：地圖、模式、人數、隱私、車輛限制、傷害模式、自動開始、觀戰者

signal config_changed(row: String, value: String)

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.22, 0.74, 0.97)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)

@onready var map_option: OptionButton = $ConfigContainer/MapRow/MapOption
@onready var mode_option: OptionButton = $ConfigContainer/ModeRow/ModeOption
@onready var max_players_spin: SpinBox = $ConfigContainer/MaxPlayersRow/MaxPlayersSpin
@onready var privacy_option: OptionButton = $ConfigContainer/PrivacyRow/PrivacyOption
@onready var car_restriction_option: OptionButton = $ConfigContainer/CarRestrictionRow/CarRestrictionOption
@onready var damage_mode_option: OptionButton = $ConfigContainer/DamageModeRow/DamageModeOption
@onready var auto_start_option: OptionButton = $ConfigContainer/AutoStartRow/AutoStartOption
@onready var spectator_check: CheckBox = $ConfigContainer/SpectatorCheck
@onready var save_btn: Button = $ConfigContainer/ActionRow/SaveBtn
@onready var cancel_btn: Button = $ConfigContainer/ActionRow/CancelBtn

var _is_host: bool = true

func _ready() -> void:
	_setup_options()
	_connect_signals()
	
	# Style buttons
	_style_action_buttons()

func _setup_options() -> void:
	# Map options
	map_option.clear()
	var maps := ["東京灣夜景", "極光峽谷", "沙漠風暴", "城市賽道", "山脈蜿蜒"]
	for m in maps:
		map_option.add_item(m)
	
	# Mode options
	mode_option.clear()
	var modes := ["經典競速", "計時賽", "淘汰賽", "追逐戰"]
	for m in modes:
		mode_option.add_item(m)
	
	# Privacy options
	privacy_option.clear()
	privacy_option.add_item("公開")
	privacy_option.add_item("私人")
	privacy_option.add_item("好友")
	
	# Car restriction options
	car_restriction_option.clear()
	var car_opts := ["全開放", "同級別", "指定車輛"]
	for c in car_opts:
		car_restriction_option.add_item(c)
	
	# Damage mode options
	damage_mode_option.clear()
	var dmg_opts := ["關閉", "輕度", "標準", "真實"]
	for d in dmg_opts:
		damage_mode_option.add_item(d)
	
	# Auto start options
	auto_start_option.clear()
	auto_start_option.add_item("立即開始")
	auto_start_option.add_item("倒數10秒")
	auto_start_option.add_item("倒數30秒")
	auto_start_option.add_item("手動開始")

func _connect_signals() -> void:
	map_option.item_selected.connect(_on_map_changed)
	mode_option.item_selected.connect(_on_mode_changed)
	max_players_spin.value_changed.connect(_on_max_players_changed)
	privacy_option.item_selected.connect(_on_privacy_changed)
	car_restriction_option.item_selected.connect(_on_car_restriction_changed)
	damage_mode_option.item_selected.connect(_on_damage_mode_changed)
	auto_start_option.item_selected.connect(_on_auto_start_changed)
	spectator_check.toggled.connect(_on_spectator_toggled)
	save_btn.pressed.connect(_on_save_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)

func _style_action_buttons() -> void:
	# Save button style
	var save_style = StyleBoxFlat.new()
	save_style.bg_color = C_CYAN
	save_style.set_corner_radius_all(8)
	save_style.content_margin_left = 16
	save_style.content_margin_right = 16
	save_btn.add_theme_stylebox_override("normal", save_style)
	save_btn.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
	
	var save_hover = save_style.duplicate()
	save_hover.bg_color = Color(0.3, 0.85, 1.0)
	save_btn.add_theme_stylebox_override("hover", save_hover)
	
	# Cancel button style
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.2, 0.25, 0.3)
	cancel_style.set_corner_radius_all(8)
	cancel_style.set_border_width_all(1)
	cancel_style.border_color = C_BORDER
	cancel_style.content_margin_left = 16
	cancel_style.content_margin_right = 16
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_color_override("font_color", C_TEXT)
	
	var cancel_hover = cancel_style.duplicate()
	cancel_hover.bg_color = Color(0.3, 0.35, 0.4)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)

func update_config(config: Dictionary) -> void:
	# Update UI from config
	if config.has("map"):
		map_option.select(map_option.get_item_index(config["map"]))
	if config.has("mode"):
		mode_option.select(mode_option.get_item_index(config["mode"]))
	if config.has("max_players"):
		max_players_spin.value = config["max_players"]
	if config.has("privacy"):
		var privacy_map = {"public": 0, "private": 1, "friends": 2}
		privacy_option.select(privacy_map.get(config["privacy"], 0))
	if config.has("car_restriction"):
		car_restriction_option.select(car_restriction_option.get_item_index(config["car_restriction"]))
	if config.has("damage_mode"):
		damage_mode_option.select(damage_mode_option.get_item_index(config["damage_mode"]))
	if config.has("auto_start"):
		auto_start_option.select(auto_start_option.get_item_index(config["auto_start"]))
	if config.has("spectator"):
		spectator_check.pressed = config["spectator"]

func _on_map_changed(index: int) -> void:
	config_changed.emit("map", map_option.get_item_text(index))

func _on_mode_changed(index: int) -> void:
	config_changed.emit("mode", mode_option.get_item_text(index))

func _on_max_players_changed(value: float) -> void:
	config_changed.emit("maxp", "%d人" % int(value))

func _on_privacy_changed(index: int) -> void:
	var privacy_map = ["public", "private", "friends"]
	config_changed.emit("privacy", privacy_map[index])

func _on_car_restriction_changed(index: int) -> void:
	config_changed.emit("carr", car_restriction_option.get_item_text(index))

func _on_damage_mode_changed(index: int) -> void:
	config_changed.emit("dmg", damage_mode_option.get_item_text(index))

func _on_auto_start_changed(index: int) -> void:
	config_changed.emit("auto", auto_start_option.get_item_text(index))

func _on_spectator_toggled(pressed: bool) -> void:
	# Could emit a signal if needed
	pass

func _on_save_pressed() -> void:
	# Emit all current values
	_on_map_changed(map_option.selected)
	_on_mode_changed(mode_option.selected)
	_on_max_players_changed(max_players_spin.value)
	_on_privacy_changed(privacy_option.selected)
	_on_car_restriction_changed(car_restriction_option.selected)
	_on_damage_mode_changed(damage_mode_option.selected)
	_on_auto_start_changed(auto_start_option.selected)
	
	# Save button visual feedback
	UIAnimations.kill_tweens(save_btn)
	UIAnimations.scale_pop(save_btn, 0.95, 0.1)

func _on_cancel_pressed() -> void:
	UIAnimations.kill_tweens(cancel_btn)
	UIAnimations.scale_pop(cancel_btn, 0.95, 0.1)