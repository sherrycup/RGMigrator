@tool
extends ConfirmationDialog
signal accepted(audio: Dictionary)
var _browser: VBoxContainer

func open(documents: RefCounted, category: String, audio: Dictionary) -> void:
	if _browser==null:
		_browser=preload("EditorAudioBrowser.gd").new(); _browser.custom_minimum_size=Vector2(580,400); add_child(_browser)
		confirmed.connect(func() -> void: accepted.emit(_browser.draft()))
		visibility_changed.connect(func() -> void: if not visible: _browser.stop())
	_browser.configure(documents,category,audio); title="选择音频 · "+category; get_ok_button().text="使用此音频"; popup_centered(Vector2i(660,540))
