## 职责：回归验证：执行地图编辑中的鼠标反馈、选择和状态提示场景。
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
var database: ConfirmationDialog

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _write(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func _mouse(canvas: Control, cell: Vector2i, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event=InputEventMouseButton.new(); event.button_index=button; event.pressed=pressed; event.position=canvas._origin+(Vector2(cell)+Vector2(0.5,0.5))*32*canvas._zoom; canvas._gui_input(event)

func _move(canvas: Control, cell: Vector2i) -> void:
	var event=InputEventMouseMotion.new(); event.position=canvas._origin+(Vector2(cell)+Vector2(0.5,0.5))*32*canvas._zoom; canvas._gui_input(event)

func _choose(category: String) -> void:
	for index in database._categories.item_count:
		if database._categories.get_item_metadata(index)==category: database._categories.select(index); database._select_category(index); return

func run(parent: Node, original: RefCounted, capture: Callable = Callable()) -> Dictionary:
	var tree=parent.get_tree(); var folder="res://.godot/feedback_%d/" % Time.get_ticks_usec()
	var schema=load("res://addons/rgm_editor/04_Database/Editor_DatabaseSchema.gd")
	for path in ["data/system.json","data/manifest.json","data/map_infos.json","data/asset_index.json","data/test_setup.json"]: _write(folder+path,original.read(path))
	for category in schema.CATEGORIES:
		if category!="System": _write(folder+"data/database/"+category+".json",original.records(category))
	var manifest: Dictionary=original.read("data/manifest.json"); var map_id=0
	for name in manifest.maps:
		var map: Dictionary=original.read("data/maps/"+str(name)+".json"); _write(folder+"data/maps/"+str(name)+".json",map)
		if map_id==0 and not map.events.is_empty() and int(map.width)>4 and int(map.height)>4: map_id=str(name).trim_prefix("Map").to_int()
	var docs=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder)
	var panel=load("res://addons/rgm_editor/00_Plugin/Editor_Panel.gd").new(); panel.setup(docs); parent.add_child(panel); await tree.process_frame
	panel._load_map(map_id); panel._choose_events()
	var event: Dictionary=panel._map.events.values()[0].duplicate(true); var event_id=int(event.id); var from=Vector2i(int(event.x),int(event.y)); var destination=Vector2i(3,3) if from!=Vector2i(3,3) else Vector2i(4,4)
	var count=docs._history.size(); _mouse(panel._canvas,from,true); _move(panel._canvas,destination)
	expect(docs._history.size()==count and Vector2i(int(panel._map.events[str(event_id)].x),int(panel._map.events[str(event_id)].y))==destination,"drag moves preview without committing a history entry per cell")
	_mouse(panel._canvas,destination,false)
	expect(docs._history.size()==count+1,"release commits exactly one event move")
	var saved_event: Dictionary=docs.read(panel._path).events[str(event_id)]; saved_event.x=event.x; saved_event.y=event.y
	expect(saved_event==event,"moving an event preserves its ID, pages, commands and extra fields")
	panel._undo_action(); expect(panel._map.events[str(event_id)]==event,"one undo restores event position")
	panel._redo_action(); expect(int(panel._map.events[str(event_id)].x)==destination.x,"redo restores destination")
	_mouse(panel._canvas,destination,true); _move(panel._canvas,Vector2i(2,2)); panel._cancel_stroke()
	expect(int(panel._map.events[str(event_id)].x)==destination.x and docs._history.size()==count+1,"Escape cancels event dragging without another transaction")
	for child in panel._event_tools.get_children(): expect(not child is Button or child.text!="设置玩家起点","obsolete start toolbar button is removed")
	_mouse(panel._canvas,Vector2i(1,2),true,MOUSE_BUTTON_RIGHT); panel._context.hide(); panel._context_action(6)
	expect(int(docs.read("data/system.json").start_map_id)==map_id and panel._canvas._start==Vector2i(1,2),"right click start command uses the clicked cell and immediately refreshes the marker")
	panel._undo_action()
	database=load("res://addons/rgm_editor/04_Database/Editor_DatabaseDialog.gd").new(); parent.add_child(database); database.open(docs); _choose("System")
	var form=database._form; expect(not form._tabs.tabs_visible and not database._search.visible,"System uses left page navigation")
	expect(database._records.item_count==form._tabs.get_tab_count() and database._records.get_item_text(1)=="玩家起点","left System navigation contains each purpose page")
	expect(form._extra().is_empty() and not form._extensions.visible and form._controls.has(str(["battler_hue"])),"native battle image hue is classified; no misleading extension button in original System")
	database._records.select(1); database._select_record(1); expect(form._tabs.current_tab==1,"left System page selection opens its dedicated UI")
	var picker=form._start_picker; picker._load(map_id)
	expect(picker._canvas._map.data==panel._map.data and picker._canvas._normal_layout.tile_count>0,"start picker renders real map layers using its tile collection")
	var before_system: Dictionary=docs.read("data/system.json"); _mouse(picker._canvas,Vector2i(2,3),true); _mouse(picker._canvas,Vector2i(2,3),false)
	expect(int(form.draft().start_map_id)==map_id and int(form.draft().start_x)==2 and int(form.draft().start_y)==3 and docs.read("data/system.json")==before_system,"clicking start preview changes only the System form draft")
	if capture.is_valid(): await capture.call(database,"system-start-map")
	database.canceled.emit(); expect(int(docs.read("data/system.json").start_x)==2,"closing System retains the clicked position in the shared draft")
	database._records.select(1); database._select_record(1); picker._load(map_id); _mouse(picker._canvas,Vector2i(2,3),true)
	expect(database.apply_current() and int(docs.read("data/system.json").start_x)==2,"applying System location follows normal draft history")
	database._undo(false); expect(docs.read("data/system.json")==before_system,"System start point supports one undo")
	for index in database._records.item_count:
		if database._records.get_item_text(index)=="音乐与音效": database._records.select(index); database._select_record(index); break
	expect(form._controls[str(["cursor_se"])].control is Button and not form._controls.has(str(["cursor_se","volume"])),"System audio uses one dedicated selector rather than duplicate scalar fields")
	form._controls[str(["cursor_se"])].control.pressed.emit(); expect(form._audio_dialog.visible and form._audio_dialog._browser._category=="SE","System sound button opens the shared audition selector"); form._audio_dialog.hide()
	if capture.is_valid(): await capture.call(database,"system-music-navigation")
	var command=load("res://addons/rgm_editor/03_Event/Editor_CommandDialog.gd").new(); parent.add_child(command); database.hide()
	command.open(docs,201,[0,map_id,0,0,2,0],false)
	expect(command._destination.visible and not command._form.visible,"direct transfer replaces numeric fields with a map picker")
	for index in command._location_picker._maps.item_count:
		var id=int(command._location_picker._maps.get_item_metadata(index))
		if id!=map_id:
			command._location_picker._load(id); expect(command.get_ok_button().disabled,"browsing a different map requires selecting its destination before confirm"); break
	command._location_picker._load(map_id)
	_mouse(command._location_picker._canvas,Vector2i(4,2),true); await tree.process_frame
	expect(command._form.draft()==[0,map_id,4,2,2,0] and command._location_picker._canvas._normal_layout.tile_count>0,"destination click writes direct native coordinates from the real map")
	if capture.is_valid(): await capture.call(command,"transfer-map-click")
	command.hide(); command.open(docs,201,[1,2,3,4,0,1],false)
	expect(not command._destination.visible and command._form.visible and command._form.draft()==[1,2,3,4,0,1],"variable transfer remains variable based and is never converted to a guessed location")
	command.hide()
	var audio_name=""
	for name in docs.assets("SE"):
		var stream: AudioStream=docs.asset_audio("SE",str(name))
		if stream!=null and stream.get_length()>=0.4: audio_name=str(name); break
	expect(not audio_name.is_empty(),"original project supplies a decodable sound for actual audio playback")
	var value_form=load("res://addons/rgm_editor/04_Database/Editor_ValueForm.gd").new(); parent.add_child(value_form)
	var audio={"_class":"RPG::AudioFile","name":audio_name,"volume":70,"pitch":110,"custom_keep":[1,2]}
	for kind in ["BGM","BGS","ME","SE"]:
		value_form.configure([audio],[],docs,{"0/name":{"asset":kind}}); value_form.edit_path([0,"name"])
		expect(value_form._audio_dialog.visible and value_form._audio_dialog._browser._category==kind,"audio selector includes audition and parameters for "+kind)
		expect(value_form.draft()==[audio],"opening audio selector keeps legacy payload for "+kind)
		value_form._audio_dialog.hide()
	value_form.configure([audio],[],docs,{"0/name":{"asset":"SE"}}); value_form.edit_path([0]); var browser=value_form._audio_dialog._browser
	browser._preview(); expect(browser._audio._players.size()==1 and browser._audio._players[0].stream!=null,"audition creates an isolated AudioStreamPlayer with a decoded stream")
	browser._volume.value=35; browser._pitch.value=125
	expect(is_equal_approx(db_to_linear(browser._audio._players[0].volume_db),0.35) and is_equal_approx(browser._audio._players[0].pitch_scale,1.25),"volume and pitch change live on the playing sound")
	if capture.is_valid(): await capture.call(value_form._audio_dialog,"audio-selector-live")
	value_form._audio_dialog.confirmed.emit(); value_form._audio_dialog.hide()
	expect(value_form.draft()[0].volume==35 and value_form.draft()[0].pitch==125 and value_form.draft()[0].custom_keep==[1,2],"audio accept preserves unknown fields with edited volume and pitch")
	expect(browser._audio._players.is_empty(),"closing audio selector releases all audition sounds")
	value_form.edit_path([0,"pitch"]); browser._volume.value=99; value_form._audio_dialog.hide(); expect(value_form.draft()[0].volume==35,"canceling a parameter picker discards the new value")
	# New maps historically have AudioFile-shaped dictionaries without a class tag.
	var untagged=audio.duplicate(true); untagged.erase("_class"); value_form.configure({"bgm":untagged},{},docs,{"bgm/name":{"asset":"BGM"}}); value_form.edit_path(["bgm","name"])
	expect(value_form._audio_dialog.visible and value_form._audio_path==["bgm"],"map audio without a class tag uses the same preview selector")
	value_form._audio_dialog.hide(); database.show(); _choose("Audio"); count=docs.dirty_paths().size()
	for index in 4:
		database._records.select(index); database._select_record(index); expect(database._audio_browser._category==["BGM","BGS","ME","SE"][index],"database audio library has category "+str(index))
	expect(database._new_button.disabled and not database._form.visible and database.pending_status().is_empty(),"audio library browses assets instead of fabricating database records")
	if capture.is_valid(): await capture.call(database,"database-audio-library")
	expect(docs.dirty_paths().size()==count,"audio library never writes an asset or database definition")
	database.hide()
	database.show(); _choose("Animations")
	var definition=schema.new_record("Animations",1,docs); definition.frames=[schema.frame(),schema.frame()]; definition.frame_max=2; definition.timings=[]
	for entry in [[0,0,100],[1,1,110],[1,2,120]]:
		var timing=schema.timing(); timing.frame=entry[0]; timing.condition=entry[1]; timing.se=audio.duplicate(true); timing.se.pitch=entry[2]; definition.timings.append(timing)
	database._form._put([],definition); var animation=database._form._animation; animation.set_process(false); database._form._tabs.current_tab=1
	expect(not animation._loop.button_pressed,"animation defaults to one shot preview")
	animation._toggle_play(); expect(animation._frame==0 and animation._audio._players.size()==1,"play restarts on frame zero and emits its sound once")
	animation._process(0.06); expect(animation._frame==1 and animation._audio._players.size()==2 and is_equal_approx(animation._audio._players[1].pitch_scale,1.1),"crossing frames emits matching hit sounds with their timing parameters")
	animation._process(0.06); expect(not animation._playing and animation._frame==1 and animation._audio._players.size()==2,"single playback stops at the last frame without truncating its sound or replaying frame zero")
	# Capture real mixed samples on a muted, test-only bus; no audible test noise.
	var bus=AudioServer.bus_count; AudioServer.add_bus(); AudioServer.set_bus_name(bus,"FeedbackCapture"); var effect=AudioEffectCapture.new(); AudioServer.add_bus_effect(bus,effect); AudioServer.set_bus_volume_db(bus,-80)
	for player in animation._audio._players: player.bus="FeedbackCapture"
	await tree.create_timer(0.12).timeout
	var samples=effect.get_buffer(effect.get_frames_available()); var peak=0.0
	for sample in samples: peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	if DisplayServer.get_name()=="headless": expect(animation._audio._players[0].stream.get_length()>0 and animation._audio._players[0].has_stream_playback(),"headless animation sound has decoded duration and an active playback object")
	else: expect(samples.size()>0 and peak>0.00001,"animation sounds produce actual nonzero mixer samples")
	animation._stop(); AudioServer.remove_bus(bus); animation._hit.button_pressed=false; animation._toggle_play(); animation._process(0.06)
	expect(animation._audio._players.size()==2 and is_equal_approx(animation._audio._players[1].pitch_scale,1.2),"miss simulation obeys audio timing conditions")
	animation._stop(); animation._loop.button_pressed=true; animation._toggle_play(); animation._process(0.11)
	expect(animation._playing and animation._frame==0 and animation.draft()==definition,"explicit loop wraps without modifying animation data")
	animation._stop(); animation._loop.button_pressed=false
	if capture.is_valid(): await capture.call(database,"animation-one-shot-audio")
	animation.hide(); expect(not animation._playing and animation._audio._players.is_empty(),"hiding animation editor stops preview and audio")
	var presentation=load("res://addons/rgm_editor/07_Common/Editor_Presentation.gd"); var system: Dictionary=docs.read("data/system.json"); system.switches=[null,"一号开关","二号开关","3号开关"]; docs.apply("data/system.json",system)
	expect(presentation.summary(121,[3,3,0],"",docs)=="开关 [0003] 3号开关 打开","event switch display follows type, stable ID/name, change")
	expect(presentation.summary(125,[0,0,10],"",docs)=="金钱 +10","money uses compact amount format")
	expect(presentation.route_summary(27,[3],"",docs)=="开关 [0003] 3号开关 打开","route actions use the same reference and change order")
	expect(JSON.parse_string(FileAccess.get_file_as_string(folder+panel._path)).events[str(event_id)]==event,"event movement remains detached until explicit Save")
	expect(docs.save_all().ok,"feedback edits save through existing validation")
	var reopened=load("res://addons/rgm_editor/01_Documents/Editor_Documents.gd").new(folder)
	expect(int(reopened.read(panel._path).events[str(event_id)].x)==destination.x,"event position survives save and reopen")
	for node in [panel,database,command,value_form]: node.queue_free()
	await tree.process_frame
	return {"checks":checks,"failures":failures,"mixed_samples":samples.size(),"audio_peak":peak}
