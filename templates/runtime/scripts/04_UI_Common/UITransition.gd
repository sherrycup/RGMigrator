## 职责：由页面单一时钟推进位置、缩放和透明度过渡，支持替换、取消及旧页面失效。
##
## 调用方式：
##   页面持有一个实例，play(target,goals,seconds)开始；所属页面每次_process只需advance(delta)。
##   同一实例在同一引擎帧只累计一次时间；再次play从当前属性开始替换旧目标，cancel保持当前画面。
##   目标使用弱引用；目标释放、移出场景树或排队删除后停止，不修改旧页面。
##
## 调用接口：
##   func play(target: Control, goals: Dictionary, seconds: float) -> void
##     用途：替换当前过渡并记录目标的当前属性。
##     参数 target（Control；必填）：仍有效的Control界面节点。
##     参数 goals（Dictionary；必填）：目标属性字典；仅支持position/scale的Vector2及modulate的Color。
##     参数 seconds（float；必填）：过渡时长或本次推进量，秒；play为0立即到达，负数或非有限值不推进。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func advance(seconds: float) -> bool
##     用途：由页面时钟推进当前过渡。
##     参数 seconds（float；必填）：过渡时长或本次推进量，秒；play为0立即到达，负数或非有限值不推进。
##     返回：true表示仍在过渡；false表示完成、取消或目标失效。
##
##   func cancel() -> void
##     用途：取消过渡并清除旧目标引用，保留当前属性。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func active() -> bool
##     用途：查询是否仍有活动过渡。
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 接口说明结束。

extends RefCounted
var _target: WeakRef
var _start: Dictionary = {}
var _goals: Dictionary = {}
var _duration = 0.0
var _elapsed = 0.0
var _last_frame = -1
var _active = false


func play(target: Control, goals: Dictionary, seconds: float) -> void:
	cancel()
	if not is_instance_valid(target) or not is_finite(seconds) or seconds < 0:
		return
	for key in goals:
		if key not in ["position", "scale", "modulate"]:
			return
		if typeof(goals[key]) != typeof(target.get(key)):
			return
	_target = weakref(target)
	_goals = goals.duplicate(true)
	for key in _goals:
		_start[key] = target.get(key)
	_duration = seconds
	_active = true
	if seconds == 0:
		_apply(1.0)
		_active = false


func advance(seconds: float) -> bool:
	if not _active:
		return false
	if not is_finite(seconds) or seconds < 0:
		return true
	var frame = Engine.get_process_frames()
	if frame == _last_frame:
		return true
	_last_frame = frame
	var target: Object = _target.get_ref()
	if target == null or not target.is_inside_tree() or target.is_queued_for_deletion():
		cancel()
		return false
	_elapsed = minf(_duration, _elapsed + seconds)
	_apply(_elapsed / _duration)
	_active = _elapsed < _duration
	return _active


func cancel() -> void:
	_active = false
	_target = null
	_start.clear()
	_goals.clear()
	_elapsed = 0


func active() -> bool:
	return _active


func _apply(progress: float) -> void:
	var target: Object = _target.get_ref()
	if target == null:
		return
	for key in _goals:
		target.set(key, lerp(_start[key], _goals[key], progress))
