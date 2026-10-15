extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); root.content_scale_size=Vector2i(640,640)
	var state=root.get_node("RuntimeState")
	state.map_id=8; state.player_motion.relocate(Vector2i(4,4))
	var world=state.custom_data.map_system()
	var a=Data.map(8); var b=Data.map(12)
	world.record_transfer({"id":8,"x":int(a.width)-1,"y":5,"width":int(a.width),"height":int(a.height),"facing":6},{"id":12,"x":0,"y":5,"width":int(b.width),"height":int(b.height),"facing":6})
	var screen: Control=load("res://runtime/scripts/FlashMapScreen.gd").new(); root.add_child(screen)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path=ProjectSettings.globalize_path("res://.godot/flash-map-screen.png")
	var status=image.save_png(path)
	print("FLASH MAP RENDER: ","PASSED" if status==OK else "FAILED"," / ",path)
	quit(0 if status==OK else 1)
