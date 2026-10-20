## 职责：编辑原 Table 类型的维度与单元数据，保留其整数布局。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/04_Database/Editor_TableDialog.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func open(value: Dictionary, kind: String, documents: RefCounted = null) -> void
##     用途：打开页面、对话框或目标记录。
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 documents（RefCounted；默认值 null）：编辑器文档服务，持有独立草稿与保存接口。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   accepted(table: Dictionary)：用户确认了当前对话框草稿。
##     table：RM Table 的维度与整数单元数据。
##
## 接口说明结束。

@tool
extends ConfirmationDialog
signal accepted(table: Dictionary)
var _value: Dictionary
var _kind = ""
var _tree: Tree
var _page: SpinBox
var _slice: SpinBox
var _width: SpinBox
var _note: Label
var _building = false
var _documents: RefCounted
var _selection: Label
var _rank_legacy: Dictionary = {}


func open(value: Dictionary, kind: String, documents: RefCounted = null) -> void:
	_value = value.duplicate(true)
	_kind = kind
	_documents = documents
	if _tree == null:
		_build()
	title = "编辑表格 · " + str(preload("Editor_DatabaseSchema.gd").LABELS.get(kind, kind))
	_building = true
	_page.max_value = maxi(0, _rows() - 1)
	_page.value = 0
	_slice.max_value = maxi(0, int(_value.get("z_size", 1)) - 1)
	_slice.value = 0
	_width.max_value = 16 if kind == "cell_data" else 100000
	_width.value = int(_value.get("x_size", 0))
	_width.editable = kind != "parameters"
	_slice.get_parent().visible = true
	for control in [_slice, _width]:
		control.visible = kind not in ["parameters", "element_ranks", "state_ranks"]
	for index in [2, 4]:
		_slice.get_parent().get_child(index).visible = (
			kind not in ["parameters", "element_ranks", "state_ranks"]
		)
	_building = false
	_refresh()
	popup_centered(Vector2i(850, 580))


func _build() -> void:
	get_ok_button().text = "应用表格"
	confirmed.connect(func() -> void: accepted.emit(_value.duplicate(true)))
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 460)
	add_child(box)
	_note = Label.new()
	_note.custom_minimum_size.x = 760
	_note.size.x = 760
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	var bar = HBoxContainer.new()
	box.add_child(bar)
	for entry in [["起始行", 0], ["Z层", 1], ["X长度/单元数", 2]]:
		var label = Label.new()
		label.text = entry[0]
		bar.add_child(label)
		var spin = SpinBox.new()
		spin.min_value = 0
		spin.step = 1
		bar.add_child(spin)
		match entry[1]:
			0:
				_page = spin
				spin.value_changed.connect(
					func(_n: float) -> void:
						if not _building:
							_refresh()
				)
			1:
				_slice = spin
				spin.value_changed.connect(
					func(_n: float) -> void:
						if not _building:
							_refresh()
				)
			2:
				_width = spin
				spin.value_changed.connect(_resize)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tree)
	_tree.item_edited.connect(_edited)
	_tree.cell_selected.connect(_show_selection)
	_selection = Label.new()
	_selection.custom_minimum_size.x = 760
	_selection.size.x = 760
	_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_selection)


func _rows() -> int:
	return (
		int(_value.get("x_size", 0))
		if _kind == "cell_data" or int(_value.get("y_size", 1)) == 1
		else int(_value.get("y_size", 0))
	)


func _refresh() -> void:
	_tree.clear()
	_rank_legacy.clear()
	var root = _tree.create_item()
	var one = int(_value.y_size) == 1
	var transposed = _kind == "cell_data"
	var columns = 8 if transposed else 1 if one else int(_value.x_size)
	var ranked = _kind in ["element_ranks", "state_ranks"]
	_tree.columns = columns + 1
	_tree.set_column_title(
		0,
		"单元" if transposed else "等级" if _kind == "parameters" else "名称 / 编号" if ranked else "编号/行"
	)
	var names: Array = (
		["图案(-1隐藏)", "X（像素）", "Y（像素）", "缩放%", "旋转°", "镜像(0/1)", "不透明度", "混合(0…2)"]
		if transposed
		else (
			["最大HP", "最大SP", "力量", "灵巧", "速度", "魔力"]
			if _kind == "parameters"
			else ["有效度 A…F"] if ranked else []
		)
	)
	for c in columns:
		_tree.set_column_title(
			c + 1, str(names[c]) if c < names.size() else "数值" if one else "X=%d" % c
		)
		_tree.set_column_custom_minimum_width(c + 1, 80)
	var start = int(_page.value)
	var z = int(_slice.value)
	for row in range(start, mini(_rows(), start + 80)):
		var item = _tree.create_item(root)
		item.set_text(
			0,
			(
				_documents.reference_label(
					"elements" if _kind == "element_ranks" else "States", row
				)
				if ranked and _documents != null and row > 0
				else (
					"%d（保留）" % row
					if row == 0 and not transposed
					else str(row + 1 if transposed else row)
				)
			)
		)
		for c in columns:
			var index = (
				(
					row + c * int(_value.x_size)
					if transposed
					else row if one else c + row * int(_value.x_size)
				)
				+ z * int(_value.x_size) * int(_value.y_size)
			)
			item.set_metadata(c + 1, index)
			if ranked:
				var native = int(_value.values[index])
				var legacy = native < 1 or native > 6
				item.set_cell_mode(c + 1, TreeItem.CELL_MODE_RANGE)
				item.set_text(c + 1, "A,B,C,D,E,F" + (",原值 %d" % native if legacy else ""))
				item.set_range_config(c + 1, 0, 6 if legacy else 5, 1)
				item.set_range(c + 1, 6 if legacy else native - 1)
				if legacy:
					_rank_legacy[index] = native
			else:
				item.set_text(c + 1, str(int(_value.values[index])))
			item.set_editable(c + 1, not (row == 0 and not transposed))
			item.set_tooltip_text(
				c + 1,
				(
					"保留数据，不编辑"
					if row == 0 and not transposed
					else "%s · %s" % [item.get_text(0), _tree.get_column_title(c + 1)]
				)
			)
	_note.text = "双击数值编辑；每次显示80行。等级0/编号0为RM保留数据。"
	if _kind == "passages":
		_note.text += " 通行位：1禁止下、2禁止左、4禁止右、8禁止上，15全禁；64草丛、128柜台。按位相加。"
	if _kind == "cell_data":
		_note.text += " 图案从0开始；-1隐藏。参数保存为原RM的单元×8表格。"
	if ranked:
		_note.text = "按名称设置有效度：A=1、B=2、C=3、D=4、E=5、F=6。编号0保留。"
	_selection.text = "选择单元格查看所属等级/名称和参数。"


func _edited() -> void:
	var item = _tree.get_edited()
	var col = _tree.get_edited_column()
	if item != null and col > 0:
		var index = int(item.get_metadata(col))
		if _kind in ["element_ranks", "state_ranks"]:
			_value.values[index] = (
				_rank_legacy.get(index, 1)
				if int(item.get_range(col)) == 6
				else int(item.get_range(col)) + 1
			)
		elif (
			item.get_text(col).is_valid_int()
			and int(item.get_text(col)) >= -32768
			and int(item.get_text(col)) <= 32767
		):
			_value.values[index] = int(item.get_text(col))
		else:
			item.set_text(col, str(int(_value.values[index])))
			_selection.text = "请输入-32768…32767内的整数。"
			return
		_show_selection()


func _show_selection() -> void:
	var item = _tree.get_selected()
	var col = _tree.get_selected_column()
	if item != null and col > 0:
		_selection.text = (
			"%s · %s · 当前 %s"
			% [
				item.get_text(0),
				_tree.get_column_title(col),
				str(int(_value.values[int(item.get_metadata(col))]))
			]
		)


func _resize(n: float) -> void:
	if _building:
		return
	var old = _value.duplicate(true)
	var width = int(n)
	var values: Array = []
	values.resize(width * int(old.y_size) * int(old.z_size))
	values.fill(0)
	for z in int(old.z_size):
		for y in int(old.y_size):
			if _kind == "cell_data":
				for x in width:
					values[x + y * width + z * width * int(old.y_size)] = [
						-1, 0, 0, 100, 0, 0, 255, 0
					][y]
			for x in mini(width, int(old.x_size)):
				values[x + y * width + z * width * int(old.y_size)] = old.values[
					x + y * int(old.x_size) + z * int(old.x_size) * int(old.y_size)
				]
	_value.x_size = width
	_value.values = values
	_page.max_value = maxi(0, _rows() - 1)
	_refresh()
