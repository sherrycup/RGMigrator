## 职责：管理事件原生 GDScript 的稳定身份、编译诊断和保存前检查，不执行事件。
##
## 调用方式：
##   事件参数保存实际 GDScript 业务正文；包装和 Actor_Init 接口绑定由本服务在编译时生成。
##   兼容0.52早期完整模块；新增事件无需填写 extends、run 或完整文件头。
##   编译诊断扣除包装行偏移，始终指向编辑框中的业务正文。
##
## 调用接口：
##   static func template(condition: bool = false) -> String
##     参数 condition（bool；默认值 false）：是否创建须返回布尔值的脚本条件模板。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func is_module(source: String) -> bool
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func module_source(source: String) -> Dictionary
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func binding(source: String, previous: Dictionary = {}, count: int = 1) -> Dictionary
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     参数 previous（Dictionary；默认值 {}）：该入口原有绑定；编辑保留身份，复制时另换新身份。
##     参数 count（int；默认值 1）：此绑定消耗的原事件记录数量；普通新GDScript为1。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func is_native(value: Variant) -> bool
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   static func compile(source: String, id: String = "draft") -> Dictionary
##     用途：编译原脚本并返回生成代码与诊断。
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     参数 id（String；默认值 "draft"）：编译诊断中使用的稳定原生身份，默认draft；不从该编号读取其它记录的源码。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func preview(source: String) -> String
##     参数 source（String；必填）：待处理的原始文本、数据或状态。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func validate_tree(value: Variant, location: String = "") -> Dictionary
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 location（String；默认值 ""）：当前文档及递归字段路径，用于定位编译失败。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func copy_with_new_ids(value: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 公开常量：FORMAT。
## 注意：源码和绑定哈希不匹配时禁止执行或发布；编译失败保留磁盘旧文件。
## 接口说明结束。

@tool
extends RefCounted

const FORMAT = "rgm-native-event-v1"
static var _cache: Dictionary = {}
static var compiling = 0
static var _active_origins: Dictionary = {}
static var _line_offsets: Dictionary = {}


class CompileLog:
	extends Logger
	var diagnostics: Array = []

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_notify: bool,
		kind: int,
		_traces: Array[ScriptBacktrace]
	) -> void:
		if kind == Logger.ERROR_TYPE_SCRIPT:
			diagnostics.append(
				{
					"line": line,
					"message": rationale if not rationale.is_empty() else code,
					"file": file,
					"function": function
				}
			)


static func template(condition: bool = false) -> String:
	return "return false\n" if condition else "# 在这里编写事件业务代码，可直接使用 ctx 接口。\npass\n"


static func is_module(source: String) -> bool:
	var expression = RegEx.new()
	expression.compile("(?m)^extends[ \t]+")
	return expression.search(source) != null


static func module_source(source: String) -> Dictionary:
	if is_module(source):
		return {"text": source, "offset": 0}
	var lines: Array[String] = []
	for line in source.split("\n"):
		lines.append("\t" + line)
	if source.strip_edges().is_empty():
		lines = ["\tpass"]
	var prefix = "extends RefCounted\nstatic func run(ctx):\n"
	if source.contains("Actor_Init"):
		prefix += "\tvar Actor_Init: Variant = ctx.actor_init\n"
	return {"text": prefix + "\n".join(lines) + "\n", "offset": prefix.count("\n")}


static func binding(source: String, previous: Dictionary = {}, count: int = 1) -> Dictionary:
	if (
		is_native(previous)
		and previous.get("source_sha256") == source.sha256_text()
		and previous.get("command_count") == count
	):
		return previous.duplicate(true)
	var result = previous.duplicate(true)
	result.language = FORMAT
	if not result.has("native_id"):
		result.native_id = "native_" + Crypto.new().generate_random_bytes(16).hex_encode()
	result.unit_id = result.get("unit_id", result.native_id)
	result.command_count = count
	result.source_sha256 = source.sha256_text()
	result.author = "user"
	result.source_form = "module" if is_module(source) else "body"
	var migration_origin: Dictionary = previous.get("origin", {})
	if migration_origin.get("kind") == "native_event":
		migration_origin = migration_origin.get("migration_origin", {})
	result.origin = {"kind": "native_event", "migration_origin": migration_origin}
	result.policy = {"false_result_waits": false}
	return result


static func is_native(value: Variant) -> bool:
	return value is Dictionary and value.get("language") == FORMAT


static func compile(source: String, id: String = "draft") -> Dictionary:
	var checksum = source.sha256_text()
	if _cache.has(checksum):
		return _cache[checksum]
	var logger = CompileLog.new()
	OS.add_logger(logger)
	compiling += 1
	var script = GDScript.new()
	script.resource_path = (
		"res://runtime/events/%s_%s_%d.gd"
		% [id.validate_filename(), checksum.left(12), script.get_instance_id()]
	)
	var module = module_source(source)
	_line_offsets[script.resource_path] = module.offset
	script.source_code = module.text
	var status = script.reload()
	compiling -= 1
	OS.remove_logger(logger)
	var entry = false
	if status == OK:
		for method in script.get_script_method_list():
			if (
				method.name == "run"
				and method.args.size() == 1
				and int(method.flags) & METHOD_FLAG_STATIC
			):
				entry = true
	if status != OK or not entry or (not Engine.is_editor_hint() and not script.can_instantiate()):
		for diagnostic in logger.diagnostics:
			diagnostic.line = maxi(1, int(diagnostic.line) - int(module.offset))
		var first: Dictionary = logger.diagnostics[0] if not logger.diagnostics.is_empty() else {}
		return {
			"ok": false,
			"message": "GDScript 编译失败。 " + str(first.get("message", "")),
			"diagnostics": logger.diagnostics,
			"span": {"line": first.get("line", 0), "column": 1}
		}
	var result = {"ok": true, "script": script, "sha256": checksum}
	_cache[checksum] = result
	return result


static func preview(source: String) -> String:
	var inside = not is_module(source)
	for line in source.split("\n"):
		if line.begins_with("static func run("):
			inside = true
			continue
		if inside and not line.strip_edges().is_empty() and not line.strip_edges().begins_with("#"):
			return line.strip_edges()
	return "GDScript（打开编辑查看）"


static func validate_tree(value: Variant, location: String = "") -> Dictionary:
	if value is Array:
		for index in value.size():
			var checked = validate_tree(value[index], location + "/" + str(index))
			if not checked.ok:
				return checked
	elif value is Dictionary:
		var tag: Variant = value.get("_script_binding")
		if is_native(tag):
			var code = int(value.get("code", 0))
			var parameters: Array = value.get("parameters", [])
			var text = str(
				(
					parameters[1]
					if code == 111 and parameters.size() > 1
					else parameters[0] if not parameters.is_empty() else ""
				)
			)
			if text.sha256_text() != tag.get("source_sha256"):
				return {"ok": false, "message": location + "：GDScript 源码与绑定不同步，请重新应用脚本。"}
			var checked = compile(text, str(tag.get("native_id", "draft")))
			if not checked.ok:
				return checked.merged({"location": location, "origin": tag.get("origin", {})})
		for key in value:
			if str(key).begins_with("_legacy") or str(key).begins_with("_editor_original"):
				continue
			var checked = validate_tree(value[key], location + "/" + str(key))
			if not checked.ok:
				return checked
	return {"ok": true}


static func copy_with_new_ids(value: Variant) -> Variant:
	var result: Variant = value.duplicate(true) if value is Dictionary or value is Array else value
	_renew(result)
	return result


static func _renew(value: Variant) -> void:
	if value is Array:
		for item in value:
			_renew(item)
	elif value is Dictionary:
		if is_native(value.get("_script_binding")):
			value._script_binding.native_id = (
				"native_" + Crypto.new().generate_random_bytes(16).hex_encode()
			)
		for key in value:
			if not str(key).begins_with("_legacy"):
				_renew(value[key])
