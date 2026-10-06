extends RefCounted

const RuntimeData = preload("res://runtime/scripts/RuntimeData.gd")
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}
static var _font: SystemFont


static func texture(name: String) -> Texture2D:
	# Compatibility implementation. Category-facing callers use RmxpCache.
	if _textures.has(name):
		return _textures[name]
	if name == "Graphics/Pictures/@test_picture":
		var marker := Image.create(128, 96, false, Image.FORMAT_RGBA8)
		marker.fill(Color("195275"))
		marker.fill_rect(Rect2i(4, 4, 120, 88), Color("59c9eb"))
		marker.fill_rect(Rect2i(12, 12, 32, 32), Color("ffe38a"))
		marker.fill_rect(Rect2i(88, 52, 24, 32), Color("d75474"))
		marker.fill_rect(Rect2i(58, 4, 8, 88), Color("ffffff"))
		_textures[name] = ImageTexture.create_from_image(marker)
		return _textures[name]
	if name == "Graphics/Animations/@test_animation":
		var image := Image.create(960, 192, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for pattern in 5:
			for y in 192:
				for x in 192:
					var radius := Vector2(x - 96, y - 96).length()
					if absf(radius - (35 + pattern * 10)) < 4:
						image.set_pixel(pattern * 192 + x, y, Color("77cfff"))
		_textures[name] = ImageTexture.create_from_image(image)
		return _textures[name]
	if name.begins_with("Graphics/Icons/@test_"):
		var icon := _test_icon(name.get_file())
		_textures[name] = icon
		return icon
	var path := RuntimeData.asset_path(name)
	var result: Texture2D
	if not path.is_empty() and ResourceLoader.exists(path):
		result = load(path) as Texture2D
	_textures[name] = result
	return result


static func _test_icon(kind: String) -> Texture2D:
	# Small original procedural markers, not RTP or a reused source-game icon.
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	if kind in ["@test_hp", "@test_sp"]:
		image.fill_rect(Rect2i(9, 2, 6, 5), Color("d8bc82"))
		image.fill_rect(Rect2i(6, 7, 12, 15), Color("e1e9ef"))
		image.fill_rect(Rect2i(8, 11, 8, 9), Color("ea5365") if kind == "@test_hp" else Color("559cf0"))
	elif kind == "@test_weapon":
		image.fill_rect(Rect2i(10, 2, 4, 14), Color("d8e6ee"))
		image.fill_rect(Rect2i(6, 15, 12, 3), Color("d8b260"))
		image.fill_rect(Rect2i(10, 18, 4, 5), Color("806246"))
	else:
		image.fill_rect(Rect2i(4, 4, 16, 12), Color("91b6d0"))
		image.fill_rect(Rect2i(7, 16, 10, 4), Color("91b6d0"))
		image.fill_rect(Rect2i(10, 20, 4, 2), Color("91b6d0"))
		image.fill_rect(Rect2i(10, 6, 4, 12), Color("d9c077"))
	return ImageTexture.create_from_image(image)


static func region(name: String, rectangle: Rect2) -> Texture2D:
	var key := name + str(rectangle)
	if _regions.has(key):
		return _regions[key]
	var source := texture(name)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = rectangle
	_regions[key] = atlas
	return atlas


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun", "Arial"])
		_font.allow_system_fallback = true
	return _font


static func word(key: String, fallback: String) -> String:
	# Standard calculations must not be labelled with untranslated Ruby stat mappings.
	var parameters := {"str": "力量", "dex": "灵巧", "agi": "速度", "int": "魔力", "atk": "攻击力", "pdef": "物理防御", "mdef": "魔法防御"}
	if parameters.has(key):
		return parameters[key]
	var slots := {"weapon": "武器", "armor1": "盾", "armor2": "头部防具", "armor3": "身体防具", "armor4": "饰品"}
	if slots.has(key):
		return slots[key]
	var result := str(RuntimeData.system().get("words", {}).get(key, ""))
	return fallback if result.is_empty() else result


static func play_sound(parent: Node, key: String) -> void:
	var audio: Dictionary = RuntimeData.system().get(key, {})
	var name := str(audio.get("name", ""))
	if name.is_empty():
		return
	var path := RuntimeData.asset_path("Audio/SE/" + name)
	if path.is_empty() or not ResourceLoader.exists(path):
		RuntimeState.report_diagnostic("System.%s 引用的界面音效缺失或不受支持：%s" % [key, name])
		return
	var stream := load(path) as AudioStream
	if stream == null:
		RuntimeState.report_diagnostic("无法读取界面音效：%s" % name)
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = linear_to_db(clampf(float(audio.get("volume", 100)) / 100.0, 0.0, 1.0))
	player.pitch_scale = clampf(float(audio.get("pitch", 100)) / 100.0, 0.5, 1.5)
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func clear() -> void:
	# Menus retain their own texture references while open. Clear at game exit.
	_regions.clear()
	_textures.clear()
