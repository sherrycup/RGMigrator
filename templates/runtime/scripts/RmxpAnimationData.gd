extends RefCounted
## Validated immutable-by-convention playback data, not a Godot Animation resource.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const FRAME_SECONDS := 0.05 # XP default: 40 game updates/sec, one animation frame per two updates.
static var _resolved: Dictionary={}

static func prewarm() -> void:
	Data.database("Animations")
	if Data.read_json("res://data/custom_data.json",{}).get("profile")!="flash": return
	var ids: Dictionary={}
	var rules: Dictionary=Data.read_json("res://data/flash_gameplay.json",{})
	for id in rules.get("storage",{}).get("actor_init_animation",{}).values(): _warm_id(ids,id)
	for key in rules.get("constants",{}):
		if str(key).ends_with("_ANIMATION_ID"): _warm_id(ids,rules.constants[key])
	for unit in Data.read_json("res://data/script_units.json",{}).get("units",{}).values():
		_warm_literals(unit.get("ast",{}),ids)
	for id in ids:
		# Warm only original, immutable data. An invalid unused reference must
		# still report its error when actually executed, not during prefetch.
		if not Data.is_test_record("Animations",id) and is_same(Data.record("Animations",id),Data.source_record("Animations",id)):
			resolve(id)

static func _warm_id(ids: Dictionary,value: Variant) -> void:
	if (value is int or value is float) and value>0 and value<=10000 and value==floor(value): ids[int(value)]=true

static func _warm_literals(value: Variant,ids: Dictionary,depth: int=0) -> void:
	if depth>128: return
	if value is Array:
		for child in value: _warm_literals(child,ids,depth+1)
	elif value is Dictionary:
		if value.get("kind")=="assign" and value.get("left",{}).get("kind")=="call" and value.left.get("name")=="animation_id" and value.get("right",{}).get("kind")=="literal":
			_warm_id(ids,value.right.get("value"))
		for child in value.values():
			if child is Array or child is Dictionary: _warm_literals(child,ids,depth+1)


static func resolve(animation_id: int) -> Dictionary:
	if animation_id == 0:
		return {"ok": true, "empty": true}
	var definition := Data.record("Animations", animation_id)
	if definition.is_empty():
		return failure(animation_id, "动画 ID 不存在。")
	var immutable_source=is_same(definition,Data.source_record("Animations",animation_id)) and not Data.is_test_record("Animations",animation_id)
	var cached: Dictionary=_resolved.get(animation_id,{})
	if immutable_source and not cached.is_empty() and is_same(cached.definition,definition): return cached.playback
	var compiled := compile(definition)
	if not compiled.ok:
		return compiled
	var name := str(definition.get("animation_name", ""))
	var texture: Texture2D = null
	if not name.is_empty():
		texture = Cache.animation(name)
		if texture == null:
			return failure(animation_id, "动画素材缺失（不补取 RTP）：Graphics/Animations/" + name)
	for cells in compiled.frames:
		for cell in cells:
			var pattern: int = cell[0]
			if pattern >= 0 and texture != null and ((pattern % 5 + 1) * 192 > texture.get_width() or (int(pattern / 5) + 1) * 192 > texture.get_height()):
				return failure(animation_id, "帧单元索引超出动画图像范围：%d" % pattern)
	compiled["texture"] = texture
	if immutable_source: _resolved[animation_id]={"definition":definition,"playback":compiled}
	return compiled


static func compile(definition: Dictionary) -> Dictionary:
	var id := int(definition.get("id", 0))
	var frames: Variant = definition.get("frames", [])
	var count := int(definition.get("frame_max", 0))
	var position := int(definition.get("position", 1))
	if not frames is Array or count <= 0 or count > 10000 or count != frames.size() or position not in [0, 1, 2, 3]:
		return failure(id, "帧数或动画位置无效。")
	var compiled: Array = []
	for frame in frames:
		if not frame is Dictionary or not frame.get("cell_data", {}) is Dictionary:
			return failure(id, "帧单元数据缺失。")
		var table: Dictionary = frame.cell_data
		var width := int(table.get("x_size", 0))
		var cells := int(frame.get("cell_max", width))
		var values: Variant = table.get("values", [])
		if width < cells or cells < 0 or cells > 16 or int(table.get("y_size", 0)) != 8 or not values is Array or values.size() < width * 8:
			return failure(id, "cell_data 必须包含至多 16 个单元及 8 列参数。")
		var rows: Array = []
		for cell in cells:
			var row: Array[int] = []
			for column in 8:
				var value: Variant = values[cell + column * width]
				if not value is int and not value is float:
					return failure(id, "单元参数必须为数字。")
				row.append(int(value))
			rows.append(row)
		compiled.append(rows)
	var timings: Variant = definition.get("timings", [])
	if not timings is Array:
		return failure(id, "动画时序必须为数组。")
	for timing in timings:
		if not timing is Dictionary or int(timing.get("frame", -1)) < 0 or int(timing.get("frame", -1)) >= count:
			return failure(id, "音效/闪光时序帧无效。")
		if int(timing.get("condition", 0)) not in [0, 1, 2] or int(timing.get("flash_scope", 0)) not in [0, 1, 2, 3] or not timing.get("se", {}) is Dictionary or not timing.get("flash_color", {}) is Dictionary:
			return failure(id, "音效/闪光时序参数无效。")
	return {"ok": true, "empty": false, "id": id, "position": position, "hue": int(definition.get("animation_hue", 0)), "frames": compiled, "timings": timings.duplicate(true)}


static func failure(id: int, message: String) -> Dictionary:
	return {"ok": false, "message": "Animations[%d]：%s" % [id, message]}
