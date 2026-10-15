extends Control
## Source 0177–0183/0202: owned RPG categories, recover targets and nine presets.
const Presets=preload("FlashItemPresets.gd")
const Actions=preload("FlashActions.gd")
const Service=preload("InventoryService.gd")
const Resources=preload("UIResources.gd")
const Cache=preload("RmxpCache.gd")
const Data=preload("RuntimeData.gd")
signal back_requested
signal common_event_requested
var page="flash_items"
var stage="category"
var categories: Array=[]
var category_index=0
var item_ids: Array=[]
var index=0
var target_index=0
var slot=0
var active_item=0
var notice=""
var _content: Control
var _category_buttons: Array[Button]=[]
var _item_buttons: Array[Button]=[]
var _preset_buttons: Array[Button]=[]
var _target_buttons: Array[Button]=[]
var _description: RichTextLabel

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Presets.normalize(RuntimeState)
	RuntimeState.state_changed.connect(refresh); resized.connect(refresh); refresh()

func selected_id() -> int:
	return int(item_ids[index]) if not item_ids.is_empty() else 0

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_category_buttons.clear(); _item_buttons.clear(); _preset_buttons.clear(); _target_buttons.clear()
	var groups: Dictionary={}
	# Source category/item scans ascending RPG item IDs; weapon/armor branches empty.
	for id in Data.database("Items").size():
		if id<=0 or RuntimeState.inventory_count("item",id)<=0: continue
		var name=Presets.category(Presets.native_item(id,RuntimeState))
		if not groups.has(name): groups[name]=[]
		groups[name].append(id)
	categories=groups.keys(); category_index=clampi(category_index,0,maxi(categories.size()-1,0)); item_ids=groups.get(categories[category_index],[]) if not categories.is_empty() else []; index=clampi(index,0,maxi(item_ids.size()-1,0))
	_label("物品资源",Rect2(16,12,size.x-32,32),22)
	for id in categories.size():
		var button=Button.new(); button.text=str(categories[id]); button.position=Vector2(16,64+id*36); button.size=Vector2(136,32); button.add_theme_font_override("font",Resources.font()); button.pressed.connect(func():category_index=id; index=0; stage="item"; refresh())
		if category_index==id: button.modulate=Color("a9ffe1")
		_content.add_child(button); _category_buttons.append(button)
	var list=ScrollContainer.new(); list.position=Vector2(168,64); list.size=Vector2(maxf(size.x-240,1),224); _content.add_child(list)
	var rows=VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_child(rows)
	for id in item_ids:
		var item=Presets.native_item(id,RuntimeState); var button=Button.new(); button.text="%s ×%d" % [str(item.get("name","")),RuntimeState.inventory_count("item",id)]; button.add_theme_font_override("font",Resources.font()); button.custom_minimum_size.y=34; button.icon=Cache.icon(str(item.get("icon_name",""))); button.pressed.connect(func():index=item_ids.find(id); stage="item"; activate())
		if not Service.item_reason(id).is_empty(): button.modulate=Color("888888")
		button.set_meta("normal_color",button.modulate); button.set_meta("item_id",id)
		if selected_id()==id and stage!="category": button.modulate=Color("a9ffe1")
		rows.add_child(button); _item_buttons.append(button)
	var item=Presets.native_item(active_item if stage=="target" else selected_id(),RuntimeState)
	var text=RichTextLabel.new(); text.position=Vector2(168,304); text.size=Vector2(maxf(size.x-240,1),maxf(size.y-412,1)); text.text=str(item.get("description","")).get_slice("@",0); text.add_theme_font_override("normal_font",Resources.font()); text.add_theme_font_size_override("normal_font_size",18); text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(text)
	_description=text
	var slots=Presets.slots(RuntimeState)
	for cell in 9:
		var item_id=int(slots[cell][0]); var button=Button.new(); button.text="%d\nx%d" % [cell+1,int(slots[cell][1])] if item_id>0 else str(cell+1); button.position=Vector2(size.x-60,56+cell*48); button.size=Vector2(48,44); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",12); button.icon=Cache.icon(str(Presets.native_item(item_id,RuntimeState).get("icon_name",""))) if item_id>0 else null
		button.pressed.connect(func():
			if stage=="preset": slot=cell; assign_preset())
		if stage=="preset" and slot==cell: button.modulate=Color("a9ffe1")
		_content.add_child(button); _preset_buttons.append(button)
	if stage=="target":
		target_index=clampi(target_index,0,maxi(RuntimeState.party.size()-1,0))
		for row in RuntimeState.party.size():
			var actor=RuntimeState.actor(int(RuntimeState.party[row])); var button=Button.new(); button.text="%s · HP %d / %d · SP %d / %d" % [actor.actor_name,actor.hp,actor.get_parameter("maxhp"),actor.sp,actor.get_parameter("maxsp")]; button.position=Vector2(168,360+row*48); button.size=Vector2(maxf(size.x-240,1),44); button.add_theme_font_override("font",Resources.font()); button.pressed.connect(func():target_index=row; activate())
			if row==target_index: button.modulate=Color("a9ffe1")
			_content.add_child(button); _target_buttons.append(button)
	_label(notice if not notice.is_empty() else "↑↓选择 · Enter使用 · A预设 · Esc返回",Rect2(16,size.y-64,size.x-32,40),16)
	queue_redraw()

func activate() -> void:
	if stage=="category": stage="item"; refresh(); return
	if stage=="preset": assign_preset(); return
	var id=active_item if stage=="target" else selected_id()
	if id<=0: return
	var result: Dictionary={}
	if stage=="target":
		if RuntimeState.party.is_empty(): return
		result=Actions.recover_item(RuntimeState,id,int(RuntimeState.party[target_index]))
		if result.ok and RuntimeState.inventory_count("item",id)==0: stage="item"; active_item=0
	else:
		var reason=Service.item_reason(id)
		if not reason.is_empty(): notice=reason; refresh(); return
		if int(Data.record("Items",id).get("occasion",3))==0: active_item=id; target_index=0; stage="target"; refresh(); return
		result=Actions.request_tool(RuntimeState,id)
		if result.ok: common_event_requested.emit(); return
	if not result.is_empty(): notice="物品已使用。" if result.ok else str(result.get("message",""))
	refresh()

func assign_preset() -> void:
	var result=Presets.set_slot(RuntimeState,slot+1,selected_id()); notice="物品预设已更新。" if result.ok else str(result.get("message","")); refresh()

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]:
		if stage=="category": back_requested.emit()
		else:
			stage="item" if stage in ["preset","target"] else "category"
			active_item=0; refresh()
	elif key==KEY_A and stage=="item" and selected_id()>0: stage="preset"; slot=0; refresh()
	elif key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		var step=-1 if key in [KEY_UP,KEY_LEFT] else 1
		if stage=="category" and not categories.is_empty():
			var next=posmod(category_index+step,categories.size())
			if next!=category_index: category_index=next; index=0; refresh()
			return
		elif stage=="item" and not item_ids.is_empty(): index=posmod(index+step,item_ids.size())
		elif stage=="target" and not RuntimeState.party.is_empty(): target_index=posmod(target_index+step,RuntimeState.party.size())
		elif stage=="preset": slot=posmod(slot+step,9)
		_paint_selection()
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()

func _paint_selection() -> void:
	for button in _item_buttons: button.modulate=Color("a9ffe1") if button.get_meta("item_id")==selected_id() and stage!="category" else button.get_meta("normal_color")
	for i in _preset_buttons.size(): _preset_buttons[i].modulate=Color("a9ffe1") if stage=="preset" and slot==i else Color.WHITE
	for i in _target_buttons.size(): _target_buttons[i].modulate=Color("a9ffe1") if target_index==i else Color.WHITE
	var item=Presets.native_item(active_item if stage=="target" else selected_id(),RuntimeState)
	_description.text=str(item.get("description","")).get_slice("@",0)

func _label(text: String,rect: Rect2,font_size: int) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(label)

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
