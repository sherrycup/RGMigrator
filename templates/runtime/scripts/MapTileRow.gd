extends Node2D
## Retained batched row, sorted by Godot against character positions.
var map_runtime: Node
var cells: Array[Vector3i] = []
var animated := false


func _draw() -> void:
	for cell in cells:
		map_runtime.draw_tile(self, cell.z, Vector2(cell.x * 32, cell.y * 32) - position)
