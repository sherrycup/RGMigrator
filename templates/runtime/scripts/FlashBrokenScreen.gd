extends RefCounted
## 0311 Broken_Screen. Preserve original 480x480 crop, x=160 start, corner
## subdivision and red-channel shard grouping; textures are owned per instance.
var shards: Array=[]
var ticks=0
var _rng=RandomNumberGenerator.new()
func configure(source: Image,mask: Image,seed_value: int=-1) -> Dictionary:
	if source==null or source.is_empty() or mask==null or mask.is_empty() or mask.get_width()<480 or mask.get_height()<480: return {"ok":false,"message":"碎屏蒙版须至少480×480，且截图有效。"}
	source=source.duplicate(); source.convert(Image.FORMAT_RGBA8)
	if seed_value<0: _rng.randomize()
	else: _rng.seed=seed_value
	var groups: Dictionary={}
	for y in range(0,480,240):
		for x in range(160,480,240): _split(Rect2i(x,y,mini(240,480-x),mini(240,480-y)),source,mask,groups,true)
	shards.clear(); ticks=0
	for key in groups:
		var group: Dictionary=groups[key]; var pos: Vector2=group.origin
		shards.append({"texture":ImageTexture.create_from_image(group.image),"origin":pos,"position":pos,"velocity":Vector2(_rng.randi_range(0,maxi(0,int(pos.x)-1))+20-_rng.randi_range(0,39),pos.y-208),"axis":_rng.randi_range(0,1),"scale":Vector2.ONE})
	return {"ok":true,"count":shards.size()}
func _split(rect: Rect2i,source: Image,mask: Image,groups: Dictionary,force_split: bool=false) -> void:
	var end=rect.end-Vector2i.ONE; var color=mask.get_pixelv(rect.position)
	if rect.size.x==1 and rect.size.y==1 or not force_split and color==mask.get_pixel(end.x,rect.position.y) and color==mask.get_pixel(rect.position.x,end.y) and color==mask.get_pixelv(end):
		var key=color.r8
		if not groups.has(key):
			var bitmap=Image.create(480,480,false,Image.FORMAT_RGBA8); bitmap.fill(Color.TRANSPARENT)
			groups[key]={"image":bitmap,"origin":Vector2(int((rect.position.x+rect.size.x)/2),int((rect.position.y+rect.size.y)/2))}
		var available=rect.intersection(Rect2i(Vector2i.ZERO,source.get_size()))
		if available.has_area(): groups[key].image.blit_rect(source,available,available.position)
		return
	var xhalf=maxi(1,int(rect.size.x/2)); var yhalf=maxi(1,int(rect.size.y/2))
	for y in [0,yhalf] if rect.size.y>1 else [0]:
		for x in [0,xhalf] if rect.size.x>1 else [0]:
			_split(Rect2i(rect.position+Vector2i(x,y),Vector2i(mini(xhalf,rect.size.x-x) if x==0 and rect.size.x>1 else rect.size.x-x,mini(yhalf,rect.size.y-y) if y==0 and rect.size.y>1 else rect.size.y-y)),source,mask,groups)
func advance_tick() -> void:
	if ticks>=90: return
	ticks+=1
	for shard in shards:
		shard.position+=Vector2(floor(shard.velocity.x/10.0),floor(shard.velocity.y/20.0)); shard.velocity.y+=10
		if shard.axis==0: shard.scale.x-=0.01
		else: shard.scale.y-=0.01
	if ticks==90: shards.clear()
func dispose() -> void: shards.clear(); ticks=90
