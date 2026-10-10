@tool
extends RefCounted
const Layout=preload("res://runtime/scripts/TilesetLayout.gd")
const Schema=preload("EditorDatabaseSchema.gd")

static func prepare(documents: RefCounted, id: int, before: Dictionary, value: Dictionary) -> Dictionary:
	var reason=Schema.reason("Tilesets",value,before,documents)
	if not reason.is_empty(): return {"ok":false,"message":reason}
	var loader: Callable=func(name: String) -> Texture2D: return documents.asset_texture("Tilesets",name)
	var old=Layout.new(); old.configure(before,loader)
	var next=Layout.new(); next.configure(value,loader)
	if value.has("tileset_sources"):
		var seen: Dictionary={}
		for source in value.tileset_sources:
			if not source is Dictionary or str(source.get("key"," ")).strip_edges().is_empty() or seen.has(str(source.key)): return {"ok":false,"message":"组合素材的标识须唯一。"}
			seen[str(source.key)]=true
		if not next.errors.is_empty(): return {"ok":false,"message":"；".join(next.errors)}
	var changed=false; var mapping: Dictionary={}
	for segment in old.segments:
		var target: Dictionary={}
		for candidate in next.segments:
			if candidate.key==segment.key: target=candidate; break
		for tile in range(int(segment.first),int(segment.end)):
			var offset=tile-int(segment.first); var dest=int(target.first)+offset if not target.is_empty() and offset<int(target.end)-int(target.first) else -1
			mapping[tile]=dest; changed=changed or tile!=dest
	var edited=value.duplicate(true)
	if changed:
		for field in ["passages","priorities","terrain_tags"]:
			var table: Dictionary=edited[field].duplicate(true); var original: Array=value[field].values
			var values: Array=[]; values.resize(384+next.tile_count); values.fill(0)
			for tile in mini(384,original.size()): values[tile]=original[tile]
			for tile in mapping:
				if int(mapping[tile])>=0 and int(tile)<original.size(): values[int(mapping[tile])]=original[int(tile)]
			table.values=values; table.x_size=values.size(); table.y_size=1; table.z_size=1; table.dimensions=1; edited[field]=table
	else:
		for field in ["passages","priorities","terrain_tags"]:
			var table: Dictionary=edited[field]; var length=maxi(384+next.tile_count,table.values.size())
			if table.values.size()<length:
				while table.values.size()<length: table.values.append(0)
				table.x_size=length; table.y_size=1; table.z_size=1; table.dimensions=1
	var changes: Dictionary={}
	if changed:
		var manifest: Dictionary=documents.read("data/manifest.json")
		for name in manifest.get("maps",[]):
			var path="data/maps/"+str(name)+".json"; var map: Variant=documents.read(path)
			if not map is Dictionary: return {"ok":false,"message":"无法读取地图："+path}
			if int(map.get("tileset_id",0))!=id: continue
			var original=map.duplicate(true)
			for i in map.data.values.size():
				var tile=int(map.data.values[i])
				if tile<384: continue
				if not mapping.has(tile) or int(mapping[tile])<0: return {"ok":false,"message":"%s仍使用图块%d，不能移除该素材或裁去该行。" % [str(name),tile]}
				map.data.values[i]=mapping[tile]
			for event in map.get("events",{}).values():
				for page in event.get("pages",[]):
					var tile=int(page.get("graphic",{}).get("tile_id",0))
					if tile<384: continue
					if not mapping.has(tile) or int(mapping[tile])<0: return {"ok":false,"message":"%s事件%d仍使用图块%d，不能移除该素材或裁去该行。" % [str(name),int(event.id),tile]}
					page.graphic.tile_id=mapping[tile]
			if map!=original: changes[path]=map
	var records: Array=documents.records("Tilesets"); records[id]=edited; changes["data/database/Tilesets.json"]=records
	return {"ok":true,"changes":changes,"value":edited}
