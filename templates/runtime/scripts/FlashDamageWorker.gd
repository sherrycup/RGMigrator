extends RefCounted
## One sleeping worker per map view. Mailboxes contain detached values only;
## newer requests replace queued work and cancel obsolete batches between enemies.
const Simulator=preload("FlashBattleSimulator.gd")
var _thread: Thread
var _mutex=Mutex.new()
var _wake=Semaphore.new()
var _mailbox={"request":{},"result":{},"revision":0,"stop":false}

func request(job: Dictionary) -> Error:
	if _thread==null:
		_thread=Thread.new()
		var error=_thread.start(_run.bind(_mailbox,_mutex,_wake))
		if error!=OK: _thread=null; return error
	_mutex.lock()
	var notify_worker=_mailbox.request.is_empty()
	_mailbox.request=job; _mailbox.revision=job.revision; _mailbox.result={}
	_mutex.unlock()
	if notify_worker: _wake.post()
	return OK

func take() -> Dictionary:
	_mutex.lock(); var result: Dictionary=_mailbox.result; _mailbox.result={}; _mutex.unlock()
	return result

func stop() -> void:
	if _thread==null: return
	_mutex.lock(); _mailbox.stop=true; _mailbox.request={}; _mailbox.result={}; _mutex.unlock()
	_wake.post(); _thread.wait_to_finish(); _thread=null

static func _run(mailbox: Dictionary,mutex: Mutex,wake: Semaphore) -> void:
	var simulator=Simulator.new(); var cached: Dictionary={}; var previous: Dictionary={}
	while true:
		wake.wait(); mutex.lock()
		var stopping: bool=mailbox.stop; var job: Dictionary=mailbox.request; mailbox.request={}
		mutex.unlock()
		if stopping: return
		if job.is_empty(): continue
		var started=Time.get_ticks_usec(); var rows: Array=[]; var next_cache: Dictionary={}; var failure=""; var simulations=0
		var reuse=not previous.is_empty() and previous.party==job.party and previous.skills==job.skills and previous.constants==job.constants and previous.catalog_failure==job.catalog_failure and previous.map_id==job.map_id
		simulator.skills=job.skills; simulator.constants=job.constants; simulator.catalog_failure=job.catalog_failure
		for enemy in job.enemies:
			mutex.lock(); var obsolete: bool=mailbox.stop or mailbox.revision!=job.revision; mutex.unlock()
			if obsolete: break
			var key: int=enemy.event_id; var checked: Dictionary
			if enemy.pending!=null: checked={"ok":true,"result":enemy.pending}
			elif reuse and cached.has(key) and cached[key].input==enemy.input and cached[key].pending==null: checked=cached[key].checked
			else:
				checked=simulator.predict(job.party[0],job.party[1],enemy.input); simulations+=1
			if not checked.ok: failure=checked.message; break
			next_cache[key]={"input":enemy.input,"pending":enemy.pending,"checked":checked}
			rows.append({"event_id":key,"damage":int(checked.result.damage),"patience":int(enemy.input.patience)})
		cached=next_cache; previous=job
		var result={"revision":job.revision,"generation":job.generation,"map_id":job.map_id,"hp":job.hp,"rows":rows,"failure":failure,"simulations":simulations,"elapsed_us":Time.get_ticks_usec()-started,"thread_id":OS.get_thread_caller_id()}
		mutex.lock()
		if not mailbox.stop and mailbox.revision==job.revision: mailbox.result=result
		mutex.unlock()
