extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var directory := ""
	var mode := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-directory="): directory = argument.trim_prefix("--save-directory=")
		if argument.begins_with("--phase="): mode = argument.trim_prefix("--phase=")
	if not directory.begins_with(ProjectSettings.globalize_path("res://.godot/")) or mode not in ["write", "read"]:
		printerr("FAIL: restart test requires a disposable project-local save directory")
		quit(1)
		return
	var saves: Script = load("res://runtime/scripts/SaveService.gd")
	var data: Script = load("res://runtime/scripts/RuntimeData.gd")
	var state: Node = root.get_node("RuntimeState")
	restart_audio_fixture(data, mode)
	saves.directory_override = directory
	if mode == "write":
		state.begin_new_game(data.system())
		state.set_windowskin("@restart_skin")
		state.audio.play("BGM", {"name": "@restart_audio", "volume": 80, "pitch": 120}, 2.5)
		state.audio.memorize()
		state.audio.fade_out("BGM", 4)
		state.audio._process(1)
		state.gold = 4567
		state.steps = 89
		state.play_seconds = 987.5
		state.player_direction = 6
		if not state.configure_player({"move_speed": 5, "step_anime": true, "direction_fix": true, "opacity": 180, "blend_type": 1}).ok:
			printerr("FAIL: restart player options preparation")
			quit(1)
			return
		state.variables["99"] = -1234
		state.actor(int(state.party[0])).hp = 3
		var actor: RefCounted = state.actor(int(state.party[0]))
		if not actor.add_parameter_plus("atk", 7).ok or not actor.add_parameter_plus("str", -10).ok or not actor.rename("重启测试角色").ok or not actor.set_graphic(actor.character_name, 120).ok:
			printerr("FAIL: restart actor mutation preparation")
			quit(1)
			return
		actor.set_event_graphic(actor.character_name, 120, "跨进程战斗元数据", 180)
		var skill := int(data.test_config().toggle_skill_id)
		state.change_skill(int(state.party[0]), skill, false)
		state.inventory["item:%d" % int(data.test_config().stock[0].id)] = 1
		state.show_picture(7, "@test_picture", {"x": 80, "y": 300, "origin": 1, "blend_type": 2})
		state.move_picture(7, {"x": 280, "opacity": 100}, 4)
		state.rotate_picture(7, 60)
		state.tint_picture(7, [-30, 20, 0, 100], 2)
		state.screen.start_tone_change([-50, 10, 0, 90], 2)
		state.screen.start_flash([255, 100, 50, 200], 2)
		state.screen.start_shake(10, 1, 2)
		state.screen.advance(0.5)
		state.configure_map_view({"view_rect": [160, 0, 480, 480], "follow_center": [180, 192]})
		state.screen.weather(3, 8, 2)
		state.screen.weather_state.advance(0.5)
		state.map_effects.fade_fog(20, 2)
		state.map_effects.advance(0.5)
		state.timer.start(12)
		state.timer.advance(0.5)
		var result: Dictionary = saves.save_slot(1, state)
		if not result.ok:
			printerr("FAIL: ", result.message)
			quit(1)
			return
	else:
		# No begin_new_game and no in-memory cache carried over from the writer.
		var result: Dictionary = saves.load_slot(1, state)
		if not result.ok or state.gold != 4567 or state.steps != 89 or state.play_seconds != 987.5 or state.player_direction != 6 or state.variables.get("99") != -1234:
			printerr("FAIL: process restart did not restore saved counters")
			quit(1)
			return
		if state.windowskin_name() != "@restart_skin" or not state.audio.channels.has("BGM") or not state.audio.memory.has("BGM") or not state.audio.fades.has("BGM") or state.audio.fades.BGM.remaining != 3 or state.audio.channels.BGM.get_playback_position() < 2.4:
			printerr("FAIL: restart lost system skin/audio position/memory/fade")
			quit(1)
			return
		var actor: RefCounted = state.actor(int(state.party[0]))
		if state.player_motion.options.move_speed != 5 or not state.player_motion.options.step_anime or not state.player_motion.options.direction_fix or state.player_motion.options.opacity != 180 or state.player_motion.options.blend_type != 1 or not state.player_motion.is_idle():
			printerr("FAIL: process restart lost player options or restored an unfinished move")
			quit(1)
			return
		if actor.hp != 3 or actor.has_skill(int(data.test_config().toggle_skill_id)) or state.inventory["item:%d" % int(data.test_config().stock[0].id)] != 1:
			printerr("FAIL: process restart reinitialized actor or supplied testing stock")
			quit(1)
			return
		if actor.atk_plus != 7 or actor.str_plus != -10 or actor.actor_name != "重启测试角色" or actor.character_hue != 120 or actor.battler_name != "跨进程战斗元数据" or actor.battler_hue != 180:
			printerr("FAIL: process restart lost permanent bonuses or actor identity")
			quit(1)
			return
		var picture: RefCounted = state.screen.picture(7)
		if state.map_view.options.follow_center != [180.0, 192.0] or state.map_view.options.view_rect != [160.0, 0.0, 480.0, 480.0] or state.screen.weather_snapshot().weather_type != 3 or state.screen.weather_snapshot().weather_remaining != 1.5 or state.timer.remaining != 11.5:
			printerr("FAIL: restart lost map view, weather/fog or countdown")
			quit(1)
			return
		if picture == null or picture.snapshot().x != 105 or picture.snapshot().angle != 30 or picture.snapshot().move_remaining != 3.5 or picture.snapshot().tone_remaining != 1.5 or state.screen.effects_snapshot().tone[0] != -12.5 or state.screen.effects_snapshot().flash_color[3] != 150:
			printerr("FAIL: process restart lost picture/screen transitions")
			quit(1)
			return
		state.screen.advance(3.5)
		if picture.snapshot().x != 280 or picture.snapshot().opacity != 100 or state.screen.effects_snapshot().shake != 0 or state.screen.effects_snapshot().flash_color[3] != 0:
			printerr("FAIL: restarted transitions did not reach exact endpoints")
			quit(1)
			return
		var game: Node = load("res://scenes/Game.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		for _index in 3: await process_frame
		if game._player.facing != Vector2i.RIGHT or game._dialogue.is_open() or state.resume_from_save:
			printerr("FAIL: restarted Game did not restore direction or replayed startup event")
			quit(1)
			return
		if not state.audio.channels.has("BGM") or not state.audio.fades.has("BGM") or state.audio.channels.BGM.get_playback_position() < 2.4:
			printerr("FAIL: map autoplay replaced restored audio")
			quit(1)
			return
		game.queue_free()
		current_scene = null
		await process_frame
		await create_timer(0.2).timeout
	state.audio.stop_all()
	for step in 3: await process_frame
	await create_timer(0.2).timeout
	print("SAVE RESTART TESTS: PASSED / ", mode)
	quit(0)

func restart_audio_fixture(data: Script, mode: String) -> void:
	var skin_path := "res://.godot/restart-skin.tres"
	var audio_path := "res://.godot/restart-audio.tres"
	if mode == "write":
		var image := Image.create(192, 128, false, Image.FORMAT_RGBA8)
		image.fill(Color("408060"))
		ResourceSaver.save(ImageTexture.create_from_image(image), skin_path)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 11025
		var bytes := PackedByteArray(); bytes.resize(11025 * 12 * 2); wav.data = bytes
		ResourceSaver.save(wav, audio_path)
	var index: Dictionary = data.read_json("res://data/asset_index.json")
	index["Graphics/Windowskins/@restart_skin"] = skin_path
	index["Audio/BGM/@restart_audio"] = audio_path
