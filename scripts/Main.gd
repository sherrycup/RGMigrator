## 职责：构建迁移器主界面，接收源工程与输出选项，并协调迁移进度和报告展示。
##
## 调用方式：
##   脚本由所属场景或插件挂载；下列回调由 Godot 调用。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends Control

const RGMigratorVersion = preload("res://scripts/Version.gd")
const RmxpValidator = preload("res://scripts/importer/RmxpValidator.gd")
const MigrationPipeline = preload("res://scripts/importer/MigrationPipeline.gd")

var _source_path := ""
var _export_path := ""
var _last_preflight: Dictionary = {}
var _validator := RmxpValidator.new()
var _source_edit: LineEdit
var _export_edit: LineEdit
var _encoding_option: OptionButton
var _test_mode: CheckBox
var _preflight_button: Button
var _migrate_button: Button
var _log: RichTextLabel
var _source_dialog: FileDialog
var _export_dialog: FileDialog


func _ready() -> void:
	name = "RGMigrator"
	_build_ui()
	_append("[b]%s[/b]\n选择 RMXP 工程根目录和导出位置，然后执行预检。" % RGMigratorVersion.DISPLAY_NAME)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("202632")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = RGMigratorVersion.DISPLAY_NAME
	heading.add_theme_font_size_override("font_size", 28)
	layout.add_child(heading)

	var description := Label.new()
	description.text = "RMXP → Godot 4 标准版工程迁移器（Windows）"
	description.modulate = Color("b9c3d4")
	layout.add_child(description)

	layout.add_child(_make_path_row("RMXP 工程根目录", true))
	layout.add_child(_make_path_row("导出位置", false))

	var encoding_row := HBoxContainer.new()
	encoding_row.add_theme_constant_override("separation", 12)
	var encoding_label := Label.new()
	encoding_label.text = "源文本编码"
	encoding_label.custom_minimum_size.x = 130
	encoding_row.add_child(encoding_label)
	_encoding_option = OptionButton.new()
	_encoding_option.add_item("自动（Windows ANSI 代码页）", 0)
	_encoding_option.add_item("GBK / CP936", 936)
	_encoding_option.add_item("Shift-JIS / CP932", 932)
	_encoding_option.tooltip_text = "自动模式采用 Windows 当前 ANSI 代码页；预检后可根据标题文字调整。"
	encoding_row.add_child(_encoding_option)
	layout.add_child(encoding_row)
	_encoding_option.item_selected.connect(func(_index: int) -> void:
		_last_preflight.clear()
		_migrate_button.disabled = true
	)
	_test_mode = CheckBox.new()
	_test_mode.text = "准备测试物资（药品、装备、特技与动画预览；HP/SP 为一半）"
	_test_mode.button_pressed = true
	_test_mode.tooltip_text = "仅作用于新导出工程；测试定义独立保存，可在 data/test_setup.json 关闭或调整，不修改原 RM 数据。"
	layout.add_child(_test_mode)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	_preflight_button = Button.new()
	_preflight_button.text = "预检"
	_preflight_button.pressed.connect(_on_preflight_pressed)
	action_row.add_child(_preflight_button)
	_migrate_button = Button.new()
	_migrate_button.text = "开始迁移"
	_migrate_button.disabled = true
	_migrate_button.pressed.connect(_on_migrate_pressed)
	action_row.add_child(_migrate_button)
	var clear_button := Button.new()
	clear_button.text = "清空日志"
	clear_button.pressed.connect(func() -> void: _log.clear())
	action_row.add_child(clear_button)
	layout.add_child(action_row)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size.y = 240
	_log.add_theme_color_override("default_color", Color("d9e2ef"))
	layout.add_child(_log)

	_source_dialog = _make_directory_dialog("选择 RMXP 工程根目录")
	_source_dialog.dir_selected.connect(_on_source_selected)
	add_child(_source_dialog)
	_export_dialog = _make_directory_dialog("选择导出位置")
	_export_dialog.dir_selected.connect(_on_export_selected)
	add_child(_export_dialog)


func _make_path_row(label_text: String, is_source: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = "请选择文件夹"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.editable = false
	row.add_child(edit)
	var button := Button.new()
	button.text = "选择…"
	button.pressed.connect(func() -> void:
		if is_source:
			_source_dialog.popup_centered_ratio(0.75)
		else:
			_export_dialog.popup_centered_ratio(0.75)
	)
	row.add_child(button)
	if is_source:
		_source_edit = edit
	else:
		_export_edit = edit
	return row


func _make_directory_dialog(title_text: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.title = title_text
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	return dialog


func _on_source_selected(path: String) -> void:
	_source_path = path
	_source_edit.text = path
	_last_preflight.clear()
	_migrate_button.disabled = true
	_append("已选择 RMXP 根目录：%s" % path)


func _on_export_selected(path: String) -> void:
	_export_path = path
	_export_edit.text = path
	_last_preflight.clear()
	_migrate_button.disabled = true
	_append("已选择导出位置：%s" % path)


func _selected_encoding() -> int:
	return _encoding_option.get_selected_id()


func _on_preflight_pressed() -> void:
	_log.clear()
	_last_preflight = _validator.preflight(_source_path, _export_path, _selected_encoding())
	for line: String in _last_preflight.get("messages", []):
		_append(line)
	_migrate_button.disabled = not _last_preflight.get("ok", false)
	if _last_preflight.get("ok", false):
		_append("[color=#82d173]预检通过，可以开始迁移。[/color]")
	else:
		_append("[color=#ff8585]预检未通过；请修正红色问题后重试。[/color]")


func _on_migrate_pressed() -> void:
	if not _last_preflight.get("ok", false):
		_on_preflight_pressed()
		if not _last_preflight.get("ok", false):
			return
	_migrate_button.disabled = true
	_preflight_button.disabled = true
	_append("[b]开始迁移…[/b]")
	var pipeline := MigrationPipeline.new()
	_last_preflight["test_mode"] = _test_mode.button_pressed
	var result := pipeline.run(_last_preflight, _on_pipeline_progress)
	if result.get("ok", false):
		_append("[color=#82d173][b]迁移完成：%s[/b][/color]" % result.get("output_path", ""))
	else:
		for line: String in result.get("messages", []):
			_append(line)
		_append("[color=#ff8585][b]迁移失败。不会覆盖已有目标目录；请查看上方诊断。[/b][/color]")
	_preflight_button.disabled = false
	_migrate_button.disabled = result.get("ok", false) or not _last_preflight.get("ok", false)


func _on_pipeline_progress(message: String) -> void:
	_append(message)


func _append(message: String) -> void:
	_log.append_text(message + "\n")
	_log.scroll_to_line(_log.get_line_count())
