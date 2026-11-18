extends RichTextLabel

## ChatMessageLine - lightweight plain-text message row (BBCode, no card).
## Replaces ChatMessageItem bricks: no avatar, no background block.
## Sender name is a [url] link (click → private chat); right-click opens reactions.

signal sender_clicked(sender_name: String, sender_id: String)
signal reaction_panel_requested(message_id: String, item_rect: Rect2)

const C_SELF_NAME := "#0ce892"
const C_SELF_TEXT := "#e0e0e0"
const C_OTHER_NAME := "#90a0b0"
const C_OTHER_TEXT := "#ffffff"
const C_SYSTEM := "#38bdfa"
const C_HIGHLIGHT := "#FFE14D"

var _msg: Dictionary = {}
var _highlight: String = ""

func _ready() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_font_size_override("normal_font_size", 13)
	add_theme_color_override("default_color", Color(0.9, 0.92, 0.95))
	meta_clicked.connect(_on_meta_clicked)
	gui_input.connect(_on_gui_input)

func setup(msg: Dictionary, _self_id: String = "") -> void:
	_msg = msg
	_render()

func set_highlight(query: String) -> void:
	_highlight = query
	_render()

static func escape_bbcode(s: String) -> String:
	return s.replace("[", "[lb]")

func _render() -> void:
	if _msg.is_empty():
		text = ""
		return
	var sender := str(_msg.get("sender", ""))
	var sender_id := str(_msg.get("sender_id", ""))
	var body := str(_msg.get("text", ""))
	var is_self := bool(_msg.get("is_self", false))
	var is_private := bool(_msg.get("is_private", false))
	var esc_body := escape_bbcode(body)
	if not _highlight.strip_edges().is_empty():
		esc_body = _apply_highlight(esc_body, _highlight)
	var line := ""
	if sender == "System":
		line = "[color=" + C_SYSTEM + "]" + esc_body + "[/color]"
	elif is_self:
		line = "[color=" + C_SELF_NAME + "]You:[/color] [color=" + C_SELF_TEXT + "]" + esc_body + "[/color]"
	else:
		var esc_name := escape_bbcode(sender)
		line = "[url=" + sender_id + "]" + "[color=" + C_OTHER_NAME + "]" + esc_name + ":[/color][/url] [color=" + C_OTHER_TEXT + "]" + esc_body + "[/color]"
	if is_private:
		line += " [color=" + C_OTHER_NAME + "]🔒[/color]"
	var rx := _reaction_suffix()
	if rx != "":
		line += " " + rx
	text = line

func _reaction_suffix() -> String:
	var out := ""
	var reactions: Dictionary = _msg.get("reactions", {})
	for emoji in reactions.keys():
		var r: Dictionary = reactions[emoji]
		out += "[color=" + C_OTHER_NAME + "]" + str(emoji) + "×" + str(r.get("count", 0)) + "[/color] "
	return out.strip_edges()

func _apply_highlight(esc_text: String, query: String) -> String:
	var q := query.strip_edges()
	if q.is_empty():
		return esc_text
	var lower_text := esc_text.to_lower()
	var lower_q := q.to_lower()
	var result := ""
	var idx := 0
	while true:
		var found := lower_text.find(lower_q, idx)
		if found == -1:
			result += esc_text.substr(idx)
			break
		result += esc_text.substr(idx, found - idx)
		result += "[color=" + C_HIGHLIGHT + "]" + esc_text.substr(found, q.length()) + "[/color]"
		idx = found + q.length()
	return result

func _on_meta_clicked(meta: Variant) -> void:
	var sid := str(meta)
	if sid.is_empty():
		return
	sender_clicked.emit(str(_msg.get("sender", "")), sid)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			reaction_panel_requested.emit(str(_msg.get("id", "")), get_global_rect())
