extends RefCounted
## Source 0315 gameplay helpers. Drawing and object-graph cloning have separate
## version scopes; this adapter never evaluates an event name as Ruby.
const Fields=preload("FlashActorFields.gd")
const Characters=preload("FlashCharacterBridge.gd")
const Maps=preload("FlashMapBridge.gd")

static func invoke(custom: RefCounted,name: String,args: Array) -> Variant:
	if name=="DeepClone" and args.size()==1:
		var graph=preload("SaveGraph.gd").encode(args[0])
		return preload("SaveGraph.gd").decode(graph.value).value if graph.ok else custom.reject(graph.message)
	if name=="Unit" and args.size()==1: return null # Source method has an empty body.
	if name=="AdaptText" and args.size() in [3,4] and args[0] is int and args[1] is int and args[2] is String:
		if args[0]<0 or args[1]<1: return custom.reject("适配文本宽度和字号无效。")
		return adapt_text(int(args[0]),int(args[1]),args[2],args.size()==4 and args[3]==true)
	if name=="MHT_Distance" and args.size()==4:
		for value in args:
			if not Fields.number(value): return custom.reject("曼哈顿距离参数必须为有效数值。")
		return abs(args[0]-args[1])+abs(args[2]-args[3])
	if name=="h_to_i" and args.size()==1 and args[0] is String:
		var parsed=integer_text(args[0],16)
		return parsed.value if parsed.ok else custom.reject(parsed.message)
	var state: Node=custom._owner.get_ref(); var game: Node=state.game(); var map: Node=game.event_map() if game!=null else null
	if name=="Check_Area" and args.size()==4:
		for value in args:
			if not Fields.number(value): return custom.reject("区域参数必须为有效数值。")
		if map==null: return null
		for event in map._event_nodes:
			if Maps.is_dead(custom,state.map_id,event.event_id): continue
			var ref=custom.data_ref("map_event",state.map_id,"",event.event_id)
			if _inside(Characters.invoke(custom,ref,"x",[]),Characters.invoke(custom,ref,"y",[]),args): return true
		var player=custom.data_ref("player",state.map_id)
		return _inside(Characters.invoke(custom,player,"x",[]),Characters.invoke(custom,player,"y",[]),args)
	if name=="Find_Event" and args.size()==1:
		if map==null: return custom.reject("查找事件需要当前地图。")
		var names: Variant=args[0]
		if names is String and names=="钥匙": names=["物品1","物品2","物品3"]
		elif names is String and names=="药品": names=["物品50","物品51","物品52","物品53"]
		if not names is Array: names=[names]
		var matchers: Array=[]
		for pattern in names:
			if not pattern is String: return custom.reject("事件名称匹配需要字符串。")
			var matcher=RegEx.new()
			if matcher.compile(pattern)!=OK: return custom.reject("事件名称中的正则表达式无效。")
			matchers.append(matcher)
		var result: Array=[]
		for event in map._event_nodes:
			var event_name=Maps.event_name(custom,state.map_id,event.event_id)
			for matcher in matchers:
				if matcher.search(event_name)!=null: result.append(event.event_id)
		return result
	return custom.reject("Utils接口尚未迁移或参数无效："+name)

static func adapt_text(width: int,font_size: int,value: String,rich: bool=false) -> Array:
	width=int(width/font_size)*font_size
	var result: Array=[]; var text=""; var count=0.0; var cursor=0
	while cursor<value.length():
		var character=value[cursor]
		if character=="\n": result.append(text); text=""; count=0; cursor+=1; continue
		if character=="\\":
			var control=""; var start=cursor
			while cursor<value.length():
				control+=value[cursor]; cursor+=1
				if control=="\\n" or rich and control.ends_with("]"): break
			if control=="\\n": result.append(text); text=""; count=0
			else: text+=control
			if cursor==start: cursor+=1
			continue
		if character.is_valid_int():
			var digits=""
			while cursor<value.length() and (value[cursor].is_valid_int() or value[cursor] in [".","%"]): digits+=value[cursor]; cursor+=1
			text+=digits; count+=digits.length()/2.0
			if count*font_size>width:
				text=text.left(text.length()-digits.length()); result.append(text); text=digits; count=digits.length()/2.0
			continue
		text+=character; count+=0.5 if rich and character.strip_edges().is_empty() else 1; cursor+=1
		if (count+1)*font_size>width: result.append(text); text=""; count=0
	if not text.is_empty(): result.append(text)
	return result

static func get_pic(type: String,name: String,ext: String=".png") -> RefCounted:
	if type not in ["pic","picture"]: return null
	var texture=load("res://runtime/scripts/RmxpCache.gd").picture(name+ext)
	if texture==null: return null
	var bitmap=load("res://runtime/scripts/FlashBitmap.gd").new(texture.get_width(),texture.get_height()); bitmap.image=texture.get_image().duplicate(); return bitmap
static func update_mask(mask_name: String,source: RefCounted,x: int,y: int) -> Dictionary:
	var mask=load("res://runtime/scripts/RmxpCache.gd").transition(mask_name+".png")
	if mask==null or source==null or not source.get("image") is Image: return {"ok":false,"message":"蒙版或目标位图无效。"}
	source.clip_mask(mask.get_image(),x,y); return {"ok":true,"value":source}
static func sprite_unravel(state: Object,sprite: Sprite2D,args: Array=[],initialize: Callable=Callable()) -> Dictionary:
	if state.flash_effects==null: return {"ok":false,"message":"位图消散需要闪翼运行时。"}
	return state.flash_effects.unravel_sprite(sprite,args,initialize)

static func _inside(x: Variant,y: Variant,area: Array) -> bool:
	return x!=null and y!=null and x>=area[0] and x<=area[0]+area[2] and y>=area[1] and y<=area[1]+area[3]

static func integer_text(value: String,base: int) -> Dictionary:
	if base<2 or base>36: return {"ok":false,"message":"整数进制必须在2—36之间。"}
	var text=value.strip_edges().to_lower(); var sign=1
	if text.begins_with("+") or text.begins_with("-"):
		if text.begins_with("-"): sign=-1
		text=text.substr(1)
	if base==16 and text.begins_with("0x") or base==2 and text.begins_with("0b") or base==8 and text.begins_with("0o"): text=text.substr(2)
	var decimal=preload("DecimalInteger.gd"); var result: Variant=0; var count=0
	for index in text.length():
		var character=text[index]
		if character=="_":
			var next_digit="0123456789abcdefghijklmnopqrstuvwxyz".find(text[index+1]) if index+1<text.length() else -1
			if index>0 and text[index-1]!="_" and count>0 and next_digit>=0 and next_digit<base: continue
			break
		var digit="0123456789abcdefghijklmnopqrstuvwxyz".find(character)
		if digit<0 or digit>=base: break
		# DecimalInteger keeps values beyond JSON's exact range losslessly.
		var multiplied: Variant=0
		for i in base: multiplied=decimal.add(multiplied,result)
		result=decimal.add(multiplied,digit); count+=1
		if count>1024: return {"ok":false,"message":"整数文本超过1024位执行预算。"}
	if sign<0: result=decimal.negate(result)
	return {"ok":true,"value":{"__decimal_integer":result} if result is String else result}
