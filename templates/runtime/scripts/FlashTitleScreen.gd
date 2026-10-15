extends Control
## Final source 0139–0145; Godot owns the scene loop and nonblocking animation.
const Data=preload("RuntimeData.gd")
const Cache=preload("RmxpCache.gd")
const Resources=preload("UIResources.gd")
const Saves=preload("SaveService.gd")
const COMMANDS=["新游戏","继续游戏","独立副本","成就一览","音乐鉴赏","游戏设置","离开游戏"]
signal new_game_requested(difficulty: int)
signal load_requested(slot: int)
var index=0
var difficulty=1
var page="title"
var child: Control
var frame=0
var logo_progress=0
var _clock=0.0
var _background: TextureRect
var _logo: TextureRect
var _content: Control
var _frames: Dictionary={}
var _order: Array=[]
var _buttons: Array[Button]=[]
var _background_pending: Dictionary={}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background=TextureRect.new(); _background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; _background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; add_child(_background)
	_logo=TextureRect.new(); _logo.texture=Cache.title("金色.png"); _logo.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_logo)
	resized.connect(refresh); refresh(); _tick()

func refresh() -> void:
	if not is_inside_tree() or size.x<1 or child!=null: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_buttons.clear()
	if page=="mode":
		_label("选择难度",Rect2(24,176,size.x-48,32),24)
		for mode in 4:
			var button=Button.new(); button.text=["Normal","Hard","Lunatic","EX"][mode]; button.position=Vector2(32+mode*(size.x-64)/4,276); button.size=Vector2((size.x-64)/4-6,72); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",22); button.pressed.connect(func():difficulty=mode; new_game_requested.emit(mode))
			var card=Cache.title("mode/mode_%d.png" % mode)
			if card!=null: button.icon=card; button.expand_icon=true
			if mode==difficulty: button.modulate=Color("fff0b7")
			_content.add_child(button); _buttons.append(button)
		_label("←→选择 · Enter开始 · Esc返回",Rect2(24,size.y-64,size.x-48,32),16)
	else:
		for command in 7:
			var button=Button.new(); button.text=COMMANDS[command]; button.position=Vector2(size.x/2-120,300+command*40); button.size=Vector2(240,36); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",20); button.disabled=command==2 or command==1 and not Saves.has_valid_save(); button.pressed.connect(func():index=command; activate())
			if command==index: button.modulate=Color("fff0b7")
			_content.add_child(button); _buttons.append(button)
		_label("↑↓选择 · Enter确认",Rect2(24,size.y-40,size.x-48,28),15)
	queue_redraw()

func activate() -> void:
	if index==2: return
	if index==0: page="mode"; difficulty=1; refresh(); return
	if index==6: RuntimeState.request_quit(); return
	if index==1 and not Saves.has_valid_save(): return
	var script: Script=load("res://runtime/scripts/FlashArchivePage.gd") if index==1 else load("res://runtime/scripts/FlashConfigPage.gd") if index==5 else load("res://runtime/scripts/FlashTitleExtrasPage.gd")
	child=script.new()
	if index==1:
		child.mode="load"; child.allow_mode_switch=false; child.load_requested.connect(func(slot: int):load_requested.emit(slot))
		child.sound_requested.connect(func(key: String):Resources.play_sound(self,key))
	elif index in [3,4]: child.kind="merit" if index==3 else "music"
	child.back_requested.connect(back); _content.hide(); add_child(child)
	child.modulate.a=0; child.create_tween().tween_property(child,"modulate:a",1.0,16.0/60)

func back() -> void:
	if child!=null: remove_child(child); child.queue_free(); child=null
	page="title"; refresh()

func handle_key(key: int) -> void:
	if child!=null:
		if child.has_method("handle_key"): child.handle_key(key)
		elif key in [KEY_ESCAPE,KEY_X]: child.back()
		elif key in [KEY_UP,KEY_LEFT]: child.navigate(-1)
		elif key in [KEY_DOWN,KEY_RIGHT]: child.navigate(1)
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: child.activate()
		return
	if page=="mode":
		if key in [KEY_ESCAPE,KEY_X]: back()
		elif key in [KEY_LEFT,KEY_RIGHT]: difficulty=clampi(difficulty+(-1 if key==KEY_LEFT else 1),0,3); _paint_selection()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: new_game_requested.emit(difficulty)
	elif key in [KEY_UP,KEY_DOWN]:
		index=posmod(index+(-1 if key==KEY_UP else 1),7)
		if index==2: index=posmod(index+(-1 if key==KEY_UP else 1),7)
		_paint_selection()
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()

func _process(delta: float) -> void:
	_clock+=delta*60
	var count=mini(int(_clock),120); _clock-=count
	for i in count: _tick()

func _tick() -> void:
	for id in _background_pending.keys():
		var status=ResourceLoader.load_threaded_get_status(_background_pending[id])
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		_frames[id]=ResourceLoader.load_threaded_get(_background_pending[id]) if status==ResourceLoader.THREAD_LOAD_LOADED else null
		_background_pending.erase(id); _order.append(id)
		if _order.size()>32: _frames.erase(_order.pop_front())
	for offset in 8: _request_background(posmod(frame+offset,480))
	if _frames.has(frame): _background.texture=_frames[frame]
	frame=posmod(frame+1,480)
	logo_progress=clampi(logo_progress+(1 if page=="title" and child==null else -1),0,16)
	if _logo.texture!=null:
		_logo.size=_logo.texture.get_size(); _logo.position=Vector2((size.x-_logo.size.x)/2,-20+5*logo_progress); _logo.modulate.a=minf(logo_progress*16/255.0,1)

func _paint_selection() -> void:
	for i in _buttons.size(): _buttons[i].modulate=Color("fff0b7") if i==(difficulty if page=="mode" else index) else Color.WHITE

func _request_background(id: int) -> void:
	if _frames.has(id) or _background_pending.has(id) or _background_pending.size()>=8: return
	var path=Cache.resolve("Titles","title_1/bg%03d" % id)
	if path.is_empty() or not ResourceLoader.exists(path): return
	if ResourceLoader.load_threaded_request(path)==OK: _background_pending[id]=path

func _label(text: String,rect: Rect2,font_size: int) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); _content.add_child(label)

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
