## 职责：提供移动路线编辑对话框，确认后将路线草稿交回调用方。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/03_Event/Editor_RouteDialog.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func open(route: Dictionary, documents: RefCounted = null) -> void
##     用途：打开页面、对话框或目标记录。
##     参数 route（Dictionary；必填）：人物移动路线数据。
##     参数 documents（RefCounted；默认值 null）：编辑器文档服务，持有独立草稿与保存接口。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   accepted(route: Dictionary)：用户确认了当前对话框草稿。
##     route：人物移动路线数据。
##
## 接口说明结束。

@tool
extends ConfirmationDialog
const RouteForm = preload("Editor_RouteForm.gd")
const Commands = preload("Editor_Commands.gd")
signal accepted(route: Dictionary)
var _form: VBoxContainer
var _message: Label


func open(route: Dictionary, documents: RefCounted = null) -> void:
	if _form == null:
		title = "设置自主移动路线"
		dialog_hide_on_ok = false
		var box = VBoxContainer.new()
		add_child(box)
		_form = RouteForm.new()
		box.add_child(_form)
		_message = Label.new()
		_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message.custom_minimum_size.x = 760
		_message.size.x = 760
		box.add_child(_message)
		confirmed.connect(_accept)
	_form.configure(route, documents)
	_message.text = ""
	popup_centered(Vector2i(960, 560))


func _accept() -> void:
	var route: Dictionary = _form.draft()
	var result = Commands.Catalog.route_validation(route)
	if not result.ok:
		_message.text = result.message
		return
	accepted.emit(route)
	hide()
