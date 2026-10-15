@tool
extends VBoxContainer
## Native move-route authoring: actions, their parameters and route flags.
const Commands = preload("EditorCommands.gd")
const ValueForm = preload("EditorValueForm.gd")
const _PARAMETER_LABELS := {14:["横向格数","纵向格数"],15:["等待（1/20秒）"],27:["开关ID"],28:["开关ID"],29:["速度"],30:["频度"],41:["行走图","色相","朝向","图案帧"],42:["不透明度"],43:["混合方式"],44:["SE"],45:["原Ruby脚本（修改后需重新编译）"]}
var _route: Dictionary = {}
var _documents: RefCounted
var _read_only = false
var _list: Tree
var _repeat: CheckBox
var _skip: CheckBox
var _message: Label
var _buttons: Array[Button] = []
var _edit: Button
var _delete: Button
var _copy: Button
var _up: Button
var _down: Button
var _param_dialog: ConfirmationDialog
var _param_form: VBoxContainer
var _param_index = -1

func configure(route: Dictionary, documents: RefCounted = null, read_only: bool = false) -> void:
	_build()
	_route = route.duplicate(true)
	if _documents!=null and _documents.changed.is_connected(_refresh_labels): _documents.changed.disconnect(_refresh_labels)
	_documents = documents
	if _documents!=null: _documents.changed.connect(_refresh_labels)
	_read_only = read_only
	_repeat.set_pressed_no_signal(bool(_route.get("repeat", false)))
	_skip.set_pressed_no_signal(bool(_route.get("skippable", false)))
	for button in _buttons: button.disabled = read_only
	_repeat.disabled = read_only; _skip.disabled = read_only
	_message.text = "点击动作按钮插入；双击左侧动作编辑参数。末尾结束标记自动保留。"
	if _route.has("_editor_original_route"): _message.text += " 原Ruby脚本已保留，暂不执行。"
	elif _route.get("_script_runtime_route",false): _message.text += " 迁移脚本按绑定执行；修改源码后需重新编译。"
	_refresh()

func draft() -> Dictionary:
	return _route.duplicate(true)

func _build() -> void:
	if _list != null: return
	custom_minimum_size = Vector2(820,350)
	var flags = HBoxContainer.new(); add_child(flags)
	_repeat = CheckBox.new(); _repeat.text = "重复执行"; flags.add_child(_repeat)
	_skip = CheckBox.new(); _skip.text = "遇到障碍时跳过"; flags.add_child(_skip)
	_repeat.toggled.connect(func(value: bool) -> void: _route.repeat = value)
	_skip.toggled.connect(func(value: bool) -> void: _route.skippable = value)
	var body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(body)
	var left = VBoxContainer.new(); left.custom_minimum_size.x = 290; left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(left)
	var bar = HBoxContainer.new(); left.add_child(bar)
	_edit = _button(bar,"编辑参数",_edit_selected)
	_copy = _button(bar,"复制",_copy_selected)
	_delete = _button(bar,"删除",_delete_selected)
	_up = _button(bar,"↑",_move_selected.bind(-1))
	_down = _button(bar,"↓",_move_selected.bind(1))
	_list = Tree.new(); _list.hide_root = true; _list.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(_list)
	_list.item_activated.connect(_edit_selected); _list.item_selected.connect(_update_buttons)
	var tabs = TabContainer.new(); tabs.custom_minimum_size.x = 500; tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(tabs)
	for group in [["移动",1,15],["朝向",16,26],["属性与音效",27,45]]:
		var grid = GridContainer.new(); grid.name = group[0]; grid.columns = 4; tabs.add_child(grid)
		for code in range(int(group[1]),int(group[2])+1):
			var button = _button(grid,Commands.ROUTE_NAMES[code],_insert.bind(code)); button.custom_minimum_size.x = 118
	_message = Label.new(); _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 760; _message.size.x = 760; add_child(_message)
	_param_dialog = ConfirmationDialog.new(); _param_dialog.title = "路线动作参数"; _param_dialog.dialog_hide_on_ok = false; add_child(_param_dialog)
	_param_form = ValueForm.new(); _param_form.custom_minimum_size = Vector2(620,260); _param_dialog.add_child(_param_form)
	_param_dialog.confirmed.connect(_accept_parameters)

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button = Button.new(); button.text = text; button.tooltip_text = text; button.pressed.connect(action); parent.add_child(button); _buttons.append(button); return button

func _refresh_labels() -> void:
	_refresh(_selected())

func _refresh(selection: int = -1) -> void:
	_list.clear(); var root = _list.create_item()
	var commands: Array = _route.get("list", [])
	for i in commands.size():
		var command: Dictionary = commands[i]
		var code = int(command.get("code", 0))
		var row = _list.create_item(root); row.set_metadata(0,i)
		var name = Commands.ROUTE_NAMES[code] if code >= 0 and code < Commands.ROUTE_NAMES.size() else "未知动作%d（保留）" % code
		var parameters: Array = command.get("parameters", [])
		var valid=Commands.Catalog.route_reason(code,parameters).is_empty()
		var summary=preload("EditorPresentation.gd").route_summary(code,parameters,name,_documents) if valid else name+"（未支持或参数无效；原始数据保留）"
		row.set_text(0,"%02d  %s" % [i+1,summary.left(160)])
		row.set_tooltip_text(0,summary+"\n原参数："+JSON.stringify(parameters))
		preload("EditorCommandColors.gd").apply(_list,row,code,_read_only or not valid or command.has("_editor_original"),true)
		if i == (commands.size()-1 if selection < 0 else selection): row.select(0)
	_update_buttons()

func _selected() -> int:
	var row = _list.get_selected()
	return int(row.get_metadata(0)) if row != null else maxi(0,_route.get("list", []).size()-1)

func _editable(index: int) -> bool:
	var commands: Array = _route.get("list", [])
	return not _read_only and index >= 0 and index < commands.size() and int(commands[index].get("code",0)) in range(1,46)

func _update_buttons() -> void:
	var index = _selected(); var editable = _editable(index)
	_edit.disabled = not editable or _route.list[index].get("parameters", []).is_empty()
	_copy.disabled = not editable; _delete.disabled = not editable
	_up.disabled = not editable or index == 0
	_down.disabled = not editable or index >= _route.get("list", []).size()-2

func _insert(code: int) -> void:
	if _read_only: return
	var index = _selected()
	_route.list.insert(index,Commands.route_command(code))
	if code==45: _route["_script_runtime_route"]=true; _message.text="保存事件后在F8工作区重新转换路线脚本；转换成功才可执行。"
	_refresh(index+1)
	if not _route.list[index].parameters.is_empty(): _open_parameters(index)

func _edit_selected() -> void:
	var index = _selected()
	if _editable(index) and not _route.list[index].get("parameters", []).is_empty(): _open_parameters(index)

func _open_parameters(index: int) -> void:
	_param_index = index
	var code = int(_route.list[index].code)
	var hints: Dictionary = {}
	match code:
		27,28: hints["0"] = {"db":"switches","min":1}
		29,30: hints["0"] = {"min":1,"max":6}
		41: hints = {"0":{"asset":"Characters","hue_path":[1],"direction_path":[2],"pattern_path":[3]},"1":{"min":0,"max":360},"2":{"options":{"2":"下","4":"左","6":"右","8":"上"}},"3":{"min":0,"max":3}}
		42: hints["0"] = {"min":0,"max":255}
		43: hints["0"] = {"options":{"0":"正常","1":"加算","2":"减算"}}
		44: hints["0/name"] = {"asset":"SE"}
	_param_dialog.title = Commands.ROUTE_NAMES[code]+" · 参数"
	_param_form.configure(_route.list[index].get("parameters", []),_PARAMETER_LABELS.get(code,[]),_documents,hints)
	_param_dialog.popup_centered(Vector2i(680,380))

func _accept_parameters() -> void:
	var parameters: Array = _param_form.draft()
	var reason = Commands.Catalog.route_reason(int(_route.list[_param_index].code),parameters)
	if not reason.is_empty(): _message.text = reason; return
	_route.list[_param_index].parameters = parameters
	_param_dialog.hide(); _refresh(_param_index)

func _copy_selected() -> void:
	var index = _selected()
	if not _editable(index): return
	_route.list.insert(index+1,_route.list[index].duplicate(true)); _refresh(index+1)

func _delete_selected() -> void:
	var index = _selected()
	if not _editable(index): return
	_route.list.remove_at(index); _refresh(mini(index,_route.list.size()-1))

func _move_selected(direction: int) -> void:
	var index = _selected(); var target = index+direction
	if not _editable(index) or target < 0 or target >= _route.list.size()-1: return
	var old: Variant = _route.list[target]; _route.list[target] = _route.list[index]; _route.list[index] = old
	_refresh(target)
