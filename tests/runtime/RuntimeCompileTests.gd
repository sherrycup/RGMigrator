extends SceneTree
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var failed := false
	for name in ["MapViewState", "MapEffectsState", "GameTimer", "AudioRuntime", "MapCamera", "WeatherRenderer", "MapEffectsRenderer", "TransitionRenderer", "PresentationTools"]:
		var extra: Script = load("res://runtime/scripts/%s.gd" % name)
		if extra == null or not extra.can_instantiate(): failed = true
	for name in ["ActorParameters", "ActorState", "RuntimeData", "RmxpCache", "CharacterMotion", "MapCharacter", "MapTileRow", "PlayerController", "MapEvent", "MovementFixture", "MovementTools", "EventInterpreter", "RmxpAnimationData", "RmxpAnimationPlayer", "MapRuntime", "SaveCodec", "SaveService", "SaveSlots", "AnimationLab", "SkillScene", "ShopService", "ShopScene", "StateTools", "TestTools", "ActorTools", "PictureState", "ScreenState", "PictureSprite", "ScreenRenderer", "ScreenTools", "MenuScene", "Title", "Game"]:
		var script: Script = load("res://runtime/scripts/%s.gd" % name)
		if script == null or not script.can_instantiate():
			printerr("FAIL: runtime compile ", name)
			failed = true
	print("RUNTIME COMPILE: ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
