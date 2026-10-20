## 职责：注册魔塔编辑器插件，创建主面板、脚本工作区入口及编辑器快捷键。
##
## 调用方式：
##   由 addons/rgm_editor/plugin.cfg 注册到 Godot 编辑器。
##   _enter_tree 安装魔塔主面板和脚本工作区，_exit_tree 释放插件控件。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 场景树回调（Godot 自动调用）：
##   func _enter_tree() -> void
##   func _exit_tree() -> void
##
## 接口说明结束。

@tool
extends EditorPlugin
const EditorMain = preload("Editor_Panel.gd")
var _panel: Control
var _probe: RefCounted


func _enter_tree() -> void:
	_panel = EditorMain.new()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_panel.hide()
	call_deferred("_show_editor")


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_panel):
		_panel.visible = visible


func _get_plugin_name() -> String:
	return "魔塔编辑器"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("TileMap", "EditorIcons")


func _save_external_data() -> void:
	if is_instance_valid(_panel):
		_panel.save_changes()


func _get_unsaved_status(_for_scene: String) -> String:
	return _panel.unsaved_status() if is_instance_valid(_panel) else ""


func _build() -> bool:
	return _panel.save_changes() if is_instance_valid(_panel) else true


func _show_editor() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(_panel):
		return
	_panel._refresh_map()
	EditorInterface.set_main_screen_editor("魔塔编辑器")
	if (
		"--rgm-editor-probe" in OS.get_cmdline_user_args()
		and FileAccess.file_exists("res://.godot/editor_probe.gd")
	):
		_probe = load("res://.godot/editor_probe.gd").new()
		_probe.run(self, _panel)
