## 职责：计算人物格子移动、跳跃和插值进度，统一原帧率下的移动时间。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/CharacterMotion.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/03_Map/CharacterMotion.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   static func validate(value: Variant, complete: bool = false) -> bool
##     用途：检查输入数据是否符合该服务的约定。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 complete（bool；默认值 false）：是否已达到完整结束状态。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func configure(value: Dictionary) -> Dictionary
##     用途：配置本实例使用的数据和依赖。
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func reset() -> void
##     用途：重置本服务持有的状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func relocate(destination: Vector2i) -> void
##     参数 destination（Vector2i；必填）：输出目标、目标对象或位置。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func is_idle() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func moving() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func jumping() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func turn(value: int, force: bool = false) -> bool
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     参数 force（bool；默认值 false）：是否请求强制执行；仍受接口自身校验约束。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func pixels_per_second() -> float
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func begin_move(value: int) -> bool
##     参数 value（int；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func begin_diagonal(offset: Vector2i) -> bool
##     参数 offset（Vector2i；必填）：相对基准的偏移量。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func turn_diagonal(offset: Vector2i) -> bool
##     参数 offset（Vector2i；必填）：相对基准的偏移量。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func begin_jump(offset: Vector2i) -> bool
##     参数 offset（Vector2i；必填）：相对基准的偏移量。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func advance(delta: float) -> String
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func persistent_data() -> Dictionary
##     用途：导出参与保存与恢复的状态数据。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func decode(value: Variant, width: int, height: int) -> Dictionary
##     用途：解析编码数据并返回对应原值或结构。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 width（int；必填）：区域或画布宽度。
##     参数 height（int；必填）：区域或画布高度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：DIRECTIONS、DEFAULTS。
## 接口说明结束。

extends RefCounted
## Grid decisions and time-based visual motion; no event interpreter or renderer.
const DIRECTIONS := {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}
const DEFAULTS := {
	"move_speed": 4,
	"walk_anime": true,
	"step_anime": false,
	"direction_fix": false,
	"through": false,
	"transparent": false,
	"opacity": 255,
	"blend_type": 0,
	"idle_pattern": 0
}
const Data = preload("../00_Game/RuntimeData.gd")
var cell := Vector2i.ZERO
var target := Vector2i.ZERO
var visual_cell := Vector2.ZERO
var direction := 2
var pattern := 0
var options := DEFAULTS.duplicate()
var jump_height := 0.0
var _kind := ""
var _start := Vector2.ZERO
var _duration := 0.0
var _elapsed := 0.0
var _animation := 0.0
var _idle_seconds := 0.0


func _init() -> void:
	if _flash():
		options.move_speed = 5  # Final source 0093 constructor.


static func _flash() -> bool:
	var custom: RefCounted = Data._custom_state.get_ref() if Data._custom_state != null else null
	return custom != null and custom.manifest.get("profile") == "flash"


static func validate(value: Variant, complete: bool = false) -> bool:
	if not value is Dictionary or (complete and value.size() != DEFAULTS.size()):
		return false
	for key in value:
		if not DEFAULTS.has(key):
			return false
		var field: Variant = value[key]
		if DEFAULTS[key] is bool:
			if not field is bool:
				return false
		else:
			if (
				not (field is int or field is float)
				or not is_finite(float(field))
				or floor(float(field)) != float(field)
			):
				return false
			var bounds: Array = {
				"move_speed": [1, 6],
				"opacity": [0, 255],
				"blend_type": [0, 2],
				"idle_pattern": [0, 3]
			}[key]
			if field < bounds[0] or field > bounds[1]:
				return false
	return true


func configure(value: Dictionary) -> Dictionary:
	if not validate(value):
		return {"ok": false, "message": "人物参数无效：速度 1–6、透明度 0–255、混合 0–2、静止帧 0–3；开关须为布尔值。"}
	for key in value:
		options[key] = value[key] if DEFAULTS[key] is bool else int(value[key])
	return {"ok": true}


func reset() -> void:
	options = DEFAULTS.duplicate()
	if _flash():
		options.move_speed = 5
	direction = 2
	pattern = 0
	_animation = 0
	relocate(Vector2i.ZERO)


func relocate(destination: Vector2i) -> void:
	cell = destination
	target = destination
	visual_cell = Vector2(destination)
	_start = visual_cell
	_kind = ""
	_elapsed = 0
	jump_height = 0
	_idle_seconds = 0
	pattern = int(options.idle_pattern)


func is_idle() -> bool:
	return _kind.is_empty()


func moving() -> bool:
	return _kind == "walk"


func jumping() -> bool:
	return _kind == "jump"


func turn(value: int, force: bool = false) -> bool:
	if not DIRECTIONS.has(value) or (options.direction_fix and not force):
		return false
	direction = value
	return true


func pixels_per_second() -> float:
	return pow(2.0, int(options.move_speed)) * (15.0 if _flash() else 10.0)


func begin_move(value: int) -> bool:
	if not is_idle() or not DIRECTIONS.has(value):
		return false
	turn(value)
	_start = visual_cell
	target = cell + DIRECTIONS[value]
	_duration = 32.0 / pixels_per_second()
	_elapsed = 0
	_idle_seconds = 0
	_kind = "walk"
	return true


func begin_diagonal(offset: Vector2i) -> bool:
	if not is_idle() or absi(offset.x) != 1 or absi(offset.y) != 1:
		return false
	turn_diagonal(offset)
	_start = visual_cell
	target = cell + offset
	# RM advances each axis at its cardinal speed, rather than normalizing diagonals.
	_duration = 32.0 / pixels_per_second()
	_elapsed = 0
	_idle_seconds = 0
	_kind = "walk"
	return true


func turn_diagonal(offset: Vector2i) -> bool:
	if absi(offset.x) != 1 or absi(offset.y) != 1:
		return false
	if direction == (4 if offset.x > 0 else 6):
		return turn(6 if offset.x > 0 else 4)
	if direction == (8 if offset.y > 0 else 2):
		return turn(2 if offset.y > 0 else 8)
	return false


func begin_jump(offset: Vector2i) -> bool:
	if not is_idle():
		return false
	if abs(offset.x) > abs(offset.y):
		turn(6 if offset.x > 0 else 4)
	elif offset.y != 0:
		turn(2 if offset.y > 0 else 8)
	_start = visual_cell
	target = cell + offset
	_duration = maxf(0.24, Vector2(offset).length() * 32.0 / pixels_per_second())
	if _flash():
		_duration = 2.0 * (10 + int(round(Vector2(offset).length())) - int(options.move_speed)) / 60
	_elapsed = 0
	_idle_seconds = 0
	_kind = "jump"
	return true


func advance(delta: float) -> String:
	if not is_finite(delta) or delta <= 0:
		return ""
	var finished := ""
	var was_walking := moving()
	if not is_idle():
		_elapsed = minf(_duration, _elapsed + delta)
		var t := _elapsed / _duration
		visual_cell = _start.lerp(Vector2(target), t)
		jump_height = _jump_height(t) if jumping() else 0.0
		if _duration - _elapsed <= 0.000000001:
			cell = target
			visual_cell = Vector2(cell)
			finished = _kind
			_kind = ""
			jump_height = 0
	var cycle: bool = options.step_anime or (was_walking and options.walk_anime)
	if cycle:
		_idle_seconds = 0
		_animation += delta
		var interval := maxf(
			0.06, (18.0 - int(options.move_speed) * 2.0) / (60.0 if was_walking else 40.0)
		)
		if _flash():
			interval = (
				(
					floor(
						(
							(18.0 - int(options.move_speed) * 2)
							/ (1.5 if was_walking and options.walk_anime else 1.0)
						)
					)
					+ 1
				)
				/ 60
			)
		var frames := int(_animation / interval)
		if frames > 0:
			pattern = (pattern + frames) % 4
			_animation = fmod(_animation, interval)
	elif is_idle():
		_idle_seconds += delta
		var idle_delay = (
			0.12 if not _flash() else (floor((18.0 - int(options.move_speed) * 2) / 1.5) + 1) / 60
		)
		if _idle_seconds >= idle_delay:
			pattern = int(options.idle_pattern)
			_animation = 0
	return finished


func snapshot() -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y,
		"target_x": target.x,
		"target_y": target.y,
		"real_x": visual_cell.x * 32,
		"real_y": visual_cell.y * 32,
		"direction": direction,
		"pattern": pattern,
		"moving": moving(),
		"jumping": jumping(),
		"jump_height": jump_height,
		"options": options.duplicate()
	}


func persistent_data() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"target": [target.x, target.y],
		"start": [_start.x, _start.y],
		"direction": direction,
		"pattern": pattern,
		"options": options.duplicate(),
		"kind": _kind,
		"duration": _duration,
		"elapsed": _elapsed,
		"animation": _animation,
		"idle_seconds": _idle_seconds
	}


static func decode(value: Variant, width: int, height: int) -> Dictionary:
	if not value is Dictionary or not validate(value.get("options"), true):
		return {"ok": false, "message": "人物运动参数无效。"}
	for key in ["cell", "target", "start"]:
		var pair: Variant = value.get(key)
		if not pair is Array or pair.size() != 2:
			return {"ok": false, "message": "人物坐标无效。"}
		for axis in 2:
			var number: Variant = pair[axis]
			if (
				not (number is int or number is float)
				or not is_finite(float(number))
				or number < 0
				or number > (width - 1 if axis == 0 else height - 1)
				or (key != "start" and floor(float(number)) != number)
			):
				return {"ok": false, "message": "人物坐标越界。"}
	if (
		not preload("res://runtime/scripts/00_Game/ActorParameters.gd").integer(
			value.get("direction"), 2, 8
		)
		or int(value.direction) not in [2, 4, 6, 8]
		or not preload("res://runtime/scripts/00_Game/ActorParameters.gd").integer(
			value.get("pattern"), 0, 3
		)
		or value.get("kind") not in ["", "walk", "jump"]
	):
		return {"ok": false, "message": "人物朝向或运动类型无效。"}
	for key in ["duration", "elapsed", "animation", "idle_seconds"]:
		var number: Variant = value.get(key)
		if (
			not (number is int or number is float)
			or not is_finite(float(number))
			or number < 0
			or number > 1000000000
		):
			return {"ok": false, "message": "人物运动时间无效。"}
	if (
		value.elapsed > value.duration
		or (value.kind != "" and (value.duration <= 0 or value.elapsed >= value.duration))
		or (value.kind == "" and value.cell != value.target)
	):
		return {"ok": false, "message": "人物运动进度不一致。"}
	var result: RefCounted = load("res://runtime/scripts/03_Map/CharacterMotion.gd").new()
	result.configure(value.options)
	result.cell = Vector2i(int(value.cell[0]), int(value.cell[1]))
	result.target = Vector2i(int(value.target[0]), int(value.target[1]))
	result._start = Vector2(value.start[0], value.start[1])
	result.direction = int(value.direction)
	result.pattern = int(value.pattern)
	result._kind = value.kind
	result._duration = float(value.duration)
	result._elapsed = float(value.elapsed)
	result._animation = float(value.animation)
	result._idle_seconds = float(value.idle_seconds)
	var t: float = result._elapsed / result._duration if value.kind != "" else 1.0
	result.visual_cell = (
		result._start.lerp(Vector2(result.target), t) if value.kind != "" else Vector2(result.cell)
	)
	result.jump_height = result._jump_height(t) if value.kind == "jump" else 0.0
	return {"ok": true, "value": result}


func _jump_height(t: float) -> float:
	if _flash():
		var peak = _duration * 60 / 2
		return 2 * peak * peak * t * (1 - t)
	return 4.0 * (24.0 + minf(64.0, _start.distance_to(Vector2(target)) * 4.0)) * t * (1 - t)
