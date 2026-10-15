extends RefCounted
## Source 0320: variable 25, 100 rotating event-before snapshots, one record per frame.
const Codec=preload("SaveCodec.gd")
const Store=preload("FlashFileStore.gd")
const CAPACITY=100
const PREPARATION_BUDGET_USEC=6000
signal checkpoint_prepared(request_id: int,result: Dictionary)
var _owner: WeakRef
var _last_frame=-1
var _busy=false
var _writer: Thread
var _writing: Dictionary={}
var _jobs: Array=[]
var _pending_snapshots: Dictionary={}
var _revision=0
var _validators: Array[Thread]=[]

func _init(owner: Node) -> void: _owner=weakref(owner)

func eligible(name: String) -> bool:
	var state: Node=_owner.get_ref()
	if name.contains("怪物"): return true
	var matcher=RegEx.new(); matcher.compile("^门([0-9]+)")
	var found=matcher.search(name)
	if found==null: return false
	var id=int(found.get_string(1)); var count=1
	if name.contains(":"): count=int(name.get_slice(":",1))
	return id in [1,2,3] and state.inventory_count("item",id)>=count

func path_for(serial: int) -> String:
	return preload("SaveService.gd").directory().path_join("auto_history/record%03d.json" % posmod(serial,CAPACITY))

func record(force: bool=false) -> Dictionary:
	var state: Node=_owner.get_ref(); var frame=Engine.get_process_frames()
	if _busy or state==null or not state.playing or state.save_disabled: return {"ok":false,"message":"当前禁止自动记录。"}
	if not force and frame==_last_frame: return {"ok":true,"skipped":true}
	flush_pending()
	if not state.player_motion.is_idle(): return {"ok":false,"message":"人物移动尚未完成，不能记录事件前快照。"}
	var serial: Variant=state.variables.get("25",0)
	if not serial is int or serial<0 or serial>=Codec.MAX_INTEGER or state.save_count>=Codec.MAX_INTEGER: return {"ok":false,"message":"撤回进度编号或存档次数无效。"}
	var game: Node=state.game()
	if game!=null and not game.event_save_reason().is_empty(): return {"ok":false,"message":game.event_save_reason()}
	_busy=true
	var snapshot=Codec.capture(state); snapshot.save_count=state.save_count+1
	var checked=Codec.prepare(snapshot,state.custom_data,true)
	if not checked.ok: _busy=false; return checked
	var result=Store.write(path_for(serial+1),"undo",{"serial":serial+1,"fingerprint":preload("SaveService.gd").fingerprint(),"snapshot":snapshot})
	if result.ok:
		state.save_count=snapshot.save_count; state.set_event_variable(25,serial+1); _last_frame=frame
	_busy=false
	return result

func record_async(force: bool=false) -> Dictionary:
	poll()
	var state: Node=_owner.get_ref(); var frame=Engine.get_process_frames()
	if _busy or state==null or not state.playing or state.save_disabled: return {"ok":false,"message":"当前禁止自动记录。"}
	if not force and frame==_last_frame: return {"ok":true,"skipped":true}
	if not state.player_motion.is_idle(): return {"ok":false,"message":"人物移动尚未完成，不能记录事件前快照。"}
	if _jobs.size()>=CAPACITY: return {"ok":false,"message":"自动记录写入队列已满。"}
	var serial: Variant=state.variables.get("25",0)
	if not serial is int or serial<0 or serial>=Codec.MAX_INTEGER or state.save_count>=Codec.MAX_INTEGER: return {"ok":false,"message":"撤回进度编号或存档次数无效。"}
	var game: Node=state.game()
	if game!=null and not game.event_save_reason().is_empty(): return {"ok":false,"message":game.event_save_reason()}
	_busy=true
	# Capture and validate on the main thread; the worker only reads detached data.
	var snapshot=Codec.capture(state); snapshot.save_count=state.save_count+1
	var checked=Codec.prepare(snapshot,state.custom_data,true)
	if not checked.ok: _busy=false; return checked
	var row={"serial":serial+1,"fingerprint":preload("SaveService.gd").fingerprint(),"snapshot":snapshot}
	_jobs.append({"path":path_for(serial+1),"row":row})
	_pending_snapshots[serial+1]=row
	for key in _pending_snapshots.keys():
		if int(key)<=serial+1-CAPACITY: _pending_snapshots.erase(key)
	state.save_count=snapshot.save_count; state.set_event_variable(25,serial+1); _last_frame=frame
	_busy=false; poll()
	return {"ok":true,"pending":true,"serial":serial+1}

func prepare_record(request_id: int) -> void:
	var state: Node=_owner.get_ref(); var revision=_revision
	if _busy or state==null or not state.playing or state.save_disabled:
		checkpoint_prepared.emit(request_id,{"ok":false,"message":"当前禁止自动记录。"}); return
	if _jobs.size()>=CAPACITY:
		checkpoint_prepared.emit(request_id,{"ok":false,"message":"自动记录写入队列已满。"}); return
	var serial: Variant=state.variables.get("25",0)
	if not serial is int or serial<0 or serial>=Codec.MAX_INTEGER or state.save_count>=Codec.MAX_INTEGER:
		checkpoint_prepared.emit(request_id,{"ok":false,"message":"撤回进度编号或存档次数无效。"}); return
	var game: Node=state.game()
	if not state.player_motion.is_idle() or game==null or not game.event_save_reason(true).is_empty():
		checkpoint_prepared.emit(request_id,{"ok":false,"message":"当前现场不能记录事件前快照。"}); return
	_busy=true
	var expected_game=weakref(game); var generation=game.event_map().generation
	var clock=[Time.get_ticks_usec()+PREPARATION_BUDGET_USEC]
	var snapshot=Codec.capture(state); snapshot.save_count=state.save_count+1
	var pulse=Callable(self,"_validation_pulse").bind(revision,expected_game,generation,request_id,clock)
	var graph_check=Callable(self,"_validation_graph").bind(revision,expected_game,generation,request_id,clock)
	var checked=await preload("SavePreparation.gd").prepare_cooperatively(snapshot,state.custom_data,true,pulse,graph_check)
	if revision!=_revision:
		checkpoint_prepared.emit(request_id,{"ok":false,"cancelled":true,"message":"事件前记录已取消。"}); return
	_busy=false
	if not _validation_current(revision,expected_game,generation,request_id):
		checkpoint_prepared.emit(request_id,{"ok":false,"cancelled":true,"message":"事件前记录已取消。"}); return
	if not checked.ok: checkpoint_prepared.emit(request_id,checked); return
	var row={"serial":serial+1,"fingerprint":preload("SaveService.gd").fingerprint(),"snapshot":snapshot}
	_jobs.append({"path":path_for(serial+1),"row":row}); _pending_snapshots[serial+1]=row
	for key in _pending_snapshots.keys():
		if int(key)<=serial+1-CAPACITY: _pending_snapshots.erase(key)
	state.save_count=snapshot.save_count; state.set_event_variable(25,serial+1); _last_frame=Engine.get_process_frames()
	poll(); checkpoint_prepared.emit(request_id,{"ok":true,"pending":true,"serial":serial+1})

func _validation_current(revision: int,expected_game: WeakRef,generation: int,request_id: int) -> bool:
	var state: Node=_owner.get_ref(); var game: Node=expected_game.get_ref()
	return revision==_revision and state!=null and state.playing and game!=null and state.game()==game and game.event_map().generation==generation and game._event_checkpoint.get("request")==request_id

func _validation_pulse(revision: int,expected_game: WeakRef,generation: int,request_id: int,clock: Array) -> bool:
	# Native scene ownership cannot change between two synchronous validation
	# steps on this thread. Check the full owner/token at actual frame edges,
	# rather than walking the scene tree twice for every scalar or container.
	if revision!=_revision: return false
	if Time.get_ticks_usec()<clock[0]: return true
	if not _validation_current(revision,expected_game,generation,request_id): return false
	await _owner.get_ref().get_tree().process_frame
	if not _validation_current(revision,expected_game,generation,request_id): return false
	clock[0]=Time.get_ticks_usec()+PREPARATION_BUDGET_USEC
	return true

func _validation_graph(snapshot: Variant,classes: Variant,revision: int,expected_game: WeakRef,generation: int,request_id: int,clock: Array) -> String:
	# This worker receives only the owned snapshot and its class dictionary. It
	# never calls RuntimeData, loads resources, restores actors or touches Nodes.
	var tree=_owner.get_ref().get_tree()
	while not _validators.is_empty():
		if not _validation_current(revision,expected_game,generation,request_id): return "事件前记录已取消。"
		await tree.process_frame
	if not _validation_current(revision,expected_game,generation,request_id): return "事件前记录已取消。"
	var worker=Thread.new()
	if worker.start(_check_graph.bind(snapshot,classes))!=OK:
		return await preload("SaveGraph.gd").reason_cooperatively(snapshot,Callable(self,"_validation_pulse").bind(revision,expected_game,generation,request_id,clock),classes)
	_validators.append(worker)
	while worker.is_started() and worker.is_alive(): await tree.process_frame
	var reason: String=worker.wait_to_finish() if worker.is_started() else "事件前记录已取消。"
	_validators.erase(worker)
	if not _validation_current(revision,expected_game,generation,request_id): return "事件前记录已取消。"
	clock[0]=Time.get_ticks_usec()+PREPARATION_BUDGET_USEC
	return reason

static func _check_graph(snapshot: Variant,classes: Variant) -> String:
	return preload("SaveGraph.gd").reason(snapshot,classes)

static func _write_job(job: Dictionary) -> Dictionary:
	return Store.write(job.path,"undo",job.row)

func poll() -> void:
	if _writer!=null and not _writer.is_alive():
		var result: Dictionary=_writer.wait_to_finish(); _writer=null
		_complete_write(result)
	if _writer==null and not _jobs.is_empty():
		_writing=_jobs.pop_front(); _writer=Thread.new()
		var error=_writer.start(Callable(get_script(),"_write_job").bind(_writing))
		if error!=OK:
			_writer=null
			var result=_write_job(_writing)
			var serial=int(_writing.row.serial)
			if result.ok and is_same(_pending_snapshots.get(serial),_writing.row): _pending_snapshots.erase(serial)
			elif not result.ok and _owner.get_ref()!=null: _owner.get_ref().report_diagnostic("事件前记录写入失败："+result.message)
			_writing={}

func flush_pending() -> void:
	for worker in _validators:
		if worker.is_started(): worker.wait_to_finish()
	_validators.clear()
	while _writer!=null or not _jobs.is_empty():
		if _writer!=null:
			var result: Dictionary=_writer.wait_to_finish(); _writer=null; _complete_write(result)
		# Finish remaining jobs synchronously during explicit saves/shutdown only.
		if not _jobs.is_empty():
			_writing=_jobs.pop_front(); _complete_write(_write_job(_writing))

func reset() -> void:
	cancel_preparation()
	flush_pending(); _pending_snapshots.clear(); _last_frame=-1

func cancel_preparation() -> void:
	_revision+=1; _busy=false

func _complete_write(result: Dictionary) -> void:
	var serial=int(_writing.row.serial)
	if result.ok:
		if is_same(_pending_snapshots.get(serial),_writing.row): _pending_snapshots.erase(serial)
	else:
		var state: Node=_owner.get_ref()
		if state!=null: state.report_diagnostic("事件前记录写入失败（%d）：%s；当前会话仍可撤回。" % [serial,result.message])
	_writing={}

func undo() -> Dictionary:
	poll()
	var state: Node=_owner.get_ref()
	if _busy or state==null or not state.playing or not state.player_motion.is_idle(): return {"ok":false,"message":"当前不能撤回。"}
	var serial: Variant=state.variables.get("25",0)
	if not serial is int or serial<1: return {"ok":false,"message":"没有可撤回的记录。"}
	var result={"ok":true,"value":_pending_snapshots[serial],"recovered":false} if _pending_snapshots.has(serial) else Store.read(path_for(serial),"undo")
	if not result.ok: return result
	var row: Variant=result.value
	if not row is Dictionary or row.get("serial")!=serial or row.get("fingerprint")!=preload("SaveService.gd").fingerprint() or not row.get("snapshot") is Dictionary or serial-row.snapshot.get("variables",{}).get("25",0)!=1: return {"ok":false,"message":"撤回记录与当前进度不连续或工程数据已改变。"}
	var prepared=Codec.prepare(row.snapshot)
	if not prepared.ok: return prepared
	_busy=true; state.restore_prepared(prepared); _last_frame=Engine.get_process_frames(); _busy=false
	_jobs=_jobs.filter(func(job):return int(job.row.serial)<=serial-1)
	for key in _pending_snapshots.keys():
		if int(key)>serial-1: _pending_snapshots.erase(key)
	return {"ok":true,"serial":serial-1,"recovered":result.get("recovered",false)}
