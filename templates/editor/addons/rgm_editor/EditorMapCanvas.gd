@tool
extends Control
const Ops = preload("EditorMapOps.gd")
const Layout=preload("res://runtime/scripts/TilesetLayout.gd")
signal cell_pressed(cell: Vector2i, double_click: bool, button: int)
signal cell_dragged(cell: Vector2i)
signal stroke_finished
signal tile_selected(id: int)
signal brush_selected(tiles: Array)
signal cell_hovered(cell: Vector2i)
signal zoom_changed(value: float)
const AUTOTILE_PARTS := [
	[27, 28, 33, 34], [5, 28, 33, 34], [27, 6, 33, 34], [5, 6, 33, 34],
	[27, 28, 33, 12], [5, 28, 33, 12], [27, 6, 33, 12], [5, 6, 33, 12],
	[27, 28, 11, 34], [5, 28, 11, 34], [27, 6, 11, 34], [5, 6, 11, 34],
	[27, 28, 11, 12], [5, 28, 11, 12], [27, 6, 11, 12], [5, 6, 11, 12],
	[25, 26, 31, 32], [25, 6, 31, 32], [25, 26, 31, 12], [25, 6, 31, 12],
	[15, 16, 21, 22], [15, 16, 21, 12], [15, 16, 11, 22], [15, 16, 11, 12],
	[29, 30, 35, 36], [29, 30, 11, 36], [5, 30, 35, 36], [5, 30, 11, 36],
	[39, 40, 45, 46], [5, 40, 45, 46], [39, 6, 45, 46], [5, 6, 45, 46],
	[25, 30, 31, 36], [15, 16, 45, 46], [13, 14, 19, 20], [13, 14, 19, 12],
	[17, 18, 23, 24], [17, 18, 11, 24], [41, 42, 47, 48], [5, 42, 47, 48],
	[37, 38, 43, 44], [37, 6, 43, 44], [13, 18, 19, 24], [13, 14, 43, 44],
	[37, 42, 43, 48], [17, 18, 47, 48], [13, 18, 43, 48], [13, 18, 43, 48]
]
var _map: Dictionary = {}
var _documents: RefCounted
var _tileset: Dictionary = {}
var _texture: Texture2D
var _autotiles: Array = []
var _palette = false
var _palette_ids: Array = []
var _zoom = 1.0
var _origin = Vector2(16,16)
var _panning = false
var _drawing = false
var _selected = Vector2i(-1,-1)
var _selected_id = 0
var _layer = 0
var _event_mode=false
var _hidden_layers: Array=[]
var _normal_layout: RefCounted
var _marker_mode=""
var _continuous_select=false
var _region = Rect2i()
var _start = Vector2i(-1,-1)
var _characters: Dictionary = {}
var _palette_start = Vector2i.ZERO
var _palette_region = Rect2i(Vector2i.ZERO,Vector2i.ONE)
var _multi_select = true
var _brush: Array = [[0]]
var _show_brush = true
var _hover = Vector2i(-1,-1)

func configure(map: Dictionary, documents: RefCounted, palette: bool = false) -> void:
	_map = map
	_hidden_layers=map.get("_editor_hidden_layers",[])
	_documents = documents
	_palette = palette
	_multi_select = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sets: Array = documents.records("Tilesets")
	var id = int(map.get("tileset_id",0))
	_tileset = sets[id] if id < sets.size() and sets[id] is Dictionary else {}
	_set_tileset(_tileset)
	var system: Variant = documents.read("data/system.json")
	_start = Vector2i(int(system.get("start_x",0)),int(system.get("start_y",0))) if system is Dictionary and int(system.get("start_map_id",-1)) == int(map.get("_editor_map_id",0)) else Vector2i(-1,-1)
	_characters.clear()
	for event in map.get("events",{}).values():
		for page in event.get("pages",[]):
			var name = str(page.get("graphic",{}).get("character_name",""))
			if not name.is_empty() and not _characters.has(name): _characters[name] = documents.asset_texture("Characters",name)
	queue_redraw()

func configure_tileset(tileset: Dictionary, documents: RefCounted) -> void:
	_documents=documents; _map={}; _palette=true; _multi_select=false; _tileset=tileset.duplicate(true)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; clip_contents=true; mouse_filter=Control.MOUSE_FILTER_STOP
	_set_tileset(_tileset); queue_redraw()

func _set_tileset(tileset: Dictionary) -> void:
	_tileset=tileset
	_texture = _documents.asset_texture("Tilesets",str(_tileset.get("tileset_name","")))
	_normal_layout=Layout.new(); _normal_layout.configure(_tileset,func(name: String) -> Texture2D: return _documents.asset_texture("Tilesets",name))
	_autotiles.clear()
	for name in _tileset.get("autotile_names",[]): _autotiles.append(_documents.asset_texture("Autotiles",str(name)))
	_palette_ids = [0,48,96,144,192,240,288,336]
	for i in _normal_layout.tile_count: _palette_ids.append(384+i)
	if _palette:
		_origin = Vector2.ZERO
		custom_minimum_size = Vector2(256,ceil(float(_palette_ids.size())/8)*32)*_zoom

func set_palette_zoom(value: float) -> void:
	_zoom=clampf(value,1.0,2.0)
	if _palette: custom_minimum_size=Vector2(256,ceil(float(_palette_ids.size())/8)*32)*_zoom
	queue_redraw()

func set_layer(layer: int) -> void:
	_layer = layer
	_event_mode=layer>=Ops.layer_count(_map)
	queue_redraw()

func set_event_mode(enabled: bool) -> void:
	_event_mode=enabled; queue_redraw()

func set_property_mode(mode: String) -> void:
	_marker_mode=mode; _continuous_select=not mode.is_empty(); queue_redraw()

func set_zoom(value: float) -> void:
	var before = (size/2-_origin)/_zoom
	_zoom = clampf(value,0.25,3.0)
	_origin = size/2-before*_zoom
	zoom_changed.emit(_zoom); queue_redraw()

func reset_view() -> void:
	_origin=Vector2(16,16); _selected=Vector2i(-1,-1); _hover=Vector2i(-1,-1); _region=Rect2i()
	queue_redraw()

func update_map(map: Dictionary) -> void:
	_map=map
	queue_redraw()

func set_brush(tiles: Array, visible_brush: bool = true) -> void:
	_brush=tiles.duplicate(true); _show_brush=visible_brush
	queue_redraw()

func finish_input() -> void:
	_drawing=false

func palette_region() -> Rect2i:
	return _palette_region

func select_cell(cell: Vector2i) -> void:
	_selected = cell
	queue_redraw()

func select_tile(id: int) -> void:
	_selected_id = id
	var normalized = int(id/48)*48 if id>=48 and id<384 else id
	var index = _palette_ids.find(normalized)
	_palette_region=Rect2i(Vector2i(index%8,int(index/8)),Vector2i.ONE) if index>=0 else Rect2i()
	queue_redraw()

func focus_cell(cell: Vector2i) -> void:
	_selected = cell
	_origin = size/2-Vector2(cell*32)*_zoom
	queue_redraw()

func set_region(region: Rect2i) -> void:
	_region = region
	queue_redraw()

func _cell_at(position: Vector2) -> Vector2i:
	return Vector2i(floor((position.x-_origin.x)/(32*_zoom)),floor((position.y-_origin.y)/(32*_zoom)))

func _select_palette(cell: Vector2i) -> void:
	if _palette_ids.is_empty(): return
	cell=Vector2i(clampi(cell.x,0,7),clampi(cell.y,0,int((_palette_ids.size()-1)/8)))
	if not _multi_select: _palette_start=cell
	var first = Vector2i(mini(cell.x,_palette_start.x),mini(cell.y,_palette_start.y))
	_palette_region=Rect2i(first,Vector2i(absi(cell.x-_palette_start.x)+1,absi(cell.y-_palette_start.y)+1))
	var brush: Array = []
	for y in range(_palette_region.position.y,_palette_region.end.y):
		var row: Array = []
		for x in range(_palette_region.position.x,_palette_region.end.x): row.append(int(_palette_ids[x+y*8]))
		brush.append(row)
	_selected_id=int(brush[0][0]); tile_selected.emit(_selected_id); brush_selected.emit(brush); queue_redraw()

func _input(event: InputEvent) -> void:
	# Release captured outside the canvas still closes the single undo transaction.
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_MIDDLE: _panning=false
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and _drawing:
		_drawing=false
		if not _palette or _continuous_select: stroke_finished.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE and not _palette:
			if _drawing: _drawing=false; stroke_finished.emit()
			_panning=event.pressed; accept_event(); return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not _palette:
			if event.pressed:
				var before = (event.position-_origin)/_zoom
				_zoom=clampf(_zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2),0.25,3)
				_origin=event.position-before*_zoom
				_hover=_cell_at(event.position); zoom_changed.emit(_zoom); queue_redraw()
			accept_event(); return
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			var cell = _cell_at(event.position)
			if _palette:
				var index = cell.x+cell.y*8
				if event.pressed and cell.x in range(8) and index>=0 and index<_palette_ids.size():
					_palette_start=cell; _drawing=(_multi_select or _continuous_select) and event.button_index==MOUSE_BUTTON_LEFT; _select_palette(cell)
				elif not event.pressed and _drawing:
					_drawing=false
					if _continuous_select: stroke_finished.emit()
			elif event.pressed and Ops.valid(_map,cell):
				_selected=cell; _hover=cell; _drawing=event.button_index==MOUSE_BUTTON_LEFT
				cell_pressed.emit(cell,event.double_click,event.button_index); queue_redraw()
			elif not event.pressed and _drawing: _drawing=false; stroke_finished.emit()
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning: _origin+=event.relative; queue_redraw(); accept_event()
		elif _palette:
			if _drawing:
				var next=_cell_at(event.position)
				next=Vector2i(clampi(next.x,0,7),clampi(next.y,0,int((_palette_ids.size()-1)/8)))
				if _continuous_select:
					for cell in Ops.line_cells(_palette_start,next): _select_palette(cell)
				else: _select_palette(next)
				accept_event()
		else:
			var cell = _cell_at(event.position)
			_hover=cell if Ops.valid(_map,cell) else Vector2i(-1,-1)
			if _drawing and Ops.valid(_map,cell) and cell!=_selected: _selected=cell; cell_dragged.emit(cell)
			elif not _drawing and Ops.valid(_map,cell): cell_hovered.emit(cell)
			queue_redraw()

func _notification(what: int) -> void:
	if what==NOTIFICATION_ENTER_TREE: set_notify_transform(true)
	if what==NOTIFICATION_TRANSFORM_CHANGED and _palette: queue_redraw()
	if what==NOTIFICATION_MOUSE_EXIT: _hover=Vector2i(-1,-1); queue_redraw()
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_panning=false
		if _drawing: _drawing=false; stroke_finished.emit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("202735"))
	if _palette:
		var exposed=_palette_visible_rect(); var extent=32*_zoom
		var first=Vector2i(clampi(int(floor(exposed.position.x/extent)),0,7),maxi(0,int(floor(exposed.position.y/extent))))
		var last=Vector2i(clampi(int(ceil(exposed.end.x/extent)),0,8),mini(int(ceil(exposed.end.y/extent)),int(ceil(_palette_ids.size()/8.0))))
		if not exposed.has_area(): return
		for y in range(first.y,last.y):
			for x in range(first.x,last.x):
				_draw_palette_tile(x+y*8)
		if _palette_region.has_area():
			draw_rect(Rect2(Vector2(_palette_region.position*32)*_zoom,Vector2(_palette_region.size*32)*_zoom),Color("ffd56a"),false,3)
		return
	_draw_map()

func _palette_visible_rect() -> Rect2:
	var exposed=Rect2(Vector2.ZERO,size); var ancestor=get_parent(); var inverse=get_global_transform().affine_inverse()
	while ancestor is Control:
		if ancestor.clip_contents or ancestor is ScrollContainer:
			if not ancestor.resized.is_connected(queue_redraw): ancestor.resized.connect(queue_redraw)
			if ancestor is ScrollContainer:
				for bar in [ancestor.get_v_scroll_bar(),ancestor.get_h_scroll_bar()]:
					if not bar.value_changed.is_connected(_palette_scrolled): bar.value_changed.connect(_palette_scrolled)
			var bounds: Rect2=ancestor.get_global_rect()
			exposed=exposed.intersection(Rect2(inverse*bounds.position,(inverse*bounds.end)-(inverse*bounds.position)))
		ancestor=ancestor.get_parent()
	return exposed

func _palette_scrolled(_value: float) -> void:
	queue_redraw()

func _draw_palette_tile(i: int) -> void:
	if i<0 or i>=_palette_ids.size(): return
	var pos = Vector2(i%8,int(i/8))*32*_zoom
	draw_tile(int(_palette_ids[i]),pos,_zoom)
	draw_rect(Rect2(pos,Vector2(32,32)*_zoom),Color(1,1,1,0.15),false)
	if int(_palette_ids[i])==0: _marker_text("空",pos,Color("b2bdd0"))
	elif not _marker_mode.is_empty(): _draw_marker(int(_palette_ids[i]),pos)

func _draw_map() -> void:
	if _map.is_empty(): return
	var begin = Vector2i(maxi(0,int(-_origin.x/(32*_zoom))),maxi(0,int(-_origin.y/(32*_zoom))))
	var end = Vector2i(mini(int(_map.width),int((size.x-_origin.x)/(32*_zoom))+1),mini(int(_map.height),int((size.y-_origin.y)/(32*_zoom))+1))
	var map_rect = Rect2(_origin,Vector2(int(_map.width)*32,int(_map.height)*32)*_zoom)
	draw_rect(map_rect,Color("303c4f"))
	draw_rect(map_rect,Color("8392ab"),false,2)
	var foreground: Array = []
	for z in Ops.layer_count(_map):
		if z in _hidden_layers: continue
		for y in range(begin.y,end.y):
			for x in range(begin.x,end.x):
				var id = Ops.tile(_map,Vector2i(x,y),z)
				var priority = _priority(id)
				var pos = _origin+Vector2(x*32,y*32)*_zoom
				if priority > 0: foreground.append({"depth":y+priority-0.5,"tile":id,"pos":pos})
				else: draw_tile(id,pos,_zoom)
	for event in _map.get("events",{}).values():
		foreground.append({"depth":float(event.y)+0.5,"event":event})
	foreground.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.depth<b.depth)
	for entry in foreground:
		if entry.has("tile"): draw_tile(entry.tile,entry.pos,_zoom)
		else: _draw_event(entry.event)
	for y in range(begin.y,end.y+1): draw_line(_origin+Vector2(begin.x*32,y*32)*_zoom,_origin+Vector2(end.x*32,y*32)*_zoom,Color(1,1,1,0.12))
	for x in range(begin.x,end.x+1): draw_line(_origin+Vector2(x*32,begin.y*32)*_zoom,_origin+Vector2(x*32,end.y*32)*_zoom,Color(1,1,1,0.12))
	for event in _map.get("events",{}).values():
		var pos = _origin+Vector2(float(event.x)*32,float(event.y)*32)*_zoom
		draw_rect(Rect2(pos,Vector2(32,32)*_zoom),Color("70b9ff"),false,1)
		if _event_mode: draw_string(ThemeDB.fallback_font,pos+Vector2(2,12),str(int(event.id)),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
	if _start.x >= 0:
		var pos = _origin+Vector2(_start*32)*_zoom
		draw_rect(Rect2(pos,Vector2(32,32)*_zoom),Color("55dd88"),false,2)
		draw_string(ThemeDB.fallback_font,pos+Vector2(2,28),"起",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("55dd88"))
	if _region.has_area(): draw_rect(Rect2(_origin+Vector2(_region.position*32)*_zoom,Vector2(_region.size*32)*_zoom),Color.YELLOW,false,2)
	if _selected.x>=0 and _event_mode: draw_rect(Rect2(_origin+Vector2(_selected*32)*_zoom,Vector2(32,32)*_zoom),Color.YELLOW,false,2)
	if _hover.x>=0 and not _event_mode and not _layer in _hidden_layers:
		var brush_size = Vector2i(_brush[0].size(),_brush.size()) if _show_brush and not _brush.is_empty() else Vector2i.ONE
		var brush_rect = Rect2(_origin+Vector2(_hover*32)*_zoom,Vector2(brush_size*32)*_zoom)
		if _show_brush and not _region.has_area():
			for y in _brush.size():
				for x in _brush[y].size():
					if Ops.valid(_map,_hover+Vector2i(x,y)): draw_tile(int(_brush[y][x]),brush_rect.position+Vector2(x*32,y*32)*_zoom,_zoom,0.55)
		draw_rect(brush_rect,Color(1,0.85,0.4,0.12)); draw_rect(brush_rect,Color("ffd56a"),false,2)

func draw_tile(id: int,pos: Vector2,scale_value: float, opacity: float = 1.0) -> void:
	if id <= 0: return
	if id >= 384 and _normal_layout!=null:
		var found: Dictionary=_normal_layout.locate(id)
		if not found.is_empty(): draw_texture_rect_region(found.texture,Rect2(pos,Vector2(32,32)*scale_value),found.region,Color(1,1,1,opacity))
	elif id >= 48 and id < 384:
		var slot = int(id/48)-1
		if slot >= _autotiles.size() or _autotiles[slot] == null: return
		var texture: Texture2D = _autotiles[slot]
		if texture.get_height()==32: draw_texture_rect_region(texture,Rect2(pos,Vector2(32,32)*scale_value),Rect2(0,0,32,32),Color(1,1,1,opacity)); return
		for q in 4:
			var part = int(AUTOTILE_PARTS[id%48][q])-1
			draw_texture_rect_region(texture,Rect2(pos+Vector2(q%2,int(q/2))*16*scale_value,Vector2(16,16)*scale_value),Rect2((part%6)*16,int(part/6)*16,16,16),Color(1,1,1,opacity))

func _priority(id: int) -> int:
	var values: Array = _tileset.get("priorities",{}).get("values",[])
	return int(values[id]) if id>=0 and id<values.size() else 0

func _draw_marker(id: int, pos: Vector2) -> void:
	var flags: Array=_tileset.get("passages",{}).get("values",[]); var bits=int(flags[id]) if id<flags.size() else 0
	var extent=32*_zoom; var center=pos+Vector2.ONE*extent/2; var line_width=maxf(2,extent/16)
	draw_rect(Rect2(pos,Vector2.ONE*extent),Color(0,0,0,0.52))
	var text=""; var color=Color.WHITE
	match _marker_mode:
		"passages":
			color=Color("ff8d88") if (bits&15)==15 else Color("a3edb2")
			var radius=extent*0.28
			if (bits&15)==0: draw_arc(center,radius,0,TAU,48,color,line_width,true)
			elif (bits&15)==15:
				draw_line(center-Vector2.ONE*radius,center+Vector2.ONE*radius,color,line_width,true)
				draw_line(center+Vector2(-radius,radius),center+Vector2(radius,-radius),color,line_width,true)
			else: draw_polyline(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,radius),center+Vector2(-radius,radius),center+Vector2(0,-radius)]),color,line_width,true)
			return
		"directions":
			for entry in [[1,Vector2.DOWN],[2,Vector2.LEFT],[4,Vector2.RIGHT],[8,Vector2.UP]]:
				var direction: Vector2=entry[1]; var tip=center+direction*extent*0.36; var tail=center+direction*extent*0.13
				var side=Vector2(-direction.y,direction.x)*extent*0.10
				color=Color("ff8d88") if (bits&int(entry[0]))!=0 else Color("a3edb2")
				draw_line(tail,tip,color,line_width,true)
				draw_polyline(PackedVector2Array([tip-direction*extent*0.12+side,tip,tip-direction*extent*0.12-side]),color,line_width,true)
			return
		"priorities":
			var number=str(_priority(id)); var font=ThemeDB.fallback_font; var font_size=maxi(12,int(round(extent*0.42)))
			var measured=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
			var radius=extent*0.23; var half_width=radius*sin(PI*0.4); var gap=extent*0.03
			var left=center.x-(half_width*2+gap+measured.x)/2
			var points=PackedVector2Array(); var star=Vector2(left+half_width,center.y+radius*(1-cos(PI/5))/2)
			for index in 10:
				var angle=-PI/2+index*PI/5; var point_radius=radius if index%2==0 else extent*0.10
				points.append(star+Vector2(cos(angle),sin(angle))*point_radius)
			draw_colored_polygon(points,Color("ffe198"))
			draw_string(font,Vector2(left+half_width*2+gap,pos.y+(extent-font.get_height(font_size))/2+font.get_ascent(font_size)),number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("ffe198"))
			return
		"bush": text="草" if (bits&64)!=0 else "·"
		"counter": text="柜" if (bits&128)!=0 else "·"
		"terrain_tags":
			text=terrain_text(id)
	_marker_text(text,pos,color)

func _marker_text(text: String, pos: Vector2, color: Color, ratio: float = 0.60) -> void:
	var extent=32*_zoom; var font=ThemeDB.fallback_font; var font_size=maxi(12,int(round(extent*ratio)))
	var measured=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var baseline=pos+Vector2((extent-measured.x)/2,(extent-font.get_height(font_size))/2+font.get_ascent(font_size))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func terrain_text(id: int) -> String:
	# JSON numbers arrive as floats, while native terrain tags are integers.
	var tags: Array=_tileset.get("terrain_tags",{}).get("values",[])
	return str(int(tags[id])) if id>=0 and id<tags.size() else "0"

func _draw_event(event: Dictionary) -> void:
	var pages: Array = event.get("pages",[])
	if pages.is_empty(): return
	# Editor preview selects the first page, without evaluating live switches.
	var graphic: Dictionary = pages[0].get("graphic",{})
	var pos = _origin+Vector2(float(event.x)*32,float(event.y)*32)*_zoom
	if int(graphic.get("tile_id",0))>0: draw_tile(int(graphic.tile_id),pos,_zoom); return
	var texture: Texture2D = _characters.get(str(graphic.get("character_name","")))
	if texture==null: return
	var frame = Vector2(texture.get_width()/4.0,texture.get_height()/4.0)
	var region = Rect2(Vector2(int(graphic.get("pattern",0))*frame.x,(int(graphic.get("direction",2))/2-1)*frame.y),frame)
	var dest = Rect2(pos+Vector2((32-frame.x)/2,32-frame.y)*_zoom,frame*_zoom)
	draw_texture_rect_region(texture,dest,region,Color(1,1,1,float(graphic.get("opacity",255))/255))
