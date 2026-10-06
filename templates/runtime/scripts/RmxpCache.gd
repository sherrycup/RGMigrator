extends RefCounted
## Category-facing API shared by runtime scripts and future asset selectors.
## Textures are shared, read-only resources; transforms/materials belong to instances.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Resources = preload("res://runtime/scripts/UIResources.gd")
const CATEGORIES := ["Animations", "Autotiles", "Battlers", "Characters", "Fogs", "Gameovers", "Icons", "Panoramas", "Pictures", "Tilesets", "Titles", "Transitions", "Windowskins"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "bmp", "webp", "svg", "tga", "dds", "ktx", "exr", "hdr"]


static func categories() -> Array[String]:
	var result: Array[String] = []
	result.assign(CATEGORIES)
	return result


static func asset_key(category: String, name: String) -> String:
	if category not in CATEGORIES or name.is_empty():
		return ""
	var relative := name.replace("\\", "/")
	if relative.begins_with("/") or relative.contains(":"):
		return ""
	for part in relative.split("/"):
		if part in ["", ".", ".."]:
			return ""
	for index in relative.length():
		if relative.unicode_at(index) < 32:
			return ""
	return "Graphics/%s/%s" % [category, relative]


static func resolve(category: String, name: String) -> String:
	var key := asset_key(category, name)
	return "" if key.is_empty() else Data.asset_path(key)


static func exists(category: String, name: String) -> bool:
	# A query does not load textures or create the testing-only procedural markers.
	var path := resolve(category, name)
	return not path.is_empty() and ResourceLoader.exists(path)


static func texture(category: String, name: String) -> Texture2D:
	var key := asset_key(category, name)
	return null if key.is_empty() else Resources.texture(key)


static func region(category: String, name: String, rectangle: Rect2) -> Texture2D:
	var key := asset_key(category, name)
	return null if key.is_empty() else Resources.region(key, rectangle)


static func list_assets(category: String) -> Array[Dictionary]:
	# Enumerate the migration index, never all Graphics folders or RTP. Do not load
	# image data. Original filenames (with extension) disambiguate same-stem files
	# and remain usable even when the exported extension was corrected.
	var result: Array[Dictionary] = []
	if category not in CATEGORIES:
		return result
	var prefix := "Graphics/%s/" % category
	var index := Data.asset_index()
	var keys := index.keys()
	keys.sort()
	var by_path := {}
	for raw_key in keys:
		var key := str(raw_key).replace("\\", "/")
		if not key.to_lower().begins_with(prefix.to_lower()):
			continue
		var name := key.substr(prefix.length())
		var path := str(index[raw_key])
		if name.get_extension().to_lower() not in IMAGE_EXTENSIONS or path.get_extension().to_lower() not in IMAGE_EXTENSIONS:
			continue
		if asset_key(category, name).is_empty():
			continue
		# foo.png.jpg also has a basename alias foo.png. Keep the longest source
		# filename, not the alias, and prefer original category case on equal length.
		var previous: Dictionary = by_path.get(path, {})
		if not previous.is_empty() and (str(previous.name).length() > name.length() or (str(previous.name).length() == name.length() and str(previous.source_key).begins_with(prefix))):
			continue
		by_path[path] = {"category": category, "name": name, "source_key": key, "path": path}
	for entry in by_path.values():
		result.append(entry)
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.name) < str(second.name))
	return result


static func list_names(category: String) -> Array[String]:
	var result: Array[String] = []
	for entry in list_assets(category):
		result.append(entry.name)
	return result


static func picture(name: String) -> Texture2D:
	return texture("Pictures", name)


static func icon(name: String) -> Texture2D:
	return texture("Icons", name)


static func title(name: String) -> Texture2D:
	return texture("Titles", name)


static func windowskin(name: String) -> Texture2D:
	return texture("Windowskins", name)


static func character(name: String) -> Texture2D:
	return texture("Characters", name)


static func animation(name: String) -> Texture2D:
	return texture("Animations", name)


static func tileset(name: String) -> Texture2D:
	return texture("Tilesets", name)


static func autotile(name: String) -> Texture2D:
	return texture("Autotiles", name)


static func panorama(name: String) -> Texture2D:
	return texture("Panoramas", name)


static func fog(name: String) -> Texture2D:
	return texture("Fogs", name)


static func battler(name: String) -> Texture2D:
	return texture("Battlers", name)


static func gameover(name: String) -> Texture2D:
	return texture("Gameovers", name)


static func transition(name: String) -> Texture2D:
	return texture("Transitions", name)


static func clear() -> void:
	# Live nodes retain their references. Clearing the cache never erases pictures.
	Resources.clear()
