extends RefCounted
## Source 0149/0150 transcode and font metrics; no arbitrary expressions.
const Data=preload("RuntimeData.gd")
const Cache=preload("RmxpCache.gd")
const Presets=preload("FlashItemPresets.gd")
const CODES={"c":1,"g":2,"s":3,"se":4,"w":5,"|":6,".":7,">":14,"<":15,"!":16,"~":17,"mr":18,"&":19,"o":20,"fs":21,"ex":22,"fn":23,"ic":24,"fb":25,"fi":26,"a":27,"ls":28,"t":29,"ml":30,"mu":31,"bo":33}
const ARGUMENTS=["c","s","se","w","o","fs","ex","fn","ic","fb","fi","a","ls","t","ml","mu","bo"]
const BOX_CODES=["m","f","fg","p","al","mo","mp"]
static var _fonts: Dictionary={}

static func defaults() -> Dictionary:
	return {"font_name":"楷体","font_size":20,"bold":false,"italic":false,"color":-1,"opacity":255,"line_space":4,"halign":0,"valign":2}

static func color(id: int) -> Color:
	return {0:Color8(255,255,255),1:Color8(128,128,255),2:Color8(255,128,128),3:Color8(0,170,170,128),4:Color8(128,255,255),5:Color8(255,128,255),6:Color8(255,255,128),7:Color8(192,192,192),8:Color.BLACK,9:Color8(255,50,50),10:Color8(140,140,140),11:Color8(255,255,0,200),12:Color8(255,192,128)}.get(id,Color.BLACK)

static func frame_duration(value: int,frame_rate: int=60) -> int:
	return int(round(float(value)*frame_rate/40.0))

static func parse(raw: String,state: Object,box_setup: bool=true) -> Dictionary:
	var expanded=expand(raw,state)
	if not expanded.ok: return expanded
	var text: String=expanded.text; var tokens: Array=[]; var metadata: Dictionary={}; var index=0; var output=""
	# Public transcode/TextRow callers may supply already encoded RGSS controls.
	# Decode those bytes to the same parser path, preserving LF as a real row.
	var normalized=""
	for offset in text.length():
		var character=text[offset]
		var ordinal=character.unicode_at(0)
		if ordinal==0: normalized+="\\\\"
		elif ordinal in CODES.values() and (ordinal!=33 or offset+1<text.length() and text[offset+1]=="[" and (offset==0 or text[offset-1]!="\\")): normalized+="\\"+str(CODES.find_key(ordinal))
		else: normalized+=character
	text=normalized
	while index<text.length():
		if text[index]!="\\" or index+1>=text.length():
			tokens.append(text[index]); output+=text[index]; index+=1; continue
		if text[index+1]=="\\": tokens.append("\\"); output+="\\"; index+=2; continue
		var start=index; index+=1; var tag=text[index].to_lower(); index+=1
		if index<text.length() and text.substr(index-1,2).to_lower() in ["se","fs","fn","fb","fi","ic","ex","ls","ml","mu","bo","mr","fg","al","mo","mp"]:
			tag=text.substr(index-1,2).to_lower(); index+=1
		var argument=""; var has_argument=false
		if index<text.length() and text[index]=="[":
			var end=text.find("]",index+1)
			if end>=0: argument=text.substr(index+1,end-index-1); index=end+1; has_argument=true
		if box_setup and tag in BOX_CODES and (has_argument or tag in ["al","mp"]):
			metadata[tag]=argument; continue
		if tag=="ex" and not has_argument:
			if box_setup: metadata["extend"]=false; continue
		elif CODES.has(tag) and (tag not in ARGUMENTS or has_argument) and (tag not in ["fb","fi"] or argument in ["T","t","F","f"]):
			var value: Variant=argument
			if tag in ["c","s","w","o","fs","ex","a","ls","t","bo"]:
				if not argument.is_valid_int(): return {"ok":false,"message":"文本控制码整数参数无效：\\"+tag+"["+argument+"]"}
				value=int(argument)
			elif tag in ["ml","mu"]:
				var args=argument.split(",",true)
				if args.is_empty() or not str(args[0]).is_valid_int() or args.size()>2 or args.size()==2 and not str(args[1]).is_empty() and not str(args[1]).is_valid_int(): return {"ok":false,"message":"文本位移参数无效："+argument}
				value=[int(args[0]),str(args[1]) if args.size()==2 else ""]
			var token: Array=[String.chr(CODES[tag])]
			if tag in ARGUMENTS:
				if value is Array: token.append_array(value)
				else: token.append(value)
			tokens.append(token); output+=token[0]+("["+argument+"]" if has_argument else ""); continue
		var literal=text.substr(start,index-start)
		for character in literal: tokens.append(character)
		output+=literal
	return {"ok":true,"tokens":tokens,"text":output,"metadata":metadata}

static func expand(raw: String,state: Object) -> Dictionary:
	var text=raw; var seen: Array[String]=[]; var expression=RegEx.new()
	expression.compile("\\\\([VvNnIiEe])\\[([0-9]+)(?:,([0-9]+))?\\]")
	for pass_index in 32:
		if text in seen: return {"ok":false,"message":"文本变量替换出现循环。"}
		seen.append(text); var result=""; var offset=0; var changed=false
		for match_value in expression.search_all(text):
			# Escaped backslash remains literal. Count preceding slashes for parity.
			var slashes=0; var prior=match_value.get_start()-1
			while prior>=0 and text[prior]=="\\": slashes+=1; prior-=1
			if slashes%2==1: continue
			var replacement=""; var id=int(match_value.get_string(2)); var tag=match_value.get_string(1).to_lower()
			if tag=="v":
				var value: Variant=state.variables.get(str(id),0)
				if not (value==null or value is String or value is int or value is float or value is bool): return {"ok":false,"message":"文本变量集合的Ruby字符串表示尚未迁移。"}
				replacement="" if value==null else "true" if value is bool and value else "false" if value is bool else str(value)
			elif tag=="n":
				var actor=state.actor(id) if not Data.record("Actors",id).is_empty() else null
				replacement=actor.actor_name if actor!=null else ""
			elif tag=="i":
				var item=Presets.native_item(id,state)
				if not item.is_empty(): replacement="\\ic["+str(item.get("icon_name",""))+"]"+str(item.get("name",""))
			elif tag=="e":
				if match_value.get_string(3).is_empty(): continue
				var kind=id; var entry_id=int(match_value.get_string(3))
				if kind<0 or kind>3: return {"ok":false,"message":"文本装备类别无效。"}
				var catalog=preload("FlashObjectCatalog.gd"); var db=catalog.DATABASES[kind]
				replacement="\\ic["+str(catalog.value(state.custom_data,db,entry_id,"icon_name"))+"]"+str(catalog.value(state.custom_data,db,entry_id,"name"))
			result+=text.substr(offset,match_value.get_start()-offset)+replacement; offset=match_value.get_end(); changed=true
		result+=text.substr(offset)
		if not changed or result==text: return {"ok":true,"text":result}
		text=result
	return {"ok":false,"message":"文本变量替换超过32层。"}

static func font(style: Dictionary) -> SystemFont:
	var key=str(style.font_name)+":"+str(style.bold)+":"+str(style.italic)
	if _fonts.has(key): return _fonts[key]
	var result=SystemFont.new(); result.font_names=PackedStringArray([str(style.font_name),"楷体","SimSun","Arial"]); result.allow_system_fallback=true; result.font_weight=700 if style.bold else 400; result.font_italic=style.italic; _fonts[key]=result; return result

static func apply_style(style: Dictionary,token: Array) -> void:
	var code=token[0].unicode_at(0)
	if token.size()<2: return
	match code:
		1: style.color=int(token[1])
		20: style.opacity=int(token[1])
		21: style.font_size=clampi(int(token[1]),1,512)
		23: style.font_name=str(token[1])
		25: style.bold=str(token[1]).to_lower()=="t"
		26: style.italic=str(token[1]).to_lower()=="t"
		27: style.halign=int(token[1]); style.valign=int(token[1])
		28: style.line_space=int(token[1])
