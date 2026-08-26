extends Node

func fade_in(node: Control, duration: float = 0.2) -> Tween:
	node.modulate.a = 0.0
	node.visible = true
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

func fade_out(node: Control, duration: float = 0.2) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): node.visible = false)
	return tween

func slide_in_from_top(node: Control, duration: float = 0.3) -> Tween:
	var end_pos := node.position
	node.position = Vector2(end_pos.x, end_pos.y - node.size.y)
	node.visible = true
	var tween := create_tween()
	tween.tween_property(node, "position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

func slide_out_to_top(node: Control, duration: float = 0.2) -> Tween:
	var end_pos := Vector2(node.position.x, node.position.y - node.size.y)
	var tween := create_tween()
	tween.tween_property(node, "position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): node.visible = false)
	return tween

func slide_in_from_right(node: Control, duration: float = 0.3) -> Tween:
	var end_pos := node.position
	node.position = Vector2(end_pos.x + node.size.x, end_pos.y)
	node.visible = true
	var tween := create_tween()
	tween.tween_property(node, "position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

func slide_out_to_right(node: Control, duration: float = 0.2) -> Tween:
	var end_pos := Vector2(node.position.x + node.size.x, node.position.y)
	var tween := create_tween()
	tween.tween_property(node, "position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): node.visible = false)
	return tween

func scale_pop(node: Control, scale: float = 1.1, duration: float = 0.15) -> Tween:
	node.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(scale, scale), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func scale_press(node: Control, scale: float = 0.95, duration: float = 0.1) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(scale, scale), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func scale_release(node: Control, duration: float = 0.15) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func animate_progress_bar(bar: ProgressBar, target_value: float, duration: float = 0.5) -> Tween:
	var tween := create_tween()
	tween.tween_property(bar, "value", target_value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func panel_open(node: Control, duration: float = 0.25) -> Tween:
	node.modulate.a = 0.0
	node.scale = Vector2(0.9, 0.9)
	node.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func panel_close(node: Control, duration: float = 0.2) -> Tween:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", Vector2(0.9, 0.9), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): node.visible = false)
	return tween

func scale_to(node: Control, scale: float, duration: float = 0.12, trans: int = Tween.TRANS_SINE, ease: int = Tween.EASE_OUT) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(scale, scale), duration).set_trans(trans).set_ease(ease)
	return tween

func kill_tweens(node: Node) -> void:
	for tween in node.get_tweens():
		tween.kill()