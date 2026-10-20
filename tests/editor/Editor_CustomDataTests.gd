## 职责：回归验证：验证项目自定义数据专用表单的读取、编辑和保存。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var Documents: Script=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd")
	var Dialog: Script=load("res://addons/rgm_editor/04_Database/Editor_DatabaseDialog.gd")
	var directory=ProjectSettings.globalize_path("res://.godot/custom_editor_"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory.path_join("data/database"))
	for path in ["data/system.json","data/manifest.json","data/map_infos.json","data/custom_data.json","data/database/Actors.json","data/database/Classes.json"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://"+path),directory.path_join(path))
	var documents: RefCounted=Documents.new(directory)
	var dialog: Window=Dialog.new(); root.add_child(dialog); dialog.open(documents)
	var custom_index=-1
	for i in dialog._categories.item_count:
		if dialog._categories.get_item_metadata(i)=="CustomData": custom_index=i
	expect(custom_index>=0,"project custom data is an existing database entry")
	dialog._select_category(custom_index)
	expect(dialog._path()=="data/custom_data.json" and dialog._before.get("format")=="rgm-custom-data-v1","custom data uses its own document rather than System.json")
	expect(not dialog._form._asset_scroll.visible and dialog._form._caption_for(["currencies"])=="货币列表","project data has named fields and no unrelated battle asset editor")
	var original: Dictionary=documents.read("data/custom_data.json").duplicate(true)
	dialog._form._put(["currencies",0,"label"],"金币测试名")
	expect(dialog.apply_current() and documents.dirty_paths().has("data/custom_data.json"),"named data edits apply to detached drafts")
	expect(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("data/custom_data.json"))).currencies[0].label==original.currencies[0].label,"applying a draft does not save a file")
	expect(documents.save_all().ok,"explicit save writes custom data")
	var reopened: RefCounted=Documents.new(directory)
	expect(reopened.read("data/custom_data.json").currencies[0].label=="金币测试名","custom data edit persists after reopen")
	var source: Dictionary=reopened.read("data/custom_data.json")
	expect(source.sources==original.sources and source.adapters==original.adapters and source.diagnostics==original.diagnostics,"editing values retains unknown files and source provenance")
	var actors: Array=documents.records("Actors"); var id=2 if actors.size()>2 and actors[2] is Dictionary else 1
	for i in dialog._categories.item_count:
		if dialog._categories.get_item_metadata(i)=="Actors": dialog._select_category(i); break
	dialog._load_record(id)
	if dialog._before.get("_custom_data",{}).get("attributes",{}).has("tp_plus"):
		var path=["_custom_data","attributes","tp_plus","patk"]
		expect(dialog._form._controls.has(str(path)),"actor attribute has a named editable control")
		expect(dialog._form._caption_for(path)=="物理攻击","original actor extension key has a readable label")
		expect(not dialog._form._extra().has("_custom_data"),"extension metadata has no duplicate editable entry")
		dialog._form._put(path,73)
		expect(dialog.apply_current() and documents.save_all().ok,"actor extension saves through the database draft")
		reopened=Documents.new(directory)
		expect(reopened.records("Actors")[id]._custom_data.attributes.tp_plus.patk==73,"actor extension reloads by original actor ID")
	dialog.hide(); dialog.queue_free(); await process_frame
	for failure in failures: printerr("FAIL: ",failure)
	print("EDITOR CUSTOM DATA: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
