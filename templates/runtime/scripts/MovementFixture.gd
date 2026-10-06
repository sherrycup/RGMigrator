extends RefCounted
## Original procedural verification assets and an isolated map, never RTP/database edits.
const Resources = preload("res://runtime/scripts/UIResources.gd")


static func table(values: Array, width: int, height: int = 1, depth: int = 1) -> Dictionary:
	return {"x_size": width, "y_size": height, "z_size": depth, "values": values}


static func build() -> Dictionary:
	var image := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors := ["405c70", "7b8894", "409655", "b78140", "dccc69", "b94e57"]
	for index in colors.size():
		image.fill_rect(Rect2i(index * 32, 0, 32, 32), Color(colors[index]))
		image.fill_rect(Rect2i(index * 32, 30, 32, 2), Color("243849"))
	image.fill_rect(Rect2i(2 * 32 + 4, 8, 4, 20), Color("72d285"))
	image.fill_rect(Rect2i(2 * 32 + 16, 4, 4, 24), Color("72d285"))
	image.fill_rect(Rect2i(3 * 32, 8, 32, 3), Color("efc381"))
	image.fill_rect(Rect2i(4 * 32 + 4, 4, 24, 24), Color("fff19a"))
	Resources._textures["Graphics/Tilesets/@movement_tiles"] = ImageTexture.create_from_image(image)
	var character := Image.create(128, 192, false, Image.FORMAT_RGBA8)
	character.fill(Color.TRANSPARENT)
	for row in 4:
		for frame in 4:
			var x := frame * 32
			var y := row * 48
			character.fill_rect(Rect2i(x + 8, y + 8, 16, 28), Color("8ac7ed"))
			character.fill_rect(Rect2i(x + 10, y + 12, 12, 6), Color("ffdf91"))
			character.fill_rect(Rect2i(x + 7 + (frame % 2) * 3, y + 36, 6, 12), Color("627ab1"))
			character.fill_rect(Rect2i(x + 19 - (frame % 2) * 3, y + 36, 6, 12), Color("627ab1"))
	Resources._textures["Graphics/Characters/@movement_character"] = ImageTexture.create_from_image(character)
	var values: Array = []
	values.resize(12 * 9 * 3)
	values.fill(0)
	for y in 9:
		for x in 12:
			values[x + 12 * y] = 385 if x == 0 or y == 0 or x == 11 or y == 8 else 384
	for y in range(2, 4):
		for x in range(2, 5): values[x + 12 * y] = 386
	values[5 + 12 * 4] = 387
	values[2 + 12 * 6] = 389
	for x in [8, 9]: values[x + 12 * 2 + 12 * 9] = 388
	var passages: Array = []
	var priorities: Array = []
	var terrains: Array = []
	for array in [passages, priorities, terrains]: array.resize(390); array.fill(0)
	passages[385] = 15
	passages[386] = 0x40
	passages[387] = 0x80 | 15
	passages[389] = 4
	priorities[388] = 2
	terrains[386] = 7
	var events := {
		"1": event(5, 3, "@movement_character", 0, "隔着柜台找到人物；调用的是正式地图交互接口。"),
		"2": event(2, 7, "", 1, "到达触碰点：此处仅报告触发结果，不修改原地图事件。"),
		"3": event(7, 6, "@movement_character", 0, "面对人物按确认；人物占位会阻挡行走。")
	}
	return {"map": {"width": 12, "height": 9, "data": table(values, 12, 9, 3), "events": events}, "tileset": {"tileset_name": "@movement_tiles", "autotile_names": [], "passages": table(passages, 390), "priorities": table(priorities, 390), "terrain_tags": table(terrains, 390)}}


static func event(x: int, y: int, name_value: String, trigger: int, text: String) -> Dictionary:
	return {"x": x, "y": y, "pages": [{"condition": {}, "trigger": trigger, "through": false, "move_speed": 4, "step_anime": false, "graphic": {"tile_id": 0, "character_name": name_value, "character_hue": 0, "direction": 2, "pattern": 0, "opacity": 255, "blend_type": 0}, "list": [{"code": 101, "parameters": [text]}, {"code": 0, "parameters": []}]}]}
