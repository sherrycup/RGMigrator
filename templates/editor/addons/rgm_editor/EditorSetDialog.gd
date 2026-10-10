@tool
extends ConfirmationDialog
signal accepted(ids: Array)
var _ids: Array=[]
var _choices: Array=[]
var _ordered=false
var _tree: Tree
var _search: LineEdit
var _selected: ItemList
var _order_bar: HBoxContainer
var _count: Label

func open(ids: Array, choices: Array, ordered: bool = false, caption: String = "集合") -> void:
	_ids=ids.duplicate(true); _choices=choices.duplicate(true); _ordered=ordered
	if _tree==null: _build()
	title="选择%s（勾选多个）" % caption; _search.text=""; _order_bar.visible=ordered
	_refresh(); popup_centered(Vector2i(680,560))

func _build() -> void:
	get_ok_button().text="应用选择"; confirmed.connect(func() -> void: accepted.emit(_ids.duplicate(true)))
	var box=VBoxContainer.new(); box.custom_minimum_size=Vector2(580,430); add_child(box)
	_search=LineEdit.new(); _search.placeholder_text="按编号或名称筛选"; box.add_child(_search); _search.text_changed.connect(func(_text: String) -> void: _refresh())
	_count=Label.new(); _count.custom_minimum_size.x=580; _count.size.x=580; _count.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(_count)
	_tree=Tree.new(); _tree.hide_root=true; _tree.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(_tree); _tree.item_edited.connect(_edited)
	_order_bar=HBoxContainer.new(); box.add_child(_order_bar)
	_selected=ItemList.new(); _selected.custom_minimum_size=Vector2(380,100); _selected.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _order_bar.add_child(_selected)
	for direction in [-1,1]:
		var button=Button.new(); button.text="上移" if direction<0 else "下移"; _order_bar.add_child(button); button.pressed.connect(_move.bind(direction))

func _refresh() -> void:
	_count.text="已选择 %d 项%s" % [_ids.size()," · 下方顺序决定初始队伍顺序" if _ordered else ""]
	_tree.clear(); var root=_tree.create_item(); var choices=_choices.duplicate(true)
	for id in _ids:
		if not choices.any(func(c: Dictionary) -> bool: return int(c.id)==int(id)): choices.append({"id":id,"name":"%04d [原工程缺少定义]" % int(id)})
	for choice in choices:
		if not _search.text.is_empty() and not str(choice.name).to_lower().contains(_search.text.to_lower()): continue
		var item=_tree.create_item(root); item.set_cell_mode(0,TreeItem.CELL_MODE_CHECK); item.set_editable(0,true); item.set_text(0,str(choice.name)); item.set_metadata(0,int(choice.id)); item.set_checked(0,_ids.any(func(id: Variant) -> bool: return int(id)==int(choice.id)))
	_selected.clear()
	for id in _ids:
		var found=choices.filter(func(c: Dictionary) -> bool: return int(c.id)==int(id))
		_selected.add_item(str(found[0].name) if not found.is_empty() else str(id))

func _edited() -> void:
	var item=_tree.get_edited(); var id=int(item.get_metadata(0))
	if item.is_checked(0): _ids.append(id)
	else: _ids=_ids.filter(func(n: Variant) -> bool: return int(n)!=id)
	_refresh()

func _move(direction: int) -> void:
	var indices=_selected.get_selected_items()
	if indices.is_empty(): return
	var i=int(indices[0]); var next=i+direction
	if next<0 or next>=_ids.size(): return
	var old: Variant=_ids[i]; _ids[i]=_ids[next]; _ids[next]=old; _refresh(); _selected.select(next)
