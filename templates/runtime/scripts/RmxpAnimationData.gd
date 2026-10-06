extends RefCounted
## Validated immutable-by-convention playback data, not a Godot Animation resource.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
const FRAME_SECONDS := 0.05 # XP default: 40 game updates/sec, one animation frame per two updates.


static func resolve(animation_id: int) -> Dictionary:
	if animation_id == 0:
		return {"ok": true, "empty": true}
	var definition := Data.record("Animations", animation_id)
	if definition.is_empty():
		return failure(animation_id, "动画 ID 不存在。")
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
