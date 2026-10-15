extends Control
## Source 0198/0202 commands, locks and page ownership.
const Data=preload("RuntimeData.gd")
const Resources=preload("UIResources.gd")
const Scripts=preload("ScriptRuntime.gd")
const COMMANDS=["物品资源","记录档案","角色装备","查看笔记","神秘圆盘","查看成就","合成工艺","游戏设置","角色技能","返回标题"]
const DEFAULT_LOCKS=[1,1,0,0,0,0,0,1,0,1]
signal close_requested
signal title_requested
signal sound_requested(key: String)
signal load_requested(slot: int)
var page="flash_menu"
var index=0
var save_callback: Callable
var child: Control
var active_command=-1
var _content: Control
var _buttons: Array[Button]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not RuntimeState.variables.get("5") is Array:
		Scripts.call_transaction(RuntimeState,{"source":"0198.initialize.MENU_LOCK"},func(env):return env.index_set({"__state_table":"variable"},5,DEFAULT_LOCKS.duplicate()))
	RuntimeState.state_changed.connect(refresh); resized.connect(refresh); refresh()

func enabled(command: int) -> bool:
	var locks: Variant=RuntimeState.variables.get("5")
	return locks is Array and command>=0 and command<locks.size() and locks[command]==1

func refresh() -> void:
	if child!=null or not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_buttons.clear()
	_label("黎之闪翼",Rect2(24,18,size.x-48,36),24)
	var width=(size.x-48)/5.0
	for command in 10:
		var button=Button.new(); button.text=COMMANDS[command]; button.position=Vector2(24+int(command/2)*width,72+command%2*44); button.size=Vector2(width-4,40); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",17)
		button.pressed.connect(func():index=command; _paint_selection(); activate())
		if not enabled(command): button.modulate=Color("666666")
		elif command==index: button.modulate=Color("a9ffe1")
		_content.add_child(button); _buttons.append(button)
	var roles=RuntimeState.custom_data.gameplay().role_ids()
	for row in RuntimeState.party.size():
		var actor=RuntimeState.actor(int(RuntimeState.party[row])); var y=192+row*124
		_label(actor.actor_name+" · "+("主战" if actor.id==roles[0] else "援护" if actor.id==roles[1] else "队员"),Rect2(32,y,size.x-64,28),21,Color("a9e3d2"))
		_label("HP %d / %d    SP %d / %d" % [actor.hp,actor.get_parameter("maxhp"),actor.sp,actor.get_parameter("maxsp")],Rect2(32,y+34,size.x-64,28))
		_label("物攻 %d · 物防 %d · 魔攻 %d · 魔防 %d · 速度 %d" % [actor.get_parameter("patk"),actor.get_parameter("pdef"),actor.get_parameter("matk"),actor.get_parameter("mdef"),actor.get_parameter("agi")],Rect2(32,y+68,size.x-64,28),16)
	var money: Array[String]=[]
	for row in RuntimeState.custom_data.currency_rows(): money.append(str(row.label)+" "+str(row.value))
	_label(" · ".join(money),Rect2(24,size.y-88,size.x-48,40),15,Color("e6daa8"))
	_label("↑↓选择 · ←→换列 · Enter确认 · Esc返回",Rect2(24,size.y-48,size.x-48,28),16)
	queue_redraw()

func _paint_selection() -> void:
	for command in _buttons.size():
		_buttons[command].modulate=Color("666666") if not enabled(command) else Color("a9ffe1") if command==index else Color.WHITE

func activate() -> void:
	if not enabled(index): sound_requested.emit("buzzer_se"); return
	# These three branches are empty in the final source 0202.update_command.
	if index in [2,5,6]: return
	if index==9: title_requested.emit(); return
	var script: Script
	if index==0: script=load("res://runtime/scripts/FlashItemPage.gd")
	elif index==1: script=load("res://runtime/scripts/FlashArchivePage.gd")
	elif index==4: script=load("res://runtime/scripts/FlashBlasticPage.gd")
	elif index==8: script=load("res://runtime/scripts/FlashSkillPage.gd")
	elif index==3 and ResourceLoader.exists("res://runtime/scripts/FlashNotePage.gd"): script=load("res://runtime/scripts/FlashNotePage.gd")
	elif index==7 and ResourceLoader.exists("res://runtime/scripts/FlashConfigPage.gd"): script=load("res://runtime/scripts/FlashConfigPage.gd")
	if script==null: return
	active_command=index; child=script.new()
	if index==1: child.save_callback=save_callback
	if index==1: child.load_requested.connect(func(slot: int):load_requested.emit(slot))
	child.back_requested.connect(back)
	if child.has_signal("sound_requested"): child.sound_requested.connect(func(key: String):sound_requested.emit(key))
	if child.has_signal("common_event_requested"): child.common_event_requested.connect(func():close_requested.emit())
	if _content!=null: _content.hide()
	add_child(child); sound_requested.emit("decision_se")

func back() -> void:
	if child==null: close_requested.emit(); return
	remove_child(child); child.queue_free(); child=null; active_command=-1
	refresh(); sound_requested.emit("cancel_se")

func handle_key(key: int) -> void:
	if child!=null:
		if child.has_method("handle_key"): child.handle_key(key)
		elif key in [KEY_ESCAPE,KEY_X]: child.back()
		elif key in [KEY_UP,KEY_LEFT]: child.navigate(-1)
		elif key in [KEY_DOWN,KEY_RIGHT]: child.navigate(1)
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: child.activate()
		return
	if key in [KEY_ESCAPE,KEY_X]: back(); return
	if key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		index=posmod(index+{KEY_UP:-1,KEY_DOWN:1,KEY_LEFT:-2,KEY_RIGHT:2}[key],10); _paint_selection(); sound_requested.emit("cursor_se")
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()

func _label(text: String,rect: Rect2,font_size: int=17,color: Color=Color.WHITE) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(label)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
