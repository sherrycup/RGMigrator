extends Control
## 0135/0136/0260, ten-item groups and source numeric ±1/±10/clamps.
const Data=preload("RuntimeData.gd")
const Resources=preload("UIResources.gd")
const Scripts=preload("ScriptRuntime.gd")
const Bitmap=preload("FlashBitmap.gd")
signal back_requested
signal sound_requested(key: String)
var page="flash_debug"
var group=0
var index=0
var editing=false
var groups: Array=[]
var message=""
var _content: Control
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for type in ["switch","variable"]:
		var names: Array=Data.system().get("switches" if type=="switch" else "variables",[])
		for first in range(1,names.size(),10): groups.append({"kind":type,"first":first,"last":mini(first+9,names.size()-1)})
	refresh()
func refresh() -> void:
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_panel(Rect2(0,0,192,480)); _panel(Rect2(192,0,448,352)); _panel(Rect2(192,352,448,128))
	var start=clampi(group-5,0,maxi(0,groups.size()-14))
	for i in range(start,mini(start+14,groups.size())):
		var entry: Dictionary=groups[i]; var button=Button.new(); button.position=Vector2(16,16+(i-start)*32); button.size=Vector2(160,30); button.text="%s [%04d-%04d]" % ["S" if entry.kind=="switch" else "V",entry.first,entry.last]; button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",15)
		if i==group: button.modulate=Color("a9ffe1")
		button.pressed.connect(func():group=i; index=0; editing=false; refresh()); _content.add_child(button)
	if not groups.is_empty():
		var current: Dictionary=groups[group]; var names: Array=Data.system().get("switches" if current.kind=="switch" else "variables",[]); var table: Dictionary=RuntimeState.switches if current.kind=="switch" else RuntimeState.variables
		for id in range(current.first,current.last+1):
			var button=Button.new(); button.position=Vector2(208,16+(id-current.first)*32); button.size=Vector2(416,30); button.text="%04d: %s  [%s]" % [id,str(names[id]),"ON" if table.get(str(id),false) else "OFF"] if current.kind=="switch" else "%04d: %s  [%s]" % [id,str(names[id]),str(table.get(str(id),0))]; button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",15)
			if editing and id==current.first+index: button.modulate=Color("a9ffe1")
			button.pressed.connect(func(): editing=true; index=id-current.first; change(0)); _content.add_child(button)
	var label=Label.new(); label.position=Vector2(208,368); label.size=Vector2(416,96); label.text=message if not message.is_empty() else "Enter：ON/OFF\n←：-1  →：+1\nPageUp：-10  PageDown：+10" if editing else "选择开关/变量分组，按Enter编辑。"; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",17); _content.add_child(label); queue_redraw()
func _panel(rect: Rect2) -> void:
	var panel=Panel.new(); panel.position=rect.position; panel.size=rect.size; panel.add_theme_stylebox_override("panel",Bitmap.panel_style(Vector2i(rect.size))); _content.add_child(panel)
func change(amount: int) -> Dictionary:
	if groups.is_empty(): return {"ok":false,"message":"没有可编辑的项目。"}
	var current: Dictionary=groups[group]; var id=int(current.first)+index
	var result=Scripts.call_transaction(RuntimeState,{"source":"0260.Scene_Debug"},func(env):
		var ref={"__state_table":current.kind}; var value: Variant=env.index_get(ref,id)
		if current.kind=="switch": return env.index_set(ref,id,not value) if amount==0 else value
		if not (value is int or value is float) or not is_finite(float(value)): return env.fail("当前变量包含非数值数据，不能用数值按键修改。")
		return env.index_set(ref,id,clamp(value+amount,-99999999,99999999)))
	message="" if result.ok else str(result.get("message","")); refresh(); sound_requested.emit("cursor_se" if result.ok else "buzzer_se"); return result
func back() -> void:
	if editing: editing=false; message=""; refresh()
	else: back_requested.emit()
func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: back(); return
	if groups.is_empty(): return
	if key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]:
		if editing: change(0)
		else: editing=true; index=0; refresh()
	elif key in [KEY_UP,KEY_DOWN]:
		if editing: index=posmod(index+(-1 if key==KEY_UP else 1),int(groups[group].last)-int(groups[group].first)+1)
		else: group=posmod(group+(-1 if key==KEY_UP else 1),groups.size())
		refresh()
	elif editing and key in [KEY_LEFT,KEY_RIGHT,KEY_PAGEUP,KEY_PAGEDOWN]: change({KEY_LEFT:-1,KEY_RIGHT:1,KEY_PAGEUP:-10,KEY_PAGEDOWN:10}[key])
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("0b171e"))
