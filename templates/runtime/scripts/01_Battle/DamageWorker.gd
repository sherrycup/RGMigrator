## 职责：以独立工作线程计算脱离现场的地图显伤请求，通过邮箱发布带版本的结果。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/01_Battle/DamageWorker.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func request(job: Dictionary) -> Error
##     参数 job（Dictionary；必填）：已经脱离运行现场的后台任务数据。
##     返回：Error 类型的对象或值，供调用方继续使用。
##
##   func take() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func stop() -> void
##     用途：停止当前播放、动作或服务。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
## One sleeping worker per map view. Mailboxes contain detached values only;
## newer requests replace queued work and cancel obsolete batches between enemies.
const Simulator = preload("BattleSimulator.gd")
var _thread: Thread
var _mutex = Mutex.new()
var _wake = Semaphore.new()
var _mailbox = {"request": {}, "result": {}, "revision": 0, "stop": false}


func request(job: Dictionary) -> Error:
	if _thread == null:
		_thread = Thread.new()
		var error = _thread.start(_run.bind(_mailbox, _mutex, _wake))
		if error != OK:
			_thread = null
			return error
	_mutex.lock()
	var notify_worker = _mailbox.request.is_empty()
	_mailbox.request = job
	_mailbox.revision = job.revision
	_mailbox.result = {}
	_mutex.unlock()
	if notify_worker:
		_wake.post()
	return OK


func take() -> Dictionary:
	_mutex.lock()
	var result: Dictionary = _mailbox.result
	_mailbox.result = {}
	_mutex.unlock()
	return result


func stop() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_mailbox.stop = true
	_mailbox.request = {}
	_mailbox.result = {}
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()
	_thread = null


static func _run(mailbox: Dictionary, mutex: Mutex, wake: Semaphore) -> void:
	var simulator = Simulator.new()
	var cached: Dictionary = {}
	var previous: Dictionary = {}
	while true:
		wake.wait()
		mutex.lock()
		var stopping: bool = mailbox.stop
		var job: Dictionary = mailbox.request
		mailbox.request = {}
		mutex.unlock()
		if stopping:
			return
		if job.is_empty():
			continue
		var started = Time.get_ticks_usec()
		var rows: Array = []
		var next_cache: Dictionary = {}
		var failure = ""
		var simulations = 0
		var reuse = (
			not previous.is_empty()
			and previous.party == job.party
			and previous.skills == job.skills
			and previous.constants == job.constants
			and previous.catalog_failure == job.catalog_failure
			and previous.map_id == job.map_id
		)
		simulator.skills = job.skills
		simulator.constants = job.constants
		simulator.catalog_failure = job.catalog_failure
		for enemy in job.enemies:
			mutex.lock()
			var obsolete: bool = mailbox.stop or mailbox.revision != job.revision
			mutex.unlock()
			if obsolete:
				break
			var key: int = enemy.event_id
			var checked: Dictionary
			if enemy.pending != null:
				checked = {"ok": true, "result": enemy.pending}
			elif (
				reuse
				and cached.has(key)
				and cached[key].input == enemy.input
				and cached[key].pending == null
			):
				checked = cached[key].checked
			else:
				checked = simulator.predict(job.party[0], job.party[1], enemy.input)
				simulations += 1
			if not checked.ok:
				failure = checked.message
				break
			next_cache[key] = {"input": enemy.input, "pending": enemy.pending, "checked": checked}
			rows.append(
				{
					"event_id": key,
					"damage": int(checked.result.damage),
					"patience": int(enemy.input.patience)
				}
			)
		cached = next_cache
		previous = job
		var result = {
			"revision": job.revision,
			"generation": job.generation,
			"map_id": job.map_id,
			"hp": job.hp,
			"rows": rows,
			"failure": failure,
			"simulations": simulations,
			"elapsed_us": Time.get_ticks_usec() - started,
			"thread_id": OS.get_thread_caller_id()
		}
		mutex.lock()
		if not mailbox.stop and mailbox.revision == job.revision:
			mailbox.result = result
		mutex.unlock()
