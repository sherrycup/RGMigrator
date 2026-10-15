extends Control
## Source 0143: three pages; four working settings and an empty fifth row.
const Resources=preload("UIResources.gd")
signal back_requested
var page="flash_config"
var sheet=1
var index=0
var _content: Control
var _buttons: Array[Button]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RuntimeState.flash_preferences.changed.connect(refresh); resized.connect(refresh); refresh()

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_buttons.clear()
	_label("游戏设置",Rect2(24,20,size.x-48,36),24)
	if sheet==1:
		var prefs=RuntimeState.flash_preferences
		var values=[str(prefs.bgm_volume)+" / 10",str(prefs.se_volume)+" / 10",["1 倍","1.25 倍","1.5 倍","无边框全屏"][prefs.window_resize],["标准模式","按一次切换"][prefs.run_mode],""]
		for row in 5:
			var button=Button.new(); button.text=["背景音乐","音效","窗口大小","奔跑按键设定",""][row]+"    "+values[row]; button.position=Vector2(32,112+row*64); button.size=Vector2(size.x-64,48); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",20)
			button.pressed.connect(func():index=row; adjust(1))
			if row==index: button.modulate=Color("a9ffe1")
			_content.add_child(button); _buttons.append(button)
		_label("Normal              Hard              Lunatic",Rect2(32,456,size.x-64,40),20)
	_label("%d / 3    ↑↓选择 · ←→调整 · Q/E翻页 · Esc返回" % sheet,Rect2(24,size.y-64,size.x-48,40),16)
	queue_redraw()

func adjust(direction: int) -> void:
	if sheet!=1: return
	var prefs=RuntimeState.flash_preferences
	if index in [0,1]: prefs.set_volume("bgm" if index==0 else "se",clampi((prefs.bgm_volume if index==0 else prefs.se_volume)+direction,0,10))
	elif index==2: prefs.change_window_size(direction)
	elif index==3: prefs.next_run_mode()

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: back_requested.emit()
	elif key in [KEY_Q,KEY_E]: sheet=posmod(sheet-1+(-1 if key==KEY_Q else 1),3)+1; index=0; refresh()
	elif key in [KEY_UP,KEY_DOWN]:
		index=posmod(index+(-1 if key==KEY_UP else 1),5 if sheet==1 else 1)
		for i in _buttons.size(): _buttons[i].modulate=Color("a9ffe1") if i==index else Color.WHITE
	elif key in [KEY_LEFT,KEY_RIGHT]: adjust(-1 if key==KEY_LEFT else 1)

func _label(text: String,rect: Rect2,font_size: int) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); _content.add_child(label)

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
