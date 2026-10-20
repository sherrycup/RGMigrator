## 职责：预览原动画的 192 像素单元、位置与混合效果，隔离运行场景状态。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/04_Database/Editor_AnimationCanvas.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure(frame: Dictionary, texture: Texture2D, hue: int, selected: int = -1) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 frame（Dictionary；必填）：动画帧、逻辑帧或渲染帧数据。
##     参数 texture（Texture2D；必填）：用于显示的纹理资源。
##     参数 hue（int；必填）：素材色相参数。
##     参数 selected（int；默认值 -1）：当前选中的条目编号或状态。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _draw() -> void
##
## 接口说明结束。

@tool
extends Control
## Independent visual preview of native 192px animation cells.
const Preview = preload("../05_Assets/Editor_AssetPreview.gd")
var _cells: Array[Sprite2D] = []
var _anchor: Node2D
var _materials: Dictionary = {}
var _selected = -1
var _zoom = 0.75
var _message = ""


func configure(frame: Dictionary, texture: Texture2D, hue: int, selected: int = -1) -> void:
	if _anchor == null:
		clip_contents = true
		custom_minimum_size = Vector2(260, 180)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_anchor = Node2D.new()
		add_child(_anchor)
		resized.connect(_layout)
		for i in 16:
			var cell = Sprite2D.new()
			cell.region_enabled = true
			_anchor.add_child(cell)
			_cells.append(cell)
	_selected = selected
	_message = "未选择动画素材" if texture == null else ""
	var table: Dictionary = frame.get("cell_data", {})
	var width = int(table.get("x_size", 0))
	var values: Array = table.get("values", [])
	for i in 16:
		var cell = _cells[i]
		cell.hide()
		if (
			i >= int(frame.get("cell_max", 0))
			or i >= width
			or values.size() < width * 8
			or texture == null
		):
			continue
		var row: Array = []
		for column in 8:
			row.append(int(values[i + column * width]))
		if row[0] < 0:
			continue
		var region = Rect2((row[0] % 5) * 192, int(row[0] / 5) * 192, 192, 192)
		if region.end.x > texture.get_width() or region.end.y > texture.get_height():
			_message = "图案 %d 超出素材范围" % row[0]
			continue
		cell.texture = texture
		cell.region_rect = region
		cell.position = Vector2(row[1], row[2])
		cell.scale = Vector2.ONE * maxf(0, float(row[3]) / 100)
		cell.rotation_degrees = -float(row[4])
		cell.flip_h = row[5] == 1
		cell.modulate.a = clampf(float(row[6]) / 255, 0, 1)
		var blend = clampi(row[7], 0, 2)
		var key = "%d:%d" % [blend, hue]
		if not _materials.has(key):
			var material_instance = ShaderMaterial.new()
			var shader = Shader.new()
			shader.code = Preview.HUE_SHADER.replace(
				"shader_type canvas_item;",
				(
					"shader_type canvas_item;\nrender_mode "
					+ ["blend_mix", "blend_add", "blend_sub"][blend]
					+ ";"
				)
			)
			material_instance.shader = shader
			material_instance.set_shader_parameter("hue", float(hue) / 360)
			_materials[key] = material_instance
		cell.material = _materials[key]
		cell.show()
	_layout()
	queue_redraw()


func _layout() -> void:
	if _anchor != null:
		_anchor.position = size / 2
		_anchor.scale = Vector2.ONE * _zoom


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("202735"))
	for x in range(0, int(size.x), 24):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.06))
	for y in range(0, int(size.y), 24):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.06))
	draw_line(size / 2 - Vector2(10, 0), size / 2 + Vector2(10, 0), Color("ffd56a"))
	draw_line(size / 2 - Vector2(0, 10), size / 2 + Vector2(0, 10), Color("ffd56a"))
	if not _message.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(8, 22),
			_message,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("ffbd9b")
		)
