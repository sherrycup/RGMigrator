extends SceneTree
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var failed := false
	for filename in DirAccess.get_files_at("res://runtime/scripts"):
		if not filename.ends_with(".gd"): continue
		var production: Script=load("res://runtime/scripts/"+filename)
		if production==null or production.reload(true)!=OK or not production.can_instantiate():
			printerr("FAIL: runtime compile ",filename); failed=true
	for name in ["ScriptSemantics", "ScriptStateBridge", "ScriptRuntime", "EventPersistence", "CommonEventUse", "CharacterRoute", "EventExecutionContext", "EventWait", "EventCommandCatalog", "EventScheduler", "EventUIBroker", "EventFixture", "EventTestHUD", "EventInput", "EventMessage", "EventValueResolver"]:
		var extra: Script = load("res://runtime/scripts/%s.gd" % name)
		if extra == null or not extra.can_instantiate(): failed = true
	for name in ["SystemSettings", "WeatherState", "MapViewState", "MapEffectsState", "GameTimer", "AudioRuntime", "MapCamera", "WeatherRenderer", "MapEffectsRenderer", "TransitionRenderer", "PresentationTools"]:
		var extra: Script = load("res://runtime/scripts/%s.gd" % name)
		if extra == null or not extra.can_instantiate(): failed = true
	for name in ["ActorEventService", "NameInput", "Gameover", "ActorParameters", "ActorState", "RuntimeData", "RmxpCache", "CharacterMotion", "MapCharacter", "MapTileRow", "PlayerController", "MapEvent", "MovementFixture", "MovementTools", "EventInterpreter", "RmxpAnimationData", "RmxpAnimationPlayer", "MapRuntime", "SaveCodec", "SaveService", "SaveSlots", "AnimationLab", "SkillScene", "ShopService", "ShopScene", "StateTools", "TestTools", "ActorTools", "PictureState", "ScreenState", "PictureSprite", "ScreenRenderer", "ScreenTools", "MenuScene", "Title", "Game"]:
		var script: Script = load("res://runtime/scripts/%s.gd" % name)
		if script == null or not script.can_instantiate():
			printerr("FAIL: runtime compile ", name)
			failed = true
	print("RUNTIME COMPILE: ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
