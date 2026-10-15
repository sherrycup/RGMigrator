extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState"); var prefs=state.flash_preferences; prefs.apply_display=false
	expect(prefs.vars.size()==101 and prefs.bgm_volume==10 and prefs.se_volume==10 and prefs.run_mode==0,"fresh 101-variable app settings correct the source silent default without importing RM settings")
	expect(prefs.set_volume("bgm",7) and prefs.set_volume("se",4) and not prefs.set_volume("bgm",11),"original 0–10 independent volume ranges reject invalid change")
	expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(prefs.MUSIC_BUS))),0.7) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(prefs.EFFECT_BUS))),0.4),"actual separate audio buses apply original volume multipliers without changing source audio definitions")
	prefs.next_run_mode(); prefs.change_window_size(-1)
	expect(prefs.run_mode==1 and prefs.window_resize==3,"source run toggle and window-mode wrap work without a platform helper")
	state.begin_new_game(Data.system(),{"enabled":false})
	expect(state.flash_preferences==prefs and prefs.bgm_volume==7 and prefs.run_mode==1,"new game retains the app preference instance while resetting per-game state")
	prefs.unlock_music("森林.ogg")
	expect(prefs.music_lock.size()==2 and prefs.music_lock[1]==true and prefs.music_lock[0]==null,"corrected missing Game_Music.unlock records only exact original music_name slot")
	var config: Control=load("res://runtime/scripts/FlashConfigPage.gd").new(); root.add_child(config); await process_frame
	config.handle_key(KEY_RIGHT)
	expect(prefs.bgm_volume==8,"actual settings keyboard adjusts formal application music volume")
	config.handle_key(KEY_DOWN); config.handle_key(KEY_LEFT)
	expect(prefs.se_volume==3,"actual settings effect row adjusts only effect volume")
	config.handle_key(KEY_E); config.handle_key(KEY_RIGHT)
	expect(config.sheet==2 and prefs.se_volume==3,"source unfinished second setting page does not invent settings")
	config.handle_key(KEY_E); config.handle_key(KEY_E)
	expect(config.sheet==1,"original three-page selector wraps")
	config.queue_free(); await process_frame; state.variables.erase("10")
	var notes: Control=load("res://runtime/scripts/FlashNotePage.gd").new(); root.add_child(notes); await process_frame
	expect(state.variables["10"]==[0,0,0,0,0] and notes.entries.is_empty(),"note page initializes source category locks and does not unlock sample notes")
	state.variables["10"][0]=1; notes.refresh(); notes.handle_key(KEY_ENTER)
	expect(notes.entries.size()==9 and notes.selecting and notes.description.begins_with("啦啦啦"),"unlocked actual note page displays all source names and recovered finite-case text")
	notes.handle_key(KEY_DOWN)
	expect(notes.index==1 and notes.description=="哈哈哈哈","actual note row navigation displays the corresponding original description")
	notes.handle_key(KEY_DOWN)
	expect(notes.description.is_empty(),"missing original note description remains empty")
	notes.handle_key(KEY_ESCAPE); notes.handle_key(KEY_RIGHT); notes.handle_key(KEY_ENTER)
	expect(notes.category==1 and not notes.selecting and notes.entries.is_empty(),"category lock prevents entry while allowing original category navigation")
	notes.queue_free(); await process_frame
	var title: Control=load("res://runtime/scripts/Title.gd").new(); title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(title); await process_frame
	expect(title._flash!=null and title._flash.page=="title" and not paused,"actual Title selects Flash screen and clears pause")
	var screen=title._flash; screen.handle_key(KEY_ENTER)
	expect(screen.page=="mode" and screen.difficulty==1,"actual source new-game command enters four-mode selector at source default Hard")
	screen.handle_key(KEY_LEFT); screen.handle_key(KEY_RIGHT); screen.handle_key(KEY_RIGHT)
	var selected: Array=[]; screen.new_game_requested.disconnect(title._on_flash_new_game); screen.new_game_requested.connect(func(id: int):selected.append(id)); screen.handle_key(KEY_ENTER)
	expect(selected==[2],"actual mode confirm emits exact source difficulty without a second actor or formula state")
	screen.back(); screen.index=2; screen.activate()
	expect(screen.child==null and screen.page=="title","original disabled independent chapter does not construct an invented scene")
	screen.index=5; screen.activate()
	expect(screen.child!=null and screen.child.page=="flash_config","actual title settings command shares the same application preferences page")
	screen.handle_key(KEY_ESCAPE); screen.index=4; screen.activate(); var music=screen.child
	var bgm_before=state.audio.definitions.duplicate(true); var channels_before=state.audio.channels.duplicate()
	music._process(0.1); screen.handle_key(KEY_DOWN)
	expect(music.index==1 and music.progress==0 and state.audio.definitions==bgm_before and state.audio.channels==channels_before,"original music CD selection animates without changing tracks or restarting the live players")
	music._process(28.0/60)
	expect(music.progress==28 and music.playing,"source twenty-eight-frame CD motion finishes asynchronously")
	screen.handle_key(KEY_ESCAPE); screen.index=3; screen.activate(); var gold=state.gold; screen.handle_key(KEY_ENTER)
	expect(screen.child.book and state.gold==gold,"source merit sample book opens with no nonexistent reward payout")
	screen.handle_key(KEY_ESCAPE)
	expect(not screen.child.book,"first merit cancel returns from book to category")
	screen.handle_key(KEY_ESCAPE)
	expect(screen.child==null and screen.index==3,"next title child cancel returns to source command cursor")
	title.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH TITLE/NOTE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
