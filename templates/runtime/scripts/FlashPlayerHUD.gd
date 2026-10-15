extends CanvasLayer
## Final 0197 PlayerData, 0183 ItemBar, 0188/0203 transfer map-name view.
## Formal actors are the only source of values. Source BUFF area remains empty.
const Presets=preload("FlashItemPresets.gd")
const Resources=preload("UIResources.gd")
const Cache=preload("RmxpCache.gd")
const Data=preload("RuntimeData.gd")
const Bitmap=preload("FlashBitmap.gd")
const Character=preload("CharacterSprite.gd")
const Palette=preload("FlashPalette.gd")
class Canvas extends Control:
	var hud: CanvasLayer
	func _draw() -> void: hud.draw_hud(self)
var canvas: Control
var slots: Array=[]
var rows: Array=[]
var layout_flipped=false
var window_process=0
var itembar_process=0
var mapname_frame=80
var mapname=""
var _dirty=true
var _old_ids: Array=[]
var _clock=0.0
var _mapname_clock=0.0
var _background: Texture2D
var _meters: Texture2D
var _frame: Texture2D
var _item_frame: Texture2D
var _portraits: Array=[]
var _graphic_layout: Array=[]
var _graphic_meters: Array=[]

func _ready() -> void:
	layer=9; process_mode=Node.PROCESS_MODE_ALWAYS
	canvas=Canvas.new(); canvas.hud=self; canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(canvas)
	for i in 2:
		var character=Character.new(); character.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(character); _portraits.append(character)
	var bitmap=Bitmap.new(36,36); bitmap.draw_item_frame(Rect2i(0,0,36,36)); _item_frame=bitmap.texture()
	RuntimeState.state_changed.connect(func():_dirty=true)
	get_viewport().size_changed.connect(func():_dirty=true)
	RuntimeState.execution_reset.connect(reset)
	var game: Node=RuntimeState.game()
	if game!=null: game.event_map().map_changed.connect(map_changed)
	_process(0)

func reset() -> void:
	window_process=0; itembar_process=0; _old_ids.clear(); layout_flipped=false; _dirty=true; mapname_frame=80

func map_changed(_id: int) -> void:
	if not RuntimeState.switches.get("5",false): mapname_frame=80; return
	mapname=str(Data.read_json("res://data/map_infos.json",{}).get(str(RuntimeState.map_id),{}).get("name",""))
	mapname_frame=0; _mapname_clock=0; canvas.queue_redraw()

func visible_target() -> bool:
	return not _ui_open() and bool(RuntimeState.custom_data.values.system.get("show_playerdata",true)) and not bool(RuntimeState.switches.get("6",false))

func _ui_open() -> bool:
	var game: Node=RuntimeState.game(); var menus: Node=game.get("_menus") if game!=null else null
	return menus!=null and (menus.menu!=null or menus.shop!=null or menus.name_input!=null)

func _process(delta: float) -> void:
	if _dirty:
		_dirty=false
		# Notifications arrive inside commit; normalize on the next frame.
		Presets.normalize(RuntimeState); slots=Presets.slots(RuntimeState); refresh_rows()
		canvas.queue_redraw()
	if RuntimeState.map_time_paused() and not _ui_open(): return
	_clock+=maxf(0,delta)*60; _mapname_clock+=maxf(0,delta)*60
	var ticks=mini(120,int(_clock)); _clock-=ticks
	var old=window_process; var old_mapname=mapname_frame
	window_process=clampi(window_process+(ticks if visible_target() else -ticks),0,8)
	var old_bar=itembar_process; itembar_process=clampi(itembar_process+(-ticks if _ui_open() else ticks),0,8)
	if mapname_frame<80:
		var elapsed=mini(120,int(_mapname_clock)); _mapname_clock-=elapsed; mapname_frame=mini(80,mapname_frame+elapsed)
	else: _mapname_clock=0
	_update_portrait_positions()
	if old!=window_process or old_mapname!=mapname_frame or old_bar!=itembar_process: canvas.queue_redraw()

func refresh_rows() -> void:
	var previous=rows
	rows=[]
	var ids: Array=RuntimeState.custom_data.gameplay().role_actor_ids()
	ids=[int(ids[0]),int(ids[1]) if RuntimeState.switches.get("160",false) else 0]
	if _old_ids.size()==2 and ids[0]==_old_ids[1] and ids[1]==_old_ids[0] and ids[0]!=ids[1]: layout_flipped=not layout_flipped
	_old_ids=ids.duplicate()
	for role in 2:
		var actor: RefCounted=RuntimeState.actor(ids[role]) if ids[role]>0 else null
		if actor==null: rows.append({}); continue
		var skills: Array=[]; var passive: Variant=actor.project_fields.equip_skills.get("-1",actor.project_fields.equip_skills.get("-2",0))
		if passive is Array: passive=passive[0] if not passive.is_empty() else 0
		skills.append(int(passive))
		for turn in range(1,4 if role==0 else 3):
			var skill: Variant=actor.project_fields.equip_skills.get(str(turn),0)
			if skill is Array: skill=skill[0] if not skill.is_empty() else 0
			skills.append(int(skill))
		rows.append({"id":actor.id,"name":actor.character_name,"hue":actor.character_hue,"hp":int(actor.hp),"maxhp":int(actor.get_parameter("maxhp")),"sp":int(actor.sp),"maxsp":int(actor.get_parameter("maxsp")),"patk":actor.get_parameter("patk"),"pdef":actor.get_parameter("pdef"),"agi":actor.get_parameter("agi"),"int":actor.get_parameter("int"),"exp":actor.experience,"next_exp":actor.next_level_experience(),"level":actor.level,"skills":skills})
	if rows==previous and _background!=null: return
	_build_graphics()
	for i in _portraits.size():
		_portraits[i].visible=not rows[i].is_empty()
		if not rows[i].is_empty() and (i>=previous.size() or previous[i].is_empty() or rows[i].name!=previous[i].name or rows[i].hue!=previous[i].hue):
			_portraits[i].configure(rows[i].name,rows[i].hue,2,0); _portraits[i].size=_portraits[i]._frame_size
	_update_portrait_positions(); canvas.queue_redraw()

func _build_graphics() -> void:
	var layout=[layout_flipped,rows[0].is_empty(),rows[1].is_empty()]
	if layout!=_graphic_layout or _background==null or _frame==null:
		_build_static_graphics(); _graphic_layout=layout
	var meters: Array=[layout_flipped]
	for row in rows: meters.append([] if row.is_empty() else [row.hp,row.maxhp,row.sp,row.maxsp,row.exp,row.next_exp])
	if meters!=_graphic_meters or _meters==null:
		_build_meter_graphics(); _graphic_meters=meters

func _build_static_graphics() -> void:
	var bitmap=Bitmap.new(640,196); bitmap.draw_h8_background(Rect2i(0,4,640,168))
	bitmap.draw_h8_bulge(Vector2i(176,20),Vector2i(464,20),false,20,0)
	var main_y=104 if layout_flipped else 40; var support_y=40 if layout_flipped else 104
	bitmap.draw_hud_back(Rect2i(88,main_y+4,160,6),1); bitmap.draw_hud_back(Rect2i(88,main_y+28,160,6),1)
	bitmap.fill_rounded_rect(Rect2i(264,100,112,56) if layout_flipped else Rect2i(268,28,96,56),10,Color8(30,56,58,184))
	bitmap.fill_rounded_rect(Rect2i(372,28,240,76),10,Color8(0,8,16,128))
	bitmap.draw_line2(Vector2i(18,88),Vector2i(336,88),2,[Color.TRANSPARENT,Color8(0,128,192)])
	var turn=Vector2i(366,72 if layout_flipped else 104)
	bitmap.draw_line2(Vector2i(336,88),turn,2,[Color.TRANSPARENT,Color8(0,128,192)])
	bitmap.draw_line2(turn+Vector2i(0,-1 if layout_flipped else 1),Vector2i(366,22 if layout_flipped else 154),2,[Color.TRANSPARENT,Color8(0,128,192)])
	if not rows[1].is_empty():
		bitmap.draw_hud_back(Rect2i(80,support_y+4,80,6),1); bitmap.draw_hud_back(Rect2i(80,support_y+28,80,6),1)
	_background=bitmap.texture(); bitmap=Bitmap.new(640,196)
	for i in 4: bitmap.draw_skill_frame(Rect2i(392+i*56,116,32,32),1 if i==0 else 2,true)
	if not rows[1].is_empty():
		for i in 3: bitmap.draw_skill_frame(Rect2i(192+i*56,(48 if layout_flipped else 112)+4,32,32),1 if i==0 else 3,true)
	_frame=bitmap.texture()

func _build_meter_graphics() -> void:
	var bitmap=Bitmap.new(640,196)
	var main_y=104 if layout_flipped else 40; var support_y=40 if layout_flipped else 104
	for i in 2:
		if rows[i].is_empty(): continue
		var row: Dictionary=rows[i]; var y=main_y if i==0 else support_y; var width=160 if i==0 else 80; var x=88 if i==0 else 80
		bitmap.draw_hud_line(Rect2i(x,y+4,width,6),row.hp,row.maxhp,Palette.color(9),Palette.color(3),1)
		bitmap.draw_hud_line(Rect2i(x,y+28,width,6),row.sp,row.maxsp,Palette.color(4),Palette.color(1),1)
		if i==0: bitmap.draw_trapezoid_meter(Rect2i(176,0,288,20),row.exp,int(row.next_exp) if row.next_exp!=null else 0,Color8(40,104,206,128),Color8(255,165,0,128))
	_meters=bitmap.texture()

func draw_hud(target: Control) -> void:
	var font=Resources.font(); var base=Vector2(0,target.size.y-20*window_process-4); var opacity=clampf(window_process*32.0/255,0,1)
	if window_process>0 and _background!=null:
		target.draw_texture(_background,base,Color(1,1,1,opacity)); target.draw_texture(_meters,base,Color(1,1,1,opacity)); target.draw_texture(_frame,base,Color(1,1,1,opacity))
		for role in 2:
			if rows[role].is_empty(): continue
			var row: Dictionary=rows[role]; var y=(88 if layout_flipped else 24) if role==0 else (24 if layout_flipped else 88)
			for vital in 2:
				var text="%d/%d" % [row.hp,row.maxhp] if vital==0 else "%d/%d" % [row.sp,row.maxsp]
				target.draw_string(font,base+Vector2(128 if role==0 else 72,y+23+vital*24),text,HORIZONTAL_ALIGNMENT_RIGHT,128 if role==0 else 96,18 if role==0 else 16,Color(1,0.65,0.65,opacity) if vital==0 else Color(0.25,0.75,1,opacity))
			if role==0:
				target.draw_string(font,base+Vector2(202,18),"Lv.%d" % row.level,HORIZONTAL_ALIGNMENT_LEFT,80,18,Color(0.84,0.92,0.97,opacity))
				target.draw_string(font,base+Vector2(310,18),str(row.exp)+"/"+(str(row.next_exp) if row.next_exp!=null else ""),HORIZONTAL_ALIGNMENT_RIGHT,128,18,Color(1,0.83,0.46,opacity))
				for i in 4:
					var point=base+Vector2(376+i%2*128,53+int(i/2)*36)
					target.draw_string(font,point,["攻击","防御","速度","术法"][i],HORIZONTAL_ALIGNMENT_LEFT,45,18,Color(0.71,0.88,0.92,opacity)); target.draw_string(font,point+Vector2(36,-6),str(row[["patk","pdef","agi","int"][i]]),HORIZONTAL_ALIGNMENT_RIGHT,66,18,Color(1,1,1,opacity))
			var x=392 if role==0 else 192; var sy=112 if role==0 else (48 if layout_flipped else 112)
			for i in row.skills.size():
				var point=base+Vector2(x+i*56,sy+4); var id=int(row.skills[i])
				if id>0:
					var icon=Cache.skills(str(Data.record("Skills",id).get("name",""))+".png")
					if icon!=null: target.draw_texture_rect(icon,Rect2(point+Vector2(4,4),Vector2(40,40)),false,Color(1,1,1,opacity))
				target.draw_string(font,point+Vector2(34,31),str(i),HORIZONTAL_ALIGNMENT_CENTER,10,10,Color(1,1,1,opacity))
	for cell in slots.size():
		if itembar_process==0: break
		var alpha=clampf(itembar_process*32.0/255,0,1); var rect=Rect2(target.size.x-40+(8-itembar_process)*12,82+cell*40,36,36); var id=int(slots[cell][0]); target.draw_texture(_item_frame,rect.position,Color(1,1,1,alpha))
		if id>0:
			var icon=Cache.icon(str(Presets.native_item(id,RuntimeState).get("icon_name","")))
			if icon!=null: target.draw_texture_rect(icon,Rect2(rect.position+Vector2(4,4),Vector2(28,28)),false,Color(1,1,1,alpha))
			var count_color=Color.WHITE if slots[cell][1]>0 else Color("b8c6d2"); count_color.a=alpha
			target.draw_string(font,rect.position+Vector2(4,32),"x%d" % int(slots[cell][1]),HORIZONTAL_ALIGNMENT_LEFT,-1,12,count_color)
		target.draw_string(font,rect.position+Vector2(2,12),str(cell+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,0.94,0.69,alpha))
	if mapname_frame<80:
		var step=mini(16,mapname_frame) if mapname_frame<64 else 80-mapname_frame
		var position=Vector2(target.size.x-128,-56+step*4)
		target.draw_style_box(Bitmap.panel_style(Vector2i(128,80),8),Rect2(position,Vector2(128,80)))
		target.draw_string(font,position+Vector2(8,42),mapname,HORIZONTAL_ALIGNMENT_CENTER,112,20,Color(0.83,0.95,1,clampf(step*16.0/255,0,1)))

func _update_portrait_positions() -> void:
	if canvas==null: return
	var base=Vector2(0,canvas.size.y-20*window_process)
	for i in _portraits.size():
		_portraits[i].position=base+Vector2(32,(92 if layout_flipped else 24) if i==0 else (24 if layout_flipped else 92))
		_portraits[i].modulate.a=clampf(window_process*32.0/255,0,1)
