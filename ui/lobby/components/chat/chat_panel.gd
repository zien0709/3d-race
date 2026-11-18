extends PanelContainer

## ChatPanel - 聊天主面板（Dock 模式）
## 從底部 Dock 條向上展開，與 Dock 條共用圓角和邊框風格

const ChatData := preload("res://ui/lobby/components/chat/chat_data.gd")
const ChatMessageLineScript := preload("res://ui/lobby/components/chat/chat_message_line.gd")
const ChatTabsScript := preload("res://ui/lobby/components/chat/chat_tabs.gd")
const ChatEmojiPickerScript := preload("res://ui/lobby/components/chat/chat_emoji_picker.gd")
const ChatSearchBarScript := preload("res://ui/lobby/components/chat/chat_search_bar.gd")
const ChatReactionsScript := preload("res://ui/lobby/components/chat/chat_reactions.gd")

signal tab_changed(tab: String)
signal message_sent(text: String, is_private: bool, target_id: String)
signal private_message_sent(target_id: String, text: String)
signal reaction_added(message_id: String, emoji: String)
signal reaction_removed(message_id: String, emoji: String)
signal search_query_changed(query: String)
signal closed()

const C_BG := Color(0.08, 0.10, 0.14, 0.96)
const C_BORDER := Color(0.22, 0.74, 0.97, 0.5)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)
const C_TEXT_MUTED := Color(0.50, 0.55, 0.60)

var _tabs: Node
var _message_list: VBoxContainer
var _vbox: VBoxContainer = null
var _scroll: ScrollContainer
var _input_bar: Node
var _emoji_picker: Node
var _search_bar: Node
var _reactions_panel: Node
var _close_btn: Button
var _search_btn: Button
var _header_row: HBoxContainer
var _ui_animations: Node = null

var active_tab: String = "room"
var _messages: Array = []
var _message_items: Dictionary = {}
var _search_active: bool = false
var _search_query: String = ""
var _panel_height: float = 400.0
var _close_tween: Tween = null
var _open_tween: Tween = null
var _is_open: bool = false

func _ready() -> void:
	_ui_animations = UIAnimations
	# Embedded mode: LeftContent owns our rect (fill). No anchor forcing,
	# no offset tweens — open/close is visible + fade only.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Hard crop: nothing inside the panel may paint outside its rect.
	clip_contents = true
	_build_style()
	_build_ui()
	set_active_tab(active_tab)
	visible = false
	modulate.a = 1.0

func _hide_phrase_bar() -> void:
	# Q3-A: hide the shared ChatInputBar phrase scroller at panel level;
	# chat_input_bar.gd itself stays generic (BottomBar Dock owns phrases).
	if _input_bar == null:
		return
	for child in _input_bar.get_children():
		if child is ScrollContainer:
			child.visible = false
			return

func _build_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0.22, 0.74, 0.97, 0.15)
	sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	_vbox = vbox

	# Header: single flat HBox row — tabs + spring + search + close.
	# Search lives in its own row below and alternates with the header
	# (exactly one visible), so the top block is always one row tall.
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_header_row)

	_tabs = ChatTabsScript.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tabs.tab_selected.connect(_on_tab_selected)
	_header_row.add_child(_tabs)
	# After add_child so tabs _ready has built the button.
	_tabs.set_search_button_visible(false)

	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_row.add_child(spring)

	_search_btn = Button.new()
	_search_btn.text = "🔍"
	_search_btn.flat = true
	_search_btn.custom_minimum_size = Vector2(32, 32)
	_search_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_btn.add_theme_font_size_override("font_size", 14)
	_search_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
	_search_btn.tooltip_text = "搜尋訊息"
	_search_btn.pressed.connect(_on_search_pressed)
	_header_row.add_child(_search_btn)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
	_close_btn.tooltip_text = "關閉聊天"
	_close_btn.pressed.connect(_on_close_pressed)
	_header_row.add_child(_close_btn)

	_search_bar = ChatSearchBarScript.new()
	_search_bar.visible = false
	_search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_bar.search_changed.connect(_on_search_changed)
	_search_bar.search_closed.connect(_on_search_closed)
	vbox.add_child(_search_bar)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_message_list = VBoxContainer.new()
	_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_message_list)

	# Input lives in BottomBar (single source); attached via attach_input_bar().

	_emoji_picker = ChatEmojiPickerScript.new()
	_emoji_picker.visible = false
	_emoji_picker.emoji_selected.connect(_on_emoji_selected)
	_emoji_picker.close_requested.connect(func(): _emoji_picker.hide())
	add_child(_emoji_picker)

	_reactions_panel = ChatReactionsScript.new()
	_reactions_panel.visible = false
	_reactions_panel.reaction_selected.connect(_on_reaction_selected)
	_reactions_panel.close_requested.connect(func(): _reactions_panel.hide())
	add_child(_reactions_panel)

## ── 訊息管理 ──────────────────────────────────────────────

func add_message(sender: String, text: String, is_self: bool, tab: String = "room",
		sender_id: String = "", is_private: bool = false, target_id: String = "") -> Dictionary:
	var sid := sender_id
	if sid.is_empty():
		var nm = get_node_or_null("/root/NetworkManager")
		if nm != null:
			sid = nm.get("product_user_id")
	var msg := ChatData.create_message(sender, sid, text, tab, is_self, is_private, target_id)
	_messages.append(msg)
	_append_message_item(msg)
	if not is_private and tab != active_tab and not _search_active:
		_tabs.add_unread(tab)
	return msg

func add_system_message(text: String) -> Dictionary:
	var msg := ChatData.create_system_message(text)
	_messages.append(msg)
	_append_message_item(msg)
	if "system" != active_tab and not _search_active:
		_tabs.add_unread("system")
	return msg

func add_private_message(sender: String, target_id: String, text: String, is_self: bool) -> Dictionary:
	var sender_id := ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null:
		sender_id = nm.get("product_user_id")
	var msg := ChatData.create_message(sender, sender_id, text, "room", is_self, true, target_id)
	_messages.append(msg)
	_append_message_item(msg)
	if not _search_active:
		_tabs.add_unread("room")
	return msg

func _append_message_item(msg: Dictionary) -> void:
	if _search_active:
		if msg["text"].to_lower().contains(_search_query.to_lower()):
			_create_item(msg)
		return
	if msg.get("is_private", false):
		if active_tab == "room":
			_create_item(msg)
		return
	if msg["tab"] == active_tab:
		_create_item(msg)

func _create_item(msg: Dictionary) -> void:
	var item := ChatMessageLineScript.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.reaction_panel_requested.connect(_on_item_reaction_panel)
	item.sender_clicked.connect(_on_item_sender_clicked)
	var msg_margin := MarginContainer.new()
	msg_margin.add_theme_constant_override("margin_left", 12)
	msg_margin.add_theme_constant_override("margin_right", 12)
	msg_margin.add_theme_constant_override("margin_top", 6)
	msg_margin.add_theme_constant_override("margin_bottom", 6)
	msg_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_margin.add_child(item)
	_message_list.add_child(msg_margin)
	item.setup(msg)
	_message_items[msg["id"]] = item
	# Fade-only entrance: position tweens fight container layout (the wrap rests
	# the line at x=12, not 0) and leave the newest batch misaligned.
	item.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	# Two frames: RichTextLabel fit_content needs a layout pass before max is
	# valid, otherwise rapid sends land mid-item (half-cut shifted list).
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func clear_messages() -> void:
	for child in _message_list.get_children():
		child.queue_free()
	_message_items.clear()
	_messages.clear()

func set_active_tab(tab_id: String) -> void:
	active_tab = tab_id
	if _tabs != null:
		_tabs.set_active_tab(tab_id)
	_rebuild_message_list()

func _rebuild_message_list() -> void:
	for child in _message_list.get_children():
		child.queue_free()
	_message_items.clear()
	var msgs_to_show: Array
	if _search_active:
		msgs_to_show = ChatData.search_messages(_messages, _search_query)
	else:
		msgs_to_show = ChatData.filter_by_tab(_messages, active_tab)
		if active_tab == "room":
			msgs_to_show += ChatData.filter_private_messages(_messages, _get_self_id())
	for msg in msgs_to_show:
		_create_item(msg)

## ── 輸入列 ────────────────────────────────────────────────

func focus_input() -> void:
	if _input_bar != null:
		_input_bar.focus_input()

func set_private_target(target_name: String, target_id: String) -> void:
	if _input_bar != null:
		_input_bar.set_private_mode(true, target_name, target_id)

func clear_private_target() -> void:
	if _input_bar != null:
		_input_bar.set_private_mode(false, "")

## ── Dock 模式開關動畫 ──────────────────────────────────────

func open_chat() -> void:
	_kill_tweens()
	if _is_open:
		focus_input()
		return
	_is_open = true
	visible = true
	modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	focus_input()

func close_chat() -> void:
	if not _is_open:
		return
	_kill_tweens()
	_close_tween = create_tween()
	_close_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_close_tween.tween_callback(_hide_after_close)

func _hide_after_close() -> void:
	visible = false
	_is_open = false

func _kill_tweens() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
		_open_tween = null
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
		_close_tween = null

func attach_input_bar(bar: Node) -> void:
	if _input_bar == bar:
		return
	_input_bar = bar
	# Move the BottomBar input into the panel column (single input source).
	if bar.get_parent() != null:
		bar.get_parent().remove_child(bar)
	if _vbox != null:
		_vbox.add_child(bar)
		_vbox.move_child(bar, -1)
	_input_bar.message_submitted.connect(_on_message_submitted)
	_input_bar.emoji_button_pressed.connect(_on_emoji_pressed)
	_hide_phrase_bar()

## ── 信號處理 ──────────────────────────────────────────────

func _on_tab_selected(tab_id: String) -> void:
	set_active_tab(tab_id)
	tab_changed.emit(tab_id)

func _on_close_pressed() -> void:
	close_chat()
	closed.emit()

func _on_message_submitted(text: String, is_private: bool, target_id: String) -> void:
	if is_private and target_id != "":
		private_message_sent.emit(target_id, text)
	else:
		message_sent.emit(text, is_private, target_id)

func _set_header_mode(search_mode: bool) -> void:
	if _header_row != null:
		_header_row.visible = not search_mode
	if _search_bar != null:
		_search_bar.visible = search_mode

func _on_search_pressed() -> void:
	_search_active = true
	_set_header_mode(true)
	if _input_bar != null and _input_bar.has_method("release_input_focus"):
		_input_bar.release_input_focus()
	_search_bar.focus_input()
	_rebuild_message_list()

func _on_search_changed(query: String) -> void:
	_search_query = query
	search_query_changed.emit(query)
	_search_bar.set_match_count(ChatData.search_messages(_messages, query).size())
	_rebuild_message_list()
	for msg_id in _message_items:
		_message_items[msg_id].set_highlight(query)

func _on_search_closed() -> void:
	# NOTE: programmatic LineEdit.clear() does NOT emit text_changed,
	# so reset the query explicitly instead of relying on a cascade.
	_search_bar.clear_query()
	_search_active = false
	_search_bar.release_search_focus()
	_set_header_mode(false)
	_on_search_changed("")
	_search_bar.set_match_count(0)

func _on_emoji_pressed() -> void:
	if _emoji_picker != null:
		_emoji_picker.visible = not _emoji_picker.visible
		if _emoji_picker.visible:
			# Dock inside the panel above the message list: panel-local
			# coords keep it inside regardless of where the input bar lives.
			_emoji_picker.position = Vector2(8, size.y - 268.0)

func _on_emoji_selected(emoji: String) -> void:
	if _input_bar != null:
		_input_bar.insert_text(emoji)
	_emoji_picker.visible = false


func _on_item_reaction_panel(message_id: String, item_rect: Rect2) -> void:
	if _reactions_panel != null:
		_reactions_panel.visible = true
		_reactions_panel.position = Vector2(item_rect.position.x, item_rect.position.y - 50)
		_reactions_panel.set_target_message(message_id)

func _on_item_sender_clicked(sender_name: String, sender_id: String) -> void:
	if sender_id.is_empty():
		return
	set_private_target(sender_name, sender_id)
	focus_input()

func _on_reaction_selected(emoji: String) -> void:
	if _reactions_panel != null and _reactions_panel.has_method("get_target_message"):
		var msg_id: String = _reactions_panel.get_target_message()
		_toggle_reaction(msg_id, emoji)
	_reactions_panel.visible = false

func _toggle_reaction(message_id: String, emoji: String) -> void:
	var msg: Dictionary = {}
	for m in _messages:
		if m["id"] == message_id:
			msg = m
			break
	if msg.is_empty():
		return
	var self_id := _get_self_id()
	if ChatData.has_user_reacted(msg, emoji, self_id):
		ChatData.remove_reaction(msg, emoji, self_id)
		reaction_removed.emit(message_id, emoji)
	else:
		ChatData.add_reaction(msg, emoji, self_id)
		reaction_added.emit(message_id, emoji)
	if _message_items.has(message_id):
		_message_items[message_id].setup(msg)

func add_reaction(message_id: String, emoji: String) -> void:
	var msg: Dictionary = {}
	for m in _messages:
		if m["id"] == message_id:
			msg = m
			break
	if msg.is_empty():
		return
	ChatData.add_reaction(msg, emoji, "remote")
	if _message_items.has(message_id):
		_message_items[message_id].setup(msg)

func remove_reaction(message_id: String, emoji: String) -> void:
	var msg: Dictionary = {}
	for m in _messages:
		if m["id"] == message_id:
			msg = m
			break
	if msg.is_empty():
		return
	ChatData.remove_reaction(msg, emoji, "remote")
	if _message_items.has(message_id):
		_message_items[message_id].setup(msg)

func _get_self_id() -> String:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null:
		return nm.get("product_user_id")
	return ""

func get_messages() -> Array:
	return _messages
