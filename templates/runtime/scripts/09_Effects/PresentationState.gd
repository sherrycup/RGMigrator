## 职责：持有闪翼特殊演出的参数和时间状态，支持保存与恢复。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/09_Effects/PresentationState.gd").方法名(...)。
##
## 调用接口：
##   static func capture(state: Node) -> Dictionary
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func prepare(value: Variant) -> Dictionary
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func restore(state: Node, row: Dictionary, game: Node, request_ids: Dictionary = {}) -> void
##     用途：恢复已经保存或捕获的状态。
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 row（Dictionary；必填）：当前列表行、文本行或记录。
##     参数 game（Node；必填）：当前游戏场景实例。
##     参数 request_ids（Dictionary；默认值 {}）：需要保留、取消或匹配的请求编号集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 公开常量：EFFECT_FIELDS、BOX_FIELDS、LAYOUT_FIELDS、ENTRY_FIELDS、EFFECT_NAMES。
## 接口说明结束。

extends RefCounted
## Persist owned model data; textures become bounded PNGs and sprite links become IDs.
const Graph = preload("../10_Support/Persistence/SaveGraph.gd")
const EFFECT_FIELDS = [
	"_serial",
	"_clock",
	"map_visible",
	"rect_amount",
	"filter_enabled",
	"frozen",
	"blurred",
	"blur_radius",
	"voice_visible",
	"voice_process",
	"voice_alpha",
	"voice_zoom",
	"voice",
	"transient",
	"active",
	"_queue",
	"results"
]
const BOX_FIELDS = [
	"tokens",
	"metadata",
	"cursor",
	"state",
	"process",
	"speed",
	"waiting",
	"auto_terminate",
	"interpreter_waiting",
	"move_time",
	"movement",
	"offset",
	"back_opacity",
	"style",
	"painted",
	"pageon",
	"page_scroll",
	"page_targets",
	"hint",
	"_hint_opacity"
]
const LAYOUT_FIELDS = [
	"positions",
	"rows",
	"box_size",
	"text_origin",
	"text_size",
	"name_text",
	"face_name",
	"face_index",
	"anchor_event",
	"fixed_anchor"
]
const ENTRY_FIELDS = [
	"id",
	"request_id",
	"event_id",
	"hint",
	"kind",
	"payload",
	"released",
	"choice_index",
	"result",
	"number"
]
const EFFECT_NAMES = [
	"set_rect",
	"freeze",
	"unfreeze",
	"appear",
	"filter",
	"Blur",
	"Unravel",
	"Scanline",
	"Flashback",
	"Voiceover",
	"wake",
	"broken",
	"character_unravel",
	"picture_unravel"
]


static func capture(state: Node) -> Dictionary:
	var effects = state.flash_effects
	if effects.active.get("capturing", false):
		return {"script_error": "截图正在采集，请等待采集完成后保存。"}
	var effect_data = _fields(effects, EFFECT_FIELDS)
	effect_data.rng_state = effects._rng.state
	effect_data.rng_seed = effects._rng.seed
	effect_data.hidden = []
	effect_data.particles = []
	for ref in effects._hidden_targets:
		var target = ref.get_ref()
		if target == null:
			continue
		var link = _target(effects, target)
		if link.is_empty():
			return {"script_error": "消散精灵不属于可恢复的地图人物或图片。"}
		effect_data.hidden.append(link)
	for entry in effects.particle_sets:
		var model = entry.model
		if model.move_effect.is_valid():
			return {"script_error": "消散粒子含未登记的动态回调，无法保存。"}
		var row = {
			"particles": model.particles,
			"image": model.image,
			"moving": model.moving,
			"disposed": model.disposed,
			"seed": model._rng.seed,
			"rng": model._rng.state
		}
		if entry.has("target"):
			row.target = _target(effects, entry.target.get_ref())
			row.location = entry.location
			if row.target.is_empty():
				return {"script_error": "消散目标已经失效。"}
		effect_data.particles.append(row)
	effect_data.broken = (
		null
		if effects.broken == null
		else {
			"shards": effects.broken.shards,
			"ticks": effects.broken.ticks,
			"seed": effects.broken._rng.seed,
			"rng": effects.broken._rng.state
		}
	)
	var messages = []
	for entry in state.flash_messages.boxes:
		var row = _fields_map(entry, ENTRY_FIELDS)
		row.model = _fields(entry.model, BOX_FIELDS)
		row.layout = _fields(entry.layout, LAYOUT_FIELDS)
		row.message_ui = {
			"version": 1,
			"source_tokens": entry.model.source_tokens,
			"page_pending_token": entry.model.page_pending_token,
			"page_resume_state": entry.model.page_resume_state,
			"page_start_token": entry.model.page_start_token,
			"digit_index": int(entry.get("digit_index", 0)),
			"input_ready": bool(entry.get("input_ready", false))
		}
		messages.append(row)
	return _pack(
		{
			"effects": effect_data,
			"messages": messages,
			"message_clock": state.flash_messages._clock,
			"message_serial": state.flash_messages._serial,
			"followers": state.flash_followers.snapshot()
		}
	)


static func prepare(value: Variant) -> Dictionary:
	if (
		not value is Dictionary
		or not value.get("effects") is Dictionary
		or not value.get("messages") is Array
		or value.messages.size() > 256
	):
		return _fail("表现现场结构无效。")
	var unpacked = _unpack(value)
	if not unpacked.ok:
		return unpacked
	var row: Dictionary = unpacked.value
	var effects: Dictionary = row.effects
	for field in EFFECT_FIELDS:
		if not effects.has(field):
			return _fail("演出字段缺失：" + field)
	for field in ["_serial", "rng_state", "rng_seed"]:
		if not effects.get(field) is int:
			return _fail("演出编号或随机状态无效。")
	if effects._serial < 0:
		return _fail("演出请求编号无效。")
	if (
		not effects.active is Dictionary
		or not effects._queue is Array
		or not effects.results is Dictionary
		or effects._queue.size() > 1000
		or effects.results.size() > 128
	):
		return _fail("演出请求无效。")
	for request in effects._queue + ([] if effects.active.is_empty() else [effects.active]):
		if (
			not request is Dictionary
			or not request.get("id") is int
			or request.id < 1
			or request.get("name") not in EFFECT_NAMES
			or not request.get("args") is Array
			or request.args.size() > 6
		):
			return _fail("演出请求身份无效。")
		if (
			request.id > effects._serial
			or not (
				preload("ScreenEffects.gd")
				. parameter_reason(request.name, request.args)
				. is_empty()
			)
		):
			return _fail("演出参数或编号无效。")
	if not effects.active.is_empty():
		var active: Dictionary = effects.active
		if (
			not active.get("tick") is int
			or active.tick < 0
			or active.tick > 1000000
			or active.get("capturing", false)
		):
			return _fail("演出进度无效。")
		if active.name in ["Blur", "Voiceover", "set_rect"] and not active.get("exit") is bool:
			return _fail("演出进退状态无效。")
		var limit = (
			12
			if active.name in ["Blur", "set_rect"]
			else (
				120
				if active.name == "Scanline"
				else (
					40
					if active.name in ["Flashback", "Voiceover"]
					else 90 if active.name == "broken" else 1000000
				)
			)
		)
		if active.tick >= limit:
			return _fail("活动演出已超过结束位置。")
	if (
		not effects.map_visible is bool
		or not effects.filter_enabled is bool
		or not effects.voice_visible is bool
		or not effects.rect_amount is int
		or effects.rect_amount < 0
		or effects.rect_amount > 74
	):
		return _fail("演出显示参数无效。")
	for field in ["_clock", "blur_radius", "voice_process", "voice_alpha", "voice_zoom"]:
		if not _number(effects[field]) or absf(effects[field]) > 1000000:
			return _fail("演出计时或显示参数无效。")
	for field in ["frozen", "blurred", "voice"]:
		if effects[field] != null and not effects[field] is Texture2D:
			return _fail("演出纹理无效。")
	if (
		not effects.get("particles") is Array
		or effects.particles.size() > 1000
		or not effects.get("hidden") is Array
	):
		return _fail("消散集合无效。")
	for link in effects.hidden:
		if not _link_valid(link):
			return _fail("消散显示关系无效。")
	for entry in effects.particles:
		if (
			not entry is Dictionary
			or not entry.get("particles") is Array
			or entry.particles.size() > 65536
			or not entry.get("image") is Image
			or not entry.get("moving") is bool
			or not entry.get("disposed") is bool
		):
			return _fail("消散模型无效。")
		if (
			entry.has("target")
			and (not _link_valid(entry.target) or not entry.get("location") is Vector2)
		):
			return _fail("消散目标无效。")
		if not entry.get("seed") is int or not entry.get("rng") is int:
			return _fail("消散随机状态无效。")
		for particle in entry.particles:
			if not _particle_valid(particle):
				return _fail("消散粒子无效。")
	if effects.get("broken") != null:
		var broken: Variant = effects.broken
		if (
			not broken is Dictionary
			or not broken.get("shards") is Array
			or broken.shards.size() > 256
			or not broken.get("ticks") is int
			or broken.ticks < 0
			or broken.ticks > 90
		):
			return _fail("碎屏状态无效。")
		if not broken.get("seed") is int or not broken.get("rng") is int:
			return _fail("碎屏随机状态无效。")
		for shard in broken.shards:
			if (
				not shard is Dictionary
				or not shard.get("texture") is Texture2D
				or not shard.get("position") is Vector2
				or not shard.get("velocity") is Vector2
				or not shard.get("scale") is Vector2
				or not shard.get("axis") is int
				or shard.axis not in [0, 1]
			):
				return _fail("碎屏片段无效。")
	for message in row.messages:
		if not message is Dictionary:
			return _fail("消息记录无效。")
		for field in ENTRY_FIELDS:
			if not message.has(field):
				return _fail("消息字段缺失。")
		if (
			message.kind not in ["message", "choice", "number"]
			or not message.payload is Dictionary
			or not message.hint is bool
			or not message.released is bool
			or not message.request_id is int
		):
			return _fail("消息请求无效。")
		if (
			not message.id is int
			or message.id < 1
			or not message.event_id is int
			or not message.choice_index is int
			or message.choice_index < 0
			or not message.number is int
			or message.number < 0
		):
			return _fail("消息编号或输入值无效。")
		if (
			message.kind == "choice"
			and (
				not message.payload.get("choices") is Array
				or message.payload.choices.is_empty()
				or message.choice_index >= message.payload.choices.size()
			)
		):
			return _fail("消息选择项无效。")
		if (
			message.kind == "number"
			and (
				not message.payload.get("digits") is int
				or message.payload.digits < 1
				or message.payload.digits > 8
				or not message.payload.get("variable") is int
				or message.payload.variable < 1
			)
		):
			return _fail("消息数值输入无效。")
		if not message.get("model") is Dictionary or not message.get("layout") is Dictionary:
			return _fail("消息模型无效。")
		for field in BOX_FIELDS:
			if not message.model.has(field):
				return _fail("消息模型字段缺失。")
		for field in LAYOUT_FIELDS:
			if not message.layout.has(field):
				return _fail("消息布局字段缺失。")
		var box: Dictionary = message.model
		if (
			not box.tokens is Array
			or box.tokens.size() > 100000
			or not box.cursor is int
			or box.cursor < 0
			or box.cursor > box.tokens.size()
			or not box.state is int
			or box.state not in [-1, 0, 1, 2, 3]
			or not box.process is int
			or box.process < 0
			or box.process > 10
			or not box.painted is Array
			or not box.metadata is Dictionary
			or not box.style is Dictionary
			or not box.offset is Vector2
		):
			return _fail("消息游标或状态无效。")
		if (
			not _style_valid(box.style)
			or not box.movement is Array
			or box.movement.size() != 2
			or not box.movement[0] is int
			or not box.movement[1] is int
			or not box.page_targets is Dictionary
			or not box.interpreter_waiting is bool
			or box.hint != message.hint
		):
			return _fail("消息样式或等待无效。")
		for token in box.tokens:
			if token is String:
				continue
			if (
				not token is Array
				or token.is_empty()
				or not token[0] is String
				or token[0].length() != 1
				or (
					token[0].unicode_at(0)
					not in preload("../06_Message/MessageText.gd").CODES.values()
				)
			):
				return _fail("消息控制码无效。")
			var code = token[0].unicode_at(0)
			if (
				code in [1, 3, 5, 20, 21, 22, 27, 28, 29, 33]
				and (token.size() != 2 or not token[1] is int)
			):
				return _fail("消息整数控制码参数无效。")
			if code in [4, 23, 24, 25, 26] and (token.size() != 2 or not token[1] is String):
				return _fail("消息文本控制码参数无效。")
			if (
				code in [30, 31]
				and (
					token.size() != 3
					or not token[1] is int
					or not (token[2] is int or token[2] is String)
				)
			):
				return _fail("消息位移控制码参数无效。")
		for painted in box.painted:
			if (
				not painted is Dictionary
				or painted.get("kind") not in ["glyph", "icon", "fill", "page"]
				or not painted.get("token_index") is int
				or painted.token_index < 0
				or painted.token_index >= box.tokens.size()
				or not _style_valid(painted.get("style"))
			):
				return _fail("已绘制消息内容无效。")
			if (
				painted.kind == "glyph" and not painted.get("text") is String
				or painted.kind == "icon" and not painted.get("name") is String
				or painted.kind == "fill" and not painted.get("width") is int
			):
				return _fail("已绘制消息字段无效。")
		if message.has("message_ui") and not _message_ui_valid(message.message_ui, message):
			return _fail("消息分页或数字光标现场无效。")
		var layout: Dictionary = message.layout
		if (
			not layout.positions is Dictionary
			or not layout.rows is Array
			or not layout.box_size is Vector2
			or not layout.text_origin is Vector2
			or not layout.text_size is Vector2
			or not layout.name_text is String
			or not layout.face_name is String
			or not layout.face_index is int
			or layout.face_index < 0
			or not layout.anchor_event is int
			or layout.fixed_anchor != null and not layout.fixed_anchor is Vector2
		):
			return _fail("消息布局类型无效。")
		for key in layout.positions:
			var pos: Variant = layout.positions[key]
			if not key is int or key < 0 or key >= box.tokens.size() or not pos is Dictionary:
				return _fail("消息布局游标无效。")
			for field in ["x", "y", "height", "advance"]:
				if not _number(pos.get(field)):
					return _fail("消息布局度量无效。")
		for field in [
			"speed",
			"waiting",
			"auto_terminate",
			"move_time",
			"back_opacity",
			"pageon",
			"page_scroll"
		]:
			if not _number(box[field]) or box[field] < 0 or box[field] > 1000000000:
				return _fail("消息时间无效。")
	var follower_reason = preload("../03_Map/Followers.gd").validate_snapshot(
		row.get("followers")
	)
	if not follower_reason.is_empty():
		return _fail(follower_reason)
	if (
		not _number(row.get("message_clock"))
		or row.message_clock < 0
		or not row.get("message_serial") is int
	):
		return _fail("消息时钟无效。")
	return {"ok": true, "value": row}


static func restore(state: Node, row: Dictionary, game: Node, request_ids: Dictionary = {}) -> void:
	var effects = state.flash_effects
	for field in EFFECT_FIELDS:
		effects.set(field, row.effects[field])
	effects._rng.seed = row.effects.rng_seed
	effects._rng.state = row.effects.rng_state
	effects.particle_sets.clear()
	effects._hidden_targets.clear()
	var view: Node = effects._view.get_ref()
	for saved in row.effects.particles:
		var model = preload("Unravel.gd").new()
		model.particles = saved.particles
		model.image = saved.image
		model.moving = saved.moving
		model.disposed = saved.disposed
		model._rng.seed = saved.seed
		model._rng.state = saved.rng
		var entry = {"model": model}
		if saved.has("target"):
			var target = view.target_sprite(saved.target.kind, int(saved.target.id))
			if target != null:
				entry.target = weakref(target)
				entry.location = saved.location
		effects.particle_sets.append(entry)
	for link in row.effects.hidden:
		var target = view.target_sprite(link.kind, int(link.id))
		if target != null:
			target.set_meta("flash_unravel_hidden", true)
			target.visible = false
			effects._hidden_targets.append(weakref(target))
	if row.effects.broken != null:
		effects.broken = preload("BrokenScreen.gd").new()
		effects.broken.shards = row.effects.broken.shards
		effects.broken.ticks = row.effects.broken.ticks
		effects.broken._rng.seed = row.effects.broken.seed
		effects.broken._rng.state = row.effects.broken.rng
	else:
		effects.broken = null
	effects.appear(row.effects.map_visible)
	view.sync()
	state.flash_followers.restore_snapshot(row.followers)
	state.flash_messages.boxes.clear()
	state.flash_messages._clock = row.message_clock
	state.flash_messages._serial = row.message_serial
	for saved in row.messages:
		var model = preload("../06_Message/MessageBoxState.gd").new("", state, saved.hint)
		for field in BOX_FIELDS:
			model.set(field, saved.model[field])
		var ui: Dictionary = saved.get("message_ui", {})
		model.source_tokens = ui.get("source_tokens", saved.model.tokens).duplicate(true)
		var layout = preload("../06_Message/MessageLayout.gd").new(
			model,
			state,
			state.flash_messages.viewport_size,
			preload("../06_Message/MessageLayout.gd").choice_lines(saved.payload),
			32 if saved.kind == "number" else 0
		)
		for field in BOX_FIELDS:
			model.set(field, saved.model[field])
		if (
			ui.is_empty()
			and saved.layout.box_size.x <= layout.box_size.x
			and saved.layout.box_size.y <= layout.box_size.y
		):
			# 旧档已取出A/LS且没有原始词元，安全尺寸内保留已存的行对齐及字形位置。
			for field in LAYOUT_FIELDS:
				layout.set(field, saved.layout[field])
		model.page_pending_token = int(ui.get("page_pending_token", -1))
		model.page_resume_state = int(ui.get("page_resume_state", 0))
		model.page_start_token = int(ui.get("page_start_token", 0))
		var entry = _fields_map(saved, ENTRY_FIELDS)
		entry.digit_index = int(ui.get("digit_index", 0))
		entry.input_ready = bool(ui.get("input_ready", false))
		entry.model = model
		entry.layout = layout
		if request_ids.has(entry.request_id):
			entry.request_id = request_ids[entry.request_id]
			for request in game._event_ui._pending.duplicate():
				if request.id == entry.request_id:
					game._event_ui._pending.erase(request)
					game._event_ui.active = request
					game._dialogue._flash_request_id = entry.request_id
					break
		state.flash_messages.boxes.append(entry)
	state.flash_messages.changed.emit()


static func _message_ui_valid(ui: Variant, message: Dictionary) -> bool:
	if (
		not ui is Dictionary
		or ui.get("version") != 1
		or not ui.get("source_tokens") is Array
		or ui.source_tokens.size() > 100000
	):
		return false
	var box: Dictionary = message.model
	for field in ["page_pending_token", "page_resume_state", "page_start_token", "digit_index"]:
		if not ui.get(field) is int:
			return false
	if (
		not ui.get("input_ready") is bool
		or ui.page_resume_state not in [0, 1]
		or ui.page_start_token < 0
		or ui.page_start_token > box.cursor
	):
		return false
	if (
		ui.page_pending_token < -1
		or ui.page_pending_token >= box.tokens.size()
		or (ui.page_pending_token >= 0 and (ui.page_pending_token != box.cursor or box.state != 2))
	):
		return false
	if (
		ui.digit_index < 0
		or ui.digit_index >= (int(message.payload.digits) if message.kind == "number" else 1)
	):
		return false
	# 来源词元只多出整行A/LS设置，以及MR和紧邻换行；其余必须与已验证执行词元一致。
	var normalized: Array = []
	var merge_next = false
	for token in ui.source_tokens:
		if (
			token is Array
			and token.size() == 2
			and token[0] is String
			and token[0] in [String.chr(27), String.chr(28)]
			and token[1] is int
		):
			continue
		if token is Array and token == [String.chr(18)]:
			merge_next = true
			continue
		if token is String and token == "\n" and merge_next:
			merge_next = false
			continue
		merge_next = false
		normalized.append(token)
	return normalized == box.tokens


static func _fields(owner: Object, names: Array) -> Dictionary:
	var result = {}
	for name in names:
		result[name] = owner.get(name)
	return result


static func _fields_map(owner: Dictionary, names: Array) -> Dictionary:
	var result = {}
	for name in names:
		result[name] = owner.get(name)
	return result


static func _target(effects: RefCounted, target: Sprite2D) -> Dictionary:
	var view: Node = effects._view.get_ref() if effects._view != null else null
	if view == null or target == null:
		return {}
	for id in range(1, 51):
		if view.target_sprite("picture_unravel", id) == target:
			return {"kind": "picture_unravel", "id": id}
	if view.target_sprite("character_unravel", -1) == target:
		return {"kind": "character_unravel", "id": -1}
	for key in view.game._map.map_data.get("events", {}):
		if view.target_sprite("character_unravel", int(key)) == target:
			return {"kind": "character_unravel", "id": int(key)}
	return {}


static func _link_valid(link: Variant) -> bool:
	return (
		link is Dictionary
		and link.get("kind") in ["picture_unravel", "character_unravel"]
		and link.get("id") is int
		and (link.id >= 1 and link.id <= 50 if link.kind == "picture_unravel" else link.id >= -1)
	)


static func _particle_valid(p: Variant) -> bool:
	return (
		p is Dictionary
		and p.get("texture") is Texture2D
		and p.get("position") is Vector2
		and p.get("velocity") is Vector2
		and p.get("raw_velocity") is Vector2
		and p.get("scale") is Vector2
		and _number(p.get("fade"))
		and _number(p.get("opacity"))
		and _number(p.get("angle"))
		and p.get("blend_type") in [0, 1, 2]
		and p.get("index") is int
	)


static func _pack(value: Variant) -> Variant:
	if value is Texture2D or value is Image:
		var image: Image = value.get_image() if value is Texture2D else value
		return {
			"__flash_png": Marshalls.raw_to_base64(image.save_png_to_buffer()),
			"texture": value is Texture2D
		}
	if value is Array:
		var result = []
		for child in value:
			result.append(_pack(child))
		return result
	if value is Dictionary:
		var result = {}
		for key in value:
			result[key] = _pack(value[key])
		return result
	return value


static func _unpack(value: Variant, depth: int = 0) -> Dictionary:
	if depth > 128:
		return _fail("表现数据嵌套过深。")
	if value is Dictionary and value.has("__flash_png"):
		if (
			not value.__flash_png is String
			or value.__flash_png.length() > 8 * 1024 * 1024
			or not value.get("texture") is bool
		):
			return _fail("表现图像无效。")
		var bytes = Marshalls.base64_to_raw(value.__flash_png)
		if (
			bytes.size() < 24
			or bytes.size() > 6 * 1024 * 1024
			or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
		):
			return _fail("表现PNG无效。")
		var width = (
			(int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
		)
		var height = (
			(int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
		)
		if width < 1 or height < 1 or width > 2048 or height > 2048:
			return _fail("表现PNG尺寸超限。")
		var image = Image.new()
		if image.load_png_from_buffer(bytes) != OK:
			return _fail("表现PNG解码失败。")
		return {
			"ok": true, "value": ImageTexture.create_from_image(image) if value.texture else image
		}
	if value is Array or value is Dictionary:
		var result: Variant = [] if value is Array else {}
		for key in range(value.size()) if value is Array else value.keys():
			var child = _unpack(value[key], depth + 1)
			if not child.ok:
				return child
			if value is Array:
				result.append(child.value)
			else:
				result[key] = child.value
		return {"ok": true, "value": result}
	return {"ok": true, "value": value}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _style_valid(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not value.get("font_name") is String
		or not value.get("font_size") is int
		or value.font_size < 1
		or value.font_size > 512
		or not value.get("bold") is bool
		or not value.get("italic") is bool
	):
		return false
	for field in ["color", "opacity", "line_space", "halign", "valign"]:
		if not value.get(field) is int:
			return false
	return true


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
