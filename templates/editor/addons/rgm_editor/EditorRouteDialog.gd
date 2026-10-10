@tool
extends ConfirmationDialog
const RouteForm = preload("EditorRouteForm.gd")
const Commands = preload("EditorCommands.gd")
signal accepted(route: Dictionary)
var _form: VBoxContainer
var _message: Label

func open(route: Dictionary, documents: RefCounted = null) -> void:
	if _form == null:
		title = "设置自主移动路线"; dialog_hide_on_ok = false
		var box = VBoxContainer.new(); add_child(box)
		_form = RouteForm.new(); box.add_child(_form)
		_message = Label.new(); _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message.custom_minimum_size.x = 760; _message.size.x = 760; box.add_child(_message)
		confirmed.connect(_accept)
	_form.configure(route,documents); _message.text = ""; popup_centered(Vector2i(960,560))

func _accept() -> void:
	var route: Dictionary = _form.draft()
	var result = Commands.Catalog.route_validation(route)
	if not result.ok: _message.text = result.message; return
	accepted.emit(route); hide()
