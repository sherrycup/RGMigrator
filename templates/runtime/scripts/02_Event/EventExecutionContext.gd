## 职责：记录事件来源、分支和调用现场，为执行、诊断及恢复提供上下文。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/02_Event/EventExecutionContext.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func setup(list: Array, id: int, map_id: int, page_number: int) -> void
##     参数 list（Array；必填）：待编辑或处理的有序记录列表。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 map_id（int；必填）：地图的原编号。
##     参数 page_number（int；必填）：来源事件页的序号。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func location() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 接口说明结束。

extends RefCounted
## Per-execution control state. Source coordinates survive transfer for diagnostics.
var commands: Array = []
var index := 0
var event_id := 0
var source_event_id := 0
var source_map_id := 0
var page := 1
var common_id := 0
var stack: Array = []
var branches: Dictionary = {}
var loops: Dictionary = {}
var waiting_indent := 0
var shop_command_index := 0
var script_fields: Dictionary = {}
var script_map_id := 0


func setup(list: Array, id: int, map_id: int, page_number: int) -> void:
	script_fields = {}
	script_map_id = map_id
	commands = list
	index = 0
	event_id = id
	source_event_id = id
	source_map_id = map_id
	page = page_number
	common_id = 0
	stack = []
	branches = {}
	loops = {}


func location() -> String:
	var calls: Array[String] = []
	for frame in stack:
		if int(frame.common_id) > 0:
			calls.append(str(frame.common_id))
	if common_id > 0:
		calls.append(str(common_id))
	return (
		"Map%03d / 事件 %d / 第 %d 页 / 公共事件 %d%s"
		% [
			source_map_id,
			source_event_id,
			page,
			common_id,
			"（调用链 " + " → ".join(calls) + "）" if not calls.is_empty() else ""
		]
	)
