@tool
extends RefCounted
## Virtual vertical layout; textures remain separate and shared read-only.
var segments: Array=[]
var errors: Array[String]=[]
var tile_count=0

static func sources(definition: Dictionary, loader: Callable) -> Array:
	if definition.get("tileset_sources") is Array: return definition.tileset_sources.duplicate(true)
	var name=str(definition.get("tileset_name","")); var texture: Texture2D=loader.call(name) if not name.is_empty() else null
	var rows=int(texture.get_height()/32) if texture!=null else maxi(0,int((definition.get("passages",{}).get("values",[]).size()-384)/8))
	return [{"key":"legacy","name":name,"rows":rows}] if not name.is_empty() or rows>0 else []

func configure(definition: Dictionary, loader: Callable) -> void:
	segments.clear(); errors.clear(); tile_count=0
	for record in sources(definition,loader):
		if not record is Dictionary: errors.append("组合素材记录无效。"); continue
		var row_value: Variant=record.get("rows",0)
		if not (row_value is int or row_value is float) or not is_finite(float(row_value)) or float(row_value)!=floor(float(row_value)) or int(row_value)<0 or int(row_value)*8+tile_count>32768-384: errors.append("组合素材行数无效。"); continue
		var name=str(record.get("name","")); var rows=int(row_value); var texture: Texture2D=loader.call(name) if not name.is_empty() else null
		if texture==null: errors.append("素材未加载："+name)
		elif texture.get_width()!=256 or texture.get_height()!=rows*32: errors.append("素材尺寸变化，请在组合素材窗口重新选择："+name)
		segments.append({"key":str(record.get("key","")),"name":name,"rows":rows,"first":384+tile_count,"end":384+tile_count+rows*8,"texture":texture})
		tile_count+=rows*8

func locate(id: int) -> Dictionary:
	for segment in segments:
		if id<int(segment.first) or id>=int(segment.end): continue
		var local=id-int(segment.first); var region=Rect2((local%8)*32,int(local/8)*32,32,32)
		var texture: Texture2D=segment.texture
		if texture==null or region.end.y>texture.get_height() or region.end.x>texture.get_width(): return {}
		return {"texture":texture,"region":region,"name":segment.name,"key":segment.key}
	return {}

func tile_texture(id: int) -> Texture2D:
	var found=locate(id)
	if found.is_empty(): return null
	var atlas=AtlasTexture.new(); atlas.atlas=found.texture; atlas.region=found.region; return atlas
