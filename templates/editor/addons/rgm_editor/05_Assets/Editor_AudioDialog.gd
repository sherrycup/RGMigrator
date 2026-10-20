## 职责：编辑音频素材、音量和音调参数，协调选择、试听与确认。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/05_Assets/Editor_AudioDialog.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func open(documents: RefCounted, category: String, audio: Dictionary) -> void
##     用途：打开页面、对话框或目标记录。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 audio（Dictionary；必填）：音频名称、音量及音调等参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   accepted(audio: Dictionary)：用户确认了当前对话框草稿。
##     audio：音频名称、音量及音调等参数。
##
## 接口说明结束。

@tool
extends ConfirmationDialog
signal accepted(audio: Dictionary)
var _browser: VBoxContainer


func open(documents: RefCounted, category: String, audio: Dictionary) -> void:
	if _browser == null:
		_browser = preload("Editor_AudioBrowser.gd").new()
		_browser.custom_minimum_size = Vector2(580, 400)
		add_child(_browser)
		confirmed.connect(func() -> void: accepted.emit(_browser.draft()))
		visibility_changed.connect(
			func() -> void:
				if not visible:
					_browser.stop()
		)
	_browser.configure(documents, category, audio)
	title = "选择音频 · " + category
	get_ok_button().text = "使用此音频"
	popup_centered(Vector2i(660, 540))
