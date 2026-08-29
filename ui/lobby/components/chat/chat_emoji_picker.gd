extends PanelContainer

## ChatEmojiPicker - Emoji 選擇面板
## 從輸入列的 😊 按鈕觸發，點擊插入到輸入欄

signal emoji_selected(emoji: String)
signal close_requested()

const C_BG := Color(0.12, 0.15, 0.20, 0.98)
const C_BORDER := Color(0.22, 0.74, 0.97, 0.4)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)

# 常用 emoji 分類
const EMOJI_CATEGORIES := {
	"常用": ["😀", "😂", "❤️", "👍", "🔥", "🎉", "😎", "🏆"],
	"表情": ["😊", "😍", "😘", "😜", "🤔", "😴", "😭", "😡", "🥳", "😱", "🤯", "😇"],
	"手勢": ["👋", "✌️", "🤙", "👏", "🙌", "🤝", "💪", "👀", "🫡", "🤞"],
	"賽車": ["🏎️", "🚗", "🏁", "🛣️", "⚡", "💨", "🏆", "🥇", "🔧", "⛽"],
	"符號": ["✅", "❌", "⚠️", "❓", "❗", "💯", "🔔", "📢", "⭐", "✨"],
}

var _ui_animations: Node = null
var _tab_container: VBoxContainer

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(280, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0.22, 0.74, 0.97, 0.2)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title bar
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "選擇 Emoji"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", C_ACCENT_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Scrollable emoji grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_tab_container = VBoxContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_tab_container)

	_build_categories()

func _build_categories() -> void:
	for category in EMOJI_CATEGORIES:
		var cat_label := Label.new()
		cat_label.text = category
		cat_label.add_theme_font_size_override("font_size", 11)
		cat_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65))
		_tab_container.add_child(cat_label)

		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_tab_container.add_child(grid)

		for emoji in EMOJI_CATEGORIES[category]:
			var btn := Button.new()
			btn.text = emoji
			btn.flat = true
			btn.custom_minimum_size = Vector2(36, 36)
			btn.add_theme_font_size_override("font_size", 20)
			btn.pressed.connect(func(): emoji_selected.emit(emoji))
			btn.mouse_entered.connect(func():
				if _ui_animations: _ui_animations.scale_to(btn, 1.2, 0.1)
			)
			btn.mouse_exited.connect(func():
				if _ui_animations: _ui_animations.scale_to(btn, 1.0, 0.1)
			)
			grid.add_child(btn)
