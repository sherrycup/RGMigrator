extends Control
## Source 0224–0227 and 0202: original category lock, entries and description.
const Data=preload("RuntimeData.gd")
const Resources=preload("UIResources.gd")
const Scripts=preload("ScriptRuntime.gd")
const CATEGORIES=["说明","主线","随笔","战斗","书籍"]
signal back_requested
var page="flash_notes"
var category=0
var index=0
var selecting=false
var entries: Array=[]
var description=""
var _content: Control
var _text: RichTextLabel
var _buttons: Array[Button]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lock_id=int(RuntimeState.custom_data.gameplay().rules.constants.get("NOTECATE_LOCK",10))
	if not RuntimeState.variables.get(str(lock_id)) is Array:
		Scripts.call_transaction(RuntimeState,{"source":"0225.initialize.NOTECATE_LOCK"},func(env):return env.index_set({"__state_table":"variable"},lock_id,[0,0,0,0,0]))
	RuntimeState.state_changed.connect(refresh); resized.connect(refresh); refresh()

func enabled(id: int) -> bool:
	var locks: Variant=RuntimeState.variables.get(str(RuntimeState.custom_data.gameplay().rules.constants.get("NOTECATE_LOCK",10)))
	return locks is Array and id>=0 and id<locks.size() and locks[id]==1

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_buttons.clear()
	_label("查看笔记",Rect2(16,12,size.x-32,32),22)
	for id in 5:
		var button=Button.new(); button.text=CATEGORIES[id]; button.position=Vector2(16+id*(size.x-32)/5,56); button.size=Vector2((size.x-32)/5-4,36); button.add_theme_font_override("font",Resources.font())
		button.pressed.connect(func():
			category=id; index=0
			if enabled(id): selecting=true
			refresh())
		if not enabled(id): button.modulate=Color("666666")
		elif category==id: button.modulate=Color("a9ffe1")
		_content.add_child(button)
	var storage: Dictionary=RuntimeState.custom_data.gameplay().rules.storage
	entries=storage.get("note_name",{}).get(str(category),[]) if enabled(category) else []
	index=clampi(index,0,maxi(entries.size()-1,0))
	var list=ScrollContainer.new(); list.position=Vector2(16,108); list.size=Vector2(176,maxf(size.y-176,1)); _content.add_child(list)
	var rows=VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_child(rows)
	for id in entries.size():
		var button=Button.new(); button.text=str(entries[id]); button.custom_minimum_size.y=32; button.add_theme_font_override("font",Resources.font()); button.pressed.connect(func():index=id; selecting=true; refresh())
		if id==index and selecting: button.modulate=Color("a9ffe1")
		rows.add_child(button); _buttons.append(button)
	description=""
	var texts: Variant=storage.get("note_desc",{}).get(str(category))
	if texts is Dictionary: description=str(texts.get(str(index),""))
	_text=RichTextLabel.new(); _text.position=Vector2(208,108); _text.size=Vector2(size.x-224,maxf(size.y-176,1)); _text.text=description; _text.add_theme_font_override("normal_font",Resources.font()); _text.add_theme_font_size_override("normal_font_size",18); _text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _content.add_child(_text)
	_label("←→分类 · Enter进入 · ↑↓条目 · PgUp/PgDn滚动 · Esc返回",Rect2(16,size.y-48,size.x-32,32),15)
	queue_redraw()

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]:
		if selecting: selecting=false; refresh()
		else: back_requested.emit()
	elif not selecting and key in [KEY_LEFT,KEY_RIGHT]: category=posmod(category+(-1 if key==KEY_LEFT else 1),5); index=0; refresh()
	elif not selecting and key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE] and enabled(category): selecting=true; refresh()
	elif selecting and key in [KEY_UP,KEY_DOWN] and not entries.is_empty():
		index=posmod(index+(-1 if key==KEY_UP else 1),entries.size())
		for i in _buttons.size(): _buttons[i].modulate=Color("a9ffe1") if i==index else Color.WHITE
		var texts: Variant=RuntimeState.custom_data.gameplay().rules.storage.get("note_desc",{}).get(str(category))
		description=str(texts.get(str(index),"")) if texts is Dictionary else ""; _text.text=description
	elif key in [KEY_PAGEUP,KEY_PAGEDOWN] and _text!=null:
		var bar=_text.get_v_scroll_bar(); bar.value+=(-1 if key==KEY_PAGEUP else 1)*bar.page

func _label(text: String,rect: Rect2,font_size: int=17) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); _content.add_child(label)

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
