## 职责：构建事件指令参数对话框，校验输入并返回完整指令记录。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/03_Event/Editor_CommandDialog.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func open( documents: RefCounted, code: int = 101, parameters: Array = [], adding: bool = true, characters: Dictionary = {} ) -> void
##     用途：打开页面、对话框或目标记录。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 code（int；默认值 101）：对应指令、按键或操作的编码。
##     参数 parameters（Array；默认值 []）：按对应接口或事件指令约定排列的参数。
##     参数 adding（bool；默认值 true）：是否处于新增模式。
##     参数 characters（Dictionary；默认值 {}）：当前地图中可供选择的人物名称与编号信息。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   accepted(code: int, parameters: Array)：用户确认了当前对话框草稿。
##     code：对应指令、按键或操作的编码。
##     parameters：按对应接口或事件指令约定排列的参数。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 公开常量：GROUPS。
## 接口说明结束。

@tool
extends ConfirmationDialog
const Commands = preload("Editor_Commands.gd")
const Form = preload("../04_Database/Editor_ValueForm.gd")
const RouteForm = preload("Editor_RouteForm.gd")
const NativeSource = preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
signal accepted(code: int, parameters: Array)
var _code = 101
var _parameters: Array = []
var _documents: RefCounted
var _selector: OptionButton
var _form: VBoxContainer
var _message: Label
var _updating = false
var _goods = false
var _route_form: VBoxContainer
var _characters: Dictionary = {}
var _palette: VBoxContainer
var _tabs: TabBar
var _button_box: VBoxContainer
var _parameter_box: VBoxContainer
var _heading: Label
var _back: Button
var _destination: VBoxContainer
var _location_picker: VBoxContainer
var _transfer_options: HBoxContainer
var _native_editor: VBoxContainer
var _condition_back: Button
const GROUPS = [
	{
		"消息": [101, 102, 103, 104, 105, 108],
		"流程控制": [111, 112, 113, 115, 116, 117, 118, 119, 106],
		"开关与变量": [121, 122, 123, 124],
		"队伍与物品": [125, 126, 127, 128, 129]
	},
	{
		"地图与移动": [201, 202, 203, 204, 205, 206, 207, 208, 209, 210],
		"画面": [221, 222, 223, 224, 225],
		"图片": [231, 232, 233, 234, 235, 236],
		"声音": [241, 242, 245, 246, 247, 248, 249, 250, 251]
	},
	{
		"角色": [311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322],
		"场景": [302, 303, 351, 352, 353, 354],
		"系统": [131, 134, 135, 355]
	}
]


func _ready() -> void:
	_build()


func _build() -> void:
	if _form != null:
		return
	title = "事件指令"
	var box = VBoxContainer.new()
	add_child(box)
	box.custom_minimum_size = Vector2(640, 440)
	_selector = OptionButton.new()
	box.add_child(_selector)
	_selector.hide()
	for code in Commands.available():
		_selector.add_item("%s  [%d]" % [Commands.name_for(code), code], code)
	_selector.item_selected.connect(_select_code)
	_palette = VBoxContainer.new()
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_palette)
	_tabs = TabBar.new()
	_palette.add_child(_tabs)
	for text in ["消息与流程", "地图与画面", "角色与场景"]:
		_tabs.add_tab(text)
	_tabs.tab_changed.connect(func(_index: int) -> void: _rebuild_buttons())
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.add_child(scroll)
	_button_box = VBoxContainer.new()
	_button_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_button_box)
	_parameter_box = VBoxContainer.new()
	_parameter_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_parameter_box)
	var bar = HBoxContainer.new()
	_parameter_box.add_child(bar)
	_back = Button.new()
	_back.text = "‹ 选择其他指令"
	bar.add_child(_back)
	_back.pressed.connect(_show_palette)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 18)
	bar.add_child(_heading)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 600
	_message.size.x = 600
	_parameter_box.add_child(_message)
	_destination = VBoxContainer.new()
	_destination.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parameter_box.add_child(_destination)
	_transfer_options = HBoxContainer.new()
	_destination.add_child(_transfer_options)
	_location_picker = preload("../02_Map/Editor_MapLocationPicker.gd").new()
	_location_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_destination.add_child(_location_picker)
	_location_picker.map_browsed.connect(func(_map_id: int) -> void: _check_destination())
	_location_picker.chosen.connect(
		func(map_id: int, cell: Vector2i) -> void:
			var p: Array = _form.draft()
			p[1] = map_id
			p[2] = cell.x
			p[3] = cell.y
			_form._put([], p)
	)
	_form = Form.new()
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parameter_box.add_child(_form)
	_form.value_changed.connect(_parameter_changed)
	_route_form = RouteForm.new()
	_route_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parameter_box.add_child(_route_form)
	_route_form.hide()
	_condition_back = Button.new()
	_condition_back.text = "选择其它条件类型"
	_parameter_box.add_child(_condition_back)
	_condition_back.pressed.connect(
		func():
			_parameters = [0, 1, 0]
			_update_form()
	)
	_native_editor = preload("Editor_EventScript.gd").new()
	_native_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parameter_box.add_child(_native_editor)
	_native_editor.hide()
	confirmed.connect(_accept)
	get_ok_button().text = "应用指令"
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	for child in _button_box.get_children():
		_button_box.remove_child(child)
		child.queue_free()
	var groups: Dictionary = GROUPS[_tabs.current_tab]
	for group in groups:
		var heading = Label.new()
		heading.text = group
		heading.add_theme_font_size_override("font_size", 16)
		_button_box.add_child(heading)
		var grid = GridContainer.new()
		grid.columns = 3
		_button_box.add_child(grid)
		for code in groups[group]:
			if not code in Commands.available():
				continue
			var button = Button.new()
			button.text = Commands.name_for(code)
			button.custom_minimum_size = Vector2(210, 32)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = "指令 %d" % code
			button.set_meta("command_code", code)
			grid.add_child(button)
			button.pressed.connect(func() -> void: _select_code(_selector.get_item_index(code)))


func _show_palette() -> void:
	_palette.show()
	_parameter_box.hide()
	get_ok_button().disabled = true
	title = "选择事件指令"
	call_deferred("popup_centered", Vector2i(760, 650))


func open(
	documents: RefCounted,
	code: int = 101,
	parameters: Array = [],
	adding: bool = true,
	characters: Dictionary = {}
) -> void:
	_build()
	_documents = documents
	_characters = characters.duplicate()
	_code = code
	_parameters = Commands.defaults(code) if adding else parameters.duplicate(true)
	_goods = code == 302
	var found = _selector.get_item_index(code)
	if found < 0:
		_selector.add_item(Commands.name_for(code) + "（保留，不执行）", code)
		found = _selector.item_count - 1
	_selector.select(found)
	_selector.disabled = not adding
	_back.visible = adding
	_update_form()
	popup_centered(Vector2i(980, 700) if code == 209 else Vector2i(760, 650))
	if adding:
		_show_palette()


func _select_code(index: int) -> void:
	_code = _selector.get_item_id(index)
	_parameters = Commands.defaults(_code)
	_goods = _code == 302
	_update_form()
	if _code == 209 and visible:
		call_deferred("popup_centered", Vector2i(980, 660))


func _update_form() -> void:
	_updating = true
	_palette.hide()
	_parameter_box.show()
	_heading.text = Commands.name_for(_code)
	title = "事件指令 · " + Commands.name_for(_code)
	var supported = _code in Commands.Catalog.SUPPORTED
	_message.text = "双击字段编辑；引用显示名称和编号，可搜索名称。人物目标按当前地图或实际调用上下文确定。"
	if _code == 106:
		_message.text = "等待20对应1秒，按实际时间推进。"
	if _code == 355:
		_message.text = "编辑实际执行的 GDScript；应用并保存后重新运行生效，原 Ruby 仅作只读来源。"
	if _code == 201:
		_message.text = "直接在地图上点格指定目的地；变量方式保留具名变量选择。"
	if _code == 209:
		_message.text = "选择移动对象，在下方面板指定路线；动作按钮会插入到选中行之前。"
	if _code == 302:
		_message.text = "商品列表：每项包含商品类型和商品名称，可添加多个商品。"
	if not supported:
		_message.text = "这条原工程指令目前未接入，原始参数保留。"
	get_ok_button().disabled = not supported
	_route_form.visible = _code == 209
	_form.size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN if _code == 209 else Control.SIZE_EXPAND_FILL
	)
	if _code == 209:
		_form.configure([_parameters[0]], ["移动对象"], _documents, _hints(), not supported)
		_route_form.configure(_parameters[1], _documents, not supported)
	elif _goods:
		if _parameters.size() == 2 and (_parameters[0] is int or _parameters[0] is float):
			_parameters = [_parameters]
		_form.configure(_parameters, {}, _documents, _hints(), not supported)
	else:
		_form.configure(
			_parameters,
			Commands.parameters_for(_code, _parameters),
			_documents,
			_hints(),
			not supported
		)
	_form._tree.custom_minimum_size.y = 65 if _code == 209 else 180
	_destination.visible = _code == 201 and int(_parameters[0]) == 0
	var native = _code == 355 or _code == 111 and int(_parameters[0]) == 12
	_form.visible = not _destination.visible and not native
	_native_editor.visible = native
	_condition_back.visible = _code == 111 and native
	if native:
		_native_editor.configure(str(_parameters[1] if _code == 111 else _parameters[0]))
	if _code == 201:
		for child in _transfer_options.get_children():
			_transfer_options.remove_child(child)
			child.queue_free()
		for entry in [
			["位置来源", 0, ["直接指定", "由变量指定"]],
			["朝向", 4, ["保持", "下", "左", "右", "上"]],
			["淡化", 5, ["淡化", "不淡化"]]
		]:
			var label = Label.new()
			label.text = entry[0]
			_transfer_options.add_child(label)
			var choice = OptionButton.new()
			_transfer_options.add_child(choice)
			var param = int(entry[1])
			var values = [0, 2, 4, 6, 8] if param == 4 else [0, 1]
			for index in entry[2].size():
				choice.add_item(entry[2][index])
				choice.set_item_metadata(index, values[index])
			var selected = values.find(int(_parameters[param]))
			if selected < 0:
				choice.add_item("原值 %s" % str(_parameters[param]))
				choice.set_item_metadata(choice.item_count - 1, _parameters[param])
				selected = choice.item_count - 1
			choice.select(selected)
			choice.item_selected.connect(
				func(index: int) -> void: _form._put([param], choice.get_item_metadata(index))
			)
		if _destination.visible:
			_location_picker.configure(
				_documents, int(_parameters[1]), Vector2i(int(_parameters[2]), int(_parameters[3]))
			)
			_check_destination()
	_updating = false


func _check_destination() -> void:
	if _code != 201 or int(_parameters[0]) != 0:
		return
	var p: Array = _form.draft()
	get_ok_button().disabled = (
		_location_picker._map_id != int(p[1])
		or not preload("../02_Map/Editor_MapOps.gd").valid(
			_location_picker._map, Vector2i(int(p[2]), int(p[3]))
		)
		or _location_picker._cell.x < 0
	)


func _parameter_changed(value: Variant, path: Array, edited: Variant) -> void:
	if _updating:
		return
	if _code == 209:
		_parameters[0] = value[0]
		return
	_parameters = value
	if _code == 201 and path.is_empty():
		call_deferred("_update_form")
	if _goods:
		call_deferred("_update_form")
		return
	if (
		path.size() == 1
		and path[0] is int
		and (
			(_code == 111 and (int(path[0]) == 0 or int(path[0]) == 2 and int(_parameters[0]) == 4))
			or _code == 122 and int(path[0]) == 3
			or _code == 204 and int(path[0]) == 0
		)
	):
		_parameters = Commands.variant_parameters(_code, _parameters, int(path[0]), edited)
		call_deferred("_update_form")
	elif path.size() == 1 and path[0] is int:
		# Source, subtype and equipment slot affect dependent field hints.
		call_deferred("_update_form")


func _accept() -> void:
	if _native_editor.visible:
		if not _native_editor.check():
			return
		_parameters = [12, _native_editor.source()] if _code == 111 else [_native_editor.source()]
	else:
		_parameters = [_form.draft()[0], _route_form.draft()] if _code == 209 else _form.draft()
	if _code == 201 and int(_parameters[0]) == 0:
		_check_destination()
		if get_ok_button().disabled:
			_fail("请先在当前预览地图上点格指定目的地。")
			return
	if _goods:
		if _parameters.is_empty():
			_fail("商店至少需要一个商品。")
			return
		for item in _parameters:
			if (
				not item is Array
				or item.size() != 2
				or not item[0] is int and not item[0] is float
				or int(item[0]) not in range(3)
				or not item[1] is int and not item[1] is float
				or int(item[1]) < 1
			):
				_fail("商品类型或ID无效。")
				return
	else:
		var reason = Commands.Catalog.reason(_code, _parameters)
		if not reason.is_empty():
			_fail(reason)
			return
	accepted.emit(_code, _parameters.duplicate(true))


func _fail(message: String) -> void:
	_message.text = message
	call_deferred("popup_centered", Vector2i(760, 580))


func _hints() -> Dictionary:
	var hints = preload("../07_Common/Editor_Presentation.gd").parameter_hints(
		_code, _parameters, _characters
	)
	if _code == 322:
		hints["1"].hue_path = [2]
		hints["3"].hue_path = [4]
	if _code == 204:
		hints["1"].hue_path = [2]
		if int(_parameters[0]) == 1:
			hints["1"].opacity_path = [3]
	if _code == 231:
		hints["1"].opacity_path = [8]
	return hints
