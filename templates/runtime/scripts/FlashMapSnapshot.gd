extends RefCounted
## Source 0329 Map_Snapshot: first-page graphics, standard snapshot autotiles,
## M/U/T/A modes and PNG export, independent of the active scene and camera.
const Data=preload("RuntimeData.gd")
const Cache=preload("RmxpCache.gd")
var scale=1
var mode="M"
var output_directory="user://MapSnapshots"
var _tiles: Dictionary={}

func set_scale(value: int) -> bool:
	if value not in [1,2,4,8]: return false
	scale=value; return true
func set_mode(value: String) -> bool:
	if value not in ["M","U","T","A"]: return false
	mode=value; return true

func render(map_id: int) -> Dictionary:
	var definition=Data.map(map_id)
	if definition.is_empty(): return {"ok":false,"message":"航拍地图不存在。"}
	var size=Vector2i(int(definition.width)*32,int(definition.height)*32)
	if size.x<1 or size.y<1 or size.x>8192 or size.y>8192 or size.x*size.y>16*1024*1024: return {"ok":false,"message":"航拍地图超过图像预算。"}
	var map: Node=load("res://runtime/scripts/MapRuntime.gd").new()
	map.map_data=definition; map.tileset=Data.record("Tilesets",int(definition.tileset_id)); map._load_textures()
	_tiles={}
	var commands=[]; var lower=[]; var upper=[]
	for layer in 3:
		for y in int(definition.height):
			for x in int(definition.width):
				var id=map.tile_id(x,y,layer)
				if id<=0: continue
				var priority=map.tile_priority(id); var row={"id":id,"position":Vector2i(x*32,y*32),"z":priority*32+layer if mode=="M" else (y+priority)*32+32,"hue":0,"opacity":255,"blend":0,"order":commands.size()}
				commands.append(row)
				if priority==0: lower.append(row)
				else: upper.append(row)
	for key in definition.get("events",{}):
		var event: Dictionary=definition.events[key]
		if event.get("pages",[]).is_empty(): continue
		var page: Dictionary=event.pages[0]; var graphic: Dictionary=page.get("graphic",{})
		var id=int(graphic.get("tile_id",0)); var name=str(graphic.get("character_name",""))
		if id==0 and (name.is_empty() or mode in ["M","U"] or mode=="T" and int(page.get("move_type",0))!=0): continue
		var top=bool(page.get("always_on_top",false))
		var row={"id":id,"name":name,"graphic":graphic,"position":Vector2i(int(event.x)*32,int(event.y)*32),"z":(999 if top else 3) if mode=="M" else 32768 if top else int(event.y)*32+32,"hue":int(graphic.get("character_hue",0)),"opacity":int(graphic.get("opacity",255)),"blend":int(graphic.get("blend_type",0)),"order":commands.size()}
		commands.append(row)
		if not top and id>0: lower.append(row)
		else: upper.append(row)
	var images=[]
	var lists=[lower,upper] if mode=="U" else [commands]
	for rows in lists:
		rows.sort_custom(func(a,b): return a.order<b.order if a.z==b.z else a.z<b.z)
		var bitmap=preload("FlashBitmap.gd").new(); bitmap.image=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8); bitmap.image.fill(Color.TRANSPARENT)
		for row in rows:
			var source: Image
			var position: Vector2i=row.position
			if row.id>0: source=_tile(map,row.id)
			else:
				var texture=Cache.character(row.name)
				if texture==null: map.free(); return {"ok":false,"message":"航拍行走图缺失："+row.name}
				var width=int(texture.get_width()/4); var height=int(texture.get_height()/4)
				source=texture.get_image().get_region(Rect2i(int(row.graphic.get("pattern",0))*width,int((int(row.graphic.get("direction",2))-2)/2)*height,width,height)); position+=Vector2i(16-int(width/2),32-height)
			if source==null: map.free(); return {"ok":false,"message":"航拍图块素材缺失："+str(row.id)}
			if row.hue!=0:
				var scratch=preload("FlashBitmap.gd").new(); scratch.image=source.duplicate(); scratch.hue_change(row.hue); source=scratch.image
			if row.blend==0 and row.opacity==255: bitmap.image.blend_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),position)
			else: bitmap.blend_blt(position.x,position.y,source,Rect2i(Vector2i.ZERO,source.get_size()),row.blend,row.opacity)
		if mode!="U" and scale!=1: bitmap.image.resize(maxi(1,int(size.x/scale)),maxi(1,int(size.y/scale)),Image.INTERPOLATE_NEAREST)
		images.append(bitmap.image)
	map.free(); _tiles.clear()
	return {"ok":true,"images":images,"map_id":map_id}

func snap(map_id: int) -> Dictionary:
	if not output_directory.begins_with("user://") and not output_directory.begins_with("res://.godot/"): return {"ok":false,"message":"航拍输出必须位于用户目录。"}
	var result=render(map_id)
	if not result.ok: return result
	if DirAccess.make_dir_recursive_absolute(output_directory)!=OK: return {"ok":false,"message":"无法创建航拍目录。"}
	var paths=[]
	for i in result.images.size():
		var path=output_directory.path_join("Map%03d%s.png" % [map_id,"[U]" if i==1 else ""])
		if result.images[i].save_png(path)!=OK: return {"ok":false,"message":"航拍PNG写入失败。"}
		paths.append(ProjectSettings.globalize_path(path))
	return {"ok":true,"paths":paths}
func snaps(ids: Array) -> Dictionary:
	var results=[]
	for id in ids:
		if not id is int: return {"ok":false,"message":"航拍地图编号必须是整数。"}
		var result=snap(id)
		if not result.ok: return result
		results.append(result)
	return {"ok":true,"results":results}
func snap_all() -> Dictionary:
	var ids=[]
	for name in Data.manifest().get("maps",[]): ids.append(int(str(name).trim_prefix("Map").trim_suffix(".json")))
	return snaps(ids)
func _tile(map: Node,id: int) -> Image:
	if _tiles.has(id): return _tiles[id]
	var image: Image
	if id>=384:
		var texture=map.tile_texture(id)
		if texture!=null: image=texture.get_image()
	else:
		var slot=int(id/48)-1
		if slot<0 or slot>=7 or map._autotile_textures[slot]==null: return null
		var original: Image=map._autotile_textures[slot].get_image()
		image=Image.create(32,32,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
		if original.get_height()==32: image.blit_rect(original,Rect2i(0,0,32,32),Vector2i.ZERO)
		else:
			var parts: Array=map.AUTOTILE_PARTS[id%48]
			for quadrant in 4:
				var part=int(parts[quadrant])-1
				image.blit_rect(original,Rect2i(part%6*16,int(part/6)*16,16,16),Vector2i(quadrant%2*16,int(quadrant/2)*16))
	_tiles[id]=image; return image
