## 职责：推进Message打字、控制码、暂停翻页和进退状态；保存同一消息游标，不执行事件奖励。
##
## 调用方式：
##   由RuntimeState.flash_messages持有，tick由唯一覆盖层按60Hz推进；W/T/ML/MU沿用正式rxdata的40帧编写换算。
##   自动分页停在下一行词元之前；confirm只开始滚动，滚动期间不会关闭或返回事件结果。
##   page_pending_token/page_resume_state/page_start_token及source_tokens随FlashPresentationState保存；提示自动滚页，不阻塞地图。
##
## 调用接口：
##   func _init(raw: String, owner: Object, is_hint: bool = false) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 raw（String；必填）：尚未解释的原始值或文本。
##     参数 owner（Object；必填）：持有此对象的调用方或运行状态。
##     参数 is_hint（bool；默认值 false）：是否按短提示样式处理文本。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func mode() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func extend_enabled() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func finished() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func opacity() -> float
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func zoom() -> float
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func frame_opacity() -> float
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func confirm() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func tick() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func plain_text() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 接口说明结束。

extends RefCounted
## Source 0152–0155 timing/control state. A renderer consumes glyph/effect output.
const Text = preload("MessageText.gd")
var tokens: Array = []
var source_tokens: Array = []
var metadata: Dictionary = {}
var cursor = 0
var state = 0  # Source: typing0, instant1, pause2, complete3, closing-1.
var process = 10
var speed = 1
var waiting = 0
var auto_terminate = 0
var interpreter_waiting = true
var move_time = 0
var movement: Array = [0, 0]
var offset = Vector2.ZERO
var back_opacity = 255
var style: Dictionary = Text.defaults()
var painted: Array = []
var effects: Array = []
var pageon = 0.0
var page_scroll = 0.0
var page_targets: Dictionary = {}
var page_breaks: Dictionary = {}
var page_pending_token = -1
var page_resume_state = 0
var page_start_token = 0
var failure = ""
var hint = false
var _state_owner: WeakRef
var _hint_opacity: Variant = null


func _init(raw: String, owner: Object, is_hint: bool = false) -> void:
	_state_owner = weakref(owner)
	hint = is_hint
	var parsed = Text.parse(raw, owner)
	if not parsed.ok:
		failure = parsed.message
		return
	tokens = parsed.tokens
	source_tokens = tokens.duplicate(true)
	metadata = parsed.metadata
	if mode() in [1, 2]:
		back_opacity = 0


func mode() -> int:
	return int(metadata.get("mo", 0))


func extend_enabled() -> bool:
	return metadata.get("extend", true)


func finished() -> bool:
	return state == -1 and process >= 10


func opacity() -> float:
	if finished():
		return 0.0
	if process == 0 and state != -1 and _hint_opacity != null:
		return clampf(float(_hint_opacity) / 255, 0, 1)
	return 0.0 if mode() == 1 else clampf((55.0 + 20 * (10 - process)) / 255, 0, 1)


func zoom() -> float:
	return (0.0 if finished() else 1.0) if mode() in [1, 2] else (10 - process) * 0.1


func frame_opacity() -> float:
	if finished():
		return 0.0
	if hint and _hint_opacity != null and process == 0 and state != -1:
		return clampf(float(_hint_opacity) / 255, 0, 1)
	if mode() in [1, 2]:
		return clampf(float(back_opacity) / 255, 0, 1)
	return opacity() if process > 0 or state == -1 else clampf(float(back_opacity) / 255, 0, 1)


func confirm() -> void:
	if process > 0 or finished():
		return
	if state == 2:
		if page_pending_token >= 0:
			pageon = maxf(0, float(page_breaks.get(page_pending_token, page_scroll)) - page_scroll)
			page_start_token = page_pending_token
			page_pending_token = -1
			state = page_resume_state
		else:
			state = 0  # 原暂停补上确认继续入口。
	elif state == 3 and auto_terminate == 0 and not hint:
		state = -1
	elif state == 0 and extend_enabled():
		state = 1


func tick() -> void:
	effects.clear()
	if not failure.is_empty() or finished():
		return
	if pageon > 0:
		var amount = minf(pageon, 2)
		pageon -= amount
		page_scroll += amount
		return
	if state == -1:
		process = 10 if mode() == 1 else process + 1
		return
	if process > 0:
		process = 0 if mode() in [1, 2] else process - 1
		return
	if state == 2:
		return
	if state == 3:
		if auto_terminate > 0:
			auto_terminate -= 1
			if auto_terminate == 0:
				state = -1
		return
	# Original detects end of row before decrementing glyph wait.
	if cursor >= tokens.size():
		state = 3
		return
	if waiting > 0:
		waiting -= 1
		return
	if move_time > 0:
		move_time -= 1
		offset -= Vector2(movement[0], movement[1])
		return
	var count = 0
	while cursor < tokens.size():
		count += 1
		if count > 100000:
			failure = "单帧即时文本超过100000个控制/字符。"
			return
		if page_breaks.has(cursor) and float(page_breaks[cursor]) > page_scroll + 0.01:
			if hint:
				pageon = float(page_breaks[cursor]) - page_scroll
				page_start_token = cursor
			else:
				page_pending_token = cursor
				page_resume_state = state
				state = 2
			return
		var token: Variant = tokens[cursor]
		cursor += 1
		if token is String:
			if token == "\n":
				continue
			painted.append(
				{
					"kind": "glyph",
					"text": token,
					"style": style.duplicate(),
					"token_index": cursor - 1
				}
			)
			if state != 1:
				break
			continue
		var code = token[0].unicode_at(0)
		match code:
			1, 20, 21, 23, 25, 26, 27, 28:
				Text.apply_style(style, token)
				return
			3:
				speed = int(token[1])
				return
			4:
				var args = str(token[1]).split(",", true)
				effects.append(
					{
						"kind": "se",
						"name": args[0],
						"volume": int(args[1]) if args.size() > 1 else 100,
						"pitch": int(args[2]) if args.size() > 2 else 100
					}
				)
				return
			5:
				waiting = Text.frame_duration(int(token[1]))
				return
			29:
				auto_terminate = Text.frame_duration(int(token[1]))
				return
			30, 31:
				move_time = Text.frame_duration(int(token[1]))
				movement = [0, 0]
				movement[0 if code == 30 else 1] = (
					int(token[2]) if token.size() > 2 and not str(token[2]).is_empty() else 1
				)
				return
			33:
				if hint:
					_hint_opacity = int(token[1])
					back_opacity = int(token[1])
				else:
					back_opacity = int(token[1])
				return
			24:
				painted.append(
					{
						"kind": "icon",
						"name": str(token[1]),
						"style": style.duplicate(),
						"token_index": cursor - 1
					}
				)
				return
			22:
				painted.append(
					{
						"kind": "fill",
						"width": int(token[1]),
						"style": style.duplicate(),
						"token_index": cursor - 1
					}
				)
				return
			2:
				var owner = _state_owner.get_ref()
				var text = (
					str(owner.custom_data.currency())
					+ str(
						preload("../00_Game/RuntimeData.gd").system().get("words", {}).get(
							"gold", ""
						)
					)
				)
				painted.append(
					{
						"kind": "glyph",
						"text": text,
						"style": style.duplicate(),
						"token_index": cursor - 1
					}
				)
			6:
				painted.append(
					{"kind": "page", "style": style.duplicate(), "token_index": cursor - 1}
				)
				pageon = maxf(0, float(page_targets.get(cursor - 1, 0)) - page_scroll)
				return
			7:
				interpreter_waiting = false
			14:
				state = 1
			15:
				state = 0
			16:
				state = 2
				return
			17:
				state = -1
				return
			18:
				pass  # Row merge handled by the layout; no painted control glyph.
			19:
				pass  # Source mark has an empty body.
		if state != 1:
			break
	waiting += speed


func plain_text() -> String:
	var result = ""
	for value in painted:
		if value.kind == "glyph":
			result += value.text
	return result
