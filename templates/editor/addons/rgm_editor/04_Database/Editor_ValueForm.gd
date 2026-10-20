## 职责：使用类型化树形控件编辑嵌套值，保留原字段和未知扩展数据。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/04_Database/Editor_ValueForm.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func configure( value: Variant, labels: Variant = {}, documents: RefCounted = null, hints: Dictionary = {}, read_only: bool = false ) -> void
##     用途：配置本实例使用的数据和依赖。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 labels（Variant；默认值 {}）：控件或字段的显示名称集合。
##     参数 documents（RefCounted；默认值 null）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 hints（Dictionary；默认值 {}）：字段说明或界面提示集合。
##     参数 read_only（bool；默认值 false）：是否仅允许查看。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draft() -> Variant
##     用途：取得可交给调用方的独立编辑草稿。
##     参数：无。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   func edit_path(path: Array) -> void
##     参数 path（Array；必填）：待读取、写入或定位的文件路径。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func edit_asset(path: Array) -> void
##     参数 path（Array；必填）：待读取、写入或定位的文件路径。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   value_changed(value: Variant, path: Array, edited: Variant)：由持有方发出，通知对应状态或操作结果。
##     value：需要读取、校验或写入的值。
##     path：待读取、写入或定位的文件路径。
##     edited：edited。
##   asset_edit_requested(path: Array)：由持有方发出，通知对应状态或操作结果。
##     path：待读取、写入或定位的文件路径。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 公开常量：IMAGE_ASSETS、LABELS。
## 接口说明结束。

@tool
extends VBoxContainer
## Typed tree form: no JSON typing is required, and unknown fields are retained.
const Commands = preload("../03_Event/Editor_Commands.gd")
signal value_changed(value: Variant, path: Array, edited: Variant)
signal asset_edit_requested(path: Array)
var _value: Variant
var _labels: Variant = {}
var _hints: Dictionary = {}
var _documents: RefCounted
var _tree: Tree
var _dialog: ConfirmationDialog
var _input: Control
var _edit_body: VBoxContainer
var _editing: Array = []
var _offsets: Dictionary = {}
var _read_only = false
var _caption: Label
var _edit_button: Button
var _array_buttons: Array[Button] = []
var _page_buttons: Array[Button] = []
var _route_dialog: ConfirmationDialog
var _route_path: Array = []
var _table_dialog: ConfirmationDialog
var _set_dialog: ConfirmationDialog
var _complex_path: Array = []
var _asset_scroll: ScrollContainer
var _asset_box: HFlowContainer
var _previews: Dictionary = {}
var _asset_dialog: ConfirmationDialog
var _asset_path: Array = []
var _audio_dialog: ConfirmationDialog
var _audio_path: Array = []
const IMAGE_ASSETS = [
	"Characters",
	"Tilesets",
	"Autotiles",
	"Panoramas",
	"Fogs",
	"Windowskins",
	"Icons",
	"Animations",
	"Pictures",
	"Transitions",
	"Battlers",
	"Battlebacks",
	"Titles",
	"Gameovers"
]
const LABELS := {
	"name": "名称",
	"description": "说明",
	"id": "ID",
	"trigger": "触发方式",
	"switch_id": "触发开关ID",
	"x": "X坐标",
	"y": "Y坐标",
	"condition": "出现条件",
	"graphic": "图形",
	"switch1_valid": "开关1条件启用",
	"switch2_valid": "开关2条件启用",
	"variable_valid": "变量条件启用",
	"self_switch_valid": "独立开关条件启用",
	"switch1_id": "开关1 ID",
	"switch2_id": "开关2 ID",
	"variable_id": "变量ID",
	"variable_value": "变量下限",
	"self_switch_ch": "独立开关",
	"tile_id": "图块ID（0为行走图）",
	"character_name": "行走图",
	"character_hue": "行走图色相",
	"direction": "朝向",
	"pattern": "图案帧",
	"opacity": "不透明度",
	"blend_type": "混合方式",
	"move_type": "自主移动方式",
	"move_speed": "移动速度",
	"move_frequency": "移动频度",
	"move_route": "自主移动路线",
	"repeat": "重复路线",
	"skippable": "遇阻跳过",
	"walk_anime": "行走动画",
	"step_anime": "踏步动画",
	"direction_fix": "固定朝向",
	"through": "穿透",
	"always_on_top": "置顶",
	"list": "路线指令",
	"code": "路线动作",
	"parameters": "参数",
	"volume": "音量",
	"pitch": "音调",
	"red": "红色",
	"green": "绿色",
	"blue": "蓝色",
	"gray": "灰度",
	"alpha": "透明通道",
	"common_event_id": "公共事件ID",
	"scope": "作用范围",
	"occasion": "使用场合",
	"sp_cost": "SP消耗",
	"price": "价格",
	"icon_name": "图标",
	"tileset_name": "图块集图像",
	"autotile_names": "自动图块图像",
	"panorama_name": "全景图像",
	"fog_name": "雾图像",
	"windowskin_name": "窗口皮肤",
	"start_map_id": "起点地图ID",
	"start_x": "起点X",
	"start_y": "起点Y",
	"switches": "开关名称",
	"variables": "变量名称"
}


func _ready() -> void:
	_build()


func configure(
	value: Variant,
	labels: Variant = {},
	documents: RefCounted = null,
	hints: Dictionary = {},
	read_only: bool = false
) -> void:
	_value = value.duplicate(true) if value is Array or value is Dictionary else value
	_labels = labels
	if _documents != null and _documents.changed.is_connected(_refresh):
		_documents.changed.disconnect(_refresh)
	_documents = documents
	if _documents != null:
		_documents.changed.connect(_refresh)
	_hints = hints
	_read_only = read_only
	if _tree == null:
		_build()
	_refresh()


func draft() -> Variant:
	return _value.duplicate(true) if _value is Array or _value is Dictionary else _value


func edit_path(path: Array) -> void:
	if not _audio_info(path).is_empty():
		_open_audio(path)
		return
	# Dedicated lists can select rows beyond the generic locator's current page.
	var branch: Variant = _value
	var prefix: Array = []
	var repage = false
	for key in path:
		if branch is Array and key is int and int(key) >= 0 and int(key) < branch.size():
			var begin = int(_offsets.get(str(prefix), 0))
			if int(key) < begin or int(key) >= begin + 80:
				_offsets[str(prefix)] = int(int(key) / 80) * 80
				repage = true
		elif not branch is Dictionary or not branch.has(key):
			return
		branch = branch[key]
		prefix.append(key)
	if repage:
		_refresh()
	var pending: Array = [_tree.get_root()]
	while not pending.is_empty():
		var item: TreeItem = pending.pop_back()
		if item.get_metadata(0) == path:
			item.select(0)
			_edit_selected()
			return
		pending.append_array(item.get_children())


func edit_asset(path: Array) -> void:
	if _read_only or _protected(path):
		return
	var hint = _hint(path)
	if hint.get("source_picker", false):
		asset_edit_requested.emit(path)
		return
	if not str(hint.get("asset", "")) in IMAGE_ASSETS:
		return
	if _asset_dialog == null:
		_asset_dialog = preload("../05_Assets/Editor_AssetDialog.gd").new()
		add_child(_asset_dialog)
		_asset_dialog.accepted.connect(_accept_asset)
	_asset_path = path.duplicate()
	_asset_dialog.open(
		_documents,
		str(hint.asset),
		str(_read_at(path)),
		_asset_settings(path),
		_asset_caption(path)
	)


func _asset_caption(path: Array) -> String:
	if path.size() >= 2 and str(path[-2]) == "autotile_names":
		return "自动图块 %d" % (int(path[-1]) + 1)
	if str(path[-1]) == "tileset_name":
		return (
			"普通图块 · 素材1/%d" % _value.tileset_sources.size()
			if _value is Dictionary and _value.has("tileset_sources")
			else "普通图块（主图）"
		)
	var key: Variant = path[-1]
	if _labels is Dictionary and _labels.has(key):
		return str(_labels[key])
	if _labels is Array and key is int and key in range(_labels.size()):
		return str(_labels[key])
	return str(
		LABELS.get(
			str(key),
			preload("../05_Assets/Editor_AssetPreview.gd").TITLES.get(
				str(_hint(path).asset), str(key)
			)
		)
	)


func _asset_settings(path: Array) -> Dictionary:
	var result: Dictionary = {}
	var parent: Variant = _read_at(path.slice(0, -1))
	var hint = _hint(path)
	if parent is Dictionary:
		if parent.has("tile_id") and str(path[-1]) == "character_name":
			for key in ["direction", "pattern", "opacity", "character_hue"]:
				if parent.has(key):
					result[key] = parent[key]
		var prefix = str(path[-1]).trim_suffix("_name")
		if parent.has(prefix + "_hue"):
			result.hue = parent[prefix + "_hue"]
		if parent.has(prefix + "_opacity"):
			result.opacity = parent[prefix + "_opacity"]
	for key in ["hue", "opacity", "direction", "pattern"]:
		if hint.has(key + "_path"):
			result[key] = _read_at(hint[key + "_path"])
	return result


func _accept_asset(asset_name: String, settings: Dictionary) -> void:
	var path = _asset_path.duplicate()
	var hint = _hint(path)
	var parent: Variant = _read_at(path.slice(0, -1))
	# Apply all related graphic fields in one detached value, then refresh once.
	parent[path[-1]] = asset_name
	if parent is Dictionary:
		if parent.has("tile_id") and str(path[-1]) == "character_name":
			parent.tile_id = 0
			for key in ["direction", "pattern", "opacity"]:
				if parent.has(key) and settings.has(key):
					parent[key] = settings[key]
		var prefix = str(path[-1]).trim_suffix("_name")
		for key in ["hue", "opacity"]:
			if parent.has(prefix + "_" + key) and settings.has(key):
				parent[prefix + "_" + key] = settings[key]
	for key in ["hue", "opacity", "direction", "pattern"]:
		if hint.has(key + "_path") and settings.has(key):
			var target: Array = hint[key + "_path"]
			_read_at(target.slice(0, -1))[target[-1]] = settings[key]
	_put(path, asset_name)


func _asset_paths(value: Variant, path: Array = []) -> Array:
	var paths: Array = []
	if value is Dictionary and not _is_table(value) or value is Array and value.size() <= 80:
		for key in value.keys() if value is Dictionary else range(value.size()):
			if str(key).begins_with("_"):
				continue
			var child = path.duplicate()
			child.append(key)
			if value[key] is String and str(_hint(child).get("asset", "")) in IMAGE_ASSETS:
				paths.append(child)
			elif value[key] is Dictionary or value[key] is Array:
				paths.append_array(_asset_paths(value[key], child))
	return paths.slice(0, 16)


func _refresh_assets() -> void:
	var paths = _asset_paths(_value)
	var used: Dictionary = {}
	for path in paths:
		var key = str(path)
		used[key] = true
		if not _previews.has(key):
			var preview = preload("../05_Assets/Editor_AssetPreview.gd").new()
			preview.custom_minimum_size = Vector2(170, 140)
			_asset_box.add_child(preview)
			preview.activated.connect(edit_asset.bind(path.duplicate()))
			_previews[key] = preview
		_previews[key].configure(
			_documents,
			str(_hint(path).asset),
			str(_read_at(path)),
			_asset_settings(path),
			false,
			not _read_only,
			_asset_caption(path)
		)
	for key in _previews.keys():
		if not used.has(key):
			_previews[key].queue_free()
			_previews.erase(key)
	_asset_scroll.visible = not paths.is_empty()


func _build() -> void:
	if _tree != null:
		return
	var bar = HFlowContainer.new()
	add_child(bar)
	_caption = Label.new()
	bar.add_child(_caption)
	for entry in [
		["编辑字段", _edit_selected],
		["添加项", _add_selected],
		["删除项", _delete_selected],
		["上移", _move_selected.bind(-1)],
		["下移", _move_selected.bind(1)],
		["上80项", _page.bind(-1)],
		["下80项", _page.bind(1)]
	]:
		var button = Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		bar.add_child(button)
		if _edit_button == null:
			_edit_button = button
			button.tooltip_text = "编辑左侧表中选中的字段，也可双击该字段。"
		elif entry[0] in ["上80项", "下80项"]:
			_page_buttons.append(button)
		else:
			_array_buttons.append(button)
	_asset_scroll = ScrollContainer.new()
	_asset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_asset_scroll.custom_minimum_size.y = 190
	add_child(_asset_scroll)
	_asset_box = HFlowContainer.new()
	_asset_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_scroll.add_child(_asset_box)
	_tree = Tree.new()
	_tree.columns = 2
	_tree.set_column_title(0, "字段")
	_tree.set_column_title(1, "值（双击编辑）")
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size.y = 180
	add_child(_tree)
	_tree.item_activated.connect(_edit_selected)
	_tree.item_selected.connect(_update_toolbar)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "编辑字段"
	_dialog.confirmed.connect(_accept)
	add_child(_dialog)
	_edit_body = VBoxContainer.new()
	_edit_body.custom_minimum_size.x = 580
	_dialog.add_child(_edit_body)


func _refresh() -> void:
	var category = str(_hints.get("", {}).get("database_category", ""))
	if not category.is_empty() and _value is Dictionary:
		_hints = preload("Editor_DatabaseSchema.gd").hints(category, _value)
	_tree.clear()
	var root = _tree.create_item()
	_append(root, _value, [])
	_update_toolbar()
	_refresh_assets()


func _append(parent: TreeItem, value: Variant, path: Array) -> void:
	if value is Dictionary or value is Array:
		var keys: Array = value.keys() if value is Dictionary else []
		if value is Array:
			var begin = int(_offsets.get(str(path), 0))
			for i in range(begin, mini(value.size(), begin + 80)):
				keys.append(i)
		for key in keys:
			if str(key).begins_with("_") and not str(key).begins_with("_editor"):
				continue
			var child = _tree.create_item(parent)
			var child_path = path.duplicate()
			child_path.append(key)
			var text = (
				str(
					preload("Editor_DatabaseSchema.gd").LABELS.get(
						str(key), LABELS.get(str(key), str(key))
					)
				)
				if value is Dictionary
				else "[%d]" % int(key)
			)
			if value is Array and _hint(path).get("goods", false):
				text = (
					"商品%d" % (int(key) + 1)
					if path.is_empty()
					else ["商品类型", "商品名称"][int(key)] if int(key) < 2 else text
				)
			if value is Array and not path.is_empty() and str(path[-1]) == "parameters":
				var route: Variant = _read_at(path.slice(0, -1))
				if route is Dictionary and route.has("code"):
					var labels: Array = (
						{
							14: ["横向格数", "纵向格数"],
							15: ["等待（1/20秒）"],
							27: ["开关ID"],
							28: ["开关ID"],
							29: ["速度"],
							30: ["频度"],
							41: ["行走图", "色相", "朝向", "图案帧"],
							42: ["不透明度"],
							43: ["混合方式"],
							44: ["SE"]
						}
						. get(int(route.code), [])
					)
					if key < labels.size():
						text = str(labels[key])
			if path.is_empty():
				if _labels is Array and key is int and key < _labels.size():
					text = str(_labels[key])
				elif _labels is Dictionary:
					text = str(_labels.get(str(key), text))
			child.set_text(0, text)
			child.set_metadata(0, child_path)
			var part: Variant = value[key]
			if str(key).begins_with("_editor"):
				child.set_text(0, "脚本占位")
				child.set_text(1, "原始数据保留")
			elif _is_table(part):
				child.set_text(
					1, "%d×%d×%d；双击编辑表格" % [int(part.x_size), int(part.y_size), int(part.z_size)]
				)
			elif part is Array and _hint(child_path).has("set"):
				var names: Array = []
				for id in part.slice(0, 3):
					names.append(
						preload("../07_Common/Editor_Presentation.gd").reference_text(
							_documents, str(_hint(child_path).set), id
						)
					)
				child.set_text(
					1,
					"%d项：%s%s；双击选择" % [part.size(), "、".join(names), "…" if part.size() > 3 else ""]
				)
			elif _is_route(part):
				child.set_text(1, "%d条动作；双击设置路线" % maxi(0, part.get("list", []).size() - 1))
			elif part is Dictionary or part is Array:
				child.set_text(1, "%d 项" % part.size())
				_append(child, part, child_path)
				child.collapsed = child_path.size() > 1 or (part is Array and part.size() > 20)
			else:
				child.set_text(1, _display(part, child_path).left(180))
				child.set_tooltip_text(1, _display(part, child_path))
			if str(key).begins_with("_") or str(key) == "id":
				child.set_custom_color(0, Color.GRAY)
		if value is Array and value.size() > 80:
			var child = _tree.create_item(parent)
			child.set_text(0, "共%d项；选中此数组后用上一组/下一组" % value.size())
			child.set_metadata(0, path)


func _read_at(path: Array) -> Variant:
	var value: Variant = _value
	for key in path:
		value = value[key]
	return value


func _put(path: Array, edited: Variant) -> void:
	if path.is_empty():
		_value = edited
	else:
		var parent: Variant = _read_at(path.slice(0, -1))
		parent[path[-1]] = edited
	value_changed.emit(draft(), path, edited)
	_refresh()


func _selected_path() -> Array:
	var item = _tree.get_selected()
	return item.get_metadata(0) if item != null and item.get_metadata(0) is Array else []


func _is_table(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("_rmxp_type", "") == "table"
		and value.get("values") is Array
	)


func _complex(value: Variant, path: Array) -> bool:
	return (
		_is_route(value)
		or _is_table(value)
		or not _audio_info(path).is_empty()
		or value is Array and _hint(path).has("set")
	)


func _protected(path: Array) -> bool:
	for size in range(1, path.size() + 1):
		if _hint(path.slice(0, size)).get("readonly", false):
			return true
	return (
		not path.is_empty()
		and path[-1] is int
		and int(path[-1]) == 0
		and _hint(path.slice(0, -1)).get("indexed", false)
	)


func _is_route(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("list") is Array
		and value.has("repeat")
		and value.has("skippable")
	)


func _update_toolbar() -> void:
	_caption.text = (
		"事件页属性"
		if _value is Dictionary and _value.has("condition") and _value.has("graphic")
		else "字段"
	)
	var path = _selected_path()
	var value: Variant = _read_at(path)
	_edit_button.text = "设置路线…" if _is_route(value) else "编辑字段"
	_edit_button.disabled = (
		_read_only
		or _protected(path)
		or path.is_empty()
		or str(path[-1]).begins_with("_")
		or str(path[-1]) == "id"
		or (value is Dictionary or value is Array) and not _complex(value, path)
	)
	var array_path = _array_path()
	var array: Variant = _read_at(array_path)
	var array_hint = _hint(array_path)
	var editable = (
		not _read_only
		and not _protected(array_path)
		and array is Array
		and not array_hint.get("fixed", false)
		and not array_hint.has("set")
		and not (array_path.is_empty() and _labels is Array and not _labels.is_empty())
	)
	for button in _array_buttons:
		button.visible = editable and (not array_hint.get("indexed", false) or button.text == "添加项")
	for button in _page_buttons:
		button.visible = array is Array and array.size() > 80


func _hint(path: Array) -> Dictionary:
	var explicit: Dictionary = _hints.get(
		"/".join(path.map(func(k: Variant) -> String: return str(k))), {}
	)
	var hint: Dictionary = (
		_hints
		. get("/".join(path.map(func(k: Variant) -> String: return str(k))), {})
		. duplicate(true)
	)
	var key = str(path[-1]) if not path.is_empty() else ""
	if key == "trigger":
		hint.options = {"0": "确定键", "1": "玩家接触", "2": "事件接触", "3": "自动执行", "4": "并行处理"}
	if key == "move_type":
		hint.options = {"0": "固定", "1": "随机", "2": "接近玩家", "3": "自定义路线"}
	if key == "self_switch_ch":
		hint.options = {"A": "A", "B": "B", "C": "C", "D": "D"}
	if key == "direction":
		hint.options = {"2": "下", "4": "左", "6": "右", "8": "上"}
	if key == "blend_type":
		hint.options = {"0": "正常", "1": "加算", "2": "减算"}
	if key in ["move_speed", "move_frequency"]:
		hint.min = 1
		hint.max = 6
	if key in ["opacity", "alpha", "red", "green", "blue", "gray"]:
		hint.min = -255 if key in ["red", "green", "blue"] else 0
		hint.max = 255
	if key == "volume":
		hint.min = 0
		hint.max = 100
	if key == "pitch":
		hint.min = 50
		hint.max = 150
	if key == "name" and path.size() >= 2:
		var owner = str(path[-2])
		if owner == "se" or owner.ends_with("_se"):
			hint.asset = "SE"
		elif owner == "bgm" or owner.ends_with("_bgm"):
			hint.asset = "BGM"
		elif owner == "bgs" or owner.ends_with("_bgs"):
			hint.asset = "BGS"
		elif owner == "me" or owner.ends_with("_me"):
			hint.asset = "ME"
	if key in ["switch1_id", "switch2_id", "switch_id"]:
		hint.db = "switches"
	if key == "variable_id":
		hint.db = "variables"
	if key == "common_event_id":
		hint.db = "CommonEvents"
	if key == "code" and _read_at(path.slice(0, -1)) is Dictionary:
		var options: Dictionary = {}
		for i in range(0, 45):
			options[str(i)] = Commands.ROUTE_NAMES[i]
		hint.options = options
	if (
		key
		in [
			"character_name",
			"tileset_name",
			"panorama_name",
			"fog_name",
			"windowskin_name",
			"icon_name"
		]
	):
		hint.asset = {
			"character_name": "Characters",
			"tileset_name": "Tilesets",
			"panorama_name": "Panoramas",
			"fog_name": "Fogs",
			"windowskin_name": "Windowskins",
			"icon_name": "Icons"
		}[key]
	if path.size() >= 2 and str(path[-2]) == "parameters":
		var command: Variant = _read_at(path.slice(0, -2))
		if command is Dictionary and command.has("code"):
			var route_code = int(command.code)
			var i = int(path[-1])
			if route_code in [27, 28] and i == 0:
				hint.db = "switches"
			if route_code == 41 and i == 0:
				hint.asset = "Characters"
			if route_code == 41 and i == 2:
				hint.options = {"2": "下", "4": "左", "6": "右", "8": "上"}
			if route_code == 43 and i == 0:
				hint.options = {"0": "正常", "1": "加算", "2": "减算"}
	hint.merge(explicit, true)
	return hint


func _audio_info(path: Array) -> Dictionary:
	if _documents == null:
		return {}
	var branch: Variant = _value
	for key in path:
		if (
			branch is Dictionary and branch.has(key)
			or branch is Array and key is int and int(key) >= 0 and int(key) < branch.size()
		):
			branch = branch[key]
		else:
			return {}
	var root_path = path.duplicate()
	if (
		not branch is Dictionary
		or not (branch.has("name") and branch.has("volume") and branch.has("pitch"))
	):
		if path.is_empty():
			return {}
		root_path = path.slice(0, -1)
		branch = _read_at(root_path)
	if (
		not branch is Dictionary
		or not (branch.has("name") and branch.has("volume") and branch.has("pitch"))
	):
		return {}
	var category = str(_hint(root_path + ["name"]).get("asset", ""))
	return (
		{"path": root_path, "category": category} if category in ["BGM", "BGS", "ME", "SE"] else {}
	)


func _open_audio(path: Array) -> void:
	if _read_only or _protected(path):
		return
	var info = _audio_info(path)
	if info.is_empty():
		return
	_audio_path = info.path
	_editing = path.duplicate()
	if _audio_dialog == null:
		_audio_dialog = preload("../05_Assets/Editor_AudioDialog.gd").new()
		add_child(_audio_dialog)
		_audio_dialog.accepted.connect(func(audio: Dictionary) -> void: _put(_audio_path, audio))
	_audio_dialog.open(_documents, info.category, _read_at(_audio_path))


func _display(value: Variant, path: Array) -> String:
	if (
		path.size() == 2
		and str(path[0]) in ["switches", "variables", "elements"]
		and value is String
		and value.strip_edges().is_empty()
	):
		return "未命名" if int(path[1]) > 0 else "保留编号0"
	return preload("../07_Common/Editor_Presentation.gd").field(value, _hint(path), _documents)


func _edit_selected() -> void:
	var path = _selected_path()
	if (
		path.is_empty()
		or _read_only
		or _protected(path)
		or str(path[-1]).begins_with("_")
		or str(path[-1]) == "id"
	):
		return
	var value: Variant = _read_at(path)
	if not _audio_info(path).is_empty():
		_open_audio(path)
		return
	if _is_table(value):
		_complex_path = path.duplicate()
		if _table_dialog == null:
			_table_dialog = preload("Editor_TableDialog.gd").new()
			add_child(_table_dialog)
			_table_dialog.accepted.connect(
				func(table: Dictionary) -> void: _put(_complex_path, table)
			)
		_table_dialog.open(value, str(path[-1]), _documents)
		return
	if value is Array and _hint(path).has("set"):
		_complex_path = path.duplicate()
		if _set_dialog == null:
			_set_dialog = preload("Editor_SetDialog.gd").new()
			add_child(_set_dialog)
			_set_dialog.accepted.connect(func(ids: Array) -> void: _put(_complex_path, ids))
		_set_dialog.open(
			value,
			_documents.lookup(_hint(path).set),
			_hint(path).get("ordered", false),
			str(
				preload("Editor_DatabaseSchema.gd").LABELS.get(
					str(path[-1]), LABELS.get(str(path[-1]), path[-1])
				)
			)
		)
		return
	if _is_route(value):
		_route_path = path.duplicate()
		if _route_dialog == null:
			# Lazy loading avoids a preload cycle: route parameters reuse this form.
			_route_dialog = (
				load(get_script().resource_path.get_base_dir().path_join("Editor_RouteDialog.gd"))
				. new()
			)
			add_child(_route_dialog)
			_route_dialog.accepted.connect(
				func(route: Dictionary) -> void: _put(_route_path, route)
			)
		_route_dialog.open(value, _documents)
		return
	if value is Dictionary or value is Array or value == null:
		return
	if str(_hint(path).get("asset", "")) in IMAGE_ASSETS:
		edit_asset(path)
		return
	# Imported Ruby route actions are retained, but cannot be edited into execution.
	if str(path[-1]) == "code" and int(value) == 45:
		return
	_editing = path
	for child in _edit_body.get_children():
		_edit_body.remove_child(child)
		child.queue_free()
	_input = null
	var hint = _hint(path)
	if hint.has("options"):
		var options = OptionButton.new()
		var selected = -1
		for key in hint.options:
			options.add_item(str(hint.options[key]))
			var option_value: Variant = key if value is String else int(key)
			options.set_item_metadata(options.item_count - 1, option_value)
			if option_value == value:
				selected = options.item_count - 1
		if selected < 0:
			options.add_item("未知选项「%s」（保留）" % str(value))
			options.set_item_metadata(options.item_count - 1, value)
			selected = options.item_count - 1
		options.select(selected)
		_input = options
	elif value is bool:
		var check = CheckBox.new()
		check.text = "启用"
		check.button_pressed = value
		_input = check
	elif value is int or value is float:
		var box = SpinBox.new()
		box.min_value = minf(float(value), float(hint.get("min", -99999999)))
		box.max_value = maxf(float(value), float(hint.get("max", 99999999)))
		box.step = 1 if value is int or float(value) == floor(float(value)) else 0.01
		box.value = value
		_input = box
	else:
		var text = TextEdit.new()
		text.text = str(value)
		text.custom_minimum_size = Vector2(560, 200)
		_input = text
	_edit_body.add_child(_input)
	if _documents != null and (hint.has("db") or hint.has("asset")):
		var search = LineEdit.new()
		search.placeholder_text = "按名称或编号搜索"
		_edit_body.add_child(search)
		var picker = ItemList.new()
		picker.custom_minimum_size = Vector2(560, 150)
		picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_edit_body.add_child(picker)
		var choices: Array = (
			_documents.lookup(str(hint.db))
			if hint.has("db")
			else _documents.assets(str(hint.asset)).map(
				func(n: Variant) -> Dictionary: return {"id": n, "name": n}
			)
		)
		if hint.has("db") and int(hint.get("min", 1)) == 0:
			choices.push_front(
				{
					"id": 0,
					"name":
					preload("../07_Common/Editor_Presentation.gd").reference_text(
						_documents, str(hint.db), 0, str(hint.get("empty", "无"))
					)
				}
			)
		if hint.has("asset"):
			choices.push_front({"id": "", "name": "无素材"})
		var refill = func(query: String) -> void:
			picker.clear()
			for choice in choices:
				if (
					not query.is_empty()
					and not str(choice.name).to_lower().contains(query.to_lower())
				):
					continue
				picker.add_item(str(choice.name))
				picker.set_item_metadata(picker.item_count - 1, choice.id)
				if choice.id == value:
					picker.select(picker.item_count - 1)
		refill.call("")
		search.text_changed.connect(refill)
		picker.item_selected.connect(
			func(i: int) -> void:
				if _input is SpinBox:
					_input.value = picker.get_item_metadata(i)
				elif _input is TextEdit:
					_input.text = str(picker.get_item_metadata(i))
		)
		_dialog.title = "编辑字段 · " + _display(value, path)
	else:
		_dialog.title = "编辑字段"
	_dialog.popup_centered(
		Vector2i(640, 580) if hint.has("db") or hint.has("asset") else Vector2i(640, 380)
	)


func _accept() -> void:
	var value: Variant = _read_at(_editing)
	var edited: Variant
	if _input is OptionButton:
		edited = _input.get_item_metadata(_input.selected)
	elif _input is CheckBox:
		edited = _input.button_pressed
	elif _input is SpinBox:
		edited = (
			int(_input.value)
			if value is int or floor(float(value)) == float(value)
			else _input.value
		)
	else:
		edited = _input.text
	if str(_editing[-1]) == "code":
		var parent: Dictionary = _read_at(_editing.slice(0, -1))
		parent.parameters = Commands.route_command(int(edited)).parameters
	_put(_editing, edited)


func _array_path() -> Array:
	var path = _selected_path()
	if not path.is_empty() and _read_at(path) is Array:
		return path
	if not path.is_empty() and _read_at(path.slice(0, -1)) is Array:
		return path.slice(0, -1)
	return []


func _add_selected() -> void:
	if _read_only:
		return
	var path = _array_path()
	if _protected(path):
		return
	var array: Variant = _read_at(path)
	if not array is Array or _hint(path).get("fixed", false) or _hint(path).has("set"):
		return
	var value: Variant = "" if array.is_empty() else array[-1]
	var is_route = not path.is_empty() and str(path[-1]) == "list"
	if is_route:
		value = Commands.route_command(3)
	elif value is Dictionary:
		value = value.duplicate(true)
	elif value is Array:
		value = value.duplicate(true)
	elif value is String:
		value = ""
	elif value is bool:
		value = false
	else:
		value = 0
	if _hint(path).has("item_default"):
		value = (
			_hint(path).item_default.duplicate(true)
			if _hint(path).item_default is Dictionary or _hint(path).item_default is Array
			else _hint(path).item_default
		)
	array.insert(maxi(0, array.size() - 1) if is_route else array.size(), value)
	_put(path, array)


func _delete_selected() -> void:
	if _read_only:
		return
	var path = _selected_path()
	if _protected(path):
		return
	if path.is_empty() or not path[-1] is int:
		return
	var parent: Variant = _read_at(path.slice(0, -1))
	if (
		not parent is Array
		or _hint(path.slice(0, -1)).get("fixed", false)
		or _hint(path.slice(0, -1)).get("indexed", false)
		or _hint(path.slice(0, -1)).has("set")
	):
		return
	if parent[path[-1]] is Dictionary and int(parent[path[-1]].get("code", -1)) == 0:
		return
	if parent.size() == 1 and _hint(path.slice(0, -1)).get("keep_one", false):
		return
	parent.remove_at(path[-1])
	_put(path.slice(0, -1), parent)


func _move_selected(direction: int) -> void:
	if _read_only:
		return
	var path = _selected_path()
	if _protected(path):
		return
	if path.is_empty() or not path[-1] is int:
		return
	var parent: Variant = _read_at(path.slice(0, -1))
	if (
		not parent is Array
		or _hint(path.slice(0, -1)).get("fixed", false)
		or _hint(path.slice(0, -1)).get("indexed", false)
		or _hint(path.slice(0, -1)).has("set")
	):
		return
	var i = int(path[-1])
	var target = i + direction
	if target < 0 or target >= parent.size():
		return
	if (
		parent[i] is Dictionary and int(parent[i].get("code", -1)) == 0
		or parent[target] is Dictionary and int(parent[target].get("code", -1)) == 0
	):
		return
	var swap: Variant = parent[target]
	parent[target] = parent[i]
	parent[i] = swap
	_put(path.slice(0, -1), parent)


func _page(direction: int) -> void:
	var path = _array_path()
	var value: Variant = _read_at(path)
	if not value is Array:
		return
	_offsets[str(path)] = clampi(
		int(_offsets.get(str(path), 0)) + 80 * direction, 0, maxi(0, value.size() - 1)
	)
	_refresh()
