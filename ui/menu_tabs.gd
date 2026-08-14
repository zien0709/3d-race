extends VBoxContainer

## MainCard 分頁控制。
## 三顆分頁按鈕（登入/註冊/體驗）切換下方的內容頁面，並帶有淡入淡出 + 微縮放動畫。

enum Tab { LOGIN, REGISTER, PLAY }

const FADE_DURATION := 0.22

@onready var login_button: Button = $TabHeader/LoginButton
@onready var register_button: Button = $TabHeader/RegisterButton
@onready var play_button: Button = $TabHeader/PlayButton
@onready var login_page: Control = $ContentArea/Margin/ContentStack/LoginPage
@onready var register_page: Control = $ContentArea/Margin/ContentStack/RegisterPage
@onready var play_page: Control = $ContentArea/Margin/ContentStack/PlayPage

var _current_tab: Tab = Tab.PLAY
var _fade_tween: Tween

func _ready() -> void:
	login_button.pressed.connect(_switch_tab.bind(Tab.LOGIN))
	register_button.pressed.connect(_switch_tab.bind(Tab.REGISTER))
	play_button.pressed.connect(_switch_tab.bind(Tab.PLAY))
	_setup_page(login_page)
	_setup_page(register_page)
	_setup_page(play_page)
	_apply_tab(Tab.PLAY, false)


func _switch_tab(tab: Tab) -> void:
	_apply_tab(tab, tab != _current_tab)


func _apply_tab(tab: Tab, animate: bool) -> void:
	var old_page := _page_for(_current_tab)
	var new_page := _page_for(tab)
	_current_tab = tab

	login_button.button_pressed = tab == Tab.LOGIN
	register_button.button_pressed = tab == Tab.REGISTER
	play_button.button_pressed = tab == Tab.PLAY

	if old_page == new_page:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	new_page.visible = true
	new_page.modulate.a = 0.0
	new_page.scale = Vector2(0.97, 0.97)

	if not animate:
		_finish_switch(old_page, new_page)
		return

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(new_page, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(new_page, "scale", Vector2.ONE, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(old_page, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.chain().tween_callback(func():
		_finish_switch(old_page, new_page)
	)


func _finish_switch(old_page: Control, new_page: Control) -> void:
	old_page.visible = false
	old_page.modulate.a = 1.0
	old_page.scale = Vector2.ONE
	new_page.modulate.a = 1.0
	new_page.scale = Vector2.ONE


func _page_for(tab: Tab) -> Control:
	match tab:
		Tab.LOGIN:
			return login_page
		Tab.REGISTER:
			return register_page
		Tab.PLAY:
			return play_page
	return play_page


func _setup_page(page: Control) -> void:
	page.pivot_offset = page.size * 0.5
	page.resized.connect(_on_page_resized.bind(page))
	if page != play_page:
		page.visible = false


func _on_page_resized(page: Control) -> void:
	page.pivot_offset = page.size * 0.5
