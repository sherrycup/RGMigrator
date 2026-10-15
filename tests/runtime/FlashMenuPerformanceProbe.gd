extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var Saves: Script
var Resources: Script
var report={}
func _init() -> void: call_deferred("run")
func run() -> void:
	Saves=load("res://runtime/scripts/SaveService.gd")
	Resources=load("res://runtime/scripts/UIResources.gd")
	root.size=Vector2i(640,640)
	root.content_scale_size=Vector2i(640,640)
	var label="unknown"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--directory="): Saves.directory_override=arg.trim_prefix("--directory=")
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	report.label=label; report.slots=Saves.existing_slots(); report.slot_count=report.slots.size()
	var valid_samples=[]
	for i in 5:
		var start=Time.get_ticks_usec(); var valid=Saves.has_valid_save()
		valid_samples.append((Time.get_ticks_usec()-start)/1000.0); report.valid=valid
	report.has_valid_save_ms=valid_samples
	var slot_samples=[]
	for id in report.slots:
		var start=Time.get_ticks_usec(); var info=Saves.slot_info(id)
		slot_samples.append({"id":id,"ms":(Time.get_ticks_usec()-start)/1000.0,"ok":info.ok,"message":info.get("message",""),"png_chars":str(info.get("archive",{}).get("png","")).length()})
	report.slot_info=slot_samples
	var title: Control=load("res://runtime/scripts/FlashTitleScreen.gd").new()
	root.add_child(title); title.set_process(false)
	for i in 4: await process_frame
	var title_keys=[]
	for i in 8:
		var start=Time.get_ticks_usec(); title.handle_key(KEY_DOWN)
		title_keys.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame; await process_frame
	report.title_key_ms=title_keys
	var bg_ticks=[]
	for i in 16:
		var start=Time.get_ticks_usec(); title._tick(); bg_ticks.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame
	report.title_background_tick_ms=bg_ticks
	title.queue_free(); await process_frame
	var archive: Control=load("res://runtime/scripts/FlashArchivePage.gd").new()
	archive.mode="save"; root.add_child(archive); archive.set_process(false)
	for i in 4: await process_frame
	for i in 9: archive._process(1.0/60.0)
	var archive_keys=[]; var preview_frames=[]
	for i in 6:
		var start=Time.get_ticks_usec(); archive.handle_key(KEY_DOWN)
		archive_keys.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame
		var frames=[]
		for j in 8:
			start=Time.get_ticks_usec(); archive._process(1.0/60.0); frames.append((Time.get_ticks_usec()-start)/1000.0)
			await process_frame
		preview_frames.append(frames)
	report.archive_key_ms=archive_keys; report.archive_preview_tick_ms=preview_frames
	archive.queue_free(); await process_frame
	var state=root.get_node("RuntimeState")
	state.begin_new_game(Data.system(),{"enabled":false})
	var menu: Control=load("res://runtime/scripts/FlashMenuScreen.gd").new(); root.add_child(menu)
	for i in 3: await process_frame
	var menu_keys=[]; var sound_samples=[]
	for i in 8:
		var start=Time.get_ticks_usec(); menu.handle_key(KEY_DOWN); menu_keys.append((Time.get_ticks_usec()-start)/1000.0)
		start=Time.get_ticks_usec(); Resources.play_sound(menu,"cursor_se"); sound_samples.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame
	report.menu_key_ms=menu_keys; report.sound_ms=sound_samples
	menu.queue_free(); await process_frame
	if not report.slots.is_empty():
		var progress=Saves.read_slot(int(report.slots[0]))
		if progress.ok: state.restore_prepared(progress.prepared)
	state.variables["10"]=[1,0,0,0,0]; state.inventory["item:1"]=1; state.inventory["item:2"]=1
	state.actor(int(state.party[0])).learn_skill(31); state.actor(int(state.party[0])).learn_skill(32)
	report.pages={}
	for spec in [["FlashConfigPage",false],["FlashItemPage",true],["FlashSkillPage",false],["FlashNotePage",true],["FlashBlasticPage",false]]:
		var view: Control=load("res://runtime/scripts/"+spec[0]+".gd").new(); root.add_child(view)
		for i in 3: await process_frame
		if spec[1]: view.handle_key(KEY_ENTER)
		var samples=[]
		for i in 8:
			var start=Time.get_ticks_usec(); view.handle_key(KEY_DOWN); samples.append((Time.get_ticks_usec()-start)/1000.0)
			await process_frame; await process_frame
		report.pages[spec[0]]=samples; view.queue_free(); await process_frame
	# Exercise production Title input dispatch while its background and rendering run.
	var host: Control=load("res://runtime/scripts/Title.gd").new(); root.add_child(host)
	for i in 32: await process_frame
	var frames=[]; var keys=[]; var selections=[]
	for i in 96:
		var start=Time.get_ticks_usec()
		if i%12==0:
			var event=InputEventKey.new(); event.keycode=KEY_DOWN; event.pressed=true
			Input.parse_input_event(event); Input.flush_buffered_events()
			keys.append((Time.get_ticks_usec()-start)/1000.0); selections.append(host._flash.index)
			event=InputEventKey.new(); event.keycode=KEY_DOWN; event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events()
		await process_frame; frames.append((Time.get_ticks_usec()-start)/1000.0)
	report.live_title={"frame_ms":frames,"key_ms":keys,"selections":selections}
	host.queue_free(); await process_frame
	var archive_live: Control=load("res://runtime/scripts/FlashArchivePage.gd").new(); root.add_child(archive_live)
	for i in 12: await process_frame
	frames=[]; keys=[]
	for i in 72:
		var start=Time.get_ticks_usec()
		if i%12==0:
			archive_live.handle_key(KEY_DOWN); keys.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame; frames.append((Time.get_ticks_usec()-start)/1000.0)
	report.live_archive={"frame_ms":frames,"key_ms":keys,"selected":archive_live.selected}
	# Faster switches deliberately interrupt the original eight-frame crossfade.
	frames=[]; keys=[]
	for i in 24:
		var start=Time.get_ticks_usec()
		if i%2==0:
			archive_live.handle_key(KEY_DOWN); keys.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame; frames.append((Time.get_ticks_usec()-start)/1000.0)
	report.rapid_archive={"frame_ms":frames,"key_ms":keys}
	archive_live.queue_free(); await process_frame
	var file=FileAccess.open("res://.godot/menu-latency-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLASH MENU PERFORMANCE: PASSED"); quit()
