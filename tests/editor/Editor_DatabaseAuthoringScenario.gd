## 职责：回归验证：执行数据库字段、集合、表格和嵌套数据的交互编写场景。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary
##     用途：执行当前迁移流程或回归场景。
##     参数 parent（Node；必填）：父节点、父对象或继承关系的上级。
##     参数 original（RefCounted；必填）：修改前的原始记录或文本。
##     参数 capture（Callable；默认值 Callable()）：已捕获的现场数据或画面。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

@tool
extends RefCounted
var checks=0
var failures: Array[String]=[]
var dialog: ConfirmationDialog

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func _choose(category: String) -> void:
	for index in dialog._categories.item_count:
		if dialog._categories.get_item_metadata(index)==category: dialog._categories.select(index); dialog._select_category(index); return

func _tab(form: Control, title: String) -> void:
	for index in form._tabs.get_tab_count():
		if form._tabs.get_tab_title(index)==title: form._tabs.current_tab=index; return

func _control(form: Control, key: String) -> Control:
	return form._controls[str([key])].control

func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary:
	var tree=parent.get_tree(); var folder="res://.godot/database_authoring_%d/" % Time.get_ticks_usec()
	var schema=load("res://addons/rgm_editor/04_Database/Editor_DatabaseSchema.gd")
	var system: Dictionary=original.read("data/system.json"); system.variables=["保留", "钥匙数", "金币数"]; system.switches=["", "门已开启"]; system.elements=["", "火", "冰"]
	_write(folder+"data/system.json",system)
	for path in ["data/manifest.json","data/map_infos.json","data/asset_index.json"]: _write(folder+path,original.read(path))
	for category in schema.CATEGORIES:
		if category!="System": _write(folder+"data/database/"+category+".json",original.records(category))
	var actors: Array=original.records("Actors"); actors[1].custom_note={"keep":[8,9]}; _write(folder+"data/database/Actors.json",actors)
	var classes: Array=original.records("Classes"); classes[1].learnings=[{"_class":"RPG::Class::Learning","level":5,"skill_id":1,"custom":8},{"_class":"RPG::Class::Learning","level":5,"skill_id":2}]; _write(folder+"data/database/Classes.json",classes)
	actors=JSON.parse_string(FileAccess.get_file_as_string(folder+"data/database/Actors.json"))
	var docs=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder)
	# Fixture assets belong to the detached document, never modify shared textures.
	var image=Image.create(960,384,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	for i in 10: image.fill_rect(Rect2i((i%5)*192,int(i/5)*192,192,192),Color.from_hsv(float(i)/10,0.8,0.9))
	var texture=ImageTexture.create_from_image(image); docs._textures["Animations/专用预览.png"]=texture
	dialog=load("res://addons/rgm_editor/04_Database/Editor_DatabaseDialog.gd").new(); parent.add_child(dialog); dialog.open(docs)
	var form=dialog._form
	expect(not form._tree.visible and form._tabs.visible and not dialog._preview.visible,"database has one dedicated editor and one primary image area")
	expect(form._extra().has("custom_note") and form._extra().custom_note==actors[1].custom_note and not form._extra().has("name"),"extension contains only unknown fields")
	_control(form,"name").text="专用界面角色"; _control(form,"name").text_changed.emit("专用界面角色")
	_control(form,"initial_level").value=3
	expect(form.draft().name=="专用界面角色" and form.draft().initial_level==3 and docs.records("Actors")[1].name==actors[1].name,"direct named controls edit detached draft")
	form._extensions.pressed.emit(); form._extension_form._put(["custom_note","keep",0],10); form._extension_dialog.canceled.emit(); form._extension_dialog.hide()
	expect(form.draft().custom_note==actors[1].custom_note,"cancel extension leaves unknown fields intact")
	if capture.is_valid(): await capture.call(dialog,"database-groups")
	dialog.canceled.emit(); expect(docs.records("Actors")[1].name=="专用界面角色","closing record retains its edited definition in the shared draft"); docs.undo(); dialog._reload_record()
	_tab(form,"成长"); _control(form,"parameters").pressed.emit(); var table=form._table_dialog
	expect(table._tree.get_column_title(1)=="最大HP" and table._tree.get_root().get_first_child().get_next().get_text(1).is_valid_int(),"growth uses named integer columns")
	expect(not table._width.visible and not table._slice.visible and not table._tree.get_root().get_first_child().is_editable(1),"growth hides dimensions and protects level zero")
	var cell=table._tree.get_root().get_first_child().get_next(); cell.select(1); table._show_selection()
	expect(table._selection.text.contains("最大HP"),"growth selection identifies the stat")
	# Actual Tree edit signal cannot be synthesized without get_edited; confirm a detached table result.
	table._value.values[6]=1234
	if capture.is_valid(): await capture.call(dialog,"growth-named")
	table.confirmed.emit(); table.hide(); expect(dialog.apply_current(),"growth applies through database validation")
	expect(docs.undo() and docs.records("Actors")[1]==actors[1],"undo restores whole actor")
	expect(docs.redo() and docs.records("Actors")[1].parameters.values[6]==1234,"redo restores typed growth")
	_choose("Classes"); _tab(form,"习得特技"); var learn=form._learnings
	learn._select(0); learn._level.value=7
	expect(form.draft().learnings[0].level==7 and form.draft().learnings[0].custom==8,"learning level edit retains extra fields")
	learn._skill.pressed.emit(); expect(form._dialog.visible,"learning skill button opens named reference picker"); form._dialog.hide()
	learn._add(); learn._move(-1); learn._remove()
	expect(form.draft().learnings.size()==2 and form.draft().learnings[0].custom==8,"learning add reorder delete preserve other rows")
	var kept_learnings=form.draft().learnings; var long_learnings=kept_learnings.duplicate(true)
	while long_learnings.size()<101: long_learnings.append({"_class":"RPG::Class::Learning","level":1,"skill_id":1})
	form._put(["learnings"],long_learnings); learn._select(100); learn._skill.pressed.emit()
	expect(form._dialog.visible and form._editing==["learnings",100,"skill_id"],"dedicated skill picker locates rows beyond the old 80 row page")
	form._dialog.hide(); form._put(["learnings"],kept_learnings)
	if capture.is_valid(): await capture.call(dialog,"learnings-named")
	_tab(form,"装备与有效度"); _control(form,"weapon_set").pressed.emit(); var sets=form._set_dialog
	expect(sets.title.contains("武器") and sets._tree.get_root().get_first_child().get_text(0).length()>4,"set labels show purpose and named members")
	sets._search.text="0001"; sets._search.text_changed.emit("0001"); sets._ids=[1]; sets._refresh()
	expect(sets._count.text.contains("1"),"set selection count is explicit")
	if capture.is_valid(): await capture.call(dialog,"sets-named")
	sets.confirmed.emit(); sets.hide(); _control(form,"element_ranks").pressed.emit(); table=form._table_dialog
	expect(table._tree.get_root().get_first_child().get_next().get_text(0).contains("火"),"rank rows resolve element names")
	expect(table._tree.get_root().get_first_child().get_next().get_text(1).contains("A,B,C"),"rank uses A through F choices")
	if capture.is_valid(): await capture.call(dialog,"ranks-named")
	table.hide(); expect(dialog.apply_current(),"learning and set draft applies")
	_choose("System"); _tab(form,"变量名称"); var names=form._names.variables
	names._select_id(1); names._name.text="门钥匙数量"; names._name.text_changed.emit("门钥匙数量")
	names._search.text="0002"; names._search.text_changed.emit("0002")
	expect(names._list.item_count==1 and names._list.get_item_metadata(0)==2 and names.draft()[1]=="门钥匙数量","name search preserves IDs and renaming")
	names._append_name()
	expect(names.draft().size()==4 and names.draft()[0]=="保留" and names._selected==3,"names append at tail and protect index zero")
	names._name.text="新增变量"; names._name.text_changed.emit("新增变量")
	if capture.is_valid(): await capture.call(dialog,"names-stable")
	expect(dialog.apply_current() and docs.reference_label("variables",1).contains("门钥匙数量"),"applied naming refreshes shared references")
	_choose("CommonEvents"); _control(form,"name").text="具名公共事件"; _control(form,"name").text_changed.emit("具名公共事件")
	expect(_control(form,"switch_id").disabled==(int(form.draft().trigger)==0),"manual common events disable unused trigger switch")
	if capture.is_valid(): await capture.call(dialog,"common-groups")
	expect(dialog.apply_current(),"common event direct controls apply")
	_choose("Animations"); dialog._new_record(false); var animation_id=dialog._id
	form._put(["animation_name"],"专用预览.png"); form._put(["name"],"编辑动画验收"); _tab(form,"动画编辑"); var animation=form._animation
	animation._add_cell(); animation._cell_controls[0].value=1; animation._cell_controls[1].value=16; animation._cell_controls[2].value=-8; animation._cell_controls[3].value=75; animation._cell_controls[4].value=30
	animation._cell_controls[5].select(1); animation._cell_controls[5].item_selected.emit(1); animation._cell_controls[6].value=192
	var sprite=animation._canvas._cells[0]
	expect(sprite.visible and sprite.region_rect==Rect2(192,0,192,192) and sprite.position==Vector2(16,-8) and sprite.flip_h and is_equal_approx(sprite.rotation_degrees,-30),"animation preview matches RM cell cropping and transform")
	expect(sprite.texture==texture and texture.get_image().get_pixel(200,8)==image.get_pixel(200,8),"preview preserves source texture")
	animation._add_cell(); animation._remove_cell(); expect(animation.draft().frames[0].cell_max==1 and animation.draft().frames[0].cell_data.x_size==1,"cell add/remove synchronize count and table")
	animation._add_frame(true); animation._add_timing(); animation._timing_controls.frame.value=2; animation._timing_controls.flash_scope.select(2); animation._timing_controls.flash_scope.item_selected.emit(2)
	animation._color.color_changed.emit(Color(0.2,0.4,0.6,0.8))
	expect(animation.draft().timings[0].frame==1 and animation.draft().timings[0].flash_color.red==51 and animation.draft().timings[0].flash_color.alpha==204,"timings display one based frames and save native RGBA")
	var before=animation.draft(); animation._remove_frame(); expect(animation.draft()==before and animation._status.text.contains("时序"),"frame with timing requires moving timing before removal")
	animation._frame=0; animation._remove_frame(); expect(animation.draft().frame_max==1 and animation.draft().timings[0].frame==0,"removing earlier frame shifts later timing")
	animation._add_frame(true); before=animation.draft(); animation._toggle_play(); animation._process(0.06); animation._stop()
	expect(animation.draft()==before,"animation playback does not modify data")
	animation._frame=0; animation._refresh_frame()
	if capture.is_valid(): await capture.call(dialog,"animation-frame")
	animation.get_child(0).current_tab=1
	if capture.is_valid(): await capture.call(dialog,"animation-timing")
	var kept_timings=form.draft().timings; var long_timings=kept_timings.duplicate(true)
	while long_timings.size()<101: long_timings.append(schema.timing())
	form._put(["timings"],long_timings); animation._timing=100; animation._fill_timings(); animation._se.pressed.emit()
	expect(form._audio_dialog.visible and form._editing==["timings",100,"se","name"],"dedicated audio picker locates timing beyond the old 80 row page")
	form._audio_dialog.hide(); form._put(["timings"],kept_timings); animation._timing=0; animation._fill_timings()
	expect(dialog.apply_current(),"animation dedicated draft validates")
	_choose("Tilesets")
	if capture.is_valid(): await capture.call(dialog,"tileset-larger")
	expect(JSON.parse_string(FileAccess.get_file_as_string(folder+"data/system.json")).variables==system.variables,"no disk writes before explicit save")
	var saved: Dictionary=docs.save_all(); expect(saved.ok,"dedicated UI saves all validated definitions: "+str(saved.get("message","")))
	var reopened=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder)
	expect(reopened.read("data/system.json").variables==["保留","门钥匙数量","金币数","新增变量"],"indexed names survive reopen")
	expect(reopened.records("Classes")[1].learnings[0].custom==8 and reopened.records("Classes")[1].weapon_set.size()==1 and int(reopened.records("Classes")[1].weapon_set[0])==1,"learning unknown data and set IDs survive reopen")
	var definition: Dictionary=reopened.records("Animations")[animation_id]
	var compiled=load("res://runtime/scripts/09_Effects/RmxpAnimationData.gd").compile(definition)
	expect(compiled.ok and JSON.stringify(compiled.frames[0][0])==JSON.stringify([1,16,-8,75,30,1,192,0]) and compiled.timings[0].frame==0,"saved animation compiles with actual runtime data parser")
	# Preserve allocated unused columns when copying imported frames.
	var imported=schema.new_record("Animations",1,docs); imported.frames[0].cell_data=schema.table(16,8); imported.frames[0].cell_max=1
	var copy=imported.duplicate(true); copy.frames.append(imported.frames[0].duplicate(true)); copy.frame_max=2
	expect(schema.normalize("Animations",copy,imported).frames[1].cell_max==1,"copying allocated RM frame preserves active cell count")
	var legacy=schema.table(3); legacy.values=[0,9,3]; var before_legacy=legacy.duplicate(true)
	form._table_dialog.open(legacy,"element_ranks",docs)
	expect(form._table_dialog._tree.get_root().get_first_child().get_next().get_text(1).contains("原值 9") and form._table_dialog._value==before_legacy,"legacy rank is labeled and unchanged on opening")
	form._table_dialog.hide()
	dialog.hide(); dialog.queue_free(); await tree.process_frame
	return {"folder":folder,"animation":definition,"texture":texture,"growth":reopened.records("Actors")[1],"system":reopened.read("data/system.json")}
