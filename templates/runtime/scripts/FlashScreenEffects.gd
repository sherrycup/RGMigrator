extends RefCounted
## 0310 GameEngine::Screen + 0311/0330/0331. Requests are installed only after
## the script transaction validates. The owning Game advances one 60 Hz clock.
const Data=preload("RuntimeData.gd")
const Cache=preload("RmxpCache.gd")
const Unravel=preload("FlashUnravel.gd")
const Broken=preload("FlashBrokenScreen.gd")
const RECT_STEPS=[12,10,10,8,8,8,6,4,3,3,1,1]
var _owner: WeakRef
var _view: WeakRef
var _serial=0
var _epoch=0
var _queue: Array=[]
var active: Dictionary={}
var results: Dictionary={}
var test_capture: Image # Explicit in-memory fixture; never used by exports.
var map_visible=true
var rect_amount=0
var filter_enabled=false
var frozen: Texture2D
var blurred: Texture2D
var blur_radius=0.0
var voice_visible=false
var voice_process=0
var voice_alpha=0.0
var voice_zoom=1.0
var voice: Texture2D
var transient: Dictionary={}
var particle_sets: Array=[]
var _hidden_targets: Array=[]
var broken: RefCounted
var _clock=0.0
var _rng=RandomNumberGenerator.new()

func _init(owner: Object) -> void: _owner=weakref(owner); _rng.randomize()
func bind(view: Node) -> void:
	reset(); _view=weakref(view)
func reset() -> void:
	_epoch+=1
	for request in _queue: results[request.id]={"ok":false,"message":"剧情演出已随场景重置取消。"}
	if not active.is_empty(): results[active.id]={"ok":false,"message":"剧情演出已随场景重置取消。"}
	_queue.clear(); active={}; transient={}; frozen=null; blurred=null; voice=null; voice_visible=false; voice_process=0; rect_amount=0; filter_enabled=false; blur_radius=0; map_visible=true; _clock=0
	for value in particle_sets: value.model.dispose()
	particle_sets.clear()
	for ref in _hidden_targets:
		var target: Sprite2D=ref.get_ref()
		if target!=null: target.set_meta("flash_unravel_hidden",false)
	_hidden_targets.clear()
	if broken!=null: broken.dispose(); broken=null
	var view: Node=_view.get_ref() if _view!=null else null
	if view!=null: view.apply_map_visible(true); view.sync()
func reserve_id() -> int: _serial+=1; return _serial
func busy() -> bool: return not active.is_empty() or not _queue.is_empty()
func transient_save_reason() -> String:
	if active.get("capturing",false): return "截图正在采集，请等待采集完成后保存。"
	return ""
func restore_sprite(target: Sprite2D) -> void:
	if target==null: return
	target.set_meta("flash_unravel_hidden",false)
	for i in range(particle_sets.size()-1,-1,-1):
		if particle_sets[i].has("target") and particle_sets[i].target.get_ref()==target: particle_sets[i].model.dispose(); particle_sets.remove_at(i)
	_hidden_targets=_hidden_targets.filter(func(ref):return ref.get_ref()!=null and ref.get_ref()!=target)
func status(id: int) -> Dictionary:
	if results.has(id): return results[id].duplicate(true)
	if active.get("id",0)==id: return {"ok":true,"pending":true}
	for request in _queue:
		if request.id==id: return {"ok":true,"pending":true}
	return {"ok":false,"message":"剧情演出请求已失效。"}
func cancel(id: int) -> void:
	var group=id
	for request in _queue:
		if request.id==id: group=request.get("group",id)
	if active.get("id",0)==id: group=active.get("group",id)
	if active.get("id",0)==id or active.get("group",0)==group:
		_epoch+=1; _finish({"ok":false,"message":"剧情演出请求已取消。"})
	for i in range(_queue.size()-1,-1,-1):
		if _queue[i].id==id or _queue[i].get("group",0)==group: results[_queue[i].id]={"ok":false,"message":"剧情演出请求已取消。"}; _queue.remove_at(i)
func appear(value: bool) -> void:
	map_visible=value
	var view: Node=_view.get_ref() if _view!=null else null
	if view!=null: view.apply_map_visible(value)

static func stage(custom: RefCounted,name: String,args: Array) -> Variant:
	var owner: Node=custom._owner.get_ref(); var model: RefCounted=owner.flash_effects
	if model==null: return custom.reject("剧情演出仅属于闪翼运行时。")
	var request={"id":model.reserve_id(),"name":name,"args":args.duplicate(true)}
	var reason=model.validate([request])
	if not reason.is_empty(): return custom.reject(reason)
	if name=="Voiceover": request.previous_mask={"switch4":custom.script_switches.get("switch:4",owner.switches.get("4",false)),"switch3":custom.script_switches.get("switch:3",owner.switches.get("3",false)),"variable13":custom.script_variables.get("13",0)}
	custom.screen_edits.append(request); custom.last_screen_request=int(request.id)
	# Original voiceover writes these exact switches, without touching formulas.
	if name=="Voiceover" and args[0]:
		custom.script_variables["13"]=192; custom.script_switches["switch:4"]=true; custom.script_switches["switch:3"]=false
	elif name=="Voiceover" and (model.voice_visible or custom.screen_edits.any(func(r): return r.name=="Voiceover" and r.args[0])):
		custom.script_switches["switch:4"]=false; custom.script_switches["switch:3"]=true
	return null

func validate(requests: Array) -> String:
	var view: Node=_view.get_ref() if _view!=null else null
	if not requests.is_empty() and view==null: return "剧情演出需要有效的地图场景。"
	for request in requests:
		var name: String=request.name; var args: Array=request.args
		var valid=false; var capture=false; var pictures: Array=[]; var se=""
		match name:
			"set_rect": valid=args.size()<=3 and args.all(func(v): return v is int); valid=valid and (args.is_empty() or args[0] in [0,1])
			"freeze","unfreeze": valid=args.size()<=1 and (args.is_empty() or args[0]==null or args[0] is String); capture=name=="freeze"; se=str(args[0]) if not args.is_empty() and args[0]!=null else "m魔法-爆气-重-005" if args.is_empty() else ""
			"appear": valid=args.size()==1 and args[0] is bool
			"filter": valid=args.size()<=2 and args.all(func(v): return v is int) and (args.is_empty() or args[0] in [0,1])
			"Blur": valid=args.size()<=1 and (args.is_empty() or args[0] is bool); capture=args.is_empty() or args[0]
			"Unravel": valid=args.is_empty(); capture=true
			"Scanline": valid=args.size()<=1 and (args.is_empty() or args[0] is int); capture=true; se="静电声2.mp3"
			"Flashback":
				valid=args.is_empty(); se="静电声.mp3"
				for i in range(1,21): pictures.append("WhiteNoise/WhiteNoise_%d.png" % i)
			"Voiceover": valid=args.size()==1 and args[0] is bool; pictures=["Causal/文本记录1.png"] if valid and args[0] else []
			"wake":
				valid=args.is_empty(); pictures=["Engine/Eye/tree.jpg","Engine/Eye/start.png"]
				for i in range(26): pictures.append("Engine/Eye/%d.png" % i)
			"broken": valid=args.size()==1 and args[0] is String; capture=true; se="crash"; pictures=args if valid else []
			"character_unravel": valid=args.size()==2 and args[0] is int and args[1] is Array and particle_reason(args[1]).is_empty()
			"picture_unravel": valid=args.size()==2 and args[0] is int and args[0]>=1 and args[0]<=50 and args[1] is Array and particle_reason(args[1]).is_empty()
		if not valid: return "GameEngine::Screen.%s参数无效或接口尚未定义。" % name
		if capture and DisplayServer.get_name()=="headless" and test_capture==null: return "当前无图形设备，无法取得剧情演出截图。"
		for picture in pictures:
			if Cache.picture(str(picture))==null: return "剧情演出原素材缺失：Pictures/"+str(picture)
		if not se.is_empty():
			var path=Data.asset_path("Audio/SE/"+se.trim_prefix("Audio/SE/"))
			if path.is_empty() or not ResourceLoader.exists(path) or not load(path) is AudioStream: return "剧情演出原SE缺失："+se
		if name in ["character_unravel","picture_unravel"] and view.target_sprite(name,int(args[0]))==null: return "消散对象没有有效的当前图像。"
	return ""

static func parameter_reason(name: String,args: Array) -> String:
	var valid=false
	match name:
		"set_rect": valid=args.size()<=3 and args.all(func(v):return v is int) and (args.is_empty() or args[0] in [0,1])
		"freeze","unfreeze": valid=args.size()<=1 and (args.is_empty() or args[0]==null or args[0] is String)
		"appear","Voiceover": valid=args.size()==1 and args[0] is bool
		"filter": valid=args.size()<=2 and args.all(func(v):return v is int) and (args.is_empty() or args[0] in [0,1])
		"Blur": valid=args.size()<=1 and (args.is_empty() or args[0] is bool)
		"Unravel","Flashback","wake": valid=args.is_empty()
		"Scanline": valid=args.size()<=1 and (args.is_empty() or args[0] is int)
		"broken": valid=args.size()==1 and args[0] is String
		"character_unravel","picture_unravel": valid=args.size()==2 and args[0] is int and args[1] is Array and particle_reason(args[1]).is_empty() and (name!="picture_unravel" or args[0]>=1 and args[0]<=50)
	return "" if valid else "演出参数无效："+name
static func particle_reason(args: Array) -> String:
	if args.size()>6: return "位图消散最多接受六个源参数。"
	var defaults=[0,4,0.5,"RU","C",true]
	for i in args.size(): defaults[i]=args[i]
	if not defaults[0] is int or defaults[0]<-1 or defaults[0]>65536 or not defaults[1] is int or defaults[1]<1 or defaults[1]>128 or not (defaults[2] is int or defaults[2] is float) or not is_finite(float(defaults[2])) or defaults[2]<0 or not defaults[3] in ["RU","LU","RD","LD","LR","LRUD"] or not defaults[4] in ["C","S","T"] or not defaults[5] is bool: return "位图消散参数无效。"
	return ""
func install(requests: Array) -> void:
	if requests.is_empty(): return
	var group: int=requests[-1].id
	for request in requests:
		var copy: Dictionary=request.duplicate(true); copy.group=group; _queue.append(copy)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	var view: Node=_view.get_ref() if _view!=null else null
	if view==null:
		if busy(): reset()
		return
	if active.is_empty() and not _queue.is_empty(): _start(_queue.pop_front())
	_clock+=delta*60
	var count=mini(120,int(_clock)); _clock-=count
	for i in count:
		for j in range(particle_sets.size()-1,-1,-1):
			var set: Dictionary=particle_sets[j]; var target: Sprite2D=set.target.get_ref() if set.has("target") else null
			if set.has("target") and target==null: set.model.dispose()
			elif target!=null:
				var location=target.get_global_transform_with_canvas().origin; set.model.all_move(location.x-set.location.x,location.y-set.location.y); set.location=location; target.visible=false
			set.model.advance_ticks(1,view.get_viewport().get_visible_rect().size)
			if set.model.disposed: particle_sets.remove_at(j)
		if not active.is_empty() and not active.get("capturing",false): _tick()
		if active.is_empty() and not _queue.is_empty(): _start(_queue.pop_front())
	view.sync()
func _start(request: Dictionary) -> void:
	active=request; active.tick=0
	active.previous_visual={"rect_amount":rect_amount,"filter_enabled":filter_enabled,"frozen":frozen,"blurred":blurred,"blur_radius":blur_radius,"voice_visible":voice_visible,"voice":voice,"voice_process":voice_process,"voice_alpha":voice_alpha,"voice_zoom":voice_zoom,"map_visible":map_visible}
	var name: String=active.name; var args: Array=active.args
	if name in ["freeze","unfreeze"]: _play(str(args[0]) if not args.is_empty() and args[0]!=null else "m魔法-爆气-重-005" if args.is_empty() else "",80)
	if name in ["Scanline","Flashback","broken"]: _play({"Scanline":"静电声2.mp3","Flashback":"静电声.mp3","broken":"crash"}[name])
	match name:
		"appear": appear(args[0]); _finish()
		"filter": filter_enabled=not args.is_empty() and args[0]==1 and (args.size()<2 or args[1]==0); _finish()
		"unfreeze": frozen=null; _finish()
		"set_rect":
			active.exit=not args.is_empty() and args[0]==1
			if active.exit and rect_amount==0: _finish()
			elif not active.exit: rect_amount=0
		"Blur":
			active.exit=not args.is_empty() and not args[0]
			if active.exit and blurred==null: appear(true); _finish()
			elif not active.exit: _capture()
		"freeze","Unravel","Scanline","broken": _capture()
		"Flashback": transient={"kind":name,"tick":0}
		"Voiceover":
			active.exit=not args[0]
			if active.exit and not voice_visible: _finish()
			else: voice_visible=true; voice=Cache.picture("Causal/文本记录1.png")
		"wake":
			var tree_image=Image.create(768,768,false,Image.FORMAT_RGBA8); tree_image.fill(Color.TRANSPARENT)
			var source=Cache.picture("Engine/Eye/tree.jpg").get_image().duplicate(); source.convert(Image.FORMAT_RGBA8)
			var region=Rect2i(0,0,768,768).intersection(Rect2i(Vector2i.ZERO,source.get_size())); tree_image.blit_rect(source,region,Vector2i.ZERO)
			transient={"kind":name,"level":1,"delay":3,"picture":0,"tree_y":-77.0,"radius":5,"alpha":255.0,"temp":1,"tree_texture":ImageTexture.create_from_image(tree_image)}; appear(false)
		"character_unravel","picture_unravel": _unravel_target(name,int(args[0]),args[1]); _finish()
func _capture() -> void:
	active.capturing=true
	var id: int=active.id; var epoch=_epoch
	var image: Image
	if test_capture!=null: image=test_capture.duplicate()
	else:
		await RenderingServer.frame_post_draw
		if epoch!=_epoch or active.get("id",0)!=id: return
		var view: Node=_view.get_ref() if _view!=null else null
		if view!=null and view.is_inside_tree(): image=view.get_viewport().get_texture().get_image()
	if epoch!=_epoch or active.get("id",0)!=id: return
	if image==null or image.is_empty(): _finish({"ok":false,"message":"剧情演出的实际截图失败。"}); return
	active.capturing=false
	match active.name:
		"freeze":
			for y in image.get_height():
				for x in image.get_width():
					var color=image.get_pixel(x,y); var gray=color.r*0.299+color.g*0.587+color.b*0.114; image.set_pixel(x,y,Color(gray,gray,gray,color.a))
			frozen=ImageTexture.create_from_image(image); _finish()
		"Blur": blurred=ImageTexture.create_from_image(image); blur_radius=0; appear(false)
		"Scanline": transient={"kind":"Scanline","texture":ImageTexture.create_from_image(image),"tick":0,"direction":0 if active.args.is_empty() else int(active.args[0]),"glitch_alpha":0.0,"glitch_rect":Rect2()}
		"Unravel":
			var source=blurred.get_image() if blurred!=null else image; _make_unravel(source,Vector2.ZERO,Rect2i(Vector2i.ZERO,source.get_size()),[0,30,1,"LRUD","S",false]); blurred=null; frozen=null; appear(false); _finish()
		"broken":
			broken=Broken.new(); var result=broken.configure(image,Cache.picture(str(active.args[0])).get_image())
			if not result.ok: _finish(result)
func _tick() -> void:
	active.tick+=1; var tick: int=active.tick
	match active.name:
		"set_rect": rect_amount=clampi(rect_amount+(-1 if active.exit else 1)*RECT_STEPS[tick-1],0,74); if tick==12: _finish()
		"Blur":
			blur_radius=13-tick if active.exit else tick
			if tick==12:
				if active.exit: blurred=null; blur_radius=0; appear(true)
				_finish()
		"Scanline":
			transient.tick=tick
			if _rng.randi_range(0,99)<5:
				var view: Node=_view.get_ref(); var area: Vector2=view.get_viewport().get_visible_rect().size; var width=_rng.randi_range(10,29)
				transient.glitch_rect=Rect2(0,_rng.randi_range(0,maxi(0,int(area.y)-width-1)),area.x,width) if transient.direction==0 else Rect2(_rng.randi_range(0,maxi(0,int(area.x)-width-1)),0,width,area.y); transient.glitch_alpha=255.0
			else: transient.glitch_alpha=maxf(0,transient.glitch_alpha-25)
			if tick==120: transient={}; _finish()
		"Flashback":
			transient.tick=tick-1
			_owner.get_ref().screen.start_shake(4 if tick<=6 else 0,5 if tick<=6 else 0,1.0/60)
			if tick==40: transient={}; _owner.get_ref().screen.start_shake(0,0,0); _finish()
		"Voiceover":
			voice_process=tick; voice_zoom=0.8+tick*0.005 if active.exit else 1-tick*0.005; voice_alpha=clampf(255-tick*7 if active.exit else tick*7,0,255)
			if tick==(30 if active.exit else 40):
				if active.exit: voice_visible=false; voice=null
				_finish()
		"wake": _wake_tick()
		"broken": broken.advance_tick(); if tick==90: broken=null; _finish()
func _wake_tick() -> void:
	var level: int=transient.level; var delay: int=transient.delay
	if level==10: transient.radius=4 if delay==15 else 3 if delay==5 else transient.radius
	if level==21 and delay<16: transient.alpha=maxf(0,transient.alpha-16)
	transient.delay-=1
	if transient.delay>=0: return
	if level<10:
		transient.level+=1; transient.picture=level; transient.tree_y+=3; transient.delay=20 if level==9 else 3
	elif level<19:
		transient.level+=1; transient.picture=18-level; transient.tree_y+=1; transient.delay=15 if level==18 else 3
		if level==15: transient.radius=5
	elif level==19:
		transient.picture=1; transient.level=20; transient.tree_y-=1; transient.temp=2; transient.delay=2
	elif level==20:
		var temp: int=transient.temp; transient.picture=temp; transient.tree_y-=5; transient.temp+=1; transient.delay=2 if transient.temp<10 else 1
		if temp in [5,10,15,20,25]: transient.radius=4 if temp==5 else 3 if temp==10 else 2 if temp==15 else 1 if temp==20 else 0
		if transient.temp==26: transient.level=21; transient.delay=40; appear(true)
	else: transient={}; _finish()
func _make_unravel(image: Image,origin: Vector2,region: Rect2i,args: Array,target: Sprite2D=null,initialize: Callable=Callable()) -> void:
	var values=[0,4,0.5,"RU","C",true]
	for i in args.size(): values[i]=args[i]
	var model=Unravel.new(); var old_speed=Unravel.speed; Unravel.make_speed(50,50,300)
	var result=model.configure(image,origin,region,int(values[0]),int(values[1]),float(values[2]),str(values[3]),str(values[4]),bool(values[5]),-1,initialize if initialize.is_valid() else func(part): part.blend_type=1)
	Unravel.speed=old_speed
	if not result.ok: _owner.get_ref().report_diagnostic(result.message); return
	var set={"model":model}
	if target!=null:
		set.target=weakref(target); set.location=target.get_global_transform_with_canvas().origin; target.set_meta("flash_unravel_hidden",true); target.visible=false
		if not _hidden_targets.any(func(ref):return ref.get_ref()==target): _hidden_targets.append(weakref(target))
	particle_sets.append(set)
func _unravel_target(name: String,id: int,args: Array) -> void:
	var view: Node=_view.get_ref(); var target: Sprite2D=view.target_sprite(name,id)
	if target==null: return
	unravel_sprite(target,args)
func unravel_sprite(target: Sprite2D,args: Array=[],initialize: Callable=Callable()) -> Dictionary:
	var reason=particle_reason(args)
	if not reason.is_empty(): return {"ok":false,"message":reason}
	if target==null or target.texture==null or not target.is_inside_tree(): return {"ok":false,"message":"消散精灵必须有有效的现场图像。"}
	var region=Rect2i(target.region_rect) if target.region_enabled else Rect2i(Vector2i.ZERO,target.texture.get_size())
	var top_left=target.get_global_transform_with_canvas()*(-target.texture.get_size()/2 if target.centered else Vector2.ZERO)
	if target.region_enabled and target.centered: top_left=target.get_global_transform_with_canvas()*(-region.size/2)
	var image=target.texture.get_image().duplicate(); var parent=target.get_parent()
	if parent!=null and parent.has_method("configure_motion") and int(parent._hue)%360!=0:
		var bitmap=load("res://runtime/scripts/FlashBitmap.gd").new(image.get_width(),image.get_height()); bitmap.image=image; bitmap.hue_change(float(parent._hue)); image=bitmap.image
	_make_unravel(image,top_left-Vector2(region.position),region,args,target,initialize); return {"ok":true}
func _play(name: String,volume: int=100) -> void:
	if name.is_empty(): return
	var result=_owner.get_ref().audio.play("SE",{"name":name.trim_prefix("Audio/SE/"),"volume":volume,"pitch":100})
	if not result.ok: _owner.get_ref().report_diagnostic(result.message)
func _finish(result: Dictionary={"ok":true}) -> void:
	if active.is_empty(): return
	if not result.ok:
		if active.has("previous_visual"):
			for field in active.previous_visual:
				if field=="map_visible": appear(bool(active.previous_visual[field]))
				else: set(field,active.previous_visual[field])
		transient={}
		if broken!=null: broken.dispose(); broken=null
		for i in range(_queue.size()-1,-1,-1):
			if _queue[i].get("group",0)==active.get("group",-1):
				if _queue[i].has("previous_mask"):
					var owner: Node=_owner.get_ref(); var mask: Dictionary=_queue[i].previous_mask; owner.set_event_switch(4,mask.switch4); owner.set_event_switch(3,mask.switch3); owner.set_event_variable(13,mask.variable13)
				results[_queue[i].id]=result.duplicate(); _queue.remove_at(i)
		if active.has("previous_mask"):
			var owner: Node=_owner.get_ref(); owner.set_event_switch(4,active.previous_mask.switch4); owner.set_event_switch(3,active.previous_mask.switch3); owner.set_event_variable(13,active.previous_mask.variable13)
	results[active.id]=result; active={}
	while results.size()>128: results.erase(results.keys()[0])
