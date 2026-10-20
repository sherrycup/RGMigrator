## 职责：按地图行组织图块绘制，维护图块层级和局部刷新。
##
## 调用方式：
##   脚本由所属场景或插件挂载；下列回调由 Godot 调用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 场景树回调（Godot 自动调用）：
##   func _draw() -> void
##
## 接口说明结束。

extends Node2D
## Retained batched row, sorted by Godot against character positions.
var map_runtime: Node
var cells: Array[Vector4i] = []
var animated := false


func _draw() -> void:
	for cell in cells:
		map_runtime.draw_tile(
			self,
			cell.w,
			Vector2(cell.x * 32, cell.y * 32) - position,
			map_runtime.tile_opacity(cell.x, cell.y, cell.z)
		)
