@tool
extends RefCounted
## Native database shapes. Unknown source fields survive every edit.
const Commands = preload("EditorCommands.gd")
const CATEGORIES := {"Actors":"角色","Classes":"职业","Skills":"特技","Items":"物品","Weapons":"武器","Armors":"防具","Enemies":"敌人","States":"状态","Animations":"动画","Tilesets":"图块（图块集）","CommonEvents":"公共事件","System":"系统","Troops":"敌群数据（保留）"}
const LABELS := {"initial_level":"初始等级","final_level":"最高等级","class_id":"职业","exp_basis":"经验基础值","exp_inflation":"经验增长值","parameters":"各等级能力值","maxhp":"最大HP","maxsp":"最大SP","str":"力量","dex":"灵巧","agi":"速度","int":"魔力","atk":"攻击力","pdef":"物理防御","mdef":"魔法防御","eva":"回避","weapon_id":"武器","armor_id":"防具","armor1_id":"盾","armor2_id":"头部防具","armor3_id":"身体防具","armor4_id":"饰品","weapon_fix":"固定武器","armor1_fix":"固定盾","armor2_fix":"固定头部防具","armor3_fix":"固定身体防具","armor4_fix":"固定饰品","battler_name":"战斗图（元数据）","battler_hue":"战斗图色相","weapon_set":"可装备武器","armor_set":"可装备防具","element_ranks":"属性有效度（1=A…6=F）","state_ranks":"状态有效度（1=A…6=F）","learnings":"习得特技","level":"等级","skill_id":"特技","position":"位置","element_set":"攻击属性","guard_element_set":"防御属性","guard_state_set":"防御状态","plus_state_set":"附加状态","minus_state_set":"解除状态","auto_state_id":"自动状态","kind":"种类","animation_id":"动画","animation1_id":"使用者动画","animation2_id":"目标动画","animation_name":"动画图像","animation_hue":"动画色相","frame_max":"总帧数（自动同步）","frames":"动画帧","cell_max":"单元数量（自动同步）","cell_data":"帧单元（图案/X/Y/缩放/旋转/镜像/透明/混合）","timings":"音效与闪光时序","frame":"帧编号（从0开始）","flash_scope":"闪光范围","flash_color":"闪光颜色","flash_duration":"闪光时长（动画帧）","se":"音效","power":"威力","hit":"命中率","variance":"分散度","atk_f":"攻击关系度","pdef_f":"物防关系度","mdef_f":"魔防关系度","str_f":"力量关系度","dex_f":"灵巧关系度","agi_f":"速度关系度","int_f":"魔力关系度","eva_f":"回避关系度","consumable":"消耗品","recover_hp":"HP恢复量","recover_hp_rate":"HP恢复率","recover_sp":"SP恢复量","recover_sp_rate":"SP恢复率","parameter_type":"提升能力","parameter_points":"提升数值","menu_se":"菜单使用音效","str_plus":"力量加成","dex_plus":"灵巧加成","agi_plus":"速度加成","int_plus":"魔力加成","zero_hp":"HP为0的状态","restriction":"行动限制","nonresistance":"不受抵抗影响","cant_get_exp":"不能获得经验","cant_evade":"不能回避","slip_damage":"持续伤害（元数据）","battle_only":"仅战斗状态（元数据）","rating":"优先度","hit_rate":"命中倍率","maxhp_rate":"HP倍率","maxsp_rate":"SP倍率","str_rate":"力量倍率","dex_rate":"灵巧倍率","agi_rate":"速度倍率","int_rate":"魔力倍率","atk_rate":"攻击倍率","pdef_rate":"物防倍率","mdef_rate":"魔防倍率","hold_turn":"持续回合（元数据）","auto_release_prob":"自然解除概率（元数据）","shock_release_prob":"受击解除概率（元数据）","exp":"经验","gold":"金币","item_id":"掉落物品","treasure_prob":"掉落概率","actions":"原生行动（元数据）","passages":"通行标记（位值）","priorities":"显示优先级（0…5）","terrain_tags":"地形标记（0…7）","fog_hue":"雾色相","fog_opacity":"雾不透明度","fog_blend_type":"雾混合方式","fog_zoom":"雾缩放百分比","fog_sx":"雾横向滚动","fog_sy":"雾纵向滚动","panorama_hue":"全景色相","battleback_name":"战斗背景（元数据）","party_members":"初始队伍","words":"界面用语","elements":"属性名称（编号保持）","title_name":"标题图","gameover_name":"游戏结束图","title_bgm":"标题BGM","gameover_me":"游戏结束ME","cursor_se":"光标音效","decision_se":"确认音效","cancel_se":"取消音效","buzzer_se":"无效操作音效","equip_se":"装备音效","shop_se":"商店音效","save_se":"存档音效","load_se":"读档音效","edit_map_id":"RM编辑地图（元数据）","magic_number":"RM数据标识（元数据）","test_troop_id":"RM战斗测试敌群（元数据）","test_battlers":"RM战斗测试队伍（元数据）","battle_bgm":"战斗BGM（元数据）","battle_end_me":"战斗结束ME（元数据）","battle_transition":"战斗过渡（元数据）","battle_start_se":"战斗开始音效（元数据）","escape_se":"逃跑音效（元数据）","actor_collapse_se":"角色倒下音效（元数据）","enemy_collapse_se":"敌人倒下音效（元数据）"}
const REFERENCES := {"class_id":"Classes","weapon_id":"Weapons","armor_id":"Armors","armor1_id":"Armors","armor2_id":"Armors","armor3_id":"Armors","armor4_id":"Armors","skill_id":"Skills","item_id":"Items","common_event_id":"CommonEvents","animation_id":"Animations","animation1_id":"Animations","animation2_id":"Animations","auto_state_id":"States","actor_id":"Actors","start_map_id":"Maps"}
const SETS := {"weapon_set":"Weapons","armor_set":"Armors","element_set":"elements","guard_element_set":"elements","guard_state_set":"States","plus_state_set":"States","minus_state_set":"States","party_members":"Actors"}

static func audio(name: String = "") -> Dictionary:
	return {"_class":"RPG::AudioFile","name":name,"volume":80,"pitch":100}

static func table(x: int, y: int = 1, z: int = 1, fill: int = 0) -> Dictionary:
	var values: Array=[]; values.resize(x*y*z); values.fill(fill)
	return {"_rmxp_type":"table","dimensions":3 if z>1 else 2 if y>1 else 1,"x_size":x,"y_size":y,"z_size":z,"values":values}

static func frame() -> Dictionary:
	return {"_class":"RPG::Animation::Frame","cell_max":0,"cell_data":table(0,8)}

static func timing() -> Dictionary:
	return {"_class":"RPG::Animation::Timing","frame":0,"se":audio(),"flash_scope":0,"flash_color":{"_class":"Color","red":255,"green":255,"blue":255,"alpha":255},"flash_duration":5,"condition":0}

static func new_record(category: String, id: int, documents: RefCounted) -> Dictionary:
	var value: Dictionary={"_class":"RPG::"+category.trim_suffix("s"),"id":id,"name":""}
	match category:
		"Actors":
			value.merge({"_class":"RPG::Actor","class_id":1,"initial_level":1,"final_level":99,"exp_basis":30,"exp_inflation":30,"character_name":"","character_hue":0,"battler_name":"","battler_hue":0,"parameters":table(6,100)},true)
			for level in range(1,100):
				for i in 6: value.parameters.values[level*6+i]=500+level*50 if i==0 else 50+level*5 if i==1 else 10+level
			for key in ["weapon","armor1","armor2","armor3","armor4"]: value[key+"_id"]=0; value[key+"_fix"]=false
		"Classes","Enemies":
			var system: Dictionary=documents.read("data/system.json")
			value.merge({"element_ranks":table(system.get("elements",[]).size(),1,1,3),"state_ranks":table(documents.records("States").size(),1,1,3)},true)
			value.element_ranks.values[0]=0; value.state_ranks.values[0]=0
			if category=="Classes": value.merge({"_class":"RPG::Class","position":0,"weapon_set":[],"armor_set":[],"learnings":[]},true)
			else:
				value.merge({"_class":"RPG::Enemy","battler_name":"","battler_hue":0,"maxhp":500,"maxsp":500,"str":50,"dex":50,"agi":50,"int":50,"atk":100,"pdef":100,"mdef":100,"eva":0,"animation1_id":0,"animation2_id":0,"exp":0,"gold":0,"item_id":0,"weapon_id":0,"armor_id":0,"treasure_prob":100,"actions":[]},true)
		"Items","Skills","Weapons","Armors":
			value.merge({"icon_name":"","description":"","price":0},true)
			if category in ["Items","Skills","Weapons"]: value.merge({"animation1_id":0,"animation2_id":0,"element_set":[],"plus_state_set":[],"minus_state_set":[]},true)
			if category in ["Items","Skills"]: value.merge({"scope":0,"occasion":0,"common_event_id":0,"menu_se":audio(),"hit":100,"pdef_f":0,"mdef_f":0,"variance":0},true)
			if category=="Items": value.merge({"consumable":true,"recover_hp_rate":0,"recover_hp":0,"recover_sp_rate":0,"recover_sp":0,"parameter_type":0,"parameter_points":0},true)
			if category=="Skills":
				value.erase("price"); value.merge({"sp_cost":0,"power":0,"atk_f":0,"eva_f":0,"str_f":0,"dex_f":0,"agi_f":0,"int_f":0},true)
			if category in ["Weapons","Armors"]: value.merge({"pdef":0,"mdef":0,"str_plus":0,"dex_plus":0,"agi_plus":0,"int_plus":0},true)
			if category=="Weapons": value.atk=0
			if category=="Armors": value.merge({"kind":0,"eva":0,"auto_state_id":0,"guard_element_set":[],"guard_state_set":[]},true)
		"States":
			value.merge({"_class":"RPG::State","animation_id":0,"restriction":0,"nonresistance":false,"zero_hp":false,"cant_get_exp":false,"cant_evade":false,"slip_damage":false,"battle_only":true,"rating":5,"eva":0,"hold_turn":0,"auto_release_prob":0,"shock_release_prob":0,"guard_element_set":[],"plus_state_set":[],"minus_state_set":[]},true)
			for key in ["maxhp","maxsp","str","dex","agi","int","atk","pdef","mdef","hit"]: value[key+"_rate"]=100
		"Animations": value.merge({"_class":"RPG::Animation","animation_name":"","animation_hue":0,"position":1,"frame_max":1,"frames":[frame()],"timings":[]},true)
		"Tilesets": value.merge({"_class":"RPG::Tileset","tileset_name":"","autotile_names":["","","","","","",""],"panorama_name":"","panorama_hue":0,"fog_name":"","fog_hue":0,"fog_opacity":64,"fog_blend_type":0,"fog_zoom":200,"fog_sx":0,"fog_sy":0,"battleback_name":"","passages":table(384),"priorities":table(384),"terrain_tags":table(384)},true)
		"CommonEvents": value.merge({"_class":"RPG::CommonEvent","trigger":0,"switch_id":1,"list":[Commands.command(0)]},true)
	return value

static func hints(category: String, value: Dictionary) -> Dictionary:
	var result: Dictionary={"":{"database_category":category}}
	_collect_hints(value,[],result)
	if category=="CommonEvents": result.trigger={"options":{"0":"无（由事件/物品/特技调用）","1":"自动执行","2":"并行处理"}}
	if category=="Armors": result.kind={"options":{"0":"盾","1":"头部防具","2":"身体防具","3":"饰品"}}
	if category=="Classes": result.position={"options":{"0":"前列（元数据）","1":"中列（元数据）","2":"后列（元数据）"}}
	if category=="Animations": result.position={"options":{"0":"头部","1":"中心","2":"脚部","3":"画面"}}; result.frame_max={"readonly":true}
	if category=="Tilesets" and value.has("tileset_sources"):
		result.tileset_sources={"readonly":true,"fixed":true}
		result.tileset_name={"source_picker":true}
	return result

static func _collect_hints(value: Variant, path: Array, result: Dictionary) -> void:
	if not value is Dictionary and not value is Array: return
	var keys: Array=value.keys() if value is Dictionary else range(value.size())
	for key in keys:
		var child=path+[key]; var p="/".join(child.map(func(k: Variant) -> String: return str(k)))
		var name=str(key); var hint: Dictionary={}
		if REFERENCES.has(name): hint.db=REFERENCES[name]; hint.min=0; hint.empty="无"
		if SETS.has(name): hint.set=SETS[name]; hint.ordered=name=="party_members"
		if name in ["switches","variables","elements"]: hint.indexed=true; hint.item_default=""
		if name=="autotile_names": hint.fixed=true
		if name=="learnings": hint.item_default={"_class":"RPG::Class::Learning","level":1,"skill_id":1}
		if name=="frames": hint.item_default=frame(); hint.keep_one=true
		if name=="timings": hint.item_default=timing()
		if name=="cell_max": hint.readonly=true
		if name=="scope": hint.options={"0":"无","1":"敌方单体（元数据）","2":"敌方全体（元数据）","3":"队友单体","4":"队友全体","5":"死亡队友单体（元数据）","6":"死亡队友全体（元数据）","7":"使用者"}
		if name=="occasion": hint.options={"0":"始终","1":"战斗中（元数据）","2":"菜单中","3":"不能使用"}
		if name=="parameter_type": hint.options={"0":"无","1":"最大HP","2":"最大SP","3":"力量","4":"灵巧","5":"速度","6":"魔力"}
		if name=="restriction": hint.options={"0":"无","1":"不能使用特技","2":"攻击敌人（元数据）","3":"攻击队友（元数据）","4":"不能行动"}
		if name=="fog_blend_type": hint.options={"0":"正常","1":"加算","2":"减算"}
		if not path.is_empty() and str(path[0])=="actions":
			if name=="kind": hint.options={"0":"基本动作（元数据）","1":"特技（元数据）"}
			if name=="basic": hint.options={"0":"攻击（元数据）","1":"防御（元数据）","2":"逃跑（元数据）","3":"不行动（元数据）"}
		if name=="flash_scope": hint.options={"0":"无","1":"目标","2":"画面","3":"隐藏目标"}
		if name=="condition" and not path.is_empty() and path[0]=="timings": hint.options={"0":"始终","1":"命中","2":"未命中"}
		if name in ["initial_level","final_level","level"]: hint.min=1; hint.max=99
		if name.ends_with("_hue"): hint.min=0; hint.max=360
		if name=="price": hint.min=0; hint.max=9999999
		if name=="name" and not path.is_empty() and (str(path[-1]).ends_with("_se") or str(path[-1])=="se"): hint.asset="SE"
		if name=="name" and not path.is_empty() and str(path[-1]).ends_with("_bgm"): hint.asset="BGM"
		if name=="name" and not path.is_empty() and str(path[-1]).ends_with("_me"): hint.asset="ME"
		if name in ["battler_name","animation_name","title_name","gameover_name","battleback_name"]: hint.asset={"battler_name":"Battlers","animation_name":"Animations","title_name":"Titles","gameover_name":"Gameovers","battleback_name":"Battlebacks"}[name]
		if path==["autotile_names"]: hint.asset="Autotiles"
		if not hint.is_empty(): result[p]=hint
		_collect_hints(value[key],child,result)

static func normalize(category: String, record: Dictionary, before: Dictionary = {}) -> Dictionary:
	var value=record.duplicate(true)
	if category=="CustomData" and value.get("floors",{}).get("maps") is Dictionary:
		var lookup: Dictionary={}
		for map_id in value.floors.maps:
			var indices: Array=value.floors.maps[map_id].get("I",[])
			if indices.size()==2: lookup["%d:%d" % [int(indices[0]),int(indices[1])]]=int(map_id)
		value.floors.lookup=lookup
	if value.has("_custom_data") and value.get("name") is String and value.name!=before.get("name"):
		value._custom_data.tags=preload("res://runtime/scripts/CustomDataTags.gd").parse(value.name)
	if category=="Animations":
		var frames: Array=value.get("frames",[])
		if frames.size()!=before.get("frames",[]).size(): value.frame_max=frames.size()
		for i in frames.size():
			var f: Variant=frames[i]
			var old: Dictionary=before.frames[i] if before.get("frames") is Array and i<before.frames.size() and before.frames[i] is Dictionary else {}
			# Generic table resizing needs a counter; dedicated frame edits already supply it.
			if f is Dictionary and f.get("cell_data") is Dictionary and not old.is_empty() and int(f.get("cell_max",-1))==int(old.get("cell_max",-1)) and int(f.cell_data.get("x_size",0))!=int(old.get("cell_data",{}).get("x_size",0)): f.cell_max=int(f.cell_data.get("x_size",0))
	return value

static func reason(category: String, value: Dictionary, before: Dictionary, documents: RefCounted) -> String:
	if category=="CustomData":
		var decimal=preload("res://runtime/scripts/DecimalInteger.gd")
		if not value.get("currencies") is Array: return "货币定义须为数组。"
		var keys={}
		for currency in value.currencies:
			if not currency is Dictionary or not currency.get("key") is String or keys.has(currency.key) or not currency.get("label") is String or decimal.normalize(currency.get("maximum")).is_empty() or decimal.compare(currency.maximum,0)<0: return "货币标识、名称或上限无效。"
			keys[currency.key]=true
		if keys.keys()!=before.get("currencies",[]).map(func(c: Dictionary) -> String: return c.key): return "货币标识由脚本接口引用，不允许增删或改名。"
		var seen: Dictionary={}
		for map_id in value.get("floors",{}).get("maps",{}):
			var indices: Variant=value.floors.maps[map_id].get("I")
			if not indices is Array or indices.size()!=2 or not _integer(indices[0]) or not _integer(indices[1]): return "区域/楼层编号须为两个整数。"
			var signature="%d:%d" % [int(indices[0]),int(indices[1])]
			if seen.has(signature): return "区域和楼层组合重复："+signature
			seen[signature]=true
		return preload("res://runtime/scripts/CustomDataState.gd").plain_reason(value)

	var error=_shape_reason(value,before,[])
	if not error.is_empty(): return error
	if category=="CommonEvents":
		if not _integer(value.get("trigger")) or int(value.trigger) not in range(3): return "公共事件触发方式须为无、自动或并行。"
		if int(value.trigger)>0 and (not _integer(value.get("switch_id")) or int(value.switch_id)<=0): return "自动/并行公共事件须选择正整数开关。"
		if value.get("list",[])!=before.get("list",[]): return Commands.validate_structure(value.get("list",[]))
	if category=="Actors":
		if not _integer(value.get("initial_level")) or not _integer(value.get("final_level")) or int(value.initial_level)<1 or int(value.final_level)>99 or int(value.initial_level)>int(value.final_level): return "等级范围须为1…99内的整数，初始等级不能高于最高等级。"
		var t: Variant=value.get("parameters")
		if not t is Dictionary or int(t.get("x_size",0))!=6 or int(t.get("y_size",0))!=100: return "角色成长表须为6项能力×100行（等级0为保留行）。"
	if category=="Tilesets":
		if not value.get("autotile_names") is Array or value.autotile_names.size()!=7: return "自动图块须保留7个槽位。"
		if value.has("tileset_sources"):
			if not value.tileset_sources is Array: return "组合素材须为有序列表。"
			var keys: Array=[]
			var total=384
			for source in value.tileset_sources:
				if not source is Dictionary or not source.get("key") is String or str(source.key).is_empty() or source.key in keys or not source.get("name") is String or str(source.name).is_empty() or not _integer(source.get("rows")) or int(source.rows)<1: return "组合素材须有唯一标识、素材名称和正整数行数。"
				keys.append(source.key); total+=int(source.rows)*8
			if total>32768: return "组合图块编号不能超过RM表格可保存的32767。"
			var first="" if value.tileset_sources.is_empty() else str(value.tileset_sources[0].name)
			if value.get("tileset_name","")!=first: return "主图名称须与组合素材第一项一致，请使用组合素材窗口修改。"
		var lengths: Array=[]
		for name in ["passages","priorities","terrain_tags"]:
			var t: Variant=value.get(name)
			if not t is Dictionary: return "缺少图块标记表："+name
			lengths.append(t.get("values",[]).size())
			if t!=before.get(name):
				for n in t.get("values",[]):
					if int(n)<0 or int(n)>{"passages":255,"priorities":5,"terrain_tags":7}[name]: return "图块标记超出范围："+name
		if lengths[0]!=lengths[1] or lengths[0]!=lengths[2]: return "通行、优先级、地形表的图块数量须一致。"
	if category=="Animations" and value!=before:
		if not value.get("frames") is Array or value.frames.is_empty() or int(value.get("frame_max",0))!=value.frames.size(): return "动画至少一帧，总帧数须与帧列表一致。"
		for f in value.frames:
			if not f is Dictionary or not f.get("cell_data") is Dictionary or int(f.cell_data.get("y_size",0))!=8 or int(f.get("cell_max",-1))<0 or int(f.cell_max)>mini(16,int(f.cell_data.get("x_size",0))): return "动画帧须有0…16个单元，每个单元8项参数。"
		for t in value.get("timings",[]):
			if not t is Dictionary or int(t.get("frame",-1))<0 or int(t.frame)>=value.frames.size(): return "音效/闪光时序的帧编号超出动画范围。"
	if documents!=null:
		error=_reference_reason(value,before,[],documents)
		if category=="System" and value.get("party_members",[])!=before.get("party_members",[]) and value.get("party_members",[]).size()>4: return "初始队伍最多4名角色。"
		if category=="System" and [value.get("start_map_id"),value.get("start_x"),value.get("start_y")]!=[before.get("start_map_id"),before.get("start_x"),before.get("start_y")]:
			if not _integer(value.get("start_map_id")) or not _integer(value.get("start_x")) or not _integer(value.get("start_y")): return "玩家起点须为整数地图ID与格坐标。"
			var map: Variant=documents.read("data/maps/Map%03d.json" % int(value.start_map_id))
			if not map is Dictionary or int(value.start_x)<0 or int(value.start_y)<0 or int(value.start_x)>=int(map.get("width",0)) or int(value.start_y)>=int(map.get("height",0)): return "玩家起点超出地图范围。"
	return error

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

static func _shape_reason(value: Variant, before: Variant, path: Array) -> String:
	if value==before: return ""
	if value is Dictionary:
		if value.get("_rmxp_type","")=="table":
			for key in ["x_size","y_size","z_size"]:
				if not _integer(value.get(key)) or int(value[key])<0: return "表格尺寸无效："+str(path)
			if not value.get("values") is Array or value.values.size()!=int(value.x_size)*int(value.y_size)*int(value.z_size): return "表格尺寸与数值数量不一致："+str(path)
			for n in value.values:
				if not _integer(n) or int(n)<-32768 or int(n)>32767: return "RM表格数值须为-32768…32767的整数："+str(path)
			return ""
		for key in value:
			var error=_shape_reason(value[key],before.get(key) if before is Dictionary else null,path+[key])
			if not error.is_empty(): return error
	elif value is Array:
		for i in value.size():
			var error=_shape_reason(value[i],before[i] if before is Array and i<before.size() else null,path+[i])
			if not error.is_empty(): return error
	elif (value is int or value is float) and (not is_finite(float(value)) or abs(float(value))>9007199254740991): return "数值超出JSON精确范围；大整数货币上限请使用十进制文本："+str(path)
	return ""

static func _reference_reason(value: Variant, before: Variant, path: Array, documents: RefCounted) -> String:
	if value==before: return ""
	if value is Dictionary:
		# Command operands are checked by their own catalog, not by database field names.
		if value.has("code") or value.has("_editor_original"): return ""
		for key in value:
			if str(key).begins_with("_"): continue
			var old: Variant=before.get(key) if before is Dictionary else null
			if value[key]==old: continue
			var target=str(REFERENCES.get(key,""))
			if not target.is_empty() and value[key]!=0:
				var choices=documents.lookup(target)
				if not _integer(value[key]) or not choices.any(func(c: Dictionary) -> bool: return int(c.id)==int(value[key])): return "%s引用不存在：%s" % [str(path+[key]),str(value[key])]
			if SETS.has(key):
				if not value[key] is Array: return "集合须为编号数组："+str(path+[key])
				var choices=documents.lookup(SETS[key]); var seen: Array=[]
				for id in value[key]:
					if not _integer(id) or int(id)<=0 or int(id) in seen or not choices.any(func(c: Dictionary) -> bool: return int(c.id)==int(id)): return "集合中有重复或无效编号："+str(path+[key])
					seen.append(int(id))
			var error=_reference_reason(value[key],old,path+[key],documents)
			if not error.is_empty(): return error
	elif value is Array:
		for i in value.size():
			var error=_reference_reason(value[i],before[i] if before is Array and i<before.size() else null,path+[i],documents)
			if not error.is_empty(): return error
	return ""
