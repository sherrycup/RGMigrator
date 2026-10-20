## 职责：提供角色姓名输入界面，校验长度并将结果交回事件流程。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/06_Message/NameInput.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func submit() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func restore_name() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func back() -> void
##     用途：从当前页面或操作返回。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   confirmed(value: String)：由持有方发出，通知对应状态或操作结果。
##     value：需要读取、校验或写入的值。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends Control
## A separate native 303 page; text entry supports the operating system IME.
signal confirmed(value: String)
var actor_id := 0
var maximum := 12
var initial_name := ""
var edit: LineEdit
var _notice: Label
var _window: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font = preload("res://runtime/scripts/04_UI_Common/UIResources.gd").font()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_window = preload("res://runtime/scripts/04_UI_Common/WindowBase.gd").new()
	_window.custom_minimum_size = Vector2(minf(500, get_viewport_rect().size.x - 48), 280)
	center.add_child(_window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.content.add_child(box)
	var label := Label.new()
	label.text = "输入角色姓名"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	edit = LineEdit.new()
	edit.max_length = maximum
	edit.text = initial_name.left(maximum)
	edit.expand_to_text_length = false
	edit.custom_minimum_size.y = 40
	edit.add_theme_font_override(
		"font", preload("res://runtime/scripts/04_UI_Common/UIResources.gd").font()
	)
	box.add_child(edit)
	edit.text_submitted.connect(func(_text: String) -> void: submit())
	_notice = Label.new()
	_notice.text = "最多%d个字符；Esc删除一个字符" % maximum
	box.add_child(_notice)
	var confirm := Button.new()
	confirm.text = "确认"
	confirm.pressed.connect(submit)
	box.add_child(confirm)
	var restore := Button.new()
	restore.text = "恢复原名"
	restore.pressed.connect(restore_name)
	box.add_child(restore)
	edit.grab_focus()
	edit.caret_column = edit.text.length()


func submit() -> void:
	if edit.text.is_empty():
		restore_name()
		_notice.text = "姓名不能为空，请输入或确认原名。"
		return
	if edit.text.length() > maximum:
		return
	confirmed.emit(edit.text)


func restore_name() -> void:
	edit.text = initial_name.left(maximum)
	edit.grab_focus()
	edit.caret_column = edit.text.length()


func back() -> void:
	edit.text = edit.text.left(maxi(0, edit.text.length() - 1))
	edit.grab_focus()
	edit.caret_column = edit.text.length()
