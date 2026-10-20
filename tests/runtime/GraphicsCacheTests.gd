## 职责：回归验证：验证素材分类查询、缓存共享及实例材质隔离。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_source_catalog() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func test_fixture() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func expect(condition: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 condition（bool；必填）：是否创建须返回布尔值的脚本条件模板。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _initialize() -> void
##
## 接口说明结束。

extends SceneTree
var failures: Array[String] = []
var checks := 0
var cache: Script
var data: Script
var resources: Script


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	cache = load("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
	data = load("res://runtime/scripts/00_Game/RuntimeData.gd")
	resources = load("res://runtime/scripts/04_UI_Common/UIResources.gd")
	if cache == null or not cache.can_instantiate():
		printerr("FAIL: graphics cache did not compile")
		quit(1)
		return
	test_source_catalog()
	test_fixture()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("GRAPHICS CACHE TESTS: ", "PASSED" if failures.is_empty() else "FAILED", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func test_source_catalog() -> void:
	var before := JSON.stringify(data.asset_index())
	var texture_count: int = resources._textures.size()
	var total := 0
	for category in cache.categories():
		var entries: Array = cache.list_assets(category)
		var paths := {}
		var isolated := true
		for entry in entries:
			isolated = isolated and entry.category == category and str(entry.source_key).to_lower().begins_with(("Graphics/%s/" % category).to_lower())
			isolated = isolated and not paths.has(entry.path) and cache.resolve(category, entry.name) == entry.path
			paths[entry.path] = true
		total += entries.size()
		expect(isolated, "real catalog is category-only, unique and resolvable: " + category)
	expect(total > 0, "real migrated images are enumerated")
	expect(resources._textures.size() == texture_count, "enumeration never loads textures")
	expect(JSON.stringify(data.asset_index()) == before, "catalog does not modify migration index")
	for category in ["Pictures", "Icons", "Titles"]:
		var entries: Array = cache.list_assets(category)
		if entries.is_empty(): continue
		var entry: Dictionary = entries[0]
		var first: Texture2D = cache.texture(category, entry.name)
		expect(first != null and first == cache.texture(category, entry.name), "real category loading shares texture: " + category)
		expect(cache.exists(category, entry.name), "real lookup exists: " + category)
		expect(first == resources.texture(cache.asset_key(category, entry.name)), "legacy texture path shares same cache: " + category)
		entries[0].name = "changed snapshot"
		expect(cache.list_assets(category)[0].name == entry.source_key.substr(("Graphics/%s/" % category).length()), "catalog records are detached: " + category)


func test_fixture() -> void:
	var index_key := "res://data/asset_index.json"
	var original: Dictionary = data.asset_index()
	var old_textures: Dictionary = resources._textures.duplicate()
	var picture: Texture2D = resources.texture("Graphics/Pictures/@test_picture")
	var icon: Texture2D = resources.texture("Graphics/Icons/@test_hp")
	var fixture := {
		"Graphics/Pictures/同名.png": "res://fixture/picture.png",
		"Graphics/Pictures/同名": "res://fixture/picture.png",
		"graphics/pictures/同名": "res://fixture/picture.png",
		"Graphics/Icons/同名.png": "res://fixture/icon.png",
		"Graphics/Icons/同名": "res://fixture/icon.png",
		"Graphics/Titles/同名.png": "res://fixture/title.png",
		"Graphics/Pictures/子目录/中文 文件.PNG": "res://fixture/nested.png",
		"Graphics/Pictures/子目录/中文 文件": "res://fixture/nested.png",
		"Graphics/Pictures/双扩展.png.jpg": "res://fixture/corrected.jpg.rgm_123.png",
		"Graphics/Pictures/双扩展.png": "res://fixture/corrected.jpg.rgm_123.png",
		"Graphics/Pictures/选择.png": "res://fixture/choice.png",
		"Graphics/Pictures/选择.jpg": "res://fixture/choice.jpg",
		"Graphics/Pictures/说明.txt": "res://fixture/readme.txt",
		"Graphics/Pictures/../Icons/越界.png": "res://fixture/escape.png",
		"Audio/SE/同名.png": "res://fixture/sound.png"
	}
	data._cache[index_key] = fixture
	resources._textures["Graphics/Pictures/同名"] = picture
	resources._textures["Graphics/Icons/同名"] = icon
	var title_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	title_image.fill(Color.RED)
	var title_texture := ImageTexture.create_from_image(title_image)
	resources._textures["Graphics/Titles/同名"] = title_texture
	var names: Array = cache.list_names("Pictures")
	expect(names == ["双扩展.png.jpg", "同名.png", "子目录/中文 文件.PNG", "选择.jpg", "选择.png"], "names preserve Unicode, subfolders, original extensions and same-stem collisions")
	expect(cache.list_names("Icons") == ["同名.png"] and cache.list_names("Titles") == ["同名.png"], "selectors do not mix folders")
	expect(cache.resolve("Pictures", "同名") == "res://fixture/picture.png" and cache.resolve("Icons", "同名") == "res://fixture/icon.png", "same basename remains category-qualified")
	expect(cache.picture("同名") == picture and cache.icon("同名") == icon and picture != icon, "named loaders do not share another category's same-name image")
	expect(cache.title("同名") == title_texture and title_texture != picture and title_texture != icon, "same-named title is neither picture nor icon")
	for role in [["animation", "Animations"], ["autotile", "Autotiles"], ["battler", "Battlers"], ["character", "Characters"], ["fog", "Fogs"], ["gameover", "Gameovers"], ["icon", "Icons"], ["panorama", "Panoramas"], ["picture", "Pictures"], ["tileset", "Tilesets"], ["title", "Titles"], ["transition", "Transitions"], ["windowskin", "Windowskins"]]:
		var marker := ImageTexture.create_from_image(title_image)
		resources._textures["Graphics/%s/@api_marker" % role[1]] = marker
		expect(cache.call(role[0], "@api_marker") == marker, "each named loader selects its own category: " + role[0])
	expect(cache.resolve("Pictures", "子目录\\中文 文件.PNG") == "res://fixture/nested.png", "relative Windows separators normalize inside category")
	expect(cache.resolve("Pictures", "双扩展.png.jpg") == "res://fixture/corrected.jpg.rgm_123.png", "original name resolves corrected exported image")
	expect(cache.list_names("Fogs").is_empty() and cache.fog("不存在") == null, "empty category never falls back")
	expect(cache.list_assets("Unknown").is_empty() and cache.texture("Unknown", "同名") == null, "unknown category rejected")
	for name in ["", "../Icons/同名", "a/../b", "/absolute", "C:/image", "res://image", "a//b", "a/./b", "x\n", "..\\Icons\\同名"]:
		expect(cache.asset_key("Pictures", name).is_empty() and cache.picture(name) == null, "reject cross-category or malformed name: " + name.replace("\n", "[newline]"))
	expect(not cache.exists("Pictures", "不存在") and not cache.exists("Pictures", "同名"), "missing indexed file query fails without loading")
	var categories: Array = cache.categories()
	var category_snapshot: Array = categories.duplicate()
	categories.clear()
	names.clear()
	expect(cache.categories() == category_snapshot and category_snapshot.has("Faces") and category_snapshot.has("Skills") and cache.list_names("Pictures").size() == 5, "returned arrays do not mutate the current catalog including faces and skill graphics")
	var retained := Sprite2D.new()
	retained.texture = picture
	cache.clear()
	expect(retained.texture == picture and retained.texture.get_width() == 128, "clearing cache does not destroy textures retained by live sprites")
	retained.free()
	data._cache[index_key] = original
	resources._textures = old_textures


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
