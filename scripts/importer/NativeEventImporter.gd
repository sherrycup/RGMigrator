## 职责：升级迁移事件绑定为实际可编辑 GDScript，并只读保留原 Ruby 来源。
##
## 调用方式：
##   迁移器在绑定成功后调用 record_upgrade，输出实际GDScript、只读原数据和精确前后校验值。
##   编辑器打开旧格式文档时只调用 upgrade 生成内存草稿；保存前不写回。
##
## 调用接口：
##   static func record_upgrade( value: Variant, root: String, path: String, units: Dictionary, policy: Dictionary, indent: String = "", trailing_newline: bool = true ) -> void
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 root（String；必填）：导出或待升级 Godot 工程的根目录。
##     参数 path（String；必填）：工程根目录下的 data/... 相对数据路径。
##     参数 units（Dictionary；必填）：脚本编译或迁移单元集合。
##     参数 policy（Dictionary；必填）：原解释器的 false 返回重试、合并和帧率规则。
##     参数 indent（String；默认值 ""）：输出 JSON 的缩进字符串；空串为紧凑格式，制表符为原宏定义格式。
##     参数 trailing_newline（bool；默认值 true）：最终写入器是否保留末尾换行；地图/公共事件为true，开门配置为false；新旧哈希与实际写入字节一致。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   static func upgrade(value: Variant, root: String, units: Dictionary, policy: Dictionary) -> void
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 root（String；必填）：导出或待升级 Godot 工程的根目录。
##     参数 units（Dictionary；必填）：脚本编译或迁移单元集合。
##     参数 policy（Dictionary；必填）：原解释器的 false 返回重试、合并和帧率规则。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted


static func record_upgrade(
	value: Variant,
	root: String,
	path: String,
	units: Dictionary,
	policy: Dictionary,
	indent: String = "",
	trailing_newline: bool = true
) -> void:
	var ending = "\n" if trailing_newline else ""
	var original = JSON.stringify(value, indent, false) + ending
	var existing = root.path_join(path)
	if FileAccess.file_exists(existing):
		var bytes = FileAccess.get_file_as_string(existing)
		if JSON.parse_string(bytes) == value:
			original = bytes
	var source_path = "legacy/native_events/" + path
	DirAccess.make_dir_recursive_absolute(root.path_join(source_path).get_base_dir())
	var file = FileAccess.open(root.path_join(source_path), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original)
	file.close()
	upgrade(value, root, units, policy)
	var index_path = root.path_join("data/native_event_sources.json")
	var index: Variant = (
		JSON.parse_string(FileAccess.get_file_as_string(index_path))
		if FileAccess.file_exists(index_path)
		else {"format": "rgm-native-event-upgrade-v1", "entries": {}}
	)
	index.entries[path] = {
		"legacy_path": source_path,
		"legacy_sha256": original.sha256_text(),
		"native_sha256": (JSON.stringify(value, indent, false) + ending).sha256_text()
	}
	file = FileAccess.open(index_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(index, "\t", false) + "\n")
		file.close()


static func upgrade(value: Variant, root: String, units: Dictionary, policy: Dictionary) -> void:
	if value is Array:
		for item in value:
			upgrade(item, root, units, policy)
		_sync_previews(value)
	elif value is Dictionary:
		var binding: Variant = value.get("_script_binding")
		var position = 1 if int(value.get("code", 0)) == 111 else 0
		var text = str(value.get("parameters", [""])[position]) if binding is Dictionary else ""
		var old_module = (
			binding is Dictionary
			and binding.get("author") == "migration"
			and text.contains("ctx.migrated(program)")
			and text.sha256_text() == binding.get("source_sha256")
		)
		if binding is Dictionary and (not binding.has("language") or old_module):
			var unit: Dictionary = units.get(binding.get("unit_id", ""), {})
			if unit.get("status") == "generated":
				var ast: Dictionary = unit.get("ast", {})
				if ast.is_empty():
					var ast_path = str(unit.get("ast_path", "")).trim_prefix("res://")
					if not ast_path.is_empty():
						ast = JSON.parse_string(
							FileAccess.get_file_as_string(root.path_join(ast_path))
						)
				var emitted: Dictionary = preload("EventBodyEmitter.gd").new().emit(ast)
				if emitted.ok:
					if not value.has("_legacy_source"):
						value._legacy_source = {
							"parameters": value.get("parameters", []).duplicate(true),
							"binding": binding.duplicate(true)
						}
					binding.language = "rgm-native-event-v1"
					binding.native_id = binding.get("native_id", "migrated_" + str(binding.unit_id))
					binding.source_sha256 = str(emitted.source).sha256_text()
					binding.origin = unit.get("origin", {}).duplicate(true)
					binding.policy = policy.duplicate(true)
					binding.author = "migration"
					binding.source_form = "body"
					value.parameters[position] = emitted.source

		for key in value:
			if str(key).begins_with("_legacy") or str(key).begins_with("_editor_original"):
				continue
			upgrade(value[key], root, units, policy)
		if (
			int(value.get("code", 0)) == 655
			and not value.has("_script_binding")
			and not value.has("_legacy_source")
		):
			value._legacy_source = value.get("parameters", []).duplicate(true)
			value.parameters = ["# 迁移续行：GDScript 正文已合并到本组首条。"]


static func _sync_previews(commands: Array) -> void:
	for index in commands.size():
		var command: Variant = commands[index]
		if not command is Dictionary or int(command.get("code", 0)) != 209:
			continue
		var parameters: Array = command.get("parameters", [])
		if parameters.size() < 2 or not parameters[1] is Dictionary:
			continue
		var route: Array = parameters[1].get("list", [])
		var offset = 0
		while (
			index + 1 + offset < commands.size()
			and int(commands[index + 1 + offset].get("code", 0)) == 509
		):
			if offset < route.size():
				commands[index + 1 + offset].parameters = [route[offset].duplicate(true)]
			offset += 1
