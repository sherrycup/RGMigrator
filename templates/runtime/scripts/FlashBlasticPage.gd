extends Control
## Source 0215–0221 and 0202: the same circle/slot/crystal transaction as .45.
const Blastic=preload("FlashBlastic.gd")
const Actions=preload("FlashActions.gd")
const Data=preload("RuntimeData.gd")
const Resources=preload("UIResources.gd")
const Cache=preload("RmxpCache.gd")
const Presets=preload("FlashItemPresets.gd")
const CRYSTAL_NAME="结晶回路" # 0221 source category, separate from Game_Item wrappers.
signal back_requested
var page="flash_blastic"
var blastic_id=0
var slot=0
var choosing=false
var candidates: Array=[]
var candidate_index=0
var notice=""
var value: Dictionary={}
var preview_elements: Array=[]
var preview_rows: Array=[]
var crystal_description=""
var echo_rows: Array=[]
var _echo_scroll: ScrollContainer
var _content: Control
var _slot_buttons: Array[Button]=[]
var _description_label: Label

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RuntimeState.state_changed.connect(refresh); resized.connect(refresh); refresh()

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_slot_buttons.clear()
	if RuntimeState.party.is_empty(): _label("队伍中没有角色",Rect2(16,16,608,32)); return
	var actor=RuntimeState.actor(int(RuntimeState.party[0]))
	blastic_id=int(actor.project_fields.blastic) if actor.project_fields.blastic!=null else 0
	value=Blastic.record(RuntimeState.custom_data,blastic_id)
	_label(actor.actor_name+" · 神秘圆盘",Rect2(16,12,size.x-32,32),22)
	if value.is_empty(): _label(RuntimeState.custom_data.failure,Rect2(16,64,size.x-32,96)); return
	var width=value.pos[0].size(); var total=width+value.pos[1].size(); slot=clampi(slot,0,maxi(total-1,0))
	var circle=int(slot/width); var column=slot%width
	var rows=VBoxContainer.new(); rows.position=Vector2(16,56); rows.size=Vector2(224,288); _content.add_child(rows)
	for chain in 2:
		_label("主战链" if chain==0 else "援护链",Rect2(16,56+chain*(width+1)*28,216,26),17,Color("9ce3d0"))
		for cell in value.pos[chain].size():
			var index=chain*width+cell; var crystal: Variant=value.equip[chain][cell]
			var restriction=int(value.restrict[chain][cell]); var names=["全","地","水","火","风","无"]
			var label="%s %d · %s" % ["外圈" if chain==0 else "内圈",cell+1,"未解锁" if not value.lock[chain][cell] else "可装入"+names[clampi(restriction,0,5)]+"属性" if crystal==null else str(Presets.native_item(int(crystal),RuntimeState).get("name",""))]
			var button=Button.new(); button.text=label; button.position=Vector2(16,84+chain*(width+1)*28+cell*28); button.size=Vector2(224,26); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",15)
			button.pressed.connect(func():slot=index; choosing=value.lock[chain][cell]; candidate_index=0; refresh())
			if slot==index: button.modulate=Color("a9ffe1")
			_content.add_child(button); _slot_buttons.append(button)
	candidates=[0]
	var storage: Dictionary=RuntimeState.custom_data.gameplay().rules.storage
	for key in storage.crystal:
		var native=Presets.native_item(int(key),RuntimeState)
		# Source item110 has a valid Storage.crystal and crystal name but omitted
		# its @category. Repair only that verified empty record (no formula change).
		var crystal_category=Presets.category(native)==CRYSTAL_NAME or int(key)==110 and str(native.get("description","")).is_empty() and str(native.get("name",""))=="结晶回路(刃牙)"
		if int(key)>=71 and RuntimeState.inventory_count("item",int(key))>0 and crystal_category: candidates.append(int(key))
	candidates.sort_custom(func(a,b):return a<b if a==0 or b==0 else int(storage.crystal[str(a)][0])<int(storage.crystal[str(b)][0]) if storage.crystal[str(a)][0]!=storage.crystal[str(b)][0] else a<b)
	candidate_index=clampi(candidate_index,0,maxi(candidates.size()-1,0))
	preview_elements=value.element[circle].duplicate()
	if choosing:
		var old: Variant=value.equip[circle][column]; var next=int(candidates[candidate_index])
		for i in 5:
			if old!=null: preview_elements[i]-=int(storage.crystal[str(old)][2][i])
			if next>0: preview_elements[i]+=int(storage.crystal[str(next)][2][i])
		var list=ScrollContainer.new(); list.position=Vector2(16,416); list.size=Vector2(224,maxf(size.y-484,1)); _content.add_child(list)
		var choices=VBoxContainer.new(); choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_child(choices)
		for i in candidates.size():
			var id=int(candidates[i]); var button=Button.new(); button.text="卸下" if id==0 else "%s ×%d" % [str(Presets.native_item(id,RuntimeState).get("name","")),RuntimeState.inventory_count("item",id)]; button.add_theme_font_override("font",Resources.font()); button.custom_minimum_size.y=28
			button.pressed.connect(func():candidate_index=i; commit_choice())
			if i==candidate_index: button.modulate=Color("a9ffe1")
			if not candidate_allowed(id): button.modulate=Color("666666")
			choices.add_child(button)
	preview_rows=value.element.duplicate(true); preview_rows[circle]=preview_elements.duplicate()
	var selected: Variant=int(candidates[candidate_index]) if choosing else value.equip[circle][column]
	crystal_description=str(Presets.native_item(int(selected),RuntimeState).get("description","")).get_slice("@",0) if selected!=null and int(selected)>0 else ""
	_description_label=_label(crystal_description,Rect2(16,352,224,60),14)
	_label("两条链元素合计"+("（预览）" if choosing else ""),Rect2(256,454,size.x-272,26),16,Color("9ce3d0"))
	for chain in 2:
		_label("主" if chain==0 else "援",Rect2(256,482+chain*28,28,26),15)
		for i in 5:
			var change=int(preview_rows[chain][i])-int(value.element[chain][i]); var color=Color("ff6666") if change<0 else Color("fff080") if change>0 else Color.WHITE
			var labels=["地","水","火","风","时"]; var width_cell=(size.x-300)/5
			_label(labels[i]+str(preview_rows[chain][i]),Rect2(284+i*width_cell,482+chain*28,width_cell,26),14,color)
	echo_rows=Blastic.echoes(RuntimeState.custom_data,preview_elements,choosing)
	_echo_scroll=ScrollContainer.new(); _echo_scroll.position=Vector2(256,542); _echo_scroll.size=Vector2(maxf(size.x-272,1),maxf(size.y-596,1)); _content.add_child(_echo_scroll)
	var echo_list=VBoxContainer.new(); echo_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _echo_scroll.add_child(echo_list)
	for echo in echo_rows:
		var row=RichTextLabel.new(); row.fit_content=true; row.scroll_active=false; row.custom_minimum_size.x=maxf(size.x-292,1); row.add_theme_font_override("normal_font",Resources.font()); row.add_theme_font_size_override("normal_font_size",14)
		var requirements: Array[String]=[]
		for i in 5:
			if echo.required[i]>0: requirements.append(["地","水","火","风","时"][i]+"%d/%d" % [preview_elements[i],echo.required[i]])
		row.text=str(echo.name)+("　已满足" if echo.active else "　尚缺%d" % int(echo.distance))+"\n"+"  ".join(requirements)+"\n角色受到的所有伤害减少0%" # 0219 hardcoded placeholder, no invented formula.
		if not echo.active: row.modulate=Color("fff080")
		echo_list.add_child(row)
	_label(notice if not notice.is_empty() else "↑↓孔位/结晶 · Enter选择/装配 · Esc返回",Rect2(16,size.y-48,size.x-32,32),15,Color("ffe7b0"))
	queue_redraw()

func commit_choice() -> Dictionary:
	var result=Actions.exchange_crystal(RuntimeState,blastic_id,slot,int(candidates[candidate_index]))
	notice="回路已更新。" if result.ok else str(result.get("message",""))
	if result.ok: choosing=false
	refresh(); return result

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]:
		if choosing: choosing=false; refresh()
		else: back_requested.emit()
		return
	if value.is_empty(): return
	if key in [KEY_UP,KEY_DOWN]:
		var step=-1 if key==KEY_UP else 1
		if choosing: candidate_index=posmod(candidate_index+step,candidates.size())
		else:
			var width=value.pos[0].size(); var old_circle=int(slot/width)
			slot=posmod(slot+step,width+value.pos[1].size())
			if int(slot/width)==old_circle:
				for i in _slot_buttons.size(): _slot_buttons[i].modulate=Color("a9ffe1") if i==slot else Color.WHITE
				var crystal: Variant=value.equip[old_circle][slot%width]
				crystal_description=str(Presets.native_item(int(crystal),RuntimeState).get("description","")).get_slice("@",0) if crystal!=null and int(crystal)>0 else ""
				_description_label.text=crystal_description; queue_redraw(); return
		refresh()
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]:
		if choosing: commit_choice()
		else:
			var width=value.pos[0].size()
			if value.lock[int(slot/width)][slot%width]: choosing=true; candidate_index=0; refresh()
			else: notice="该孔位尚未解锁。"; refresh()
	elif key in [KEY_PAGEUP,KEY_PAGEDOWN] and _echo_scroll!=null: _echo_scroll.scroll_vertical+=int(_echo_scroll.size.y)*(1 if key==KEY_PAGEDOWN else -1)

func candidate_allowed(id: int) -> bool:
	if value.is_empty(): return false
	var width=value.pos[0].size(); var circle=int(slot/width); var column=slot%width
	if not value.lock[circle][column]: return false
	if id==0: return true
	var table: Dictionary=RuntimeState.custom_data.gameplay().rules.storage.crystal
	if not table.has(str(id)): return false
	var restriction=int(value.restrict[circle][column])
	if restriction!=0 and restriction!=int(table[str(id)][0]): return false
	for chain in 2:
		for cell in value.equip[chain].size():
			if chain==circle and cell==column: continue
			var equipped: Variant=value.equip[chain][cell]
			if equipped!=null and table[str(equipped)][1]==table[str(id)][1]: return false
	return true

func _label(text: String,rect: Rect2,font_size: int=17,color: Color=Color.WHITE) -> Label:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(label)
	return label

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
	if value.is_empty(): return
	var scale=minf(maxf(size.x-256,1)/480.0,0.8); var origin=Vector2(248,56)
	var plate=Cache.picture("Blastic/地之魔盘.png")
	if plate!=null: draw_texture_rect(plate,Rect2(origin,Vector2(480,480)*scale),false)
	var atlas=Cache.picture("Blastic/slot_items.png"); var outer=value.pos[0].size()
	for circle in 2:
		for column in value.pos[circle].size():
			var location: Array=value.pos[circle][column]; var pos=origin+Vector2(location[0],location[1])*scale
			var equipped: Variant=value.equip[circle][column]; var index=0
			if value.lock[circle][column] and equipped!=null: index=int(RuntimeState.custom_data.gameplay().rules.storage.crystal[str(equipped)][0])
			if atlas!=null and (not value.lock[circle][column] or equipped!=null): draw_texture_rect_region(atlas,Rect2(pos-Vector2(16,16)*scale,Vector2(32,32)*scale),Rect2(index*32,0,32,32))
			else: draw_circle(pos,12*scale,Color("53796d"))
			if slot==circle*outer+column: draw_arc(pos,20*scale,0,TAU,48,Color("fff0a6"),2,true)
