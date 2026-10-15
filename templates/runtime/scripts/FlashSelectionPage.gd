extends Control
## 0117/0118 + 0254/0255: standalone floor/actor selection returns source vars.
const Data=preload("RuntimeData.gd")
const Cache=preload("RmxpCache.gd")
const Resources=preload("UIResources.gd")
const Scripts=preload("ScriptRuntime.gd")
const Bitmap=preload("FlashBitmap.gd")
signal back_requested
signal sound_requested(key: String)
var page="flash_selection"
var kind="floor"
var index=0
var entries: Array=[]
var message=""
var _content: Control
var _buttons: Dictionary={}
var _scroll_start=0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); read_entries(); refresh()
func read_entries() -> void:
	entries=[]
	if kind=="actor": entries=RuntimeState.party.duplicate(); return
	var floors: Variant=RuntimeState.variables.get("18"); var chapter: Variant=RuntimeState.variables.get("3",0)
	var list: Variant=null
	if chapter is int or chapter is float:
		if floors is Array and chapter>=0 and chapter<floors.size(): list=floors[int(chapter)]
		elif floors is Dictionary: list=floors.get("2:"+str(int(chapter)),floors.get(str(int(chapter))))
	if list is Array:
		for floor in list:
			if (floor is int or floor is float) and not entries.has(floor): entries.append(floor)
	index=maxi(0,entries.find(RuntimeState.variables.get("2",0)))
func refresh() -> void:
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_buttons.clear()
	var panel=Panel.new(); panel.position=Vector2(0,64); panel.size=Vector2(640,416); panel.add_theme_stylebox_override("panel",Bitmap.panel_style(Vector2i(640,416))); _content.add_child(panel)
	_label("请选择您要操作的角色。" if kind=="actor" else "请选择你要到达的楼层。",Rect2(16,16,608,32))
	var columns=2 if kind=="actor" else 4; var width=320 if kind=="actor" else 160
	var scroll=maxi(0,int(index/columns)-9)
	_scroll_start=scroll
	for i in range(scroll*columns,mini(entries.size(),(scroll+12)*columns)):
		var entry=entries[i]; var actor=RuntimeState.actor(int(entry)) if kind=="actor" else null
		var button=Button.new(); button.position=Vector2(20+(i%columns)*width,80+(int(i/columns)-scroll)*32); button.size=Vector2(width-8,30); button.text=actor.actor_name if actor!=null else "第%s层" % str(entry)
		button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",18)
		if i==index: button.modulate=Color("a9ffe1")
		button.pressed.connect(func(): index=i; _paint_selection()); _content.add_child(button); _buttons[i]=button
		var pictures: Variant=RuntimeState.variables.get("94"); var name=str(pictures[int(entry)-1]) if kind=="actor" and pictures is Array and int(entry)>=1 and int(entry)<=pictures.size() else str(RuntimeState.variables.get("3",0)) if kind=="floor" else ""
		var texture=Cache.picture(name) if not name.is_empty() else null
		if texture!=null:
			var icon=TextureRect.new(); icon.texture=texture; icon.position=button.position; icon.size=Vector2(28,28); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _content.add_child(icon)
	_label(message if not message.is_empty() else "↑↓选择 · ←→换列 · Enter确认 · Esc返回",Rect2(16,496,608,56))
	if entries.is_empty(): _label("没有可选项目",Rect2(16,100,608,40))
	queue_redraw()
func _label(text: String,rect: Rect2) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",18); _content.add_child(label)
func _return(value: Variant) -> void:
	var result=Scripts.call_transaction(RuntimeState,{"source":"0255.Scene_CP" if kind=="actor" else "0254.Scene_Flytofloor"},func(env):return env.index_set({"__state_table":"variable"},12 if kind=="actor" else 13,value))
	if not result.ok: message=str(result.get("message","")); refresh(); sound_requested.emit("buzzer_se"); return
	back_requested.emit()
func activate() -> void:
	if entries.is_empty(): sound_requested.emit("buzzer_se"); return
	_return(int(entries[index])-1 if kind=="actor" else entries[index])
func back() -> void:
	_return(RuntimeState.custom_data.gameplay().role_ids()[0] if kind=="actor" else "stop")
func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: back()
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()
	elif key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and not entries.is_empty():
		index=posmod(index+{KEY_UP:-2 if kind=="actor" else -4,KEY_DOWN:2 if kind=="actor" else 4,KEY_LEFT:-1,KEY_RIGHT:1}[key],entries.size())
		var columns=2 if kind=="actor" else 4
		if maxi(0,int(index/columns)-9)!=_scroll_start: refresh()
		else: _paint_selection()
		sound_requested.emit("cursor_se")
func _paint_selection() -> void:
	for i in _buttons: _buttons[i].modulate=Color("a9ffe1") if i==index else Color.WHITE
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("0b171e"))
