extends Control
## Source 0144/0145 existing CD animation and unfinished merit sample book.
const Cache=preload("RmxpCache.gd")
const Resources=preload("UIResources.gd")
signal back_requested
var kind="music"
var index=0
var book=false
var progress=22
var old_index=0
var angle=0.0
var playing=false
var _clock=0.0
var _content: Control

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); resized.connect(refresh); refresh()

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_label("音乐鉴赏" if kind=="music" else "成就一览",Rect2(24,20,size.x-48,36),24)
	if kind=="music":
		_label("%02d / 10" % (index+1),Rect2(24,72,size.x-48,32),20)
		var filename="res://legacy/extras/Info/Music/%03d.txt" % index
		var description=FileAccess.get_file_as_string(filename) if FileAccess.file_exists(filename) else ""
		var text=RichTextLabel.new(); text.text=description; text.position=Vector2(32,size.y-224); text.size=Vector2(size.x-64,144); text.add_theme_font_override("normal_font",Resources.font()); text.add_theme_font_size_override("normal_font_size",18); _content.add_child(text)
	elif book:
		# The final source creates this repeated sample; no claim/unlock/reward call.
		for row in 4:
			_label("通过考试",Rect2(176,112+row*96,size.x-200,32),22)
			_label("和艾蕾两人成功通过入会考试",Rect2(176,144+row*96,size.x-200,28),17)
			_label("获得200金币",Rect2(112,172+row*96,size.x-136,24),14)
	else:
		for id in 4:
			var button=Button.new(); button.text=["剧情","探索","挑战","其他"][id]; button.position=Vector2(48+id%2*(size.x-96)/2,176+int(id/2)*144); button.size=Vector2((size.x-96)/2-16,112); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",23); button.pressed.connect(func():index=id; book=true; refresh())
			var picture=Cache.title("merit/chap_%d.png" % id)
			if picture!=null: button.icon=picture; button.expand_icon=true
			if id==index: button.modulate=Color("fff0b7")
			_content.add_child(button)
	_label("↑↓浏览 · Esc返回" if kind=="music" else "←→选择 · Enter查看 · Esc返回",Rect2(24,size.y-56,size.x-48,36),16)
	queue_redraw()

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]:
		if book: book=false; refresh()
		else: back_requested.emit()
	elif kind=="music" and progress==28 and key in [KEY_UP,KEY_DOWN]:
		old_index=index; index=posmod(index+(-1 if key==KEY_UP else 1),10); progress=0; playing=false; refresh()
	elif kind=="merit" and not book:
		if key in [KEY_LEFT,KEY_RIGHT]: index=posmod(index+(-1 if key==KEY_LEFT else 1),4); refresh()
		elif key in [KEY_UP,KEY_DOWN]: index=1 if index>2 else 3; refresh()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: book=true; refresh()

func _process(delta: float) -> void:
	if kind!="music": return
	_clock+=delta*60; var count=mini(int(_clock),120); _clock-=count
	for i in count:
		if playing: angle+=1
		if progress<28: progress+=1; playing=progress==28
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("131e22"))
	if kind=="music":
		var cd=Cache.title("music/CD_1.png")
		if cd!=null:
			var center=Vector2(size.x/2,264)
			var slide=0.0 if progress>=23 else (22-progress)*20.0*(1 if index>old_index else -1) if progress>=7 else 320.0
			draw_set_transform(center+Vector2(slide,0),deg_to_rad(angle)); draw_texture(cd,-cd.get_size()/2); draw_set_transform(Vector2.ZERO)
		var pointer=Cache.title("music/point.png")
		if pointer!=null: draw_texture(pointer,Vector2(size.x/2,104))
	elif book:
		var medal=Cache.title("merit/medal.png")
		if medal!=null:
			for row in 4: draw_texture(medal,Vector2(112,112+row*96))

func _label(text: String,rect: Rect2,font_size: int) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); _content.add_child(label)
