## 职责：统一生成程序的详细接口说明及历史文件头，精确处理来源行号和旧存档的源码别名。
##
## 调用方式：
##   由生成器和运行时共用固定程序说明及其历史版本，统一来源行号与旧存档归一化。
##
## 调用接口：
##   static func header_info(source: String) -> Dictionary
##     用途：识别完整生成程序使用的已知文件头。
##     参数 source（String；必填）：完整生成程序原文。
##     返回：包含 body 和 lines 的字典；未知说明保留完整源码并返回 lines=0。
##
##   static func source_hashes(source: String) -> Array
##     用途：计算当前文件及已登记历史文件头和导入路径的精确哈希别名。
##     参数 source（String；必填）：当前完整生成程序原文。
##     返回：允许用于旧存档核对的 SHA256 字符串数组；正文和其他注释继续保留。
##
##   static func canonical_line(program: String, span: Dictionary, generated_line: Variant) -> int
##     用途：核对实际 tick 与来源范围后还原未加说明时的导航行号。
##     参数 program（String；必填）：当前完整生成 GDScript 文本。
##     参数 span（Dictionary；必填）：待定位原语句的四个整数来源范围字段。
##     参数 generated_line（Variant；必填）：当前或已登记旧文件头对应的导航行号。
##     返回：可精确归一化时返回原始行号，否则返回 -1。
##
## 公开常量：LEGACY_HEADER、HEADER。
## 注意：只识别代码中明确登记的文件头文本；手工修改文件头不会被当作兼容别名。
## 接口说明结束。

extends RefCounted

const LEGACY_HEADER := "## 职责：执行由原 RM 脚本转换的语句与方法；具体来源和行号见 data/script_source_map.json。\n\n"
const HEADER := (
	"## 职责：执行由原 RM 脚本转换的语句与方法；具体来源和行号见 data/script_source_map.json。\n"
	+ "## 调用方式：通常通过 ScriptRuntime 的事件绑定或 execute_unit 进入本程序。\n"
	+ "## 接口：static func execute(state: Object, session: RefCounted = null) -> Dictionary\n"
	+ "##   state：正式 RuntimeState，使用同一角色、变量、背包和地图现场。\n"
	+ "##   session：可选 ScriptSemantics 会话；null 时为本次入口创建会话。\n"
	+ "##   返回：含 ok 与实际执行结果或来源诊断的字典；调用方先检查 ok。\n"
	+ "## 内部入口：static func program(env: RefCounted) -> Variant\n"
	+ "##   env：当前调用共享的 ScriptSemantics 会话；由 execute 或运行服务提供。\n"
	+ "##   返回：原程序最后表达式的值；语义错误记录到 env 的失败状态。\n"
	+ "## 生成的其他静态函数由原类、方法和 alias 登记调用，参数约定见来源映射。\n"
	+ "## 原 Ruby 仅作只读来源；工作源码重新转换时检查生成文件归属与冲突。\n"
	+ "## 接口说明结束。\n\n"
)
const CURRENT_IMPORT := 'extends RefCounted\nconst Semantics = preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")\n'
const LEGACY_IMPORT := 'extends RefCounted\nconst Semantics = preload("res://runtime/scripts/ScriptSemantics.gd")\n'


static func header_info(source: String) -> Dictionary:
	for known in [HEADER, LEGACY_HEADER]:
		if source.begins_with(known + CURRENT_IMPORT):
			return {"body": source.substr(known.length()), "lines": known.count("\n")}
	return {"body": source, "lines": 0}


static func source_hashes(source: String) -> Array:
	var hashes: Array = [source.sha256_text()]
	var body: String = header_info(source).body
	if not body.begins_with(CURRENT_IMPORT):
		return hashes
	for prefix in ["", LEGACY_HEADER, HEADER]:
		var hash_value: String = (prefix + body).sha256_text()
		if not hashes.has(hash_value):
			hashes.append(hash_value)
	hashes.append((LEGACY_IMPORT + body.substr(CURRENT_IMPORT.length())).sha256_text())
	return hashes


static func canonical_line(program: String, span: Dictionary, generated_line: Variant) -> int:
	var info := header_info(program)
	if info.lines == 0 or not (generated_line is int or generated_line is float):
		return -1
	if int(generated_line) != generated_line:
		return -1
	var literal := span.duplicate()
	for key in literal:
		if not (literal[key] is int or literal[key] is float) or int(literal[key]) != literal[key]:
			return -1
		literal[key] = int(literal[key])
	var tick := "\tif not env.tick(" + JSON.stringify(literal, "", false, true) + "): return null"
	var actual := program.split("\n").find(tick)
	if actual < 0:
		return -1
	var original: int = actual + 2 - int(info.lines)
	for shift in [0, LEGACY_HEADER.count("\n"), HEADER.count("\n")]:
		if int(generated_line) == original + shift:
			return original
	return -1
