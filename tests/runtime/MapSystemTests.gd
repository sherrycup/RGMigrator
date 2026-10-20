## 职责：回归验证：验证闪翼地图区块、光标、发现和页面状态。
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
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Config=preload("res://runtime/scripts/08_Menu/MapSystem/MapConfig.gd")
const Block=preload("res://runtime/scripts/08_Menu/MapSystem/MapBlock.gd")
const Cursor=preload("res://runtime/scripts/08_Menu/MapSystem/MapCursor.gd")
const System=preload("res://runtime/scripts/08_Menu/MapSystem/MapSystem.gd")
const Tiles=preload("res://runtime/scripts/03_Map/Tilemap.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.variables["14"]=[2,0]; state.map_id=1
	var old_maps=Config.MAPS.duplicate(true); var old_directions=Config.DIRECTIONS.duplicate(true)
	for id in [1,4,5,6,7,8]: Config.MAPS[id]={"area":1}
	Config.MAPS[10]={"area":2}
	expect(Config.cell_count(20,18)==1 and Config.cell_count(38,18)==2 and Config.cell_count(39,18)==3 and Config.cell_count(28,13)==2,"original interior cell-count formula excludes two border tiles")
	expect(Tiles.parts(14)==[27,28,11,12] and Tiles.parts(47)==[1,2,7,8] and Tiles.ANIMATION_SECONDS==1.0/3.0,"Flash preserves its actual custom autotile variants and twenty-frame-at-sixty-Hz animation")
	var geometry=Block.new(1,39,28,1)
	expect(geometry.width==3 and geometry.height==2 and geometry.cell_at(0,0)==[0,0] and geometry.cell_at(19,14)==[1,1] and geometry.cell_at(999,999)==[2,1],"original cells use x-1/y-1 and clamp at map-block edges")
	geometry.set_position([-3,4]); expect(geometry.center()==[-1.5,5.0],"block center retains fractional coordinates")
	var world=state.custom_data.map_system(); var first=world.discover_map(1,20,15)
	expect(first.position()==[0,0] and world.discover_map(1,99,99)==first and first.tile_width==20,"discovery preserves one block identity and original dimensions")
	expect(world.area_unlock(1) and not world.area_unlock(2) and world.connections().is_empty(),"area unlock derives only from actual discovered blocks")
	var from={"id":1,"x":19,"y":7,"width":20,"height":15,"facing":6}
	var to={"id":4,"x":0,"y":7,"width":20,"height":15,"facing":6}
	var target=world.record_transfer(from,to)
	expect(target.position()==[1,0] and world.connected(1,4) and world.connected(4,1),"observed right-edge transfer aligns a new map block and records bidirectional connectivity")
	expect(world.bridge(world.connections()[0])==[[0,0],[1,0]],"connector joins only touching blocks from the observed transfer")
	world.record_transfer(from,to); expect(world.connections().size()==1,"same observed endpoint tuple does not duplicate a connection")
	world.discover_map(5,20,15,[2,0]); expect(not world.connected(4,5) and world.connections().size()==1,"geometric adjacency alone never invents a connection")
	var overlap=world.discover_map(6,20,15,[0,0])
	expect(overlap.position()==[5,0] and world.layout_notes()[0]==["overlap",6,[0,0]],"source overlap is logged and relocated to rightmost edge plus two cells")
	Config.MAPS[7].position=[7,0]
	expect(world.discover_map(7,20,15,[9,0]).position()==[7,0],"explicit source metadata position takes precedence over proposed transfer layout")
	Config.MAPS[8].position=null
	expect(world.discover_map(8,20,15,[9,0]).position()==[9,0],"nil metadata falls through to the actual supplied position")
	var cross=world.record_transfer(to,{"id":10,"x":0,"y":0,"width":20,"height":20,"facing":2})
	expect(cross.area==2 and cross.position()==[0,0] and world.bridge(world.connections()[-1])==null,"cross-area observed transfer records an unbridged link without geometric alignment")
	Config.DIRECTIONS[[1,4]]=8
	expect(world.departure_side(from,to)==8 and world.departure_side(to,from)==2,"configured departure and reversed departure override edge guessing")
	Config.DIRECTIONS[[1,4]]=0
	expect(world.departure_side(from,to)==0 and world.departure_side(to,from)==0,"portal zero remains a valid Ruby override rather than a false value")
	Config.DIRECTIONS.clear()
	var portal_from=from.duplicate(); portal_from.x=10; portal_from.y=7
	var portal_to=to.duplicate(); portal_to.x=10; portal_to.y=7
	expect(world.departure_side(portal_from,portal_to)==0,"interior transfer without metadata keeps source portal classification")
	expect(world.nearest_map(1,1.0,0.5).id==1,"equal rectangle and center distances break ties by original map ID")
	var cursor=Cursor.new(world,first); expect(cursor.locked and cursor.rect()==Rect2(0,0,1,1),"cursor initially locks to the current discovered map rectangle")
	for i in 8: cursor.update(1,0)
	expect(not cursor.locked and cursor.x==1.5 and cursor.rect()==Rect2(1,0,1,1),"source cursor advances one eighth cell per source tick")
	for i in 5: cursor.update(0,0)
	expect(not cursor.locked,"cursor waits the full original six idle ticks before snapping")
	expect(cursor.update(0,0)=="lock" and cursor.selected.id==4,"sixth idle tick selects the nearest discovered block")
	cursor.change_area(1); expect(cursor.area==2 and cursor.selected.id==10,"source area cycling selects the lowest ID in the next unlocked area")
	cursor.change_area(1); expect(cursor.area==1 and cursor.selected.id==1,"area cycling wraps in sorted area order")
	var snapshot=state.custom_data.snapshot()
	expect(System.validate(snapshot.map_system).is_empty(),"complete plain discovery state validates before persistence")
	var before=first.position()
	var transaction=Scripts.call_transaction(state,{"kind":"map-proxy-test"},func(env):
		env._custom.map_system().block(1).set_position([-2,-3]); return true)
	expect(transaction.ok and first.position()==[-2,-3],"existing UI block proxy reads the new shared record after script transaction commit")
	var saved=state.custom_data.snapshot(); var restored=state.custom_data.restore(JSON.parse_string(JSON.stringify(saved)))
	expect(restored.ok and first.position()==[-2,-3] and world.connected(1,4),"plain map state restores while block proxies continue reading the installed records")
	var bad=saved.duplicate(true); bad.map_system.blocks["1"].width=99
	expect(not state.custom_data.restore(bad).ok and first.position()==[-2,-3],"invalid derived dimensions reject restore before any live mutation")
	bad=saved.duplicate(true); bad.map_system.connections.values()[0].to.id=99999
	expect(not state.custom_data.restore(bad).ok and world.connected(1,4),"missing connection target rejects the full map snapshot")
	var old=saved.duplicate(true); old.erase("map_system")
	expect(state.custom_data.restore(old).ok and state.custom_data.map_system().state().blocks.is_empty(),"previous migrator saves acquire an empty discovery component instead of failing schema checks")
	Config.MAPS=old_maps; Config.DIRECTIONS=old_directions
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MAP SYSTEM: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
