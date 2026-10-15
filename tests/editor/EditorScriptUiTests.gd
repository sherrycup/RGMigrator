extends SceneTree
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.gui_embed_subwindows=true
	var documents: RefCounted=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var dialog: Window=load("res://addons/rgm_editor/EditorScriptDialog.gd").new(); root.add_child(dialog)
	expect(not dialog.visible,"workspace does not create an empty visible window at startup")
	dialog.open(documents)
	expect(dialog._list.item_count>=483,"actual editor lists all Flash source and event units")
	expect(not dialog._original.editable and not dialog._generated.editable,"original and generated panes remain read-only")
	dialog._search.text="event_"; dialog._kind.select(2); dialog._filter()
	expect(dialog._list.item_count==144,"event filter selects the real 144 fragments")
	var id: String=dialog._id; var original: String=dialog._model.source(id,true)
	dialog._source.text=original+"\n# 编辑草稿"
	dialog._source.text_changed.emit()
	expect(not dialog.pending_status().is_empty(),"unsaved source is tracked before applying")
	expect(dialog.apply_current() and documents.dirty_paths().has("data/script_workspace.json"),"switching/applying writes a detached workspace draft")
	expect(dialog._model.source(id,true)==original,"typing does not change immutable original source")
	if dialog._mapping.item_count>0:
		var row: Dictionary=dialog._mapping.get_item_metadata(0); dialog._jump_mapping(0)
		expect(dialog._tabs.current_tab==2 and dialog._generated.get_caret_line()==int(row.generated_line)-1,"source mapping jumps to actual generated line")
	dialog._search.text="script_0003"; dialog._kind.select(0); dialog._filter()
	expect(not dialog._source.editable,"service-adapted Ruby is directed to its actual GDScript implementation")
	expect(not dialog._summary.text.is_empty() and dialog._coverage.get_root().get_children().size()==4,"coverage exposes functions, syntax, API sites and ownership")
	dialog._close(); expect(not dialog.visible,"closing retains applied drafts and returns to the editor")
	documents.reload(); dialog.queue_free(); await process_frame
	var database: Window=load("res://addons/rgm_editor/EditorDatabaseDialog.gd").new(); root.add_child(database); database.open(documents)
	for i in database._categories.item_count:
		if database._categories.get_item_metadata(i)=="CustomData": database._select_category(i); break
	var form: Control=database._form
	expect(form._controls.has(str(["currencies",0,"label"])) and form._controls.has(str(["currencies",0,"maximum"])),"currency has a dedicated label and precise cap control")
	expect(form._controls.has(str(["system_defaults","show_playerdata"])),"project system options have real checkboxes")
	expect(form._controls.has(str(["actor_presets","2","0","patk"])),"actor presets expose original editable values")
	expect(form._controls.has(str(["floors","maps","4","I",0])),"map/floor relationship has a direct ID control")
	expect(form._extra().is_empty() and not form._extensions.visible,"specialized custom pages do not leave duplicate generic editing")
	var normalized: Dictionary=load("res://addons/rgm_editor/EditorDatabaseSchema.gd").normalize("CustomData",form.draft())
	normalized.floors.maps["4"].I=[2,8]; normalized=load("res://addons/rgm_editor/EditorDatabaseSchema.gd").normalize("CustomData",normalized)
	expect(normalized.floors.lookup.has("2:8") and not normalized.floors.lookup.has("1:1"),"floor lookup is rebuilt from the edited IDs")
	normalized.floors.maps["5"]={"I":[2,8],"templates":{}}
	expect(not load("res://addons/rgm_editor/EditorDatabaseSchema.gd").reason("CustomData",normalized,form.draft(),documents).is_empty(),"duplicate floor addresses are rejected")
	database.hide(); database.queue_free(); await process_frame
	for failure in failures: printerr("FAIL: ",failure)
	print("EDITOR SCRIPT UI: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
