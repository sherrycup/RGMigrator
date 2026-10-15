extends RefCounted
## 0149/0151/0153/0155: measured rows, names, faces and source anchor geometry.
const Text=preload("FlashMessageText.gd")
const Cache=preload("RmxpCache.gd")
var positions: Dictionary={}
var rows: Array=[]
var box_size=Vector2.ZERO
var text_origin=Vector2(8,32)
var text_size=Vector2.ZERO
var name_text=""
var face_name=""
var face_index=0
var anchor_event=0
var fixed_anchor: Variant=null
var failure=""

func _init(model: RefCounted,owner: Object,viewport_size: Vector2) -> void:
	name_text=str(model.metadata.get("m","")); face_name=str(model.metadata.get("f",""))
	if model.metadata.has("fg"):
		var face_args=str(model.metadata.fg).rsplit(",",true,1)
		if face_args.size()!=2 or not face_args[1].strip_edges().is_valid_int(): failure="消息头像分组参数无效。"; return
		face_name=face_args[0]; face_index=int(face_args[1])
	if not face_name.is_empty() and (Cache.face(face_name)==null or face_index<0): failure="消息头像缺失或分组无效："+face_name; return
	if model.metadata.has("p"):
		var args=str(model.metadata.p).split(",",true)
		if args.size()<1 or args.size()>2: failure="消息位置参数无效。"; return
		for argument in args:
			if not argument.strip_edges().is_valid_int(): failure="消息位置需要整数坐标或事件ID。"; return
		if args.size()==2: fixed_anchor=Vector2(int(args[0]),int(args[1]))
		else: anchor_event=int(args[0])
	text_origin=Vector2(112 if not face_name.is_empty() else 8,56 if not name_text.is_empty() else 32)
	var margin=120 if not face_name.is_empty() else 16
	var left=0 if owner.switches.get("6",false) else 224
	var maximum=maxf(48,viewport_size.x-left-margin)
	var style=Text.defaults(); var row={"indices":[],"width":0.0,"height":0.0,"space":4,"align":0,"valign":2}
	# MR cancels the following newline. Row-wide A/LS are removed before typing.
	var normalized: Array=[]; var merge_next=false
	for token in model.tokens:
		if token is Array and token[0].unicode_at(0)==18: merge_next=true; continue
		if token is String and token=="\n" and merge_next: merge_next=false; continue
		merge_next=false; normalized.append(token)
	model.tokens=normalized
	for index in model.tokens.size():
		var token: Variant=model.tokens[index]
		if token is String and token=="\n":
			rows.append(row); row={"indices":[],"width":0.0,"height":0.0,"space":4,"align":0,"valign":2}; continue
		if token is Array and token[0].unicode_at(0) in [27,28]:
			if token[0].unicode_at(0)==27: row.align=int(token[1]); row.valign=int(token[1])
			else: row.space=int(token[1])
			continue
		var advance=0.0; var height=0.0
		if token is String or token is Array and token[0].unicode_at(0)==2:
			var glyph=token if token is String else str(owner.custom_data.currency())+str(preload("RuntimeData.gd").system().get("words",{}).get("gold",""))
			var measured=Text.font(style).get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,int(style.font_size)); advance=measured.x; height=measured.y
		elif token is Array:
			var code=token[0].unicode_at(0)
			if code==17: break
			if code==24:
				var icon=Cache.icon(str(token[1]))
				if icon==null and not str(token[1]).is_empty(): failure="消息图标缺失："+str(token[1]); return
				advance=(icon.get_width() if icon!=null else 32)+4; height=icon.get_height() if icon!=null else 32
			elif code==22: advance=int(token[1])
			else: Text.apply_style(style,token)
		if advance>0 and row.width>0 and row.width+advance>maximum:
			rows.append(row); row={"indices":[],"width":0.0,"height":0.0,"space":row.space,"align":row.align,"valign":row.valign}
		positions[index]={"x":row.width,"height":height,"advance":advance}
		row.indices.append(index); row.width+=advance; row.height=maxf(row.height,height)
	if not row.indices.is_empty() or rows.is_empty(): rows.append(row)
	var width=0.0; var height=0.0
	for current in rows: width=maxf(width,current.width); height+=current.height+current.space
	width=maxf(width,96 if not name_text.is_empty() else 0)
	box_size=Vector2(maxf(32,width+margin),maxf(height+(38 if not name_text.is_empty() else 14),110 if not face_name.is_empty() else 32))
	text_size=Vector2(box_size.x-margin,box_size.y-14-(24 if not name_text.is_empty() else 0))
	var y=0.0
	for current in rows:
		y+=current.space/2.0
		var shift=(text_size.x-current.width)/(2 if current.align==1 else 1) if current.align in [1,2] else 0.0
		for index in current.indices:
			positions[index].x+=shift
			positions[index].y=y+((current.height-positions[index].height)/(2 if current.valign==1 else 1) if current.valign in [1,2] else 0)
			if model.tokens[index] is Array and model.tokens[index][0].unicode_at(0)==6: model.page_targets[index]=maxf(0,y-current.space/2.0)
		y+=current.height+current.space/2.0

func anchor(owner: Object) -> Vector2:
	if fixed_anchor!=null: return fixed_anchor
	var character=owner.player() if anchor_event==0 else owner.game().event_map().event_node(anchor_event) if owner.game()!=null else null
	if character==null: return Vector2(owner.player_x*32+16,owner.player_y*32)
	var height=character._texture.get_height()/4.0 if character._texture!=null and character._tile_id==0 else 32.0
	return character.get_global_transform_with_canvas().origin+Vector2(16,48-height)

func rectangle(owner: Object,viewport_size: Vector2,model: RefCounted) -> Rect2:
	var point=anchor(owner)+model.offset; var left=0.0 if owner.switches.get("6",false) else 224.0
	var x=point.x-box_size.x/2
	if model.mode()!=3: x=minf(maxf(x,left),viewport_size.x-box_size.x)
	var y=point.y-box_size.y-50 if point.y-box_size.y-25>0 else point.y
	return Rect2(Vector2(x,y),box_size)
