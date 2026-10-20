## 职责：解析 RM 图块和自动元件编号，计算贴图区域、优先级与通行信息。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/TilesetLayout.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/03_Map/TilesetLayout.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   static func sources(definition: Dictionary, loader: Callable) -> Array
##     参数 definition（Dictionary；必填）：对象的只读定义或原数据库记录。
##     参数 loader（Callable；必填）：读取目标资源或数据的回调。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func configure(definition: Dictionary, loader: Callable) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 definition（Dictionary；必填）：对象的只读定义或原数据库记录。
##     参数 loader（Callable；必填）：读取目标资源或数据的回调。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func locate(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func tile_texture(id: int) -> Texture2D
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：Texture2D 类型的对象或值，供调用方继续使用。
##
## 接口说明结束。

@tool
extends RefCounted
## Virtual vertical layout; textures remain separate and shared read-only.
var segments: Array = []
var errors: Array[String] = []
var tile_count = 0


static func sources(definition: Dictionary, loader: Callable) -> Array:
	if definition.get("tileset_sources") is Array:
		return definition.tileset_sources.duplicate(true)
	var name = str(definition.get("tileset_name", ""))
	var texture: Texture2D = loader.call(name) if not name.is_empty() else null
	var rows = (
		int(texture.get_height() / 32)
		if texture != null
		else maxi(0, int((definition.get("passages", {}).get("values", []).size() - 384) / 8))
	)
	return (
		[{"key": "legacy", "name": name, "rows": rows}] if not name.is_empty() or rows > 0 else []
	)


func configure(definition: Dictionary, loader: Callable) -> void:
	segments.clear()
	errors.clear()
	tile_count = 0
	for record in sources(definition, loader):
		if not record is Dictionary:
			errors.append("组合素材记录无效。")
			continue
		var row_value: Variant = record.get("rows", 0)
		if (
			not (row_value is int or row_value is float)
			or not is_finite(float(row_value))
			or float(row_value) != floor(float(row_value))
			or int(row_value) < 0
			or int(row_value) * 8 + tile_count > 32768 - 384
		):
			errors.append("组合素材行数无效。")
			continue
		var name = str(record.get("name", ""))
		var rows = int(row_value)
		var texture: Texture2D = loader.call(name) if not name.is_empty() else null
		if texture == null:
			errors.append("素材未加载：" + name)
		elif texture.get_width() != 256 or texture.get_height() != rows * 32:
			errors.append("素材尺寸变化，请在组合素材窗口重新选择：" + name)
		segments.append(
			{
				"key": str(record.get("key", "")),
				"name": name,
				"rows": rows,
				"first": 384 + tile_count,
				"end": 384 + tile_count + rows * 8,
				"texture": texture
			}
		)
		tile_count += rows * 8


func locate(id: int) -> Dictionary:
	for segment in segments:
		if id < int(segment.first) or id >= int(segment.end):
			continue
		var local = id - int(segment.first)
		var region = Rect2((local % 8) * 32, int(local / 8) * 32, 32, 32)
		var texture: Texture2D = segment.texture
		if (
			texture == null
			or region.end.y > texture.get_height()
			or region.end.x > texture.get_width()
		):
			return {}
		return {"texture": texture, "region": region, "name": segment.name, "key": segment.key}
	return {}


func tile_texture(id: int) -> Texture2D:
	var found = locate(id)
	if found.is_empty():
		return null
	var atlas = AtlasTexture.new()
	atlas.atlas = found.texture
	atlas.region = found.region
	return atlas
