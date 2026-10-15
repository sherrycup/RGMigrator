extends Control
## Source 0207/0208/0209 and 0202: category, details, slots and configuration.
const Data=preload("RuntimeData.gd")
const Config=preload("FlashSkillConfig.gd")
const Actions=preload("FlashActions.gd")
const Resources=preload("UIResources.gd")
const Cache=preload("RmxpCache.gd")
signal back_requested
var page="flash_skills"
var skill_ids: Array=[]
var index=0
var easy=false
var notice=""
var _content: Control
var _topic: Control
var _buttons: Array[Button]=[]
var _detail_nodes: Dictionary={}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh); refresh()
	_topic=preload("FlashTopic.gd").new(); _topic.base_position=Vector2(maxf(0,size.x-144),8); add_child(_topic)

func actor() -> RefCounted:
	return RuntimeState.actor(int(RuntimeState.party[0])) if not RuntimeState.party.is_empty() else null

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_buttons.clear(); _detail_nodes.clear()
	var value=actor(); skill_ids.clear()
	if value==null: _label("队伍中没有角色",Rect2(16,16,608,32)); return
	var groups: Array=[[],[],[],[]]
	for id in value.get_skill_ids():
		var group=Config.category(Data.record("Skills",id))
		if group>=0: groups[group].append(id)
	for group in groups: skill_ids.append_array(group)
	index=clampi(index,0,maxi(skill_ids.size()-1,0))
	_label(value.actor_name+" · 技能配置",Rect2(16,12,size.x-32,32),22)
	var list=ScrollContainer.new(); list.position=Vector2(16,56); list.size=Vector2(176,maxf(size.y-144,1)); _content.add_child(list)
	var rows=VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_child(rows)
	for group_index in 4:
		var heading=Label.new(); heading.text=["被动技能","追击技能","主动技能","效果技能"][group_index]; heading.add_theme_font_override("font",Resources.font()); heading.add_theme_color_override("font_color",Color("91d6c2")); rows.add_child(heading)
		for id in groups[group_index]:
			var button=Button.new(); button.text=str(Data.record("Skills",id).get("name","")); button.custom_minimum_size.y=32; button.add_theme_font_override("font",Resources.font())
			button.add_theme_stylebox_override("normal",preload("FlashBitmap.gd").skill_style(Vector2i(172,32),1 if group_index in [0,1] else 2))
			button.pressed.connect(func():index=skill_ids.find(id); refresh())
			if not Config.available(RuntimeState.custom_data,value,id): button.modulate=Color("888888")
			button.set_meta("normal_color",button.modulate); button.set_meta("skill_id",id)
			if id==selected_id(): button.modulate=Color("b4ffe8")
			rows.add_child(button); _buttons.append(button)
	if skill_ids.is_empty(): _label("尚无可配置技能",Rect2(208,64,size.x-224,32))
	else: _details(value,selected_id())
	_label("↑↓选择 · Enter配置/取消 · 1—8回合 · Tab角色 · A说明",Rect2(16,size.y-74,size.x-32,26),14)
	_label("W+1—8保存主战组 · E+1—8保存援护组 · Esc返回",Rect2(16,size.y-48,size.x-32,24),14)
	if not notice.is_empty(): _label(notice,Rect2(208,size.y-112,size.x-224,30),15,Color("ffe7b0"))
	queue_redraw()
	if _topic!=null: _topic.base_position=Vector2(maxf(0,size.x-144),8); move_child(_topic,get_child_count()-1)

func selected_id() -> int:
	return int(skill_ids[index]) if not skill_ids.is_empty() else 0

func _details(value: RefCounted,id: int) -> void:
	var skill=Data.record("Skills",id); var rules=RuntimeState.custom_data.gameplay().rules
	if _detail_nodes.is_empty():
		for row in [["name",Rect2(208,56,size.x-224,32),24],["stats",Rect2(296,96,size.x-312,84),16],["selected",Rect2(208,size.y-160,size.x-224,30),16],["slots",Rect2(208,size.y-134,size.x-224,24),13]]:
			var label=Label.new(); label.position=row[1].position; label.size=row[1].size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",row[2]); label.add_theme_color_override("font_color",Color.WHITE); _content.add_child(label); _detail_nodes[row[0]]=label
		var card=TextureRect.new(); card.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; card.position=Vector2(208,96); card.size=Vector2(80,88); _content.add_child(card); _detail_nodes.card=card
		var view=TextureRect.new(); view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; view.position=Vector2(212,98); view.size=Vector2(72,84); view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _content.add_child(view); _detail_nodes.icon=view
		var text=RichTextLabel.new(); text.position=Vector2(208,192); text.size=Vector2(size.x-224,maxf(size.y-360,48)); text.add_theme_font_override("normal_font",Resources.font()); text.add_theme_font_size_override("normal_font_size",16); text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(text); _detail_nodes.description=text
	_detail_nodes.name.text=str(skill.name)
	_detail_nodes.card.texture=preload("FlashBitmap.gd").skill_style(Vector2i(80,88),1 if Config.category(skill) in [0,1] else 2).texture
	var icon=Cache.skills(str(skill.name)+".png")
	if icon==null and not str(skill.get("icon_name","")).is_empty(): icon=Cache.icon(str(skill.icon_name))
	_detail_nodes.icon.texture=icon
	var elements: Array=skill.get("element_set",[]); var tag=int(elements[-1]) if not elements.is_empty() else 0
	_detail_nodes.stats.text="%s\n消耗 %s SP\n硬直 %s" % [{13:"主战主动",14:"主战被动",15:"援护主动",16:"援护被动"}.get(tag,""),str(skill.get("sp_cost",0)),str(skill.get("power",0))]
	var description: Variant=rules.storage.get("skill_easy_description" if easy else "skill_description",{}).get(str(id),skill.get("description",""))
	_detail_nodes.description.text=("\n".join(description) if description is Array else str(description)).replace("\\n","\n")
	var selected=value.project_skill_slot(id); _detail_nodes.selected.text="已配置："+("未配置" if not selected[0] else "被动" if selected[1]==-1 else "追击" if selected[1]==-2 else "第%d回合" % int(selected[1]))
	var slots: Array=[]
	for turn in range(1,9):
		var configured=int(value.project_fields.equip_skills.get(str(turn),0)); slots.append("%d:%s" % [turn,str(Data.record("Skills",configured).get("name","—")) if configured>0 else "—"])
	_detail_nodes.slots.text="  ".join(slots)

func _label(text: String,rect: Rect2,font_size: int=17,color: Color=Color.WHITE) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(label)

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: back_requested.emit(); return
	if actor()==null: return
	if key in [KEY_UP,KEY_DOWN] and not skill_ids.is_empty():
		index=posmod(index+(-1 if key==KEY_UP else 1),skill_ids.size())
		for button in _buttons: button.modulate=Color("b4ffe8") if button.get_meta("skill_id")==selected_id() else button.get_meta("normal_color")
		_details(actor(),selected_id()); return
	if key==KEY_A:
		easy=not easy
		if selected_id()>0: _details(actor(),selected_id())
		return
	var result: Dictionary={}
	if key==KEY_TAB: result=Config.switch_page_actor(RuntimeState); index=0
	elif key>=KEY_1 and key<=KEY_8:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_E):
			var side="atk" if Input.is_key_pressed(KEY_W) else "sup"; var ids=RuntimeState.custom_data.gameplay().role_actor_ids(); var actor_id=int(ids[0 if side=="atk" else 1])
			result=Actions.save_skill_set(RuntimeState,actor_id,key-KEY_1,side) if actor_id>0 else {"ok":false,"message":"队伍中不存在援护角色。"}
			notice="已保存技能组 %d。" % (key-KEY_1+1) if result.ok else str(result.get("message",""))
		else: result=Config.set_skill(RuntimeState,actor().id,selected_id(),key-KEY_1+1)
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE] and selected_id()>0: result=Config.set_skill(RuntimeState,actor().id,selected_id())
	if not result.is_empty() and not result.ok: notice=str(result.get("message",""))
	refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
	draw_rect(Rect2(200,48,maxf(size.x-208,1),maxf(size.y-144,1)),Color("172c32"))
