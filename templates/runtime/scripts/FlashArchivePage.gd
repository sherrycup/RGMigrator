extends "SaveSlots.gd"
## 0170–0174/0202: file cards, source kind/tab, chapter, snapshot and tips.
## JSON replaces RGSS Marshal; state ownership and safe backups stay in SaveService.
const Archive=preload("FlashArchiveData.gd")
const Bitmap=preload("FlashBitmap.gd")
const Resources=preload("UIResources.gd")
var page="save"
var allow_mode_switch=true
var window_process=0
var preview_process=8
var preview_id=-1
var _clock=0.0
var _slots: Array=[]
var _archives: Dictionary={}
var _preview: TextureRect
var _preview_image: Image
var _previous: Image
var _next: Image
var _preview_texture: ImageTexture
var _windows: Array=[]
var _current: Dictionary={}
var _catalog_ready=false
var _preview_surface: SubViewport
var _previous_view: TextureRect
var _next_view: TextureRect
var _preview_cache: Dictionary={}
var _preview_order: Array[String]=[]
var _cards: Dictionary={}
var _scroll_start=0
var _chapter_title: Label
var _chapter_subtitle: Label
var _chapter_lines: Array[ColorRect]=[]
var _no_snapshot: Label
var _player_views: Array=[]
var _tip_message: Label
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selected=maxi(0,int(RuntimeState.flash_temp_fields.get("last_file_index",0)))
	refresh()
func refresh(reload_catalog: bool=true) -> void:
	if _panel!=null: remove_child(_panel); _panel.queue_free()
	_panel=Control.new(); _panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_panel); _windows=[]
	_cards.clear(); _chapter_lines.clear(); _player_views.clear()
	if reload_catalog or not _catalog_ready:
		_slots=Saves.existing_slots()
		if mode=="save":
			var next=1
			while next in _slots: next+=1
			if next<=Saves.maximum_slots(): _slots.append(next)
		_infos.clear(); _archives.clear()
		for slot in _slots:
			var info=Saves.slot_info(slot); _infos.append(info); _archives[slot]=info.get("archive",{})
		_catalog_ready=true
	selected=clampi(selected,0,maxi(0,_slots.size()-1))
	_current=_archives.get(_slots[selected],{}) if not _slots.is_empty() else {}
	var kind=_panel_at(Rect2(8,8,144,96),Vector2(0,-64)); _label(kind,"记录档案" if mode=="save" else "回看档案",Rect2(8,14,128,28),20)
	_label(kind,"TAB键切换模式",Rect2(8,48,128,28),13)
	var chapter_panel=_panel_at(Rect2(size.x-208,8,192,112),Vector2(0,-64))
	_chapter_title=_label(chapter_panel,"",Rect2(8,12,176,25),18); _chapter_subtitle=_label(chapter_panel,"",Rect2(8,60,112,25),18)
	for y in [20,28]:
		var line=ColorRect.new(); line.position=Vector2(8,y); line.size=Vector2(88,1); line.color=load("res://runtime/scripts/FlashPalette.gd").color(17); chapter_panel.add_child(line); _chapter_lines.append(line)
	var files=_panel_at(Rect2(16,136,272,320),Vector2(-96,0))
	var scroll=maxi(0,int(selected/4)-1)
	_scroll_start=scroll
	for i in range(scroll*4,mini(_slots.size(),scroll*4+8)):
		var relative=i-scroll*4; var button=Button.new(); button.position=Vector2(16+int(relative/4)*120,48+relative%4*64); button.size=Vector2(116,60)
		var info: Dictionary=_infos[i]; var date=str(info.get("saved_at","")).replace("-","/")
		button.text="File%d\n%s\n%s" % [_slots[i],date.substr(0,10),date.substr(11,5)] if info.ok else "新档案" if not info.exists and mode=="save" else "File%d\n%s" % [_slots[i],str(info.get("message",""))]
		button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",14); button.add_theme_stylebox_override("normal",Bitmap.skill_style(Vector2i(116,60),1,false))
		if i==selected: button.modulate=Color("a9ffe1")
		button.pressed.connect(func(): selected=i; _update_selection(); sound_requested.emit("cursor_se")); files.add_child(button); _cards[i]=button
	if _slots.is_empty(): _label(files,"没有档案",Rect2(16,60,240,48),18)
	var snap=_panel_at(Rect2(size.x-344,136,352,352),Vector2(96,0))
	_ensure_preview_surface()
	_preview=TextureRect.new(); _preview.position=Vector2.ZERO; _preview.size=Vector2(352,352); _preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; _preview.texture=_preview_surface.get_texture(); snap.add_child(_preview)
	_no_snapshot=_label(snap,"无截图",Rect2(32,150,288,40),18)
	var players=_panel_at(Rect2(80,488,480,136),Vector2(0,96))
	for i in 2:
		var x=i*240; var portrait=load("res://runtime/scripts/CharacterSprite.gd").new(); portrait.position=Vector2(x+8,12); portrait.size=Vector2(40,48); players.add_child(portrait)
		_player_views.append({"portrait":portrait,"name":_label(players,"",Rect2(x+52,10,176,24),18),"stats":_label(players,"",Rect2(x+52,36,182,90),14)})
	var tips=_panel_at(Rect2(160,8,264,112),Vector2(0,-64))
	_label(tips,"让我摸个鱼吧！这不就……胡了！",Rect2(8,8,248,44),15)
	_tip_message=_label(tips,"",Rect2(8,56,248,48),13)
	_update_selection()
	_confirm=null
	if not _confirmation.is_empty():
		_confirm=_panel_at(Rect2(size/2-Vector2(150,64),Vector2(300,128)))
		_label(_confirm,"确认覆盖" if _confirmation=="overwrite" else "读取上一份备份",Rect2(16,12,268,32),20)
		for i in 2:
			var button=Button.new(); button.position=Vector2(16+i*140,64); button.size=Vector2(128,40); button.text="确认" if i==0 else "取消"; button.pressed.connect(func(): _confirm.set_meta("accepted",i==0); activate()); _confirm.add_child(button)
		_confirm.set_meta("accepted",false)
	_apply_motion(); queue_redraw()
func _panel_at(rect: Rect2,offset: Vector2=Vector2.ZERO) -> Panel:
	var panel=Panel.new(); panel.position=rect.position; panel.size=rect.size; panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",Bitmap.panel_style(Vector2i(rect.size),0)); _panel.add_child(panel)
	_windows.append({"node":panel,"position":rect.position,"offset":offset}); return panel
func _label(parent: Control,text: String,rect: Rect2,font_size: int) -> Label:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",Color.WHITE); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label)
	return label
func _update_selection() -> void:
	if maxi(0,int(selected/4)-1)!=_scroll_start: refresh(false); return
	_current=_archives.get(_slots[selected],{}) if not _slots.is_empty() else {}
	for i in _cards: _cards[i].modulate=Color("a9ffe1") if i==selected else Color.WHITE
	var chapter=int(_current.get("chapter",-1))
	_chapter_title.text="Chapter %d" % chapter if chapter in [0,1] else ""
	_chapter_title.size.x=112 if chapter==1 else 176
	_chapter_subtitle.text="摸鱼" if chapter==0 else ""
	for line in _chapter_lines: line.visible=chapter==1
	_no_snapshot.visible=str(_current.get("png","")).is_empty()
	_select_preview(_slots[selected] if not _slots.is_empty() else 0,_current)
	var rows: Array=_current.get("players",[])
	for i in _player_views.size():
		var view: Dictionary=_player_views[i]
		for node in view.values(): node.visible=i<rows.size()
		if i>=rows.size(): continue
		var row: Dictionary=rows[i]; var signature=str(row.char_name)+":"+str(row.char_hue)
		if view.portrait.get_meta("signature","")!=signature:
			view.portrait.configure(row.char_name,int(row.char_hue)); view.portrait.set_meta("signature",signature)
		view.name.text=str(row.get("name",""))
		view.stats.text="HP %d / %d\nSP %d / %d\nLv %d  EXP %s / %s" % [int(row.hp),int(row.maxhp),int(row.sp),int(row.maxsp),int(row.lv),_number(row.exp),_number(row.maxexp)]
	_tip_message.text=message if not message.is_empty() else "方向键选择 · Enter确认 · Esc返回"
func _number(value: Variant) -> String:
	return "—" if value==null else str(int(value)) if value is int or value is float and value==floor(value) else str(value)
func _process(delta: float) -> void:
	_clock+=delta*60; var ticks=mini(120,int(_clock)); _clock-=ticks
	for i in ticks:
		window_process=mini(8,window_process+1)
		if preview_process<8: preview_process+=1; _compose_preview()
	_apply_motion()
func _apply_motion() -> void:
	for window in _windows:
		window.node.position=window.position+window.offset*(8-window_process)/8.0; window.node.modulate.a=clampf(window_process*32.0/255,0,1)
func _select_preview(id: int,data: Dictionary) -> void:
	# Refreshing an overwritten slot may change its picture without changing ID.
	var identity=str(id)+":"+str(data.get("png","")).sha256_text()
	if _preview_surface.get_meta("identity","")==identity: return
	_preview_surface.set_meta("identity",identity)
	if preview_process<8 and DisplayServer.get_name()!="headless":
		var current=_preview_surface.get_texture().get_image()
		_previous_view.texture=ImageTexture.create_from_image(current) if current!=null and not current.is_empty() else _preview_texture
	else: _previous_view.texture=_preview_texture
	preview_id=id
	var key=str(data.get("png","")).sha256_text()
	if not _preview_cache.has(key):
		_next=Archive.preview(data)
		var canvas=Image.create(352,352,false,Image.FORMAT_RGBA8); canvas.fill(Color.TRANSPARENT)
		if _next!=null:
			var image: Image=_next.duplicate(); image.resize(316,316,Image.INTERPOLATE_BILINEAR)
			canvas.blend_rect(image,Rect2i(0,0,316,316),Vector2i(10,10))
		_preview_cache[key]={"image":canvas,"texture":ImageTexture.create_from_image(canvas)}
		_next=null
	_preview_order.erase(key); _preview_order.append(key)
	while _preview_order.size()>8: _preview_cache.erase(_preview_order.pop_front())
	_preview_image=_preview_cache[key].image; _preview_texture=_preview_cache[key].texture; _next_view.texture=_preview_texture
	preview_process=0; _compose_preview()
func _compose_preview() -> void:
	_previous_view.modulate.a=clampi(256-preview_process*32,0,255)/255.0
	_next_view.modulate.a=clampi(preview_process*32,0,255)/255.0
	_preview_surface.render_target_update_mode=SubViewport.UPDATE_ONCE
func _ensure_preview_surface() -> void:
	if _preview_surface!=null: return
	_preview_surface=SubViewport.new(); _preview_surface.size=Vector2i(352,352); _preview_surface.transparent_bg=true; _preview_surface.disable_3d=true
	_preview_surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; add_child(_preview_surface)
	_previous_view=TextureRect.new(); _previous_view.size=Vector2(352,352); _preview_surface.add_child(_previous_view)
	_next_view=TextureRect.new(); _next_view.size=Vector2(352,352); _preview_surface.add_child(_next_view)
func navigate(direction: int) -> void:
	if _confirm!=null: _confirm.set_meta("accepted",not _confirm.get_meta("accepted",false)); return
	if not _slots.is_empty():
		var next=posmod(selected+direction,_slots.size())
		if next!=selected: selected=next; _update_selection()
		sound_requested.emit("cursor_se")
func activate() -> void:
	if _slots.is_empty(): sound_requested.emit("buzzer_se"); return
	if _confirm!=null:
		var accepted=bool(_confirm.get_meta("accepted",false)); _confirmation=""
		if accepted: execute()
		else: refresh(false)
	elif mode=="save" and _infos[selected].exists: _confirmation="overwrite"; refresh(false)
	elif mode=="load" and _infos[selected].get("recovered",false): _confirmation="backup"; refresh(false)
	else: execute()
func execute() -> void:
	if mode=="load":
		if _infos[selected].ok: RuntimeState.flash_temp_fields.last_file_index=selected; load_requested.emit(int(_slots[selected]))
		else: message=_infos[selected].message; refresh(); sound_requested.emit("buzzer_se")
		return
	var result: Dictionary=save_callback.call(int(_slots[selected])) if save_callback.is_valid() else Saves.fail("存档调用上下文不可用。")
	message=result.message; sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	if result.ok: RuntimeState.flash_temp_fields.last_file_index=selected; back_requested.emit()
	else: refresh()
func handle_key(key: int) -> void:
	if key==KEY_TAB and allow_mode_switch and _confirmation.is_empty(): mode="load" if mode=="save" else "save"; refresh(); sound_requested.emit("cursor_se")
	elif key in [KEY_ESCAPE,KEY_X]: back()
	elif key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: navigate({KEY_UP:-1,KEY_DOWN:1,KEY_LEFT:-4,KEY_RIGHT:4}[key])
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.06,0.08,0.65))
