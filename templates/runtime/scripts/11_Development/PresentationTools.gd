## 职责：提供动画、音频和界面演出的运行时测试入口。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/11_Development/PresentationTools.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func has_text_focus() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func navigate(direction: int) -> void
##     用途：移动当前页面的选中项。
##     参数 direction（int；必填）：选择或调整的方向增量；正负号按当前页面的导航逻辑处理。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func activate() -> void
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func back() -> void
##     用途：从当前页面或操作返回。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：由持有方发出，通知对应状态或操作结果。
##   sound_requested(key: String)：由持有方发出，通知对应状态或操作结果。
##     key：查询或写入使用的键名。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 接口说明结束。

extends Control
signal back_requested
signal sound_requested(key: String)
const Base = preload("res://runtime/scripts/04_UI_Common/WindowBase.gd")
const Resources = preload("res://runtime/scripts/04_UI_Common/UIResources.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const ViewModel = preload("res://runtime/scripts/00_Game/MapViewState.gd")
const Effects = preload("res://runtime/scripts/00_Game/MapEffectsState.gd")
const Countdown = preload("res://runtime/scripts/00_Game/GameTimer.gd")
const AudioService = preload("res://runtime/scripts/10_Support/Audio/AudioRuntime.gd")
var view: RefCounted = ViewModel.new()
var effects: RefCounted = Effects.new()
var screen: RefCounted = preload("res://runtime/scripts/00_Game/ScreenState.gd").new()
var timer: RefCounted = Countdown.new()
var map: Node2D
var avatar: Node2D
var camera: Camera2D
var renderer: Node
var transition: CanvasLayer
var audio: Node
var viewport: SubViewport
var tabs: TabContainer
var fields := {}
var choices := {}
var buttons: Array[Button] = []
var selected := 0
var status: Label
var _message := "独立大地图：方向键行走，Tab选按钮，Z确认；参数可用鼠标编辑。"
var _audio_paths := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Base.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.label("地图表现与镜头 · 独立验收区", Rect2(0, 0, size.x - 160, 28), Color("c0e0ff"), 20)
	_button(panel, "返回 · Esc", back).position = Vector2(size.x - 144, 16)
	tabs = TabContainer.new()
	tabs.position = Vector2(16, 52)
	tabs.size = Vector2(size.x - 32, 176)
	tabs.add_theme_font_override("font", Resources.font())
	panel.add_child(tabs)
	var camera_page := _page("镜头")
	var logical := get_viewport_rect().size
	for entry in [
		["x", "区域X", 0, logical.x],
		["y", "区域Y", 0, logical.y],
		["width", "区域宽", logical.x, 4096],
		["height", "区域高", logical.y, 4096],
		["cx", "中心X", logical.x / 2, 4096],
		["cy", "中心Y", logical.y / 2, 4096]
	]:
		_number(camera_page, entry[0], entry[1], entry[2], 0, entry[3])
	for entry in [
		["应用预览", _apply_view],
		["预览：左侧UI", _left_ui],
		["右滚4格", _scroll],
		["恢复跟随", _follow],
		["地图右下角", _edge],
		["应用到真实地图", _apply_real_view]
	]:
		_button(camera_page, entry[0], entry[1])
	var effects_page := _page("地图表现")
	_picker(effects_page, "panorama", "全景", "Panoramas", ["无", "工具绘制对照图"])
	_picker(effects_page, "fog", "雾", "Fogs", ["无", "工具绘制对照图"])
	for entry in [
		["panorama_hue", "全景色相", 0, 0, 360],
		["fog_hue", "雾色相", 0, 0, 360],
		["fog_opacity", "雾透明度", 128, 0, 255],
		["fog_blend_type", "混合0/1/2", 0, 0, 2],
		["fog_zoom", "雾缩放%", 100, 1, 10000],
		["fog_sx", "雾SX", 2, -1000, 1000],
		["fog_sy", "雾SY", 1, -1000, 1000],
		["weather_power", "天气强度", 6, 0, 9]
	]:
		_number(effects_page, entry[0], entry[1], entry[2], entry[3], entry[4])
	for entry in [
		["应用素材/参数", _apply_effects],
		["雨", _weather.bind(1)],
		["暴风雨", _weather.bind(2)],
		["雪", _weather.bind(3)],
		["关闭天气", _weather.bind(0)],
		["雾渐隐/渐显", _fog_fade],
		["雾色调渐变", _fog_tone],
		["应用到真实地图", _apply_real_effects]
	]:
		_button(effects_page, entry[0], entry[1])
	var other_page := _page("过渡·计时·音频")
	_number(other_page, "seconds", "时长(秒)", 2, 0, 3600)
	_number(other_page, "vague", "过渡边界", 40, 0, 255)
	_picker(other_page, "transition", "过渡素材", "Transitions", ["普通淡化"])
	for entry in [
		["淡出至黑", _fade.bind(255)],
		["淡入地图", _fade.bind(0)],
		["冻结并过渡", _freeze_transition],
		["取消过渡", _cancel_transition],
		["10秒计时", _timer_start],
		["停止计时", _timer_stop],
		["真实地图10秒计时", _real_timer]
	]:
		_button(other_page, entry[0], entry[1])
	for kind in ["BGM", "BGS", "ME", "SE"]:
		_audio_picker(other_page, kind)
	_number(other_page, "volume", "音量", 70, 0, 100)
	_number(other_page, "pitch", "音调", 100, 50, 150)
	for kind in ["BGM", "BGS", "ME", "SE"]:
		_button(other_page, "播放" + kind, _play_audio.bind(kind))
	for entry in [
		["BGM淡出", _audio_fade],
		["记忆BGM/BGS", _audio_memorize],
		["恢复记忆", _audio_restore],
		["停止测试音频", _audio_stop]
	]:
		_button(other_page, entry[0], entry[1])
	var preview_rect := TextureRect.new()
	preview_rect.position = Vector2(16, 238)
	preview_rect.size = Vector2(size.x - 32, maxf(96, size.y - 324))
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(preview_rect)
	viewport = SubViewport.new()
	viewport.size = Vector2i(logical)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	preview_rect.add_child(viewport)
	preview_rect.texture = viewport.get_texture()
	_build_map()
	status = panel.label("", Rect2(0, size.y - 80, size.x - 32, 48), Color("ffe9a8"), 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _page(name_value: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_value
	tabs.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid


func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(140, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", Resources.font())
	button.pressed.connect(action)
	parent.add_child(button)
	buttons.append(button)
	return button


func _number(
	parent: Node, key: String, label: String, value: float, minimum: float, maximum: float
) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var text := Label.new()
	text.text = label
	text.add_theme_font_override("font", Resources.font())
	text.add_theme_font_size_override("font_size", 14)
	row.add_child(text)
	var spinner := SpinBox.new()
	spinner.min_value = minimum
	spinner.max_value = maximum
	spinner.value = value
	spinner.custom_minimum_size.x = 78
	spinner.focus_mode = Control.FOCUS_NONE
	spinner.get_line_edit().focus_mode = Control.FOCUS_CLICK
	spinner.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				spinner.get_line_edit().call_deferred("release_focus")
	)
	row.add_child(spinner)
	fields[key] = spinner


func _picker(parent: Node, key: String, label: String, category: String, initial: Array) -> void:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.add_theme_font_override("font", Resources.font())
	picker.custom_minimum_size = Vector2(160, 30)
	for text in initial:
		picker.add_item(label + "：" + text)
	for name_value in Cache.list_names(category):
		picker.add_item(name_value)
	picker.focus_mode = Control.FOCUS_NONE
	parent.add_child(picker)
	choices[key] = picker


func _audio_picker(parent: Node, kind: String) -> void:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_theme_font_override("font", Resources.font())
	picker.custom_minimum_size = Vector2(160, 30)
	picker.add_item(kind + "：请选择原素材")
	var names := []
	var index: Dictionary = preload("res://runtime/scripts/00_Game/RuntimeData.gd").read_json(
		"res://data/asset_index.json"
	)
	for key in index:
		if key.begins_with("Audio/" + kind + "/"):
			names.append(key.trim_prefix("Audio/" + kind + "/"))
	names.sort()
	var seen := {}
	for name_value in names:
		var path: String = preload("res://runtime/scripts/00_Game/RuntimeData.gd").asset_path(
			"Audio/%s/%s" % [kind, name_value]
		)
		if not path.is_empty() and not seen.has(path):
			picker.add_item(name_value)
			seen[path] = true
	parent.add_child(picker)
	choices[kind] = picker


func _build_map() -> void:
	var fixture := preload("res://runtime/scripts/11_Development/MovementFixture.gd").build()
	var values: Array = []
	values.resize(48 * 36 * 3)
	values.fill(0)
	for y in 36:
		for x in 48:
			values[x + y * 48] = 384 if (x + y) % 5 != 0 else 386
	# The central transparent patch exposes panorama behind the map.
	for y in range(10, 18):
		for x in range(16, 26):
			values[x + y * 48] = 0
	map = preload("res://runtime/scripts/03_Map/MapRuntime.gd").new()
	viewport.add_child(map)
	map.load_definition(
		{
			"width": 48,
			"height": 36,
			"data":
			preload("res://runtime/scripts/11_Development/MovementFixture.gd").table(
				values, 48, 36, 3
			),
			"events": {}
		},
		fixture.tileset
	)
	avatar = preload("res://runtime/scripts/03_Map/MapCharacter.gd").new()
	avatar.map_runtime = map
	map.ensure_character_layer().add_child(avatar)
	avatar.set_graphic("@movement_character")
	avatar.move_to(20, 14)
	avatar.move_speed = 6
	avatar.through = true
	avatar.set_process(false)
	map.player_character = avatar
	camera = preload("res://runtime/scripts/03_Map/MapCamera.gd").new()
	camera.model = view
	camera.map = map
	camera.player = avatar
	viewport.add_child(camera)
	camera.set_process(false)
	renderer = preload("res://runtime/scripts/03_Map/MapEffectsRenderer.gd").new()
	renderer.map = map
	renderer.camera = camera
	renderer.model = effects
	renderer.screen_model = screen
	renderer.view_model = view
	renderer.timer_model = timer
	renderer.preview = true
	for key in ["@presentation_panorama", "@presentation_fog"]:
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		image.fill(Color("294267") if key.ends_with("panorama") else Color(0.9, 0.95, 1, 0.15))
		for i in range(0, 128, 32):
			image.fill_rect(
				Rect2i(i, i, 24, 24),
				Color("72a8bf") if key.ends_with("panorama") else Color(1, 1, 1, 0.6)
			)
		renderer.texture_overrides[key] = ImageTexture.create_from_image(image)
	viewport.add_child(renderer)
	renderer.set_process(false)
	transition = preload("res://runtime/scripts/09_Effects/TransitionRenderer.gd").new()
	transition.preview = true
	viewport.add_child(transition)
	audio = AudioService.new()
	add_child(audio)


func _process(delta: float) -> void:
	if avatar == null:
		return
	avatar.advance_motion(delta)
	if avatar.is_idle() and not has_text_focus():
		for entry in [["ui_up", 8], ["ui_down", 2], ["ui_left", 4], ["ui_right", 6]]:
			if Input.is_action_pressed(entry[0]):
				avatar.move_straight(entry[1])
				break
	camera.sync(delta)
	renderer.sync(delta)
	var text := (
		"%s\n地图48×36 · 原点(%.1f,%.1f) · 跟随中心%s · 天气粒子%d"
		% [
			_message,
			view.display.x,
			view.display.y,
			str(view.follow_center(Vector2(viewport.size))),
			renderer.weather.particle_count()
		]
	)
	if status.text != text:
		status.text = text


func has_text_focus() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func handle_key(key: int) -> void:
	if key == KEY_ESCAPE:
		back()
	elif has_text_focus():
		return
	elif key == KEY_X:
		back()
	elif key == KEY_TAB:
		var available := _visible_buttons()
		if not available.is_empty():
			selected = posmod(selected + 1, available.size())
			for index in available.size():
				available[index].modulate = Color("ffe38a") if selected == index else Color.WHITE
			available[selected].get_parent().get_parent().ensure_control_visible(
				available[selected]
			)
	elif key in [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		activate()


func _visible_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in buttons:
		if button.is_visible_in_tree() and button.get_parent() is GridContainer:
			result.append(button)
	return result


func navigate(direction: int) -> void:
	selected += direction


func activate() -> void:
	var available := _visible_buttons()
	if not available.is_empty():
		available[posmod(selected, available.size())].pressed.emit()


func back() -> void:
	back_requested.emit()


func _say(result: Dictionary) -> void:
	_message = "成功" if result.get("ok", false) else str(result.get("message", "失败"))


func _view_options() -> Dictionary:
	return {
		"view_rect": [fields.x.value, fields.y.value, fields.width.value, fields.height.value],
		"follow_center": [fields.cx.value, fields.cy.value]
	}


func _apply_view() -> void:
	_say(view.configure(_view_options()))


func _left_ui() -> void:
	var extent := Vector2(viewport.size)
	fields.x.value = 160
	fields.y.value = 0
	fields.width.value = extent.x - 160
	fields.height.value = extent.y
	fields.cx.value = (extent.x - 160) / 2
	fields.cy.value = extent.y / 2
	_apply_view()


func _scroll() -> void:
	_say(camera.scroll(6, 4, 1))


func _follow() -> void:
	view.resume_follow()


func _edge() -> void:
	avatar.move_to(46, 34)


func _apply_real_view() -> void:
	_say(RuntimeState.configure_map_view(_view_options()))


func _name(role: String) -> String:
	var picker: OptionButton = choices[role]
	if picker.selected == 0:
		return ""
	if picker.selected == 1:
		return "@presentation_" + role
	return picker.get_item_text(picker.selected)


func _effect_options() -> Dictionary:
	var result := {"panorama_name": _name("panorama"), "fog_name": _name("fog")}
	for key in [
		"panorama_hue", "fog_hue", "fog_opacity", "fog_blend_type", "fog_zoom", "fog_sx", "fog_sy"
	]:
		result[key] = fields[key].value
	return result


func _apply_effects() -> void:
	_say(effects.configure(_effect_options()))


func _weather(type: int) -> void:
	_say(screen.weather(type, fields.weather_power.value, 1))


func _fog_fade() -> void:
	_say(
		effects.fade_fog(
			0 if effects.data.fog_opacity > 64 else fields.fog_opacity.value, fields.seconds.value
		)
	)


func _fog_tone() -> void:
	_say(effects.tint_fog([-60, -20, 40, 80], fields.seconds.value))


func _apply_real_effects() -> void:
	var options := _effect_options()
	if (
		options.panorama_name.begins_with("@presentation_")
		or options.fog_name.begins_with("@presentation_")
	):
		_message = "工具绘制对照素材仅供预览；请选择原素材后应用。"
		return
	var result: Dictionary = RuntimeState.configure_map_effects(options)
	if result.ok:
		RuntimeState.screen.weather(
			int(screen.weather_snapshot().weather_type), fields.weather_power.value, 1
		)
	_say(result)


func _fade(opacity: int) -> void:
	_say(transition.fade(opacity, fields.seconds.value))


func _cancel_transition() -> void:
	transition.cancel()


func _freeze_transition() -> void:
	var result: Dictionary = await transition.freeze_screen()
	if not is_inside_tree():
		return
	if result.ok:
		avatar.move_to(10, 8)
		camera.sync(0, true)
		var picker: OptionButton = choices.transition
		result = transition.transition(
			fields.seconds.value,
			"" if picker.selected == 0 else picker.get_item_text(picker.selected),
			fields.vague.value
		)
	_say(result)


func _timer_start() -> void:
	_say(timer.start(10))


func _timer_stop() -> void:
	timer.stop()


func _real_timer() -> void:
	_say(RuntimeState.timer.start(10))


func _play_audio(kind: String) -> void:
	var picker: OptionButton = choices[kind]
	if picker.selected == 0:
		_message = "先选择 Audio/%s 原素材；不补取 RTP。" % kind
		return
	_say(
		audio.play(
			kind,
			{
				"name": picker.get_item_text(picker.selected),
				"volume": fields.volume.value,
				"pitch": fields.pitch.value
			}
		)
	)


func _audio_fade() -> void:
	_say(audio.fade_out("BGM", fields.seconds.value))


func _audio_memorize() -> void:
	audio.memorize()
	_message = "已记忆测试BGM/BGS及播放位置。"


func _audio_restore() -> void:
	_say(audio.restore_memory())


func _audio_stop() -> void:
	audio.stop_all()
