extends Control
## 0231–0240/0202: actual map inspection and shared ordinary battle preview.
signal close_requested
const Resources=preload("UIResources.gd")
const Cache=preload("RmxpCache.gd")
var page="flash_sight"
var game: Node
var model: RefCounted
var snapshot: Dictionary={}
var _content: Control
var _detail: RichTextLabel
var _action_scroll: ScrollContainer
var _hp_label: Label
var _after_hp_label: Label
var _hp_clock=0.0
var _marks: Node2D
class Marks extends Node2D:
	var page_ref: WeakRef
	func _draw() -> void:
		var value=page_ref.get_ref()
		if value!=null: value.draw_marks(self)

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game==null: game=RuntimeState.game()
	if game==null: RuntimeState.report_diagnostic("灵视缺少当前地图。"); return
	model=preload("FlashSightModel.gd").new(RuntimeState,game.event_map())
	_marks=Marks.new(); _marks.page_ref=weakref(self); game.event_map().ensure_character_layer().add_child(_marks); _marks.get_parent().move_child(_marks,0)
	RuntimeState.state_changed.connect(refresh); resized.connect(refresh); refresh()

func refresh() -> void:
	if model==null or not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content); _hp_label=null; _after_hp_label=null; _detail=null; _action_scroll=null
	var atlas=Cache.picture("Causal/focus.png"); var icons=[0,1,2,4]
	for id in 4:
		var button=Button.new(); button.position=Vector2(16+id*52,12); button.size=Vector2(48,64); button.text=model.FOCUS_NAMES[id]; button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",13)
		if atlas!=null:
			var texture=AtlasTexture.new(); texture.atlas=atlas; texture.region=Rect2(icons[id]*32,0,32,32); button.icon=texture; button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER; button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		button.pressed.connect(func():model.set_focus(id); refresh())
		if model.focus==id: button.modulate=Color("a9ffe0")
		_content.add_child(button)
	if model.stage=="list": _draw_list()
	else:
		snapshot=model.enemy_snapshot()
		if not snapshot.is_empty():
			if model.stage=="actions": _draw_actions()
			else: _draw_enemy()
		elif model.description_visible:
			var text=model.description()
			if not text.is_empty(): _text_panel(text,Rect2(_near_tile(Vector2(256,120)),Vector2(256,120)))
	if model.focus==3: _label("BUFF 聚焦",Rect2(232,16,180,30),18)
	_label("A 聚焦 · 方向键移动 · Enter选择 · D行动 · Esc返回",Rect2(16,size.y-40,size.x-32,32),14)
	if not model.failure.is_empty(): _label(model.failure,Rect2(16,size.y-72,size.x-32,28),14,Color("ff7f7f"))
	if _marks!=null: _marks.queue_redraw()
	queue_redraw()

func handle_key(key: int) -> void:
	if model==null: return
	if key in [KEY_ESCAPE,KEY_X]:
		if model.stage in ["skills","actions"]: model.stage="targets" if model.focus in [1,2] else "map"
		elif model.stage=="targets": model.stage="list"; model.cursor=Vector2i(RuntimeState.player_x,RuntimeState.player_y)
		else: close_requested.emit(); return
	elif key==KEY_A: model.set_focus(model.focus+1)
	elif model.stage=="skills":
		if key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			var target=model.skill_index+({KEY_LEFT:-1,KEY_RIGHT:1,KEY_UP:-3,KEY_DOWN:3}[key])
			if target>=0 and target<snapshot.get("skills",[]).size(): model.skill_index=target
		elif key in [KEY_Q,KEY_E] and _detail!=null:
			var bar=_detail.get_v_scroll_bar(); bar.value+=(1 if key==KEY_E else -1)*bar.page; return
	elif model.stage=="actions":
		if key in [KEY_UP,KEY_DOWN] and _action_scroll!=null:
			_action_scroll.scroll_vertical+=(1 if key==KEY_DOWN else -1)*6; _action_scroll.queue_redraw(); return
	elif model.stage=="list":
		if key in [KEY_LEFT,KEY_RIGHT] and not model.groups.is_empty(): model.list_index=posmod(model.list_index+(1 if key==KEY_RIGHT else -1),model.groups.size()); model.update_group()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_Z]: model.select_group()
	else:
		if key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: model.move_cursor({KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT}[key],size)
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_Z] and not snapshot.is_empty() and not snapshot.skills.is_empty(): model.stage="skills"
		elif key==KEY_D:
			if not snapshot.is_empty(): model.stage="actions"
			else: model.description_visible=not model.description_visible
	refresh()

func draw_marks(target: Node2D) -> void:
	if model==null: return
	for event in model.events():
		if event.id in model.focused_ids:
			var rect=Rect2(Vector2(event.cell)*32,Vector2(32,32)); target.draw_rect(rect,Color8(0,224,72,128)); target.draw_rect(rect,Color8(112,255,136,224),false,2)
	var color=Color8(200,200,200,128); var event=model.event_at_cursor()
	if model.cursor==Vector2i(RuntimeState.player_x,RuntimeState.player_y): color=Color8(50,179,240,192)
	elif not event.is_empty():
		if event.name.contains("怪物"): color=Color8(255,0,0,160)
		elif event.name.contains("物品"): color=Color8(0,255,0,160)
		elif event.name.contains("门"): color=Color8(255,255,0,160)
	if model.focus in [1,2]: color=Color8(255,0,0,160)
	var rect=Rect2(Vector2(model.cursor)*32,Vector2(32,32)); target.draw_rect(rect,color); target.draw_rect(rect,Color.WHITE,false,2)

func _draw_list() -> void:
	var panel=_panel(Rect2(16,92,maxf(1,size.x-32),104)); var scroll=ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.offset_left=8; scroll.offset_top=8; scroll.offset_right=-8; scroll.offset_bottom=-8; panel.add_child(scroll)
	var row=HBoxContainer.new(); scroll.add_child(row)
	if model.groups.is_empty(): _label("当前地图不存在敌人",Rect2(32,120,size.x-64,32),18)
	for id in model.groups.size():
		var group: Dictionary=model.groups[id]; var button=Button.new(); button.text=str(group.name)+"\nx "+str(group.event_ids.size()); button.custom_minimum_size=Vector2(100,80); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",16)
		button.pressed.connect(func():model.list_index=id; model.update_group(); model.select_group(); refresh())
		if group.has("node"):
			var node: Node=group.node; var texture=Cache.character(node._name)
			if texture!=null:
				var icon=AtlasTexture.new(); icon.atlas=texture; icon.region=Rect2(0,(node.motion.direction/2-1)*texture.get_height()/4.0,texture.get_width()/4.0,texture.get_height()/4.0); button.icon=icon; button.expand_icon=true
		if id==model.list_index: button.modulate=Color("a9ffe0")
		if group.event_ids.is_empty(): button.modulate=Color("666666")
		row.add_child(button)

func _draw_enemy() -> void:
	var count=snapshot.skills.size(); var rows=mini(3,int(ceil(float(count)/3)))
	var height=238 if rows<=1 else 284 if rows==2 else 330
	var origin=_near_tile(Vector2(280,height)); _panel(Rect2(origin,Vector2(280,height)))
	_label(str(snapshot.fields.get("name","")).get_slice(":",0),Rect2(origin+Vector2(12,6),Vector2(256,26)),20)
	var attr: Dictionary=snapshot.attributes; var result: Dictionary=snapshot.result
	_hp_label=_label("",Rect2(origin+Vector2(12,34),Vector2(256,28)),16)
	_after_hp_label=_label("",Rect2(origin+Vector2(12,34),Vector2(256,28)),16,preload("FlashPalette.gd").color(2)); _update_hp()
	_label("攻击 %d    防御 %d\n速度 %d    魔攻 %d\n回合 %d    经验 %d    耐心 %d" % [int(attr.attack),int(attr.defense),int(attr.speed),int(attr.magic_attack),int(result.main_turns),int(snapshot.fields.get("exp",0)),int(snapshot.enemy.patience)],Rect2(origin+Vector2(12,66),Vector2(256,72)),16)
	var drops: Array=snapshot.drops if snapshot.drops is Array else [5,0,0,0,0]; var atlas=Cache.picture("Causal/耀晶石.png"); var drop_index=0
	for id in mini(5,drops.size()):
		if drops[id]<=0: continue
		if drop_index>=4: break
		var rect=Rect2(origin+Vector2(12+drop_index*60,140),Vector2(16,16))
		if atlas!=null:
			var icon=TextureRect.new(); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; var texture=AtlasTexture.new(); texture.atlas=atlas; texture.region=Rect2(id*16,0,16,16); icon.texture=texture; icon.position=rect.position; icon.size=rect.size; _content.add_child(icon)
		_label(str(maxi(0,int(drops[id]))),Rect2(rect.position+Vector2(18,-2),Vector2(40,20)),14); drop_index+=1
	var page_index=int(model.skill_index/9); var visible: Array=snapshot.skills.slice(page_index*9,page_index*9+9)
	for id in visible.size():
		var info=model.skill_presentation(visible[id],snapshot.skill_set)
		var button=Button.new(); button.position=origin+Vector2(12+id%3*84,164+int(id/3)*46); button.size=Vector2(80,38); button.text=info.name+("\n"+info.origin if not info.origin.is_empty() else ""); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",13); button.add_theme_color_override("font_color",info.color)
		button.add_theme_stylebox_override("normal",preload("FlashBitmap.gd").skill_style(Vector2i(80,38),3,false))
		button.pressed.connect(func():model.skill_index=page_index*9+id; model.stage="skills"; refresh())
		if model.stage=="skills" and model.skill_index==page_index*9+id: button.modulate=Color("a9ffe0")
		_content.add_child(button)
	_label("技能 %d/%d" % [page_index+1,maxi(1,int(ceil(float(count)/9)))],Rect2(origin+Vector2(12,height-28),Vector2(256,20)),13)
	if model.stage=="skills" and not snapshot.skills.is_empty():
		var info=model.skill_presentation(snapshot.skills[clampi(model.skill_index,0,count-1)],snapshot.skill_set)
		var turn="回合: ——" if info.type in ["rage","passive"] else "回合: 通常" if info.turn==0 and info.period==1 else "行动: 第%d次" % info.turn
		var stiff="僵直: ——" if info.type in ["rage","passive"] or info.stiffness==0 else "僵直: %d" % info.stiffness
		var x=origin.x+288 if origin.x+480<=size.x else origin.x-200; var y=clampf(origin.y,88,maxf(88,size.y-350))
		_detail=_text_panel(info.name+"\n"+turn+"\n"+stiff+"\n\n"+info.description+"\n\nQ/E 滚动详情",Rect2(clampf(x,8,maxf(8,size.x-200)),y,192,280))

func _draw_actions() -> void:
	var result: Dictionary=snapshot.result
	var panel=_panel(Rect2(16,88,320,size.y-144)); _action_scroll=preload("FlashActionOrder.gd").new(); _action_scroll.rows=snapshot.timeline
	for name in ["actor_1","actor_2","enemy_1"]:
		var actor_id=int(result.main_actor_id if name=="actor_1" else result.support_actor_id if name=="actor_2" else 0)
		if actor_id>0:
			var actor=RuntimeState.actor(actor_id); _action_scroll.sprites[name]={"name":actor.character_name,"hue":actor.character_hue,"direction":2}
		elif name=="enemy_1": _action_scroll.sprites[name]={"name":snapshot.event.node._name,"hue":snapshot.event.node._hue,"direction":snapshot.event.node.motion.direction}
	_action_scroll.position=Vector2(8,8); _action_scroll.size=panel.size-Vector2(16,16); panel.add_child(_action_scroll)

func _near_tile(dimensions: Vector2) -> Vector2:
	var transform=game.event_map().get_global_transform_with_canvas(); var point=transform*(Vector2(model.cursor)*32)
	var candidates=[point+Vector2(40,16-dimensions.y/2),point+Vector2(-dimensions.x-8,16-dimensions.y/2),point+Vector2(16-dimensions.x/2,-dimensions.y-8),point+Vector2(16-dimensions.x/2,40)]
	var tile=Rect2(point,Vector2(32,32))
	for candidate in candidates:
		var clamped=Vector2(clampf(candidate.x,8,maxf(8,size.x-dimensions.x-8)),clampf(candidate.y,88,maxf(88,size.y-dimensions.y-56)))
		if not Rect2(clamped,dimensions).intersects(tile): return clamped
	return Vector2(8,88)

func _process(delta: float) -> void:
	_hp_clock=fmod(_hp_clock+delta*60,96); _update_hp()

func _update_hp() -> void:
	if _hp_label==null or snapshot.is_empty(): return
	var hp=int(snapshot.enemy.hp); var maximum=maxi(1,int(snapshot.attributes.maxhp)); var damage=maxi(0,int(snapshot.result.enemy_damage)); var after=maxi(0,hp-damage)
	_hp_label.text="生命 %d / %d  −%d" % [hp,maximum,damage]
	_after_hp_label.text="战后 %d / %d  %d%%" % [after,maximum,int(after*100/maximum)]
	var opacity=hp_opacities(int(_hp_clock)); _hp_label.modulate.a=opacity[0]/255.0; _after_hp_label.modulate.a=opacity[1]/255.0

static func hp_opacities(frame: int) -> Array:
	frame=posmod(frame,96)
	if frame<16: return [clampi(255-16*(frame+1),0,255),clampi(16*(frame+1),0,255)]
	if frame<48: return [0,255]
	if frame<64: return [clampi(16*(frame-47),0,255),clampi(255-16*(frame-47),0,255)]
	return [255,0]

func _panel(rect: Rect2) -> Panel:
	var panel=Panel.new(); panel.position=rect.position; panel.size=rect.size
	panel.add_theme_stylebox_override("panel",preload("FlashBitmap.gd").panel_style(Vector2i(rect.size),0)); _content.add_child(panel); return panel

func _text_panel(text: String,rect: Rect2) -> RichTextLabel:
	var panel=_panel(rect); var label=RichTextLabel.new(); label.position=Vector2(8,8); label.size=rect.size-Vector2(16,16); label.text=text; label.add_theme_font_override("normal_font",Resources.font()); label.add_theme_font_size_override("normal_font_size",16); panel.add_child(label); return label

func _label(text: String,rect: Rect2,font_size: int=17,color: Color=Color.WHITE) -> Label:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); _content.add_child(label); return label

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color(0.45,0.45,0.45,0.5))

func _exit_tree() -> void:
	if _marks!=null and is_instance_valid(_marks): _marks.queue_free()
