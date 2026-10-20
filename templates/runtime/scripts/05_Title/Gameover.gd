## 职责：控制游戏结束页面，处理返回标题或结束流程。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/05_Title/Gameover.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func return_to_title() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends Control
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")


func _ready() -> void:
	theme = Theme.new()
	theme.default_font = preload("res://runtime/scripts/04_UI_Common/UIResources.gd").font()
	RuntimeState.playing = false
	get_tree().paused = false
	RuntimeState.audio.stop_all()
	var shade := ColorRect.new()
	shade.color = Color("151a24")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var name_value := str(Data.system().get("gameover_name", ""))
	var texture: Texture2D = Cache.gameover(name_value)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(image)
	elif not name_value.is_empty():
		RuntimeState.report_diagnostic("Gameovers/%s缺失，显示游戏结束页面。" % name_value)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var label := Label.new()
	label.text = "游戏结束"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	box.add_child(label)
	var button := Button.new()
	button.text = "返回标题"
	button.custom_minimum_size = Vector2(220, 46)
	button.pressed.connect(return_to_title)
	box.add_child(button)
	button.grab_focus()
	var audio: Variant = Data.system().get("gameover_me", {})
	if audio is Dictionary:
		var result: Dictionary = RuntimeState.audio.play("ME", audio)
		if not result.ok:
			RuntimeState.report_diagnostic(result.message)


func return_to_title() -> void:
	preload("res://runtime/scripts/04_UI_Common/UIResources.gd").clear()
	get_tree().change_scene_to_file("res://scenes/05_Title/Title.tscn")
