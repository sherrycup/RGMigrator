## 职责：根据原延迟和行动规则计算战斗单位的出手顺序。
##
## 调用方式：
##   脚本由所属场景或插件挂载；下列回调由 Godot 调用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _draw() -> void
##
## 接口说明结束。

extends ScrollContainer
## 0236/0237 Action_Pic: four original borders, live character frames, source turns.
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
var rows: Array = []
var sprites: Dictionary = {}


class Row:
	extends Control
	var action: Array = []
	var character_name = ""
	var character_hue = 0
	var direction = 2
	var text = ""

	func _ready() -> void:
		var portrait = preload("../03_Map/CharacterSprite.gd").new()
		portrait.configure(character_name, character_hue, direction, 0)
		portrait.position = Vector2(96, 12)
		portrait.size = Vector2(32, 32)
		add_child(portrait)

	func _draw() -> void:
		var actor = str(action[0]).begins_with("actor")
		var follow = int(action[3]) == 1
		var file = (
			"RUnitBorder3.png"
			if actor and follow
			else (
				"RUnitBorder.png" if actor else "RUnitBorder4.png" if follow else "RUnitBorder2.png"
			)
		)
		var border = Cache.picture("Causal/" + file)
		if border != null:
			draw_texture_rect(border, Rect2(Vector2(60, 0), border.get_size() * 1.5), false)
		var font = Resources.font()
		var x = 152 if actor else 12
		draw_string(
			font, Vector2(x, 24), text, HORIZONTAL_ALIGNMENT_LEFT, 140, 14, Color8(220, 255, 240)
		)
		if not follow:
			draw_string(
				font,
				Vector2(x, 42),
				str(action[2]),
				HORIZONTAL_ALIGNMENT_LEFT,
				100,
				14,
				Color8(220, 255, 240)
			)


func _ready() -> void:
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	add_child(list)
	for action in rows:
		var row = Row.new()
		row.action = action
		row.custom_minimum_size = Vector2(300, 40)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var source: Dictionary = sprites.get(str(action[0]), {})
		row.character_name = str(source.get("name", ""))
		row.character_hue = int(source.get("hue", 0))
		row.direction = int(source.get("direction", 2))
		var skill: Dictionary = RuntimeState.custom_data.gameplay().simulator.skills.get(
			str(action[1]), {}
		)
		row.text = "普通攻击" if action[1] == 0 else str(skill.get("name", ""))
		list.add_child(row)


func _draw() -> void:
	var image = Cache.picture("Causal/OrderLine.png")
	if image != null:
		draw_texture_rect(
			image,
			Rect2(
				24,
				-scroll_vertical,
				image.get_width() * 1.5,
				maxf(size.y, image.get_height() * 1.5)
			),
			false
		)
