extends RefCounted
## 0169 Game_FileData; presentation metadata lives inside the checksummed save.
const CHAPTER_NAMES=["入会考试","行动预备","冬木聚源","白雾异象",""]
const MAX_PNG_BYTES=2*1024*1024
static func from_state(state: Node) -> Dictionary:
	var rows: Array=[]; var roles=state.custom_data.gameplay().role_ids()
	for i in mini(state.party.size(),2 if roles[1]>0 else 1):
		var actor=state.actor(int(state.party[i]))
		if actor!=null: rows.append(actor_row(actor))
	var chapter: Variant=state.variables.get("3",0)
	return {"chapter":int(chapter) if chapter is int or chapter is float else 0,"players":rows,"png":""}
static func actor_row(actor: RefCounted) -> Dictionary:
	return {"id":actor.id,"name":actor.actor_name,"maxhp":actor.get_parameter("maxhp"),"hp":actor.hp,"maxsp":actor.get_parameter("maxsp"),"sp":actor.sp,"lv":actor.level,"exp":actor.experience,"maxexp":actor.next_level_experience(),"char_name":actor.character_name,"char_hue":actor.character_hue}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not value.get("chapter") is int and not value.get("chapter") is float or not value.get("players") is Array or value.players.size()>2 or not value.get("png") is String: return "闪翼档案展示数据格式无效。"
	if abs(float(value.chapter))>1000000 or value.chapter!=floor(value.chapter): return "档案章节编号无效。"
	for row in value.players:
		if not row is Dictionary: return "档案角色展示数据格式无效。"
		for field in ["name","char_name"]:
			if not row.get(field) is String or row[field].length()>4096: return "档案角色文字无效。"
		for field in ["id","lv","char_hue"]:
			if not (row.get(field) is int or row.get(field) is float) or not is_finite(float(row[field])) or row[field]<0 or row[field]>9007199254740991 or row[field]!=floor(row[field]): return "档案角色数值无效。"
		for field in ["maxhp","hp","maxsp","sp"]:
			if not preload("FlashActorFields.gd").number(row.get(field)) or row[field]<0: return "档案角色数值无效。"
		for field in ["exp","maxexp"]:
			if row.get(field)!=null and not preload("FlashActorFields.gd").number(row[field]): return "档案经验值无效。"
	if value.png.length()>int(MAX_PNG_BYTES*4/3)+8: return "档案截图超过2MiB。"
	if not value.png.is_empty():
		var encoding=RegEx.new(); encoding.compile("^[A-Za-z0-9+/]+={0,2}$")
		if value.png.length()%4!=0 or encoding.search(value.png)==null: return "档案截图编码无效。"
		var bytes=Marshalls.base64_to_raw(value.png)
		# Validate dimensions before allocating an untrusted decoded image.
		if bytes.size()<24 or bytes.size()>MAX_PNG_BYTES or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]): return "档案截图不是有效PNG。"
		var width=0; var height=0
		for i in range(16,20): width=width*256+bytes[i]
		for i in range(20,24): height=height*256+bytes[i]
		if width<1 or height<1 or width>2048 or height>2048 or width*height>4194304: return "档案截图尺寸无效。"
		var image=Image.new()
		if image.load_png_from_buffer(bytes)!=OK: return "档案截图解码失败。"
	return ""
static func preview(value: Dictionary) -> Image:
	if str(value.get("png","")).is_empty(): return null
	var image=Image.new()
	return image if image.load_png_from_buffer(Marshalls.base64_to_raw(value.png))==OK else null
