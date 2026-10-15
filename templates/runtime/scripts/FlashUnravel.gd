extends RefCounted
## 0331 Unravel_Bitmap by Lyaci. Owned Image copies replace mutable RGSS cache
## bitmaps; one 60 Hz owner drives every instance, including empty instances.
static var speed := Vector3i(100,100,550)
static var opaque_only := true
static var opaque_threshold := 1
var particles: Array = []
var image: Image
var moving := true
var disposed := false
var move_effect: Callable
var _rng := RandomNumberGenerator.new()

static func make_speed(x: int=100,y: int=100,opacity: int=550) -> void:
	speed=Vector3i(maxi(1,x),maxi(1,y),maxi(1,opacity))
static func make_otake(value: bool=true) -> void: opaque_only=value
static func make_otake_value(value: int=1) -> void: opaque_threshold=clampi(value,0,255)

func configure(source: Image,origin: Vector2,region: Rect2i,n: int=0,d: int=4,co: float=0.5,type: String="RU",shape: String="C",clear_source: bool=true,seed_value: int=-1,initialize: Callable=Callable()) -> Dictionary:
	if source==null or source.is_empty() or region.size.x<1 or region.size.y<1 or d<1 or d>128 or not is_finite(co) or co<0 or not type in ["RU","LU","RD","LD","LR","LRUD"] or not shape in ["C","S","T"] or n < -1 or n>65536: return {"ok":false,"message":"位图消散参数无效。"}
	image=source.duplicate(); image.convert(Image.FORMAT_RGBA8); particles.clear(); disposed=false; moving=true
	if seed_value<0: _rng.randomize()
	else: _rng.seed=seed_value
	var count=ceili(float(region.size.x*region.size.y)/(d*d)) if n==0 else ceili(float(region.size.x*region.size.y)/(2*d*d)) if n==-1 else n
	if count>65536: return {"ok":false,"message":"位图消散超过65536个粒子预算。"}
	var columns=maxi(1,ceili(float(region.size.x)/(d*2 if n==-1 else d)))
	var row_divisor=maxi(1,ceili(count/(float(region.size.y)/d)))
	var signs={"RU":Vector2(1,-1),"LU":Vector2(-1,-1),"RD":Vector2(1,1),"LD":Vector2(-1,1)}.get(type,Vector2(1,-1))
	for i in count:
		var p=region.position+Vector2i(_rng.randi_range(0,region.size.x-1),_rng.randi_range(0,region.size.y-1)) if n>0 else region.position+Vector2i((i%columns)*d*(2 if n==-1 else 1)+(int(i/columns)%2)*d if n==-1 else (i%columns)*d,int(i/row_divisor)*d)
		var center=p+Vector2i(int(d/2),int(d/2))
		if center.x<0 or center.y<0 or center.x>=image.get_width() or center.y>=image.get_height(): continue
		if opaque_only and image.get_pixelv(center).a8<opaque_threshold: continue
		var piece=Image.create(d,d,false,Image.FORMAT_RGBA8); piece.fill(Color.TRANSPARENT)
		_copy_piece(piece,p,d,shape,clear_source and n>0)
		var velocity=Vector2(_rng.randi_range(0,speed.x-1)/100.0,_rng.randi_range(0,speed.y-1)/100.0)
		if type in ["LR","LRUD"] and i%2==0: velocity.x=-velocity.x
		if type=="LRUD" and posmod(i-1,3)==0: velocity.y=-velocity.y
		var part={"position":origin+Vector2(p),"texture":ImageTexture.create_from_image(piece),"velocity":velocity*signs,"raw_velocity":velocity,"fade":co+_rng.randi_range(0,speed.z-1)/100.0,"opacity":255.0,"angle":0.0,"scale":Vector2.ONE,"blend_type":0,"index":i}
		if initialize.is_valid(): initialize.call(part)
		particles.append(part)
	if clear_source and n<1: image.fill_rect(region.intersection(Rect2i(Vector2i.ZERO,image.get_size())),Color.TRANSPARENT)
	return {"ok":true,"count":particles.size()}

func _copy_piece(target: Image,p: Vector2i,d: int,shape: String,clear_source: bool) -> void:
	if shape=="C":
		var previous=-100000; var half=int(d/2)
		for i in d*2:
			var xo=roundi(sin(PI/(d*2)*i)*half); var yo=roundi(cos(PI/(d*2)*i)*half)
			if yo==previous: continue
			previous=yo
			var rect=Rect2i(p.x-xo+half,p.y+yo+half,xo*2,1).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			if rect.has_area():
				target.blit_rect(image,rect,rect.position-p)
				if clear_source: image.fill_rect(rect,Color.TRANSPARENT)
		return
	for y in d:
		for x in d:
			if shape=="T" and (x<int(d/2)-int(y/2) or x>=int(d/2)-int(y/2)+y): continue
			var sample=p+Vector2i(x,y)
			if sample.x<0 or sample.y<0 or sample.x>=image.get_width() or sample.y>=image.get_height(): continue
			target.set_pixel(x,y,image.get_pixelv(sample))
			if clear_source: image.set_pixelv(sample,Color.TRANSPARENT)

func advance_ticks(count: int=1,area: Vector2=Vector2(640,640)) -> void:
	if disposed or not moving: return
	for tick in maxi(0,count):
		for i in range(particles.size()-1,-1,-1):
			var part: Dictionary=particles[i]; part.position+=part.velocity; part.opacity-=part.fade
			if move_effect.is_valid(): move_effect.call(part,part.index)
			if part.opacity<=0 or part.get("disposed",false): particles.remove_at(i)
		if particles.is_empty(): dispose(); break
func all_move(x: float,y: float) -> void:
	for part in particles: part.position+=Vector2(x,y)
func stop() -> void: moving=false
func begin() -> void: moving=true
func move_effe(callback: Callable) -> void: move_effect=callback
func move_type(type: String) -> Dictionary:
	var signs={"RU":Vector2(1,-1),"LU":Vector2(-1,-1),"RD":Vector2(1,1),"LD":Vector2(-1,1),"LR":Vector2(1,-1),"LRUD":Vector2(1,-1)}
	if not signs.has(type): return {"ok":false,"message":"位图消散方向无效。"}
	for part in particles: part.velocity=part.raw_velocity*signs[type]
	return {"ok":true}
func auto_dispose(part: Dictionary,_index: int=0,area: Vector2=Vector2(640,640)) -> void:
	if part.position.x<0 or part.position.y<0 or part.position.x>area.x or part.position.y>area.y: part.disposed=true
func get_all_sprite() -> Array: return particles.duplicate()
func get_viewport() -> Variant: return null # View ownership belongs to FlashEffectView.
func dispose() -> void:
	particles.clear(); image=null; disposed=true
