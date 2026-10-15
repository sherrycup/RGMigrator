extends RefCounted
## Mutable project data belongs to RuntimeState. Definitions remain read-only.
const Data=preload("RuntimeData.gd")
const Decimal=preload("DecimalInteger.gd")
var manifest: Dictionary={}
var values: Dictionary={}
var failure=""
var actor_edits: Dictionary={}
var script_variables: Variant=null
var execution_context: Dictionary={}
var pending_effects: Dictionary={}
var character_edits: Array=[]
var screen_edits: Array=[]
var last_screen_request=0
var script_switches: Dictionary={}
var keyboard_draft: Dictionary={}
var scene_request: Dictionary={}
var temp_fields: Dictionary={}
var preference_data: Dictionary={}
var history_request=""
var movie_request: Dictionary={}
var snapshot_requests: Array=[]
var party_ids: Array=[]
var inventory_items: Dictionary={}
var _gameplay: RefCounted
var _map_system: RefCounted
var _owner: WeakRef
var _draft_gold: Variant=null
var live_execution=false
var preference_changed=false

func _init(owner: Object=null,initialize: bool=true) -> void:
	if owner!=null: _owner=weakref(owner)
	if not initialize: return
	manifest=Data.read_json("res://data/custom_data.json",{}).duplicate(true)
	reset()

func reset() -> void:
	values={"money":{},"system":native_value(manifest.get("system_defaults",{})),"actors":{},"records":{},"floors":{},"party":{"hatred":0}}
	if manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json"):
		values["blastics"]={}
		values["map_system"]=preload("FlashMapSystem.gd").empty_state()
		values["objects"]={"equipment":{}}
	for currency in manifest.get("currencies",[]):
		if currency.key!="gold": values.money[currency.key]=0
	_draft_gold=null; failure=""; actor_edits.clear(); script_variables=null; pending_effects.clear(); character_edits.clear(); _gameplay=null; _map_system=null
	screen_edits.clear(); last_screen_request=0; script_switches.clear(); keyboard_draft.clear(); scene_request.clear()

func currency_maximum(key: String="gold") -> Variant:
	for currency in manifest.get("currencies",[]):
		if currency.key==key: return currency.maximum
	return 9999999 if key=="gold" else null

func currency(key: String="gold") -> Variant:
	if key=="gold": return _draft_gold if _draft_gold!=null else _owner.get_ref().gold if _owner!=null and _owner.get_ref()!=null else 0
	return values.money.get(key)

func valid_currency(value: Variant,key: String="gold") -> bool:
	var maximum: Variant=currency_maximum(key)
	return maximum!=null and not Decimal.normalize(value).is_empty() and Decimal.compare(value,0)>=0 and Decimal.compare(value,maximum)<=0

func gain_currency(key: String,amount: Variant) -> Dictionary:
	var current: Variant=currency(key)
	if not valid_currency(current,key) or Decimal.normalize(amount).is_empty(): return error("货币类型、数值或现有状态无效："+key)
	var next: Variant=Decimal.clamped_add(current,amount,currency_maximum(key))
	if key=="gold":
		if _draft_gold!=null: _draft_gold=next
		elif _owner!=null and _owner.get_ref()!=null: _owner.get_ref().gold=next
	else: values.money[key]=next
	return {"ok":true,"value":next}

func currency_rows() -> Array:
	var rows: Array=[]
	for c in manifest.get("currencies",[{"key":"gold","label":"金币","maximum":"9999999"}]): rows.append({"key":c.key,"label":c.label,"value":currency(c.key),"maximum":c.maximum})
	return rows

func fork(copy_values: bool=true) -> RefCounted:
	var result=get_script().new(_owner.get_ref() if _owner!=null else null,false)
	result.manifest=manifest; result.values=preload("SaveGraph.gd").clone(values) if copy_values else {}; result._draft_gold=currency()
	if manifest.get("profile")=="flash": result._gameplay=preload("FlashGameplay.gd").new(result,gameplay())
	result.temp_fields=_owner.get_ref().flash_temp_fields.duplicate(true) if _owner!=null and _owner.get_ref()!=null else {}
	if _owner!=null and _owner.get_ref()!=null:
		result.preference_data=preload("SaveGraph.gd").clone({"vars":_owner.get_ref().flash_preferences.vars,"music_lock":_owner.get_ref().flash_preferences.music_lock}) if _owner.get_ref().flash_preferences!=null else {}
		result.party_ids=_owner.get_ref().party.duplicate()
		result.inventory_items=_owner.get_ref().inventory.duplicate(true)
	return result

func live_view() -> RefCounted:
	var owner: Node=_owner.get_ref()
	var result=get_script().new(owner,false)
	result.live_execution=true
	result.manifest=manifest; result.values=values
	result.temp_fields=owner.flash_temp_fields; result.party_ids=owner.party; result.inventory_items=owner.inventory
	result.script_variables=owner.variables
	result._gameplay=preload("FlashGameplay.gd").new(result,gameplay())
	if owner.flash_preferences!=null:
		result.preference_data={"vars":owner.flash_preferences.vars,"music_lock":owner.flash_preferences.music_lock}
	return result

func install(draft: RefCounted) -> void:
	values=draft.values
	if _owner!=null and _owner.get_ref()!=null: _owner.get_ref().gold=draft.currency()

func snapshot() -> Dictionary: return preload("SaveGraph.gd").clone(values)

func restore(value: Variant) -> Dictionary:
	return _restore(value,false)

func _restore(value: Variant,graph_checked: bool) -> Dictionary:
	if value is Dictionary and values.has("objects") and not value.has("objects"):
		value=preload("SaveGraph.gd").clone(value); value.objects={"equipment":{}}
	# Older migrator saves predate this plain map-discovery component.
	if value is Dictionary and values.has("map_system") and not value.has("map_system"):
		value=value.duplicate(true); value["map_system"]=preload("FlashMapSystem.gd").empty_state()
	# Only SaveCodec supplies graph_checked after validating this complete owned
	# snapshot. Schema/reference checks below always run, including every floor.
	var reason=("" if graph_checked else preload("SaveGraph.gd").reason(value)) if manifest.get("profile")=="flash" else plain_reason(value)
	if not reason.is_empty(): return error(reason)
	if not value is Dictionary or value.keys().size()!=values.keys().size(): return error("自定义数据快照结构无效。")
	for key in values:
		if not value.get(key) is Dictionary: return error("自定义数据分组无效："+key)
	for key in value.money:
		if not valid_currency(value.money[key],key): return error("自定义货币无效："+key)
	for key in values.money:
		if not value.money.has(key): return error("自定义货币缺失："+key)
	if values.has("blastics"):
		var object_reason=preload("FlashObjectCatalog.gd").validate_saved(value.get("objects"))
		if not object_reason.is_empty(): return error(object_reason)
		var blastic_reason=preload("FlashBlastic.gd").validate(self,value.blastics)
		if not blastic_reason.is_empty(): return error(blastic_reason)
		var tile_reason=preload("FlashMapBridge.gd").validate_saved_tiles(value.system.get("map_data",{}))
		if not tile_reason.is_empty(): return error(tile_reason)
		var map_reason=preload("FlashMapSystem.gd").validate(value.map_system)
		if not map_reason.is_empty(): return error(map_reason)
	for key in value.actors:
		if not str(key).is_valid_int() or Data.record("Actors",int(key)).is_empty(): return error("自定义角色引用无效："+str(key))
		var initial: Dictionary=Data.source_record("Actors",int(key)).get("_custom_data",{}).get("attributes",{})
		if manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json"):
			var actor_reason=preload("FlashActorFields.gd").validate(value.actors[key])
			if not actor_reason.is_empty(): return error(actor_reason)
			continue
		if not value.actors[key] is Dictionary or value.actors[key].keys().size()!=initial.keys().size(): return error("自定义角色属性结构无效。")
		for field in value.actors[key]:
			if not initial.has(field) or not _same_type(value.actors[key][field],initial[field]): return error("自定义角色属性无效："+key+"."+field)
	for key in value.records:
		if key.get_slice_count(":")!=2 or Data.record(key.get_slice(":",0),int(key.get_slice(":",1))).is_empty(): return error("自定义数据库引用无效："+str(key))
		var source=record(key.get_slice(":",0),int(key.get_slice(":",1)))
		if not value.records[key] is Dictionary: return error("自定义数据库字段结构无效。")
		for field in value.records[key]:
			if str(field).begins_with("_") or field=="id" or not source.has(field) or not _same_type(value.records[key][field],source[field]): return error("自定义数据库字段无效："+key+"."+field)
	for key in value.floors:
		if not str(key).is_valid_int() or Data.map(int(key)).is_empty(): return error("楼层引用无效："+str(key))
		var floor: Variant=value.floors[key]; var map=Data.map(int(key))
		if not floor is Dictionary or not floor.get("entries") is Dictionary or not floor.get("variety") is Dictionary or not floor.get("indices") is Dictionary: return error("楼层排列结构无效。")
		for event_id in floor.entries:
			var entry: Variant=floor.entries[event_id]
			if not map.get("events",{}).has(event_id) or not entry is Dictionary or not entry.get("fields") is Dictionary or not entry.get("position") is Array or entry.position.size()!=2: return error("楼层事件排列无效。")
			if not _integer(entry.fields.get("id")) or Data.source_record("Enemies",int(entry.fields.id)).is_empty(): return error("楼层怪物引用无效。")
			if manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json"):
				var enemy_reason=preload("FlashEnemyState.gd").validate(entry,Data.record)
				if not enemy_reason.is_empty(): return error(enemy_reason)
			for n in entry.position:
				if not _integer(n): return error("楼层怪物位置无效。")
		for species in floor.variety:
			if not str(species).is_valid_int() or Data.source_record("Enemies",int(species)).is_empty() or not floor.variety[species] is Array: return error("楼层怪物种类无效。")
			for event_id in floor.variety[species]:
				if not _integer(event_id) or not map.get("events",{}).has(str(int(event_id))): return error("楼层种类引用无效。")
		for ability in floor.indices:
			if ability not in ["hide","manor","cotack","hook"] or not floor.indices[ability] is Array: return error("楼层能力索引无效。")
			for position in floor.indices[ability]:
				if not position is Array or position.size()!=2 or not _integer(position[0]) or not _integer(position[1]): return error("楼层能力位置无效。")
	for key in value.system:
		if not values.system.has(key) or not _same_type(value.system[key],values.system[key]): return error("自定义系统字段无效："+key)
	if value.system.keys().size()!=values.system.keys().size(): return error("自定义系统字段缺失。")
	if value.party.keys()!=["hatred"] or not _integer(value.party.get("hatred")): return error("自定义队伍字段无效。")
	values=value if manifest.get("profile")=="flash" else native_value(value); return {"ok":true}

static func _integer(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and abs(float(value))<=Decimal.SAFE
static func _same_type(a: Variant,b: Variant) -> bool: return typeof(a)==typeof(b) or _integer(a) and _integer(b)

func record(database: String,id: int) -> Dictionary:
	var dynamic_skill=database=="Skills" and manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json")
	var result=(Data.record(database,id) if dynamic_skill or Data.is_test_record(database,id) else Data.source_record(database,id)).duplicate(true)
	result.merge(values.records.get(database+":"+str(id),{}),true)
	return native_value(result)

func actor_attributes(id: int) -> Dictionary:
	var key=str(id)
	if not values.actors.has(key): values.actors[key]=native_value(Data.record("Actors",id).get("_custom_data",{}).get("attributes",{}))
	return values.actors[key]

func staged_actor(id: int) -> RefCounted:
	if actor_edits.has(id): return actor_edits[id]
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if owner==null: reject("角色运行时未连接。"); return null
	if live_execution: return owner.actor(id)
	var actor: RefCounted
	if owner.actors.has(id):
		var copied: Dictionary=owner.actors[id].detached_copy()
		if not copied.ok: reject(copied.message); return null
		actor=copied.actor
	else: actor=owner.create_actor(id,record("Actors",id),record)
	if not actor.has_method("attach_project_fields"): reject("该工程没有闪翼角色属性接口。"); return null
	actor._lookup=record
	actor.attach_project_fields(actor_attributes(id))
	actor_edits[id]=actor
	return actor

func gameplay() -> RefCounted:
	if _gameplay==null: _gameplay=preload("FlashGameplay.gd").new(self)
	return _gameplay

func map_system() -> RefCounted:
	if _map_system==null: _map_system=preload("FlashMapSystem.gd").new(self)
	return _map_system

func data_ref(kind: String,id: int=0,database: String="",event: int=0) -> Dictionary:
	return {"__custom_ref":kind,"id":id,"database":database,"event":event}

func named(name: String) -> Variant:
	if manifest.get("profile")=="flash":
		if name=="Game_Object": return data_ref("project_object_type",0,"Game_Object")
		if name=="WindowScaler": return data_ref("flash_window_scaler")
		if name=="Movie_Player": return data_ref("flash_movie")
		if name=="Map_Snapshot": return data_ref("flash_snapshot_type")
		if preload("FlashSceneRegistry.gd").SCENES.has(name): return data_ref("flash_scene_type",0,name)
		if name=="GameEngine::Screen": return data_ref("flash_screen_effects")
		if name=="Broken_Screen": return data_ref("flash_broken_screen_type")
		if name=="$global_variables": return data_ref("flash_global_variables")
		if name=="$game_config": return data_ref("flash_config")
		if name=="$game_music": return data_ref("flash_music")
		if name=="BackSpace": return data_ref("flash_history")
		if name=="Kboard": return data_ref("flash_keyboard")
		if name=="$Key": return keyboard_draft.get("key",_owner.get_ref().flash_keyboard.key)
		if preload("FlashKeyboard.gd").SOURCE_KEYS.has(name): return _owner.get_ref().script_session.globals.get(name,preload("FlashKeyboard.gd").SOURCE_KEYS[name]) if _owner.get_ref().script_session!=null else preload("FlashKeyboard.gd").SOURCE_KEYS[name]
	if manifest.get("profile")=="flash" and name=="Message::TextRow": return data_ref("flash_text_row_type")
	if manifest.get("profile")=="flash" and name=="Message::Words": return data_ref("flash_message_words")
	var databases={"$data_actors":"Actors","$data_classes":"Classes","$data_items":"Items","$data_weapons":"Weapons","$data_armors":"Armors","$data_enemies":"Enemies","$data_skills":"Skills","$data_states":"States"}
	if databases.has(name): return data_ref("database",0,databases[name])
	if name=="$game_actors": return data_ref("actors")
	if name=="$game_system": return data_ref("system")
	if manifest.get("profile")=="flash":
		if name=="$game_mapSystem": return data_ref("flash_map_system")
		if name=="Game_MapSystem": return data_ref("flash_map_type")
		if name=="$game_troops": return data_ref("floors")
		if name=="$game_troop": return data_ref("floor",_owner.get_ref().map_id)
		if name=="DataBase": return data_ref("floor_tree")
		if FileAccess.file_exists("res://data/flash_gameplay.json"):
			if name=="Utils": return data_ref("flash_utils")
			if name in ["Game_Object","Game_Item","Game_Weapon","Game_Armor","Game_Ornament","Game_Deputy"]: return data_ref("project_object_type",0,name)
			if name in ["Object","Array","Hash","String","Integer","Fixnum","Bignum","Numeric","Float","NilClass","TrueClass","FalseClass","Game_Actor","Game_Enemy","Game_Battler","Game_Party","Game_Troop","RPG::Item","RPG::Weapon","RPG::Armor","RPG::Enemy"]: return {"__ruby_type":name}
			if name in ["Storage","BattleSystem::PartyRoles"]: return data_ref("gameplay_module",0,name)
			if name=="$game_temp": return data_ref("temp")
			if name=="$game_player": return data_ref("player",_owner.get_ref().map_id)
			if name=="$game_map": return data_ref("map",_owner.get_ref().map_id)
			if name=="$game_equipment": return data_ref("equipment")
			if name=="$game_blastics": return data_ref("blastics")
			if name=="$mapdamage_obj": return data_ref("map_damage_view",_owner.get_ref().map_id)
	if manifest.get("profile")=="antinomy" and name=="Monster": return data_ref("monster_data")
	return null

func index_get(ref: Dictionary,index: Variant) -> Variant:
	match ref.__custom_ref:
		"flash_global_variables": return preference_data.vars[index] if index is int and index>=0 and index<101 else null
		"blastics":
			if not _integer(index): return reject("原力器编号必须为整数。")
			var blastic: Dictionary=preload("FlashBlastic.gd").record(self,int(index))
			return data_ref("blastic",int(index)) if not blastic.is_empty() else null
		"database":
			if not index is int: return reject("数据库编号必须为整数。")
			return data_ref("record",index,ref.database) if not record(ref.database,index).is_empty() else null
		"actors":
			if not index is int: return reject("角色编号必须为整数。")
			return data_ref("actor",index) if not Data.record("Actors",index).is_empty() else null
		"floors":
			if not index is int: return reject("楼层地图编号必须为整数。")
			return data_ref("floor",index) if not Data.map(index).is_empty() else null
		"floor_entries": return floor_entry(ref.id,index)
		"floor_tree_entries":
			var tree: Dictionary=manifest.get("floors",{})
			if index is Array and index.size()==2 and _integer(index[0]) and _integer(index[1]): return native_value(tree.get("lookup",{}).get("%d:%d" % [int(index[0]),int(index[1])]))
			if _integer(index): return floor_tree_map(int(index))
			return null
		"map_events":
			if not _integer(index) or not Data.map(int(ref.id)).get("events",{}).has(str(int(index))): return null
			return data_ref("map_event",int(ref.id),"",int(index))
	return reject("该项目对象不支持下标读取。")

func invoke(ref: Dictionary,name: String,args: Array) -> Variant:
	var result: Variant=_invoke(ref,name,args)
	if live_execution and ref.__custom_ref in ["flash_global_variables","flash_config","flash_music","flash_window_scaler"] and (name.ends_with("=") or name in ["[]=","save","unlock","set_bgm_volume","set_se_volume","next_run_mode","change_window_size","resize"]):
		preference_changed=true
		var preferences: RefCounted=_owner.get_ref().flash_preferences
		preferences.vars=preference_data.vars; preferences.music_lock=preference_data.music_lock
		preferences.apply_audio(); preferences.apply_window()
	return result

func _invoke(ref: Dictionary,name: String,args: Array) -> Variant:
	if ref.__custom_ref=="flash_scene_type" and name=="new": return preload("FlashSceneRegistry.gd").construct(self,str(ref.database),args)
	if ref.__custom_ref=="flash_keyboard": return preload("FlashKeyboard.gd").invoke(self,name,args)
	if ref.__custom_ref=="flash_screen_effects": return load("res://runtime/scripts/FlashScreenEffects.gd").stage(self,name,args)
	if ref.__custom_ref=="flash_broken_screen_type" and name=="new" and args.size()<=1 and (args.is_empty() or args[0] is String):
		return {"__custom_ref":"flash_broken_screen","database":"sptx.png" if args.is_empty() else str(args[0]).trim_prefix("Graphics/Pictures/")}
	if ref.__custom_ref=="flash_broken_screen":
		if name=="get_bomb" and args.is_empty(): return load("res://runtime/scripts/FlashScreenEffects.gd").stage(self,"broken",[ref.database])
		if name=="dispose" and args.is_empty(): return null
		return reject("Broken_Screen接口无效："+name)
	if ref.__custom_ref in ["flash_text_row_type","flash_text_row"]: return load("res://runtime/scripts/FlashTextRow.gd").invoke(self,ref,name,args)
	if ref.__custom_ref=="flash_message_words":
		if name=="item_fails" and args.size()==2 and _integer(args[0]) and _integer(args[1]): return preload("FlashMessageWords.gd").item_fails(int(args[0]),int(args[1]),self)
		return reject("Message::Words参数或接口无效："+name)
	var kind: String=ref.__custom_ref
	if kind=="generic_project_object" and args.is_empty() and name in ["id","name","price","setting"]: return ref.fields[name]
	if kind=="flash_window_scaler":
		if name=="update" and args.is_empty(): return null
		if name=="resize" and args.size()==1 and args[0] is int:
			var value=3 if args[0]==4 else int(args[0]) if args[0] in [0,1,2,3] else 0
			preference_data.vars[7]=value; return value
		return reject("窗口缩放接口无效："+name)
	if kind=="flash_snapshot_type" and name=="new" and args.is_empty(): return {"__custom_ref":"flash_snapshot","scale":1,"mode":"M"}
	if kind=="flash_snapshot":
		if name=="set_scale" and args.size()==1 and args[0] in [1,2,4,8]: ref.scale=args[0]; return null
		if name=="set_mode" and args.size()==1 and args[0] in ["M","U","T","A"]: ref.mode=args[0]; return null
		if name in ["snap","snaps","snap_all"] and (args.size()==1 and (args[0] is int or args[0] is Array or args[0] is Dictionary and args[0].has("__ruby_range")) or name=="snap_all" and args.is_empty()):
			snapshot_requests.append({"method":name,"args":args,"scale":ref.scale,"mode":ref.mode}); return null
		return reject("航拍接口或参数无效："+name)
	if kind=="flash_movie":
		var game: Node=_owner.get_ref().game()
		if game==null or game._flash_movie==null: return reject("视频播放需要地图场景。")
		if name=="playing?" and args.is_empty(): return game._flash_movie.playing()
		if name in ["stop","pause","resume"] and args.is_empty(): movie_request={"method":name,"args":args}; return true
		if name=="resize" and args.size()<=4 and args.all(func(value):return value==null or value is int): movie_request={"method":name,"args":args}; return true
		if name=="play" and args.size()>=1 and args.size()<=7 and args[0] is String:
			var path=game._flash_movie.resolve_path(args[0])
			if path.is_empty(): return reject("原视频素材缺失："+args[0])
			if path.get_extension().to_lower()!="ogv": return reject("标准版Godot视频需要.ogv，原素材尚未转换。")
			if args.size()>1 and not args[1] is bool or args.size()>2 and not args[2] is bool: return reject("视频等待/跳过参数无效。")
			for i in range(3,args.size()):
				if args[i]!=null and not args[i] is int: return reject("视频区域参数无效。")
			movie_request={"method":name,"args":args}; return true
		return reject("视频接口或参数无效："+name)
	if kind=="flash_history" and name=="UndoSave" and args.is_empty(): history_request="undo"; return null
	if kind=="system" and name=="record" and (args.is_empty() or args==["AutoSave"]): history_request="record"; return null
	if kind=="flash_global_variables":
		if name=="[]=" and args.size()==2 and args[0] is int and args[0]>=0 and args[0]<101: preference_data.vars[args[0]]=args[1]; return args[1]
		if name=="vars" and args.is_empty(): return preference_data.vars
		if name=="save" and args.is_empty(): return null
	if kind in ["flash_config","flash_music"]:
		if kind=="flash_music" and name=="unlock" and args.size()==1 and args[0] is int:
			var names: Array=Data.read_json("res://data/flash_gameplay.json",{}).get("storage",{}).get("music_name",[])
			if args[0]<0 or args[0]>=names.size(): return reject("音乐解锁编号不属于原music_name列表。")
			while preference_data.music_lock.size()<=args[0]: preference_data.music_lock.append(null)
			preference_data.music_lock[args[0]]=true; return null
		if kind=="flash_music" and name in ["music_lock","lock"] and args.is_empty(): return preference_data.music_lock
		if kind=="flash_music" and name=="lock=" and args.size()==1 and args[0] is Array: preference_data.music_lock=args[0]; return args[0]
		if name in ["load_config","load_music"] and args.is_empty(): return null
		if kind=="flash_config":
			if name in ["set_bgm_volume","set_se_volume"] and args.size()==1 and args[0] is int: preference_data.vars[2 if name=="set_bgm_volume" else 3]=args[0]; return args[0]
			if name=="next_run_mode" and args.is_empty(): preference_data.vars[4]=posmod(int(preference_data.vars[4])+1,2); return preference_data.vars[4]
			if name=="change_window_size" and args.size()==1 and args[0] is int: preference_data.vars[7]=posmod(int(preference_data.vars[7])+args[0],4); return preference_data.vars[7]
		var indices={"bgm_volume":2,"se_volume":3,"run_mode":4,"skip_mode":5,"key_config":6,"window_resize":7}
		if indices.has(name.trim_suffix("=")):
			var index=int(indices[name.trim_suffix("=")])
			if name.ends_with("=") and args.size()==1: preference_data.vars[index]=args[0]; return args[0]
			if args.is_empty(): return preference_data.vars[index]
	if kind=="flash_map_type" and name=="current" and args.is_empty(): map_system().ensure_state(); return data_ref("flash_map_system")
	if kind in ["flash_map_system","flash_map_block"]: return map_system().invoke(ref,name,args)
	if kind=="flash_utils": return preload("FlashUtils.gd").invoke(self,name,args)
	if kind=="project_object_type" and name=="new": return preload("FlashObjectCatalog.gd").construct(self,ref.database,args)
	if kind=="project_object" and name in ["is_a?","kind_of?"] and args.size()==1:
		if not args[0] is Dictionary: return reject("类型判断需要类对象。")
		return preload("FlashObjectCatalog.gd").is_a(ref.database,str(args[0].get("database",args[0].get("__ruby_type",""))))
	if kind=="map_damage_view" and name=="refresh" and args.is_empty(): return preload("FlashMapBridge.gd").invoke(self,data_ref("map",int(ref.id)),"refresh_damage",[])
	if kind=="player" and name in ["after_step","poison_deal","hide_deal","manor_deal","cotack_deal","hook_deal"] and args.is_empty(): return preload("FlashMapDamage.gd").invoke(self,name)
	if kind=="business" and name=="exchange_crystal" and args.size()==3:
		for value in args:
			if not _integer(value): return reject("结晶交换参数必须为整数。")
		var result=preload("FlashBlastic.gd").exchange(self,int(args[0]),int(args[1]),int(args[2]))
		return result if result.ok else reject(result.message)
	if kind=="blastic": return preload("FlashBlastic.gd").invoke(self,int(ref.id),name,args)
	if kind=="project_object" and args.is_empty(): return preload("FlashObjectCatalog.gd").value(self,ref.database,int(ref.id),name,ref.get("fields",{}))
	if kind=="map": return preload("FlashMapBridge.gd").invoke(self,ref,name,args)
	if kind=="event_definition":
		var state: Node=_owner.get_ref(); var game: Node=state.game(); var map: Node=game.event_map() if game!=null else null
		if map==null or state.map_id!=ref.id: return reject("事件定义缺少当前地图。")
		var event: Dictionary=map.map_data.get("events",{}).get(str(ref.event),{})
		if name=="name" and args.is_empty() and not event.is_empty(): return str(event.get("name",""))
		return reject("事件定义接口尚未接入："+name)
	if kind=="player" or kind=="map_event" and name!="enemy": return preload("FlashCharacterBridge.gd").invoke(self,ref,name,args)
	if kind in ["gameplay_module","map_event","enemy_state"]: return gameplay().invoke(ref,name,args)
	if kind=="temp":
		if name=="attr_addition_clear" and args.is_empty():
			temp_fields["attr_addtion"]={"maxhp":0,"maxsp":0,"patk":0,"pdef":0,"matk":0,"mdef":0,"agi":0,"int":0,"resist":[0,0,0,0,0]}; return null
		if name.ends_with("=") and args.size()==1:
			temp_fields[name.trim_suffix("=")]=args[0]; return args[0]
		if args.is_empty(): return temp_fields.get(name)
	if kind=="floor_enemy" and FileAccess.file_exists("res://data/flash_gameplay.json") and (preload("FlashEnemyState.gd").handles(name) or name in ["battle_state","battle_result","simulate_battle","pending_battle_result","begin_battle!","finish_battle!","cal_damage","got_damage","got_turn","got_list","battle_skill_set","invalidate_battle_cache!","set_damage"]):
		return gameplay().enemy_call(ref,name,args)
	if kind=="database" and name in ["size","length"] and args.is_empty(): return Data.database(ref.database).size()
	if kind in ["record","floor_enemy"]:
		var fields: Dictionary=record(ref.database,ref.id) if kind=="record" else gameplay().enemy_fields(ref.id,ref.event) if FileAccess.file_exists("res://data/flash_gameplay.json") else _floor(ref.id).entries[str(ref.event)].fields
		if name.ends_with("=") and args.size()==1:
			var field=name.trim_suffix("=")
			if field in ["id","_class","_custom_data"] or not fields.has(field): return reject("未知或只读数据字段："+field)
			if typeof(fields[field])!=typeof(args[0]) and not (fields[field] is int and args[0] is float): return reject("数据字段类型不一致："+field)
			if not live_execution and not plain_reason(args[0]).is_empty(): return reject("数据字段值不能保存。")
			if kind=="record":
				var key=ref.database+":"+str(ref.id)
				if not values.records.has(key): values.records[key]={}
				values.records[key][field]=args[0]
			else: _floor(ref.id).entries[str(ref.event)].fields[field]=args[0]
			return args[0]
		if kind=="floor_enemy":
			if name=="enemy_id" and args.is_empty(): return fields.id
			if name=="troop" and args.is_empty(): return data_ref("floor",ref.id)
			if name=="pos" and args.is_empty(): return [fields.x,fields.y]
		if args.is_empty() and fields.has(name) and not name.begins_with("_"):
			var value: Variant=fields[name]
			if value is Dictionary and value.has("_generated_data_expression"):
				var result: Dictionary=_owner.get_ref().evaluate_custom_expression(value._generated_data_expression)
				return result.value if result.ok else reject(result.message)
			return value.duplicate(true) if kind=="record" and (value is Array or value is Dictionary) else value
		return reject("自定义数据字段或派生公式尚未迁移："+name)
	if kind=="actor":
		var attributes=actor_attributes(ref.id); var field=name.trim_suffix("=")
		if attributes.has(field) and name.ends_with("=") and args.size()==1:
			if field=="blastic":
				if args[0]!=null and (not _integer(args[0]) or args[0]<0 or args[0]>10): return reject("角色原力器编号无效。")
			elif typeof(attributes[field])!=typeof(args[0]) or not live_execution and not plain_reason(args[0]).is_empty(): return reject("角色扩展属性类型无效："+field)
			attributes[field]=args[0]; return args[0]
		if attributes.has(field) and args.is_empty(): return attributes[field]
		if manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json"):
			var actor=staged_actor(ref.id)
			if actor==null: return null
			if name.ends_with("=") and args.size()==1:
				var result: Dictionary
				if field in actor.PROJECT_KEYS: result=actor.set_project_parameter(field,args[0])
				elif field in ["hp","sp"]:
					if not preload("FlashActorFields.gd").number(args[0]): return reject("HP/SP必须为有效数值。")
					actor.set(field,args[0]); return actor.get(field)
				elif field=="exp": result=actor.set_experience(args[0])
				elif field=="level": result=actor.set_level(args[0])
				elif field=="class_id": result=actor.set_project_class(args[0])
				elif field=="name": result=actor.rename(args[0])
				elif field=="resist" and args[0] is Array: result=actor.set_resist(args[0])
				else: return reject("角色写接口尚未接入："+field)
				return args[0] if result.ok else reject(result.message)
			if args.is_empty():
				if field in actor.PROJECT_KEYS: return actor.get_parameter(field)
				if field in ["id","hp","sp","level"]: return actor.get(field)
				if field in ["class_id","character_name","character_hue","battler_name","battler_hue"]: return actor.get(field)
				if field=="equipment": return actor.equipment
				if field=="index": return party_ids.find(int(ref.id)) if party_ids.has(int(ref.id)) else null
				if field=="class_name": return str(record("Classes",actor.class_id).get("name",""))
				if field in ["animation1_id","animation2_id"]: return record("Weapons",int(actor.equipment[0])).get(field,0)
				if field.begins_with("base_") and field.trim_prefix("base_") in actor.PROJECT_KEYS: return actor._project_base_parameter(field.trim_prefix("base_"),actor.equipment)
				if field=="base_resist": return [0,0,0,0,0]
				if field=="exp": return actor.experience
				if field=="name": return actor.actor_name
				if field=="next_exp": return actor.next_level_experience()
				if field=="resist": return actor.get_resist()
				if field=="battle_down?": return actor.battle_down()
				if field=="dead?": return actor.hp<=0
				if field=="inflict_battle_down!": actor.inflict_battle_down(); return null
				if field=="recover_battle_down!": actor.recover_battle_down(); return null
				if field=="reset_all":
					var result: Dictionary=actor.reset_project_all(); return null if result.ok else reject(result.message)
				if field=="states": return actor.get_state_ids()
				if field=="skills": return actor.get_skill_ids()
				if field=="clear_state":
					var result: Dictionary=actor.clear_states(); return null if result.ok else reject(result.message)
				if field in ["state_animation_id","restriction","cant_get_exp?","cant_evade?","slip_damage?"]: return actor.project_state_query(field)
				if field=="tick_battle_down_recovery!": actor.tick_battle_down_recovery(); return null
				if field=="clear_skill": actor.clear_project_skills(); return null
			if args.size()==1 and name in ["set_blastic","remove_blastic"]:
				if name=="remove_blastic": attributes.blastic=null; return null
				return invoke(ref,"blastic=",args)
			if name=="set_graphic" and args.size()==2:
				var result: Dictionary=actor.set_event_graphic(args[0],args[1],actor.battler_name,actor.battler_hue)
				return null if result.ok else reject(result.message)
			if args.size()==1 and name in ["learn_skill","forget_skill","skill_learn?","skill_equiped?","skill_times_over?","turn_have?","inflict_battle_down!"]:
				if not _integer(args[0]): return reject("角色技能/回合参数必须为整数。")
				if name=="skill_learn?": return actor.has_skill(int(args[0]))
				if name=="skill_equiped?": return actor.project_skill_slot(int(args[0]))
				if name=="skill_times_over?": return actor.project_fields.equip_skills.values().has(int(args[0]))
				if name=="turn_have?": return actor.project_fields.equip_skills.get(str(args[0]))
				if name=="inflict_battle_down!": actor.inflict_battle_down(int(args[0])); return null
				var result: Dictionary=actor.learn_skill(int(args[0])) if name=="learn_skill" else actor.forget_skill(int(args[0]))
				return null if result.ok else reject(result.message)
			if (args.size()==1 or name=="add_state" and args.size()==2) and name in ["state?","add_state","remove_state"]:
				if not _integer(args[0]) or args[0]<=0: return reject("角色状态编号无效。")
				if args.size()==2 and not args[1] is bool: return reject("强制附加状态参数必须为布尔值。")
				if name=="state?": return actor.get_state_ids().has(int(args[0]))
				var result: Dictionary=actor.add_project_state(int(args[0]),args[1] if args.size()==2 else false) if name=="add_state" else actor.remove_state(int(args[0]))
				return null if result.ok else reject(result.message)
			if name=="periodic_damage" and args.size()==1:
				var attacker: Variant=args[0]
				if not attacker is Dictionary or attacker.get("__custom_ref","") not in ["actor","floor_enemy"]: return reject("周期伤害需要角色或怪物对象。")
				var value: Variant=invoke(attacker,"patk",[]); var magical: Variant=invoke(attacker,"matk",[])
				if not failure.is_empty(): return null
				attributes.damage=max(value-actor.get_parameter("pdef"),0)+max(magical-actor.get_parameter("mdef"),0); return attributes.damage
			if args.size()==2 and name in ["equip_skill","cancel_skill","save_skill","load_skill","trans_skill"]:
				if not _integer(args[0]) or name not in ["save_skill","load_skill"] and not _integer(args[1]): return reject("技能槽参数必须为整数。")
				if name=="trans_skill":
					var result: Dictionary=actor.trans_project_skill(int(args[0]),int(args[1])); return null if result.ok else reject(result.message)
				if name=="equip_skill":
					var result: Dictionary=actor.equip_project_skill(int(args[0]),int(args[1])); return null if result.ok else reject(result.message)
				if name=="cancel_skill": actor.cancel_project_skill(int(args[0]),int(args[1])); return null
				var result: Dictionary=actor.save_project_skill_set(int(args[0]),str(args[1])) if name=="save_skill" else actor.load_project_skill_set(int(args[0]),str(args[1]))
				return null if result.ok else reject(result.message)
			if name=="swap_skill" and args.size()==4:
				for value in args:
					if not _integer(value): return reject("技能交换参数必须为整数。")
				var result: Dictionary=actor.swap_project_skills(int(args[0]),int(args[1]),int(args[2]),int(args[3])); return null if result.ok else reject(result.message)
			if args.size()==2 and name=="equip":
				if not _integer(args[0]) or not _integer(args[1]): return reject("装备槽位/编号必须为整数。")
				var result: Dictionary=actor.equip_project(int(args[0]),int(args[1]))
				return null if result.ok else reject(result.message)
		return reject("角色玩法接口尚未接入："+name)
	if kind=="system":
		var field=name.trim_suffix("=")
		if not values.system.has(field): return reject("项目系统字段尚未接入："+name)
		if name.ends_with("=") and args.size()==1 and typeof(values.system[field])==typeof(args[0]) and plain_reason(args[0]).is_empty(): values.system[field]=args[0]; return args[0]
		if args.is_empty(): return values.system[field]
	if kind=="party": return party_call(name,args)
	if kind=="floor":
		if manifest.get("profile")!="flash": return reject("原生回合制Troop不在迁移范围。")
		var floor=_floor(ref.id)
		if name=="map_id" and args.is_empty(): return ref.id
		if name=="enemies" and args.is_empty(): return data_ref("floor_entries",ref.id)
		if name=="variety" and args.is_empty(): return floor.variety
		if name=="clear_enemies" and args.is_empty(): floor.entries.clear(); floor.indices={}; return null
		if name=="load_enemies" and args.is_empty(): values.floors.erase(str(ref.id)); _floor(ref.id); return null
		if name=="update" and args.is_empty(): _update_floor(ref.id); return null
		if name=="enemy_check" and args.size()==2: return floor_entry(ref.id,args)
		if name=="enemy_event" and args.size()==1: return floor_entry(ref.id,args[0])
	if kind=="floor_entries":
		if name in ["size","length"] and args.is_empty(): return _floor(ref.id).entries.size()*2
		if name=="empty?" and args.is_empty(): return _floor(ref.id).entries.is_empty()
		if name=="clear" and args.is_empty(): _floor(ref.id).entries.clear(); return ref
		if name=="delete" and args.size()==1:
			var entry: Variant=floor_entry(ref.id,args[0])
			if entry!=null: _floor(ref.id).entries.erase(str(entry[0] if args[0] is Array else args[0]))
			return entry
	if kind=="floor_tree":
		if name=="maptree" and args.is_empty(): return data_ref("floor_tree_entries")
		if name=="get_floor_type" and args.size()==2:
			var id=manifest.get("floors",{}).get("lookup",{}).get(str(args[0])+":"+str(args[1]),0)
			var map=manifest.get("floors",{}).get("maps",{}).get(str(id),{}); var template_id=int(map.get("templates",{}).get("P",0))
			if template_id==0: return []
			var infos: Dictionary=Data.read_json("res://data/map_infos.json",{}); var value=str(infos.get(str(template_id),{}).get("name","")).get_slice(":",1).get_slice(">",0); var chars: Array=[]
			for c in value: chars.append(c)
			return chars
	if kind=="floor_tree_entries":
		var keys: Array=[]; var entries: Array=[]
		for pair in manifest.get("floors",{}).get("lookup",{}):
			keys.append([int(str(pair).get_slice(":",0)),int(str(pair).get_slice(":",1))]); entries.append(native_value(manifest.floors.lookup[pair]))
		for key in manifest.get("floors",{}).get("maps",{}): keys.append(int(key)); entries.append(floor_tree_map(int(key)))
		if name in ["size","length"] and args.is_empty(): return keys.size()
		if name=="empty?" and args.is_empty(): return keys.is_empty()
		if name=="keys" and args.is_empty(): return keys
		if name=="values" and args.is_empty(): return entries
		if name in ["key?","has_key?","include?"] and args.size()==1: return index_get(ref,args[0])!=null
	if kind=="monster_data" and name in ["set","eset"]: return monster_set(name,args)
	return reject("项目自定义接口尚未接入："+kind+"."+name)

func floor_tree_map(map_id: int) -> Variant:
	var source: Variant=manifest.get("floors",{}).get("maps",{}).get(str(map_id))
	if not source is Dictionary: return null
	var row: Dictionary=native_value(source)
	row.erase("templates"); row.merge(native_value(source.get("templates",{})),true)
	return row

func party_call(name: String,args: Array) -> Variant:
	if manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json"):
		if name in ["set_transparent_actors","set_characters","get_characters_xy","set_characters_xy","delete_move","moveto_party_actors","setup_actor_character_sprites"]:
			var state: Node=_owner.get_ref(); var player: Node=state.player(); var game: Node=state.game()
			var map: Node=game.event_map() if game!=null else null
			if player==null or map==null or state.flash_followers==null: return reject("跟随调用缺少当前地图/玩家。")
			if name in ["set_characters","get_characters_xy","set_characters_xy"]:
				if args.is_empty() or not _integer(args[0]) or args[0]<0 or args[0]>=4: return reject("跟随者索引须为0..3整数。")
			if name=="get_characters_xy" and args.size()==1:
				var position: Array=state.flash_followers.get_characters_xy(int(args[0]))
				for edit in character_edits:
					if edit.field=="follower_call" and edit.value.method=="set_characters_xy" and edit.value.args[0]==args[0]: position=edit.value.args.slice(1)
				return position
			var valid=name in ["delete_move","setup_actor_character_sprites"] and args.is_empty()
			if name=="set_transparent_actors": valid=args.size()==1 and args[0] is bool
			elif name=="set_characters": valid=args.size()==2 and _integer(args[1]) and args[1] in [2,4,6,8]
			elif name in ["set_characters_xy","moveto_party_actors"]:
				var offset=1 if name=="set_characters_xy" else 0
				valid=args.size()==offset+2 and _integer(args[offset]) and _integer(args[offset+1]) and map.valid(int(args[offset]),int(args[offset+1]))
			if not valid: return reject("跟随调用参数无效："+name)
			character_edits.append({"target":weakref(player),"map":weakref(map),"id":-1,"field":"follower_call","value":{"method":"refresh" if name=="setup_actor_character_sprites" else name,"args":args.duplicate(true)}})
			return null
		if name=="actors" and args.is_empty():
			var result: Array=[]
			for id in party_ids: result.append(data_ref("actor",int(id)))
			return result
		if name=="max_level" and args.is_empty():
			var highest=0
			for id in party_ids: highest=maxi(highest,staged_actor(int(id)).level)
			return highest
		if name in ["all_dead?","all_battle_down?"] and args.is_empty():
			if party_ids.is_empty(): return false
			for id in party_ids:
				var actor=staged_actor(int(id))
				if not actor.battle_down() and (name=="all_battle_down?" or actor.hp>0): return false
			return true
		if name=="sync_battle_roles" and args.size()<=1:
			if not args.is_empty() and not args[0] is bool: return reject("初始化战斗职位参数必须为布尔值。")
			gameplay().role_ids(args[0] if not args.is_empty() else false,true); return null
		if name=="equipment" and args.is_empty():
			var result: Array=[[],[],[],[]]
			for id in party_ids:
				var actor=staged_actor(int(id))
				for slot in 6:
					var kind: int=slot if slot<2 else int(slot/2)+1
					if not result[kind].has(actor.equipment[slot]): result[kind].append(actor.equipment[slot])
			return result
		if name=="gain_exp" and args.size()==1:
			if not _integer(args[0]): return reject("经验增量必须为整数。")
			for id in party_ids:
				var actor=staged_actor(int(id))
				if actor==null: return null
				var result: Dictionary=actor.add_experience(args[0])
				if not result.ok: return reject(result.message)
			return null
		if name in ["item_can_use?","in_map_use?"] and args.size()==1:
			if not _integer(args[0]) or args[0]<=0: return false
			var item=record("Items",int(args[0]))
			if item.is_empty() or int(inventory_items.get("item:"+str(int(args[0])),0))==0: return false
			var occasion=int(item.get("occasion",3))
			return occasion==0 if name=="in_map_use?" else occasion in ([0,1] if temp_fields.get("in_battle",false) else [0,2])
		if name in ["item_number","gain_item","lose_item"] and args.size() in [1,2,3] and args[0] is int:
			var id=int(args[0]); var key="item:"+str(id)
			if name=="item_number" and args.size()==1: return int(inventory_items.get(key,0))
			if name in ["gain_item","lose_item"] and args.size() in [2,3] and _integer(args[1]):
				if id<=0: return null
				if record("Items",id).is_empty(): return reject("物品引用不存在："+str(id))
				inventory_items[key]=clampi(int(inventory_items.get(key,0))+int(args[1])*(1 if name=="gain_item" else -1),0,99)
				var amount=int(args[1])*(1 if name=="gain_item" else -1)
				var tag: Variant=args[2] if args.size()==3 else true
				if tag!=null and not (tag is bool and not tag):
					temp_fields.unblocking_text=null
					if amount>0:
						var suffix="" if amount==1 else " x %d\\." % amount
						temp_fields.unblocking_text="\\>\\mo[1]\\AL\\p[384,536]获得 "+str(record("Items",id).name)+suffix+"\\mu[2,-4]\\bo[50]\\mu[2,-4]\\bo[100]\\mu[2,-4]\\bo[150]\\mu[2,-4]\\bo[200]\\mu[2,-4]\\bo[255]\\w[20]\\mu[2,-4]\\bo[200]\\mu[2,-4]\\bo[150]\\mu[2,-4]\\bo[100]\\mu[2,-4]\\bo[50]\\mu[2,-4]\\bo[0]\\t[20]"
				var variables: Dictionary=script_variables if script_variables!=null else _owner.get_ref().variables
				if id in [4,variables.get("79",0),variables.get("71",0)] and _owner.get_ref().game()!=null: preload("FlashMapBridge.gd").invoke(self,data_ref("map",_owner.get_ref().map_id),"refresh_damage",[])
				return null
		if name in ["add_actor","remove_actor","add_battle_actor","remove_battle_actor"] and args.size()==1 and args[0] is int:
			var id=int(args[0])
			if record("Actors",id).is_empty(): return reject("队伍角色引用不存在："+str(id))
			var roles=gameplay().role_ids()
			if name.begins_with("add"):
				if not party_ids.has(id): party_ids.append(id)
				if staged_actor(id)==null: return null
				if name=="add_battle_actor":
					var main_id=int(roles[0]) if int(roles[0])>0 else id
					script_variables[str(gameplay().rules.constants.get("TEAMMATES",14))]=[main_id,0 if main_id==id else id]
			else:
				party_ids.erase(id)
				if name=="remove_battle_actor":
					if int(roles[0])==id: script_variables[str(gameplay().rules.constants.get("TEAMMATES",14))]=[int(roles[1]),0]
					elif int(roles[1])==id: script_variables[str(gameplay().rules.constants.get("TEAMMATES",14))]=[int(roles[0]),0]
					gameplay().role_ids(false,true)
			if _owner.get_ref().game()!=null: preload("FlashCharacterBridge.gd").invoke(self,data_ref("player",_owner.get_ref().map_id),"refresh",[])
			return null
	if name in ["gold","kin"] and args.is_empty(): return currency(name) if currency_maximum(name)!=null else reject("此工程没有该货币："+name)
	if name=="spar" and args.is_empty():
		if manifest.get("profile")!="flash": return reject("此工程没有耀晶石。")
		return [currency("spar:0"),currency("spar:1"),currency("spar:2"),currency("spar:3"),currency("spar:4")]
	var key=""; var amount: Variant=null
	if name in ["gain_gold","lose_gold","gain_kin","lose_kin"] and args.size()==1: key=name.get_slice("_",1); amount=args[0]
	elif name in ["gain_spar","lose_spar"] and args.size()==2 and args[1] is int and args[1]>=0 and args[1]<5: key="spar:"+str(args[1]); amount=args[0]
	elif name=="gain_currency" and args.size()==2 and args[0] is int and args[0] in [0,1]: key=["gold","kin"][args[0]]; amount=args[1]
	if not key.is_empty():
		if amount is Dictionary and amount.has("__decimal_integer"): amount=amount.__decimal_integer
		var result=gain_currency(key,Decimal.negate(amount) if name.begins_with("lose_") else amount)
		return result.value if result.ok else reject(result.message)
	if name=="hatred" and args.is_empty() and manifest.get("profile")=="flash": return values.party.hatred
	if name=="hatred=" and args.size()==1 and args[0] is int and manifest.get("profile")=="flash": values.party.hatred=args[0]; return args[0]
	return reject("项目队伍数据接口尚未接入："+name)

func monster_set(name: String,args: Array) -> Variant:
	if args.size()<(5 if name=="set" else 6) or not args[0] is int: return reject("Monster属性参数无效。")
	if args[0]<1: return null
	var db="Enemies" if name=="set" else "Weapons"; var ref=data_ref("record",args[0],db)
	if record(db,args[0]).is_empty(): return reject("Monster引用不存在："+str(args[0]))
	var fields=["maxhp","atk","pdef","agi","eva","gold","exp"] if name=="set" else ["str_plus","dex_plus","atk","pdef","mdef"]
	var vals=args.slice(1)
	if name=="set":
		var defaults=[0,-1,-1,1]
		while vals.size()<8: vals.append(defaults[vals.size()-4])
		for i in 3: vals[i]*=vals[7]
	for i in fields.size():
		if name=="set" and i in [5,6] and vals[i]<0: continue
		invoke(ref,fields[i]+"=",[vals[i]])
	if name=="eset" and args.size()>6 and args[6]!=null: invoke(ref,"name=",[args[6]])
	return null

func floor_entry(map_id: int,index: Variant) -> Variant:
	var floor=_floor(map_id)
	for key in floor.entries:
		var e: Dictionary=floor.entries[key]
		if index is int and int(key)==index or index is Array and index.size()==2 and int(e.position[0])==index[0] and int(e.position[1])==index[1]:
			if not _live_event(map_id,int(key)).get("alive",true): return null
			return [int(key) if index is Array else e.position,data_ref("floor_enemy",map_id,"",int(key))]
	return null

func _floor(map_id: int) -> Dictionary:
	var key=str(map_id)
	if values.floors.has(key): return values.floors[key]
	var floor={"entries":{},"variety":{},"indices":{"hide":[],"manor":[],"cotack":[],"hook":[]}}
	var matcher=RegEx.new(); matcher.compile("怪物([0-9]+)")
	for event in Data.map(map_id).get("events",{}).values():
		var found=matcher.search(str(event.get("name","")))
		if found==null: continue
		var x=int(event.x); var y=int(event.y)
		var bounds: Array=values.system.get("map_range",[])
		if bounds.size()==2 and (not _in_range(bounds[0],x) or not _in_range(bounds[1],y)): continue
		var enemy_id=int(found.get_string(1)); var fields=record("Enemies",enemy_id)
		if fields.is_empty(): failure="楼层怪物引用不存在："+str(enemy_id); continue
		var baseline=fields.duplicate(true)
		fields["hp"]=fields.get("maxhp",0); fields["sp"]=fields.get("maxsp",0)
		fields["x"]=x; fields["y"]=y; fields["skills"]=[]
		for action in fields.get("actions",[]):
			if action is Dictionary and int(action.get("kind",0))==1 and int(action.get("condition_level",0))==10: fields.skills.append(int(action.get("skill_id",0)))
		if FileAccess.file_exists("res://data/flash_gameplay.json"):
			fields["skill_parameters"]=preload("FlashEnemyAbilities.gd").map_parameters(fields.get("actions",[]),gameplay().rules.constants)
			fields["element"]=preload("FlashEnemyAbilities.gd").elements(fields)
		for ability in {"hide":"HIDE_SKILL_ID","manor":"MANOR_SKILL_ID","cotack":"COTACK_SKILL_ID","hook":"HOOK_SKILL_ID"}:
			var skill_id=int(manifest.get("constants",{}).get({"hide":"HIDE_SKILL_ID","manor":"MANOR_SKILL_ID","cotack":"COTACK_SKILL_ID","hook":"HOOK_SKILL_ID"}[ability],0))
			if skill_id in fields.skills: floor.indices[ability].append([x,y])
		floor.entries[str(int(event.id))]={"position":[x,y],"fields":fields,"definition_baseline":baseline}
		var species=str(enemy_id)
		if not floor.variety.has(species): floor.variety[species]=[]
		floor.variety[species].append(int(event.id))
	values.floors[key]=floor; return floor

func _update_floor(map_id: int) -> void:
	var floor=_floor(map_id)
	for key in floor.entries.keys():
		var live=_live_event(map_id,int(key)); var e: Dictionary=floor.entries[key]
		if not live.get("alive",true):
			var species=str(e.fields.id); floor.variety.get(species,[]).erase(int(key))
			if floor.variety.get(species,[]).is_empty(): floor.variety.erase(species)
			continue
		if live.has("position") and not same_value(e.position,live.position):
			for positions in floor.indices.values():
				for i in positions.size():
					if same_value(positions[i],e.position): positions[i]=live.position.duplicate()
			e.position=live.position

func rebuild_floor_indices(map_id: int) -> void:
	var floor=_floor(map_id)
	floor.indices={"hide":[],"manor":[],"cotack":[],"hook":[]}
	for entry in floor.entries.values():
		for ability in {"hide":"HIDE_SKILL_ID","manor":"MANOR_SKILL_ID","cotack":"COTACK_SKILL_ID","hook":"HOOK_SKILL_ID"}:
			if int(manifest.get("constants",{}).get({"hide":"HIDE_SKILL_ID","manor":"MANOR_SKILL_ID","cotack":"COTACK_SKILL_ID","hook":"HOOK_SKILL_ID"}[ability],0)) in entry.fields.get("skills",[]): floor.indices[ability].append(entry.position.duplicate())

func _live_event(map_id: int,event_id: int) -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if owner==null or owner.map_id!=map_id or owner.game()==null: return {}
	var map: Node=owner.game().event_map(); var event: Node=map.event_node(event_id) if map!=null else null
	if FileAccess.file_exists("res://data/flash_gameplay.json") and preload("FlashMapBridge.gd").is_dead(self,map_id,event_id): return {"alive":false}
	return {"alive":false} if event==null else {"alive":true,"position":preload("FlashCharacterBridge.gd").invoke(self,data_ref("map_event",map_id,"",event_id),"position",[])}

static func _in_range(value: Variant,n: int) -> bool:
	if value is Dictionary and value.has("__ruby_range"): return n>=int(value.__ruby_range.first) and (n<int(value.__ruby_range.last) if value.__ruby_range.exclusive else n<=int(value.__ruby_range.last))
	if value is Dictionary and value.has("_integer_range"): return n>=int(value._integer_range[0]) and (n<int(value._integer_range[1]) if value.get("exclusive",false) else n<=int(value._integer_range[1]))
	return false

func reject(message: String) -> Variant: failure=message; return null
static func error(message: String) -> Dictionary: return {"ok":false,"message":message}

static func native_value(value: Variant) -> Variant:
	if value is Dictionary and value.has("_decimal_integer"): return {"__decimal_integer":str(value._decimal_integer)}
	if value is Dictionary and value.has("_integer_range"): return {"__ruby_range":{"first":int(value._integer_range[0]),"last":int(value._integer_range[1]),"exclusive":value.get("exclusive",false)}}
	if value is float and value==floor(value) and abs(value)<=Decimal.SAFE: return int(value)
	if value is Array:
		var result: Array=[]
		for child in value: result.append(native_value(child))
		return result
	if value is Dictionary:
		var result={}
		for key in value: result[str(key) if key is StringName else key]=native_value(value[key])
		return result
	return value

static func plain_reason(value: Variant,seen: Array=[],depth: int=0) -> String:
	if depth>96: return "自定义数据嵌套超过96层。"
	if value is int or value is float: return "" if is_finite(float(value)) and abs(float(value))<=Decimal.SAFE else "自定义数值超出JSON精确范围。"
	if value==null or value is bool or value is String: return ""
	if not value is Array and not value is Dictionary: return "自定义对象存档按0.47接入。"
	for previous in seen:
		if is_same(previous,value): return "自定义共享引用/循环对象的存档按0.47接入。"
	seen.append(value)
	if value.size()>100000: return "自定义集合过大。"
	if value is Dictionary:
		for key in value:
			if not key is String and not key is StringName or key in ["__custom_ref","__ruby_class","__ruby_type","__service","__state_table"]: return "自定义运行对象的存档按0.47接入。"
			var reason=plain_reason(value[key],seen,depth+1)
			if not reason.is_empty(): return reason
	else:
		for child in value:
			var reason=plain_reason(child,seen,depth+1)
			if not reason.is_empty(): return reason
	return ""

static func same_value(a: Variant,b: Variant,seen: Array=[]) -> bool:
	if (a is Array or a is Dictionary) and (b is Array or b is Dictionary):
		for pair in seen:
			if is_same(pair[0],a): return is_same(pair[1],b)
		seen.append([a,b])
	if typeof(a)!=typeof(b): return (a is int or a is float) and (b is int or b is float) and a==b
	if a is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same_value(a[i],b[i],seen): return false
		return true
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same_value(a[key],b[key],seen): return false
		return true
	return a==b
