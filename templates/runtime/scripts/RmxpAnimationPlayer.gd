extends Node2D
## Independent animation instance. Callers supply hit/miss; no combat is simulated.
signal finished
signal timing_reached(frame: int, timing: Dictionary)
const AnimationData = preload("res://runtime/scripts/RmxpAnimationData.gd")
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Character = preload("res://runtime/scripts/CharacterSprite.gd")
static var _materials: Dictionary = {}
static var _flashes: Dictionary = {}
static var _flash_shader: Shader
var frame_index := -1
var elapsed := 0.0
var _data: Dictionary
var _target_provider: Callable
var _hit := true
var _cells: Array[Sprite2D] = []
var _audio: Array[AudioStreamPlayer] = []
var _flash_target: CanvasItem
var _flash_left := 0.0
var _flash_duration := 0.0
var _flash_color := Color.TRANSPARENT
var _flash_scope := 0
var _screen_flash: Polygon2D
var _screen_left := 0.0
var _screen_duration := 0.0
var _screen_color := Color.TRANSPARENT
var _ended := false


static func play(parent: Node, animation_id: int, target_provider: Callable, hit: bool = true) -> Dictionary:
	var data := AnimationData.resolve(animation_id)
	if not data.ok or data.get("empty", false):
		return data
	if not target_provider.is_valid() or not is_instance_valid(target_provider.call()):
		return {"ok": false, "message": "Animations[%d]：播放目标不存在。" % animation_id}
	var instance := new()
	instance._data = data
	instance._target_provider = target_provider
	instance._hit = hit
	parent.add_child(instance)
	return {"ok": true, "empty": false, "player": instance}


func _ready() -> void:
	z_index = 2000
	for index in 16:
		var cell := Sprite2D.new()
		cell.texture = _data.texture
		cell.region_enabled = true
		cell.hide()
		add_child(cell)
		_cells.append(cell)
	_screen_flash = Polygon2D.new()
	_screen_flash.z_index = 1
	_screen_flash.hide()
	add_child(_screen_flash)
	_update_frame(0)
	_update_anchor()
	_update_flash(0.0)


func _process(delta: float) -> void:
	if RuntimeState.game() != null and get_parent() == RuntimeState.game().event_map() and RuntimeState.map_time_paused(): return
	advance(delta)


func advance(delta: float) -> void:
	if _ended:
		return
	if not _target_provider.is_valid() or not is_instance_valid(_target_provider.call()):
		stop()
		return
	var end_time := elapsed + maxf(0, delta)
	# Advance flash clocks between crossings, not once per rendered frame. A stall
	# must not replay old timings as new flashes with a full duration.
	while frame_index < _data.frames.size() and (frame_index + 1) * AnimationData.FRAME_SECONDS <= end_time + 0.000001:
		var boundary: float = (frame_index + 1) * AnimationData.FRAME_SECONDS
		_update_flash(maxf(0, boundary - elapsed))
		elapsed = boundary
		_update_frame(frame_index + 1)
	_update_flash(maxf(0, end_time - elapsed))
	elapsed = end_time
	_update_anchor()
	if frame_index >= _data.frames.size() and _flash_left <= 0 and _screen_left <= 0:
		var sounding := false
		for player in _audio:
			if is_instance_valid(player) and player.playing:
				sounding = true
		if not sounding:
			stop()


func _update_frame(index: int) -> void:
	frame_index = index
	for cell in _cells:
		cell.hide()
	if index >= _data.frames.size():
		return
	var rows: Array = _data.frames[index]
	for i in rows.size():
		var row: Array = rows[i]
		if row[0] < 0 or _data.texture == null:
			continue
		var cell := _cells[i]
		cell.show()
		cell.region_rect = Rect2(int(row[0]) % 5 * 192, int(int(row[0]) / 5) * 192, 192, 192)
		cell.position = Vector2(row[1], row[2])
		cell.scale = Vector2.ONE * maxf(0, float(row[3]) / 100.0)
		cell.rotation_degrees = -float(row[4])
		cell.flip_h = row[5] == 1
		cell.modulate.a = clampf(float(row[6]) / 255.0, 0, 1)
		cell.material = _cell_material(clampi(int(row[7]), 0, 2), int(_data.hue))
	for timing in _data.timings:
		if int(timing.frame) == index and (int(timing.get("condition", 0)) == 0 or (int(timing.condition) == 1) == _hit):
			timing_reached.emit(index, timing.duplicate(true))
			_play_timing(timing)


func _update_anchor() -> void:
	var target: CanvasItem = _target_provider.call()
	if not is_instance_valid(target):
		return
	var rect := Rect2(Vector2(-16, -16), Vector2(32, 32))
	if target.has_method("animation_bounds"):
		rect = target.animation_bounds()
	elif target is Control:
		rect = Rect2(Vector2.ZERO, target.size)
	var anchor := rect.get_center()
	if _data.position == 0:
		anchor.y -= rect.size.y / 4.0
	elif _data.position == 2:
		anchor.y += rect.size.y / 4.0
	var local_to_screen := get_global_transform_with_canvas().affine_inverse()
	if _data.position == 3:
		position += local_to_screen * (get_viewport_rect().size / 2.0)
	else:
		position += local_to_screen * (target.get_global_transform_with_canvas() * anchor)
	# Flash covers the logical viewport and follows the camera, not the target.
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var viewport := get_viewport_rect()
	_screen_flash.polygon = PackedVector2Array([inverse * viewport.position, inverse * Vector2(viewport.end.x, 0), inverse * viewport.end, inverse * Vector2(0, viewport.end.y)])
	for i in _cells.size():
		if frame_index < _data.frames.size() and i < _data.frames[frame_index].size():
			_cells[i].modulate.a = clampf(float(_data.frames[frame_index][i][6]) / 255.0, 0, 1) * target.modulate.a


static func _cell_material(blend: int, hue: int) -> ShaderMaterial:
	var key := "%d:%d" % [blend, posmod(hue, 360)]
	if not _materials.has(key):
		var shader := Shader.new()
		shader.code = Character.HUE_SHADER.replace("shader_type canvas_item;", "shader_type canvas_item;\nrender_mode %s;" % ["blend_mix", "blend_add", "blend_sub"][blend])
		var result := ShaderMaterial.new()
		result.shader = shader
		result.set_shader_parameter("hue", float(hue) / 360.0)
		_materials[key] = result
	return _materials[key]


func _play_timing(timing: Dictionary) -> void:
	var se: Dictionary = timing.get("se", {})
	var name := str(se.get("name", ""))
	if not name.is_empty():
		var stream: AudioStream
		var path := Data.asset_path("Audio/SE/" + name)
		if not path.is_empty() and ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream == null:
			RuntimeState.report_diagnostic("Animations[%d] 第 %d 帧音效缺失：%s" % [_data.id, frame_index + 1, name])
		else:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = linear_to_db(clampf(float(se.get("volume", 100)) / 100.0, 0.0001, 1))
			player.pitch_scale = clampf(float(se.get("pitch", 100)) / 100.0, 0.01, 4)
			add_child(player)
			_audio.append(player)
			player.play()
	var scope := int(timing.get("flash_scope", 0))
	if scope == 0:
		return
	var color: Dictionary = timing.get("flash_color", {})
	var flash_color := Color(float(color.get("red", 0)) / 255.0, float(color.get("green", 0)) / 255.0, float(color.get("blue", 0)) / 255.0, float(color.get("alpha", 0)) / 255.0)
	var duration := maxf(0, float(timing.get("flash_duration", 0))) * AnimationData.FRAME_SECONDS
	if scope == 2:
		_screen_duration = duration
		_screen_left = duration
		_screen_color = flash_color
		_update_flash(0)
		return
	_release_flash()
	_flash_scope = scope
	_flash_duration = duration
	_flash_left = _flash_duration
	_flash_color = flash_color
	_flash_target = _target_provider.call()
	_update_flash(0)


func _update_flash(delta: float) -> void:
	_flash_left = maxf(0, _flash_left - delta)
	_screen_left = maxf(0, _screen_left - delta)
	_screen_flash.visible = _screen_left > 0
	var screen_color := _screen_color
	screen_color.a *= _screen_left / maxf(_screen_duration, 0.0001)
	_screen_flash.color = screen_color
	var color := _flash_color
	color.a *= _flash_left / maxf(_flash_duration, 0.0001)
	if is_instance_valid(_flash_target):
		var target_id := _flash_target.get_instance_id()
		if _flash_left <= 0:
			_release_flash()
		else:
			if not _flashes.has(target_id):
				if _flash_shader == null:
					_flash_shader = Shader.new()
					_flash_shader.code = "shader_type canvas_item; uniform vec4 flash_color : source_color; uniform bool erased = false; void fragment() { COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash_color.a); if (erased) { COLOR.a = 0.0; } }"
				var shader_material := ShaderMaterial.new()
				shader_material.shader = _flash_shader
				_flashes[target_id] = {"target": _flash_target, "original": _flash_target.material, "material": shader_material, "owners": {}}
				_flash_target.material = shader_material
			_flashes[target_id].owners[get_instance_id()] = {"color": color, "hidden": _flash_scope == 3}
			_apply_flash(target_id)


static func _apply_flash(target_id: int) -> void:
	var state: Dictionary = _flashes[target_id]
	var color := Color.TRANSPARENT
	var hidden := false
	for effect in state.owners.values():
		hidden = hidden or effect.hidden
		if effect.color.a > color.a:
			color = effect.color
	state.material.set_shader_parameter("flash_color", color)
	state.material.set_shader_parameter("erased", hidden)


func _release_flash() -> void:
	if is_instance_valid(_flash_target):
		var target_id := _flash_target.get_instance_id()
		if _flashes.has(target_id):
			var state: Dictionary = _flashes[target_id]
			state.owners.erase(get_instance_id())
			if state.owners.is_empty():
				_flash_target.material = state.original
				_flashes.erase(target_id)
			else:
				_apply_flash(target_id)
	_flash_target = null


func stop() -> void:
	if _ended:
		return
	_ended = true
	_release_flash()
	hide()
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	_release_flash()
	# Remove records for targets destroyed by a map refresh/transfer.
	for key in _flashes.keys():
		if not is_instance_valid(_flashes[key].target):
			_flashes.erase(key)
