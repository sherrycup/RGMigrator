extends "SaveCodec.gd"
## Generated from SaveCodec.prepare by tools/sync_save_preparation.py.
## Schema validation stays on the main thread; a detached graph checker may run
## the same bounded graph/class validation on a worker before schema restoration.
static func prepare_cooperatively(value: Variant,definitions: RefCounted,owned_snapshot: bool,pulse: Callable,graph_check: Callable=Callable()) -> Dictionary:
	if not await pulse.call(): return fail("事件前记录已取消。")
	if value is Dictionary and value.get("format")==Graph.FORMAT:
		var graph=Graph.decode(value)
		if not graph.ok: return fail(graph.message)
		value=graph.value
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not value is Dictionary:
		return fail("进度必须是对象。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	if value.has("script_error"): return fail(str(value.script_error))
	if not await pulse.call(): return fail("事件前记录已取消。")
	var graph_profile: bool=Data.read_json("res://data/custom_data.json",{}).get("profile")=="flash"
	if not await pulse.call(): return fail("事件前记录已取消。")
	var captured_classes: Variant={"Object":{"parent":"","kind":"class"}}
	if not await pulse.call(): return fail("事件前记录已取消。")
	if value.get("script_data") is Dictionary: captured_classes=value.script_data.get("classes",captured_classes)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not captured_classes is Dictionary: captured_classes={}
	if not await pulse.call(): return fail("事件前记录已取消。")
	if graph_profile:
		# One bounded pass checks both graph data and object-class links. The
		# class/method registry itself is still validated below before publication.
		var graph_reason=(await graph_check.call(value,captured_classes)) if graph_check.is_valid() else (await Graph.reason_cooperatively(value,pulse,captured_classes))
		if not graph_reason.is_empty(): return fail(graph_reason)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var saved: Dictionary = value if owned_snapshot else Graph.clone(value) if graph_profile else value.duplicate(true)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if saved.has("flash_archive"):
		var archive_reason=preload("FlashArchiveData.gd").validate(saved.flash_archive)
		if not archive_reason.is_empty(): return fail(archive_reason)
	if not await pulse.call(): return fail("事件前记录已取消。")
	for field in ["save_count", "message_position", "message_frame"]:
		if not await pulse.call(): return fail("事件前记录已取消。")
		var default_value := 2 if field == "message_position" else 0
		var limit := MAX_INTEGER if field == "save_count" else (2 if field == "message_position" else 1)
		if not integer(saved.get(field, default_value), 0, limit): return fail("%s 无效。" % field)
		saved[field] = int(saved.get(field, default_value))
	if not await pulse.call(): return fail("事件前记录已取消。")
	var custom=Custom.new(null,false) if definitions!=null else Custom.new()
	if not await pulse.call(): return fail("事件前记录已取消。")
	if definitions!=null: custom.manifest=definitions.manifest; custom.reset()
	if not await pulse.call(): return fail("事件前记录已取消。")
	if definitions!=null and custom.manifest.get("profile")=="flash": custom._gameplay=preload("FlashGameplay.gd").new(custom,definitions.gameplay())
	if not await pulse.call(): return fail("事件前记录已取消。")
	var flash_actor: bool=custom.manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json")
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not custom.valid_currency(saved.get("gold")): return fail("gold 必须为工程货币上限内的精确整数。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.gold=Decimal.compact(saved.gold)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var custom_result=custom._restore(saved.custom_data if saved.has("custom_data") else custom.snapshot(),graph_profile)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not custom_result.ok: return fail(custom_result.message)
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.custom_data=custom.values
	if not await pulse.call(): return fail("事件前记录已取消。")
	var script_data: Variant=saved.script_data if saved.has("script_data") else {"globals":Custom.native_value(custom.manifest.get("globals",{})),"constants":Custom.native_value(custom.manifest.get("constants",{}))}
	if not await pulse.call(): return fail("事件前记录已取消。")
	var script_reason="" if graph_profile else Custom.plain_reason(script_data)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not script_reason.is_empty() or not script_data is Dictionary or not script_data.get("globals") is Dictionary or not script_data.get("constants") is Dictionary: return fail(script_reason if not script_reason.is_empty() else "脚本数据快照无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.script_data=script_data
	if not await pulse.call(): return fail("事件前记录已取消。")
	var definitions_reason=preload("ScriptRuntime.gd").validate_saved_data(script_data)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not definitions_reason.is_empty(): return fail(definitions_reason)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var objects_reason="" if graph_profile and value.get("script_data") is Dictionary else (await Graph.reason_cooperatively(saved,pulse,script_data.get("classes",{"Object":{"parent":"","kind":"class"}})))
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not objects_reason.is_empty(): return fail(objects_reason)
	if not await pulse.call(): return fail("事件前记录已取消。")
	for field in ["map_id", "player_x", "player_y", "player_direction", "steps"]:
		if not await pulse.call(): return fail("事件前记录已取消。")
		if not integer(saved.get(field)):
			return fail("%s 必须为有效整数。" % field)
		saved[field] = int(saved[field])
	if not await pulse.call(): return fail("事件前记录已取消。")
	if saved.player_direction not in [2, 4, 6, 8]:
		return fail("角色朝向无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	var player_options: Variant = saved.get("player_options", Motion.DEFAULTS.duplicate())
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not Motion.validate(player_options, true): return fail("人物移动/显示参数无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.player_options = player_options.duplicate()
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not saved.get("play_seconds") is float and not saved.get("play_seconds") is int:
		return fail("游戏时间必须为数字。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not is_finite(float(saved.play_seconds)) or saved.play_seconds < 0 or saved.play_seconds > MAX_INTEGER:
		return fail("游戏时间无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	for field in ["save_disabled", "menu_disabled"]:
		if not await pulse.call(): return fail("事件前记录已取消。")
		if not saved.get(field) is bool:
			return fail("%s 必须为布尔值。" % field)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var map := Data.map(int(saved.map_id))
	if not await pulse.call(): return fail("事件前记录已取消。")
	if map.is_empty() or saved.player_x >= int(map.get("width", 0)) or saved.player_y >= int(map.get("height", 0)):
		return fail("Map%03d 不存在或角色坐标越界。" % saved.map_id)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var overlay := testing_records(saved.get("testing"))
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not overlay.ok:
		return overlay
	if not await pulse.call(): return fail("事件前记录已取消。")
	var records: Dictionary = overlay.records
	if not await pulse.call(): return fail("事件前记录已取消。")
	var lookup := func(database: String, id: int) -> Dictionary:
		var key="%s:%d" % [database,id]
		var record: Dictionary=records.get(key,Data.source_record(database,id))
		var record_overlay: Dictionary=custom.values.records.get(key,{})
		# All consumers read definitions. In particular, checking that a common
		# event exists must not deep-copy its entire command list and bindings.
		return record if record_overlay.is_empty() else record.merged(record_overlay,true)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not saved.get("actors") is Array or saved.actors.size() > 10000:
		return fail("角色列表无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	var actors := {}
	if not await pulse.call(): return fail("事件前记录已取消。")
	for entry in saved.actors:
		if not await pulse.call(): return fail("事件前记录已取消。")
		if not entry is Dictionary or not integer(entry.get("id"), 1) or actors.has(int(entry.id)):
			return fail("角色 ID 无效或重复。")
		var id := int(entry.id)
		if Data.source_record("Actors", id).is_empty() or not integer(entry.get("class_id"), 1) or Data.source_record("Classes", int(entry.class_id)).is_empty():
			return fail("Actors[%d] 或其职业引用不存在。" % id)
		if not entry.get("name") is String or entry.name.length() > 1024:
			return fail("Actors[%d].name 无效。" % id)
		for field in ["level", "experience", "hp", "sp"]:
			if not await pulse.call(): return fail("事件前记录已取消。")
			if flash_actor and field in ["hp","sp"]:
				if not preload("FlashActorFields.gd").number(entry.get(field)) or entry[field]<0: return fail("Actors[%d].%s 无效。" % [id,field])
				continue
			if not integer(entry.get(field)):
				return fail("Actors[%d].%s 无效。" % [id, field])
		var slot_count=6 if flash_actor else 5
		if not entry.get("equipment") is Array or entry.equipment.size() != slot_count:
			return fail("Actors[%d] 必须包含%d个装备槽。" % [id,slot_count])
		for slot in slot_count:
			if not await pulse.call(): return fail("事件前记录已取消。")
			var equipment: Variant = entry.equipment[slot]
			if not integer(equipment):
				return fail("Actors[%d] 装备 ID 无效。" % id)
			if equipment != 0:
				var database: String=["Weapons","Deputies","Armors","Armors","Ornaments","Ornaments"][slot] if flash_actor else "Weapons" if slot==0 else "Armors"
				var definition: Dictionary = lookup.call(database, int(equipment))
				if definition.is_empty() or (not flash_actor and slot > 0 and int(definition.get("kind", -1)) != slot - 1):
					return fail("Actors[%d] 第 %d 槽装备引用无效。" % [id, slot + 1])
		for field in ["skill_ids", "state_ids"]:
			if not await pulse.call(): return fail("事件前记录已取消。")
			var reason := id_list(entry.get(field), "Skills" if field == "skill_ids" else "States", lookup)
			if not reason.is_empty():
				return fail("Actors[%d].%s：%s" % [id, field, reason])
		# Additive extension of schema 1: old ver0.14/0.15 saves have zero
		# actor bonuses and database graphics. Never infer bonuses from equipment.
		if entry.has("parameter_plus"):
			if not entry.parameter_plus is Dictionary or entry.parameter_plus.size() != Actor.Parameters.KEYS.size():
				return fail("Actors[%d].parameter_plus 必须包含九个属性修正。" % id)
			for key in Actor.Parameters.KEYS:
				if not await pulse.call(): return fail("事件前记录已取消。")
				if not integer(entry.parameter_plus.get(key), -Actor.Parameters.maximum(key), Actor.Parameters.maximum(key)):
					return fail("Actors[%d].%s_plus 无效。" % [id, key])
				entry.parameter_plus[key] = int(entry.parameter_plus[key])
		for field in ["character_name", "character_hue", "battler_name", "battler_hue"]:
			if not await pulse.call(): return fail("事件前记录已取消。")
			if not entry.has(field):
				continue
			if field in ["character_name", "battler_name"] and (not entry[field] is String or entry[field].length() > 1024):
				return fail("Actors[%d].%s 无效。" % [id, field])
			if field in ["character_hue", "battler_hue"] and not integer(entry[field], 0, 360):
				return fail("Actors[%d].%s 无效。" % [id, field])
		if flash_actor and not Custom.same_value(custom.values.actors.get(str(id)),entry.get("flash_actor_fields")): return fail("Actors[%d]的共享属性与角色快照不一致。" % id)
		var instance: RefCounted = preload("FlashActorState.gd").new() if flash_actor else Actor.new()
		if flash_actor: instance._rules_override=custom.gameplay().rules
		instance.configure(id, Data.source_record("Actors", id), lookup)
		var reason: String = instance.restore_persistent(entry)
		if not reason.is_empty():
			return fail("Actors[%d]：%s" % [id, reason])
		actors[id] = instance
	if not await pulse.call(): return fail("事件前记录已取消。")
	var party_reason := id_list(saved.get("party"), "Actors", lookup)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not party_reason.is_empty():
		return fail("队伍：" + party_reason)
	if not await pulse.call(): return fail("事件前记录已取消。")
	for index in saved.party.size():
		if not await pulse.call(): return fail("事件前记录已取消。")
		saved.party[index] = int(saved.party[index])
		if not actors.has(saved.party[index]):
			return fail("队伍角色缺少运行状态。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	for field in ["switches", "variables", "self_switches", "inventory"]:
		if not await pulse.call(): return fail("事件前记录已取消。")
		if not saved.get(field) is Dictionary or saved[field].size() > 100000:
			return fail("%s 必须是有效字典。" % field)
		for key in saved[field]:
			if not await pulse.call(): return fail("事件前记录已取消。")
			var entry: Variant = saved[field][key]
			if not key is String:
				return fail("%s 的键必须为字符串。" % field)
			if field == "inventory":
				var database: String = {"item": "Items", "weapon": "Weapons", "armor": "Armors"}.get(key.get_slice(":", 0), "")
				if key.get_slice_count(":") != 2 or database.is_empty() or not positive_key(key.get_slice(":", 1)) or lookup.call(database, int(key.get_slice(":", 1))).is_empty() or not integer(entry, 0, 99):
					return fail("背包引用或数量无效：" + key)
				saved.inventory[key] = int(entry)
			elif field == "self_switches":
				if key.get_slice_count(":") != 3 or not positive_key(key.get_slice(":", 0)) or not positive_key(key.get_slice(":", 1)) or key.get_slice(":", 2) not in ["A", "B", "C", "D"] or not entry is bool:
					return fail("独立开关无效：" + key)
				var event_map := Data.map(int(key.get_slice(":", 0)))
				if not event_map.get("events", {}).has(key.get_slice(":", 1)):
					return fail("独立开关地图/事件引用不存在：" + key)
			else:
				if not positive_key(key) or (field == "switches" and not entry is bool):
					return fail("开关/变量无效：" + key)
				if field == "variables" and not graph_profile and not Custom.plain_reason(entry).is_empty(): return fail("变量数据无效："+key)
				if field == "variables":
					saved.variables[key] = entry if graph_profile else Custom.native_value(entry)
	# Additive schema-1 field: old native saves default to an empty neutral screen.
	if not await pulse.call(): return fail("事件前记录已取消。")
	var settings := Settings.decode(saved.get("system_settings", Settings.new().snapshot()))
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not settings.ok: return settings
	if not await pulse.call(): return fail("事件前记录已取消。")
	var skin: Variant = settings.value.windowskin_override
	if not await pulse.call(): return fail("事件前记录已取消。")
	if skin != null and not skin.is_empty():
		var texture: Texture2D = Cache.windowskin(skin)
		if texture == null or texture.get_width() != 192 or texture.get_height() != 128: return fail("存档的窗口皮肤缺失或尺寸错误。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	var audio := Audio.decode_persistent(saved.get("audio", {"playing": {}, "memory": {}, "fades": {}}))
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not audio.ok: return audio
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.system_settings = settings.value.snapshot()
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.audio = saved.get("audio", {"playing": {}, "memory": {}, "fades": {}}).duplicate(true)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var screen_value: Variant = saved.get("screen", Screen.new().snapshot())
	if not await pulse.call(): return fail("事件前记录已取消。")
	var screen_result := Screen.decode(screen_value)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not screen_result.ok: return fail(screen_result.message)
	if not await pulse.call(): return fail("事件前记录已取消。")
	for entry in screen_value.pictures:
		if not await pulse.call(): return fail("事件前记录已取消。")
		if entry.name.begins_with("@test_") and not saved.testing.enabled:
			return fail("正式存档包含测试图片。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	var extensions := {}
	if not await pulse.call(): return fail("事件前记录已取消。")
	for entry in [["map_view", MapView], ["map_effects", Effects], ["timer", Countdown]]:
		if not await pulse.call(): return fail("事件前记录已取消。")
		var script: Script = entry[1]
		var result: Dictionary = script.decode(saved.get(entry[0], script.new().snapshot()))
		if not result.ok: return fail(result.message)
		extensions[entry[0]] = result.value
		if entry[0] == "map_effects" and result.get("legacy_weather") != null:
			var legacy_weather: RefCounted = result.legacy_weather
			if screen_value.has("weather") and screen_result.screen.weather_snapshot() != legacy_weather.snapshot(): return fail("屏幕与旧地图表现的天气字段冲突。")
			screen_result.screen.weather_state = legacy_weather
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.screen = screen_result.screen.snapshot()
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.map_effects = extensions.map_effects.snapshot()
	if not await pulse.call(): return fail("事件前记录已取消。")
	if int(extensions.map_effects.data.map_id) not in [0, saved.map_id]: return fail("地图表现所属地图与进度不一致。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	var events := Events.decode(saved.get("event_state", {}), map, lookup)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not events.ok: return events
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not events.value.is_empty() and int(events.value.map_id) != int(saved.map_id): return fail("事件现场所属地图与进度不一致。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not events.value.is_empty() and (int(events.value.player.motion.cell[0]) != int(saved.player_x) or int(events.value.player.motion.cell[1]) != int(saved.player_y) or int(events.value.player.motion.direction) != int(saved.player_direction) or events.value.player.motion.options != saved.player_options): return fail("玩家与事件现场的人物记录冲突。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	var reservation: Variant = saved.get("common_event_reservation", {})
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not reservation is Dictionary: return fail("公共事件预约无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	if not reservation.is_empty():
		if not integer(reservation.get("id"), 1) or lookup.call("CommonEvents", int(reservation.id)).is_empty() or not reservation.get("source") is String or not integer(reservation.get("actor_id"), 0) or not integer(reservation.get("target_id"), 0): return fail("公共事件预约引用无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.event_state = events.value
	if not await pulse.call(): return fail("事件前记录已取消。")
	saved.common_event_reservation = reservation.duplicate(true)
	if not await pulse.call(): return fail("事件前记录已取消。")
	var presentation={"ok":true,"value":{}}
	if not await pulse.call(): return fail("事件前记录已取消。")
	if saved.has("flash_presentation"):
		presentation=preload("FlashPresentationState.gd").prepare(saved.flash_presentation)
		if not presentation.ok: return fail(presentation.message)
	if not await pulse.call(): return fail("事件前记录已取消。")
	if saved.has("flash_temp_fields") and (not saved.flash_temp_fields is Dictionary or not graph_profile and not (await Graph.reason_cooperatively(saved.flash_temp_fields,pulse)).is_empty()): return fail("临时字段快照无效。")
	if not await pulse.call(): return fail("事件前记录已取消。")
	return {"ok": true, "state": saved, "actors": actors, "test_records": records, "screen": screen_result.screen,
		"map_view": extensions.map_view, "map_effects": extensions.map_effects, "timer": extensions.timer, "system_settings": settings.value, "audio": audio,"flash_presentation":presentation.value}
