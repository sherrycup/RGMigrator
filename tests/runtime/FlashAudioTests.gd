extends SceneTree
var checks=0
var failures: Array[String]=[]
var measurements: Array=[]
var effect: AudioEffectCapture
var mixed=false
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState")
	var Data=load("res://runtime/scripts/RuntimeData.gd")
	var Prefs=load("res://runtime/scripts/FlashPreferences.gd")
	var Store=load("res://runtime/scripts/FlashFileStore.gd")
	var Resources=load("res://runtime/scripts/UIResources.gd")
	var original_prefs=state.flash_preferences
	Prefs.directory_override="res://.godot/audio_preferences_%d" % Time.get_ticks_usec()
	var prefs=Prefs.new(state); prefs.apply_display=false; state.flash_preferences=prefs
	expect(prefs.bgm_volume==10 and prefs.se_volume==10,"fresh install starts with audible independent music/effect defaults")
	expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Prefs.MUSIC_BUS)) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(Prefs.EFFECT_BUS)),"fresh actual audio buses are not muted")
	expect(prefs.set_volume("bgm",0) and prefs.set_volume("se",0),"explicit mute persists")
	var loaded=Prefs.new(state); loaded.apply_display=false
	expect(loaded.bgm_volume==0 and loaded.se_volume==0,"saved intentional mute survives restart")
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(Prefs.MUSIC_BUS)) and AudioServer.is_bus_mute(AudioServer.get_bus_index(Prefs.EFFECT_BUS)),"saved mute reaches actual buses")
	# Old settings have no additional marker: retain all original fields/locks.
	var legacy=Store.read(prefs.storage_path(),"preferences").value
	legacy.vars[21]=["kept"]; legacy.music_lock=[true,null,false]
	expect(Store.write(prefs.storage_path(),"preferences",legacy).ok and prefs.load_preferences().ok and prefs.bgm_volume==0 and prefs.vars[21]==["kept"] and prefs.music_lock==[true,null,false],"older zero-volume preferences and achievement/music data remain intact")
	prefs.set_volume("bgm",10); prefs.set_volume("se",10)
	mixed="--mixed-audio" in OS.get_cmdline_user_args()
	var master_volume=AudioServer.get_bus_volume_db(0)
	if mixed:
		effect=AudioEffectCapture.new(); AudioServer.add_bus_effect(0,effect)
		AudioServer.set_bus_volume_db(0,-80) # Capture before master attenuation; quiet QA.
	var title=load("res://scenes/Title.tscn").instantiate(); root.add_child(title); await process_frame
	expect(state.audio.channels.has("BGM") and state.audio.definitions.BGM.name==Data.system().title_bgm.name,"actual Title scene starts the original MP2-derived title music")
	if state.audio.channels.has("BGM"):
		expect(state.audio.channels.BGM.bus==Prefs.MUSIC_BUS and state.audio.channels.BGM.stream.get_length()>100,"title uses the music bus and complete decoded song")
		state.audio.channels.BGM.seek(5.0)
		await capture("title",true)
	title.queue_free(); await process_frame
	var bgms: Array=[]
	for key in Data.read_json("res://data/asset_index.json",{}):
		if key.begins_with("Audio/BGM/") and key.ends_with(".mp3"): bgms.append(key.trim_prefix("Audio/BGM/"))
	expect(bgms.size()==7,"all seven original map MP3s are available in runtime index")
	for name in bgms:
		var result=state.audio.play("BGM",{"name":name,"volume":80,"pitch":100},5.0)
		expect(result.ok,"actual source map MP3 plays "+name)
		if result.ok: await capture(name,true)
	var player=state.audio.channels.get("BGM")
	if player!=null:
		var result=state.audio.play("BGM",state.audio.definitions.BGM)
		expect(result.ok and state.audio.channels.BGM==player,"same-track replay preserves current playback object")
		var snapshot=state.audio.persistent_snapshot(); var decoded=state.audio.decode_persistent(snapshot)
		expect(decoded.ok,"source BGM positions/definitions pass detached save validation")
		state.audio.stop_all(); state.audio.restore_prepared(decoded)
		expect(state.audio.channels.has("BGM") and state.audio.channels.BGM.bus==Prefs.MUSIC_BUS,"saved BGM restores through the preference music bus")
		prefs.set_volume("bgm",0); await capture("muted_music",false); prefs.set_volume("bgm",10)
	state.audio.stop_all()
	# Source System has empty UI sounds. Supply a detached test definition to
	# exercise that route with a real original SE, without editing source data.
	var original_system=Data.system()
	var sound_system=original_system.duplicate(true); sound_system.cursor_se={"name":"001-System01","volume":80,"pitch":100}
	Data._cache["res://data/system.json"]=sound_system
	var holder=Node.new(); root.add_child(holder); var routing: Array=[]
	await capture("menu_se",true,func():
		Resources.play_sound(holder,"cursor_se")
		if holder.get_child_count()>0: routing.append(str(holder.get_child(0).bus)))
	expect(routing==[Prefs.EFFECT_BUS],"actual menu SE shares the effect volume bus")
	prefs.set_volume("se",0); await capture("muted_menu_se",false,func():Resources.play_sound(holder,"cursor_se"))
	prefs.set_volume("se",10)
	var target=Node2D.new(); root.add_child(target)
	var animation=load("res://runtime/scripts/RmxpAnimationPlayer.gd").new()
	animation._data={"id":1,"texture":null,"frames":[[]],"timings":[],"position":1}
	animation._target_provider=func():return target
	root.add_child(animation); animation.set_process(false)
	var timing={"se":{"name":"001-System01","volume":80,"pitch":100},"flash_scope":0}
	await capture("animation_se",true,func():animation._play_timing(timing))
	expect(animation._audio.size()==1 and animation._audio[0].bus==Prefs.EFFECT_BUS,"actual animation timing SE shares the effect volume bus")
	prefs.set_volume("se",0); await capture("muted_animation_se",false,func():animation._play_timing(timing))
	animation.queue_free(); target.queue_free()
	holder.queue_free(); await process_frame
	Data._cache["res://data/system.json"]=original_system
	prefs.set_volume("se",10)
	state.flash_preferences=original_prefs; original_prefs.apply_audio(); Prefs.directory_override=""
	if mixed:
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1); AudioServer.set_bus_volume_db(0,master_volume)
	for message in failures: printerr("FAIL: ",message)
	print("AUDIO MIX: ",JSON.stringify(measurements))
	print("FLASH AUDIO: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	call_deferred("finish")
func finish() -> void:
	await create_timer(0.08).timeout
	quit(0 if failures.is_empty() else 1)
func capture(label: String,audible: bool,start: Callable=Callable()) -> void:
	if not mixed:
		if start.is_valid(): start.call()
		return
	# Discard previous bus buffers before measuring the current routing.
	await create_timer(0.06).timeout; effect.clear_buffer()
	if start.is_valid(): start.call()
	await create_timer(0.3).timeout
	var samples=effect.get_buffer(effect.get_frames_available()); var peak=0.0
	for sample in samples: peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	measurements.append({"name":label,"samples":samples.size(),"peak":peak})
	expect(samples.size()>0 and (peak>0.00001 if audible else peak<0.00001),"actual mixed output "+label+" obeys playback/mute")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
