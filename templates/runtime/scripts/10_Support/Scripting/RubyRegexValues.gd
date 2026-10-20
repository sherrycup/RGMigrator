## 职责：封装原脚本正则表达式及匹配结果，保留捕获和查询语义。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/10_Support/Scripting/RubyRegexValues.gd").方法名(...)。
##
## 调用接口：
##   static func compile(pattern: String, flags: String) -> Dictionary
##     用途：编译原脚本并返回生成代码与诊断。
##     参数 pattern（String；必填）：匹配模式或图形帧编号。
##     参数 flags（String；必填）：组合标志位或选项标志集合。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func match_value(descriptor: Dictionary, value: String) -> Dictionary
##     参数 descriptor（Dictionary；必填）：描述资源、动作或对象的结构化数据。
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   static func split(descriptor: Dictionary, value: String, limit: int = 0) -> Dictionary
##     参数 descriptor（Dictionary；必填）：描述资源、动作或对象的结构化数据。
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 limit（int；默认值 0）：允许的最大条数、数量或范围。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted


## Ruby 1.8 regexp flags and UTF-8 byte offsets at the migration boundary.
## RegExp objects remain value descriptors; the Godot RegEx is transient.
static func compile(pattern: String, flags: String) -> Dictionary:
	for flag in flags:
		if flag not in ["i", "m", "x", "o"]:
			return {"ok": false, "message": "正则标志尚未支持：" + flag}
	var regex = RegEx.new()
	# Ruby's default anchors are per-line; Ruby /m enables dot-all.
	var prefix = (
		"(?m)"
		+ ("(?i)" if flags.contains("i") else "")
		+ ("(?s)" if flags.contains("m") else "")
		+ ("(?x)" if flags.contains("x") else "")
	)
	if regex.compile(prefix + pattern) != OK:
		return {"ok": false, "message": "正则无法编译：" + pattern}
	return {"ok": true, "regex": regex}


static func match_value(descriptor: Dictionary, value: String) -> Dictionary:
	var compiled = compile(descriptor.source, descriptor.flags)
	if not compiled.ok:
		return compiled
	var found: RegExMatch = compiled.regex.search(value)
	if found == null:
		return {"ok": true, "data": null}
	var groups: Array = []
	var starts: Array = []
	for i in found.get_group_count() + 1:
		var start = found.get_start(i)
		groups.append(found.get_string(i) if start >= 0 else null)
		starts.append(value.left(start).to_utf8_buffer().size() if start >= 0 else null)
	return {
		"ok": true,
		"data":
		{
			"__ruby_match": true,
			"groups": groups,
			"starts": starts,
			"pre": value.left(found.get_start()),
			"post": value.substr(found.get_end()),
			"source": value
		}
	}


static func split(descriptor: Dictionary, value: String, limit: int = 0) -> Dictionary:
	var compiled = compile(descriptor.source, descriptor.flags)
	if not compiled.ok:
		return compiled
	if limit == 1:
		return {"ok": true, "value": [value]}
	var rows: Array = []
	var cursor = 0
	var pieces = 0
	for found in compiled.regex.search_all(value):
		if found.get_start() == 0 and found.get_end() == 0:
			continue
		if limit > 0 and pieces >= limit - 1:
			break
		rows.append(value.substr(cursor, found.get_start() - cursor))
		pieces += 1
		for i in range(1, found.get_group_count() + 1):
			if found.get_start(i) >= 0:
				rows.append(found.get_string(i))
		cursor = found.get_end()
	rows.append(value.substr(cursor))
	if limit == 0:
		while not rows.is_empty() and rows[-1] == "":
			rows.pop_back()
	return {"ok": true, "value": rows}
