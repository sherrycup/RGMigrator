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
		if int(frame.common_id) > 0: calls.append(str(frame.common_id))
	if common_id > 0: calls.append(str(common_id))
	return "Map%03d / 事件 %d / 第 %d 页 / 公共事件 %d%s" % [source_map_id, source_event_id, page, common_id, "（调用链 " + " → ".join(calls) + "）" if not calls.is_empty() else ""]
