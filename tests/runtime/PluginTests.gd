## 职责：回归验证：验证闪翼通用脚本插件接口及值扩展行为。
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
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10
	var snapshot=load("res://runtime/scripts/10_Support/Persistence/MapSnapshot.gd").new()
	snapshot.output_directory="res://.godot/snapshot-tests-%d" % Time.get_ticks_usec()
	expect(not snapshot.set_scale(3) and snapshot.set_scale(2) and not snapshot.set_mode("bad"),"snapshot keeps original accepted scales and modes")
	var source=Data.map(10); var map_before=state.map_id
	var normal=snapshot.render(10)
	expect(normal.ok and normal.images[0].get_size()==Vector2i(int(source.width)*16,int(source.height)*16),"M mode renders the original map at source scale: "+str(normal.get("message","")))
	var exported=snapshot.snap(10)
	expect(exported.ok and FileAccess.file_exists(exported.paths[0]),"snapshot produces an actual PNG file")
	if exported.ok:
		var png=Image.load_from_file(exported.paths[0]); expect(png.get_size()==normal.images[0].get_size(),"exported PNG decodes with expected dimensions")
	snapshot.set_mode("U"); var split=snapshot.render(10)
	expect(split.ok and split.images.size()==2 and split.images[0].get_width()==int(source.width)*32,"U mode returns lower and upper layers at forced full size")
	snapshot.set_mode("T"); expect(snapshot.render(10).ok,"T mode renders static first-page character events")
	snapshot.set_mode("A"); expect(snapshot.render(10).ok,"A mode renders all first-page character events")
	expect(state.map_id==map_before and not snapshot.render(999999).ok,"snapshot does not change live map and rejects missing map")
	var movie: Node=load("res://runtime/scripts/10_Support/Utilities/MoviePlayer.gd").new(); root.add_child(movie)
	expect(movie.resolve_path("../outside.ogv").is_empty() and movie.resolve_path("D:/outside.mp4").is_empty(),"video files stay in generated project resources")
	expect(not movie.play("missing.mp4").ok and movie.request_id==0,"missing original video fails without starting a request")
	expect(not movie.pause() and not movie.resume() and not movie.resize() and not movie.playing(),"video controls correctly report unopened state")
	movie.stop(); expect(movie.request_id==0,"video stop is idempotent")
	var generic=Scripts.new_object("Game_Object",["item",1,"Items.exdata","Data/"],state)
	expect(generic.ok and generic.value.fields.id==1 and generic.value.fields.setting.get("scope")==0,"generic file constructor reads bound migrated external data")
	var missing=Scripts.new_object("Game_Object",["item",1,"absent.exdata","Data/"],state)
	expect(missing.ok and missing.value.fields.name=="" and missing.value.fields.price==0,"generic file constructor preserves absent-file defaults")
	# Fatal case is covered in FailureIsolationProbe: unsafe-object
	var title=Scripts.call_transaction(state,{"source":"__TITLE"},func(env):return env.invoke(env.root_receiver(),"__TITLE",[]))
	expect(title.ok and title.value==str(ProjectSettings.get_setting("application/config/name")),"source title helper uses current Godot configuration")
	var window=Scripts.call_transaction(state,{"source":"WindowScaler"},func(env):return env.invoke(env._custom.named("WindowScaler"),"resize",[4]))
	expect(window.ok and window.value==3 and state.flash_preferences.window_resize==3,"window scaler normalizes original mode4 to engine fullscreen mode3")
	# Fatal case is covered in FailureIsolationProbe: window
	movie.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH PLUGIN TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
