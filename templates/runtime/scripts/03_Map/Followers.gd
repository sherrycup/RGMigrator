## 职责：管理闪翼跟随者的队列、位置与动作同步，并支持现场保存恢复。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/Followers.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/03_Map/Followers.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(owner: Node) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 owner（Node；必填）：持有此对象的调用方或运行状态。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func reset() -> void
##     用途：重置本服务持有的状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func bind(player: Node, map: Node) -> void
##     参数 player（Node；必填）：当前玩家人物实例。
##     参数 map（Node；必填）：当前接口使用的地图数据或地图对象。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func accept_action(type: int, args: Array = []) -> void
##     参数 type（int；必填）：当前操作的类型标识。
##     参数 args（Array；默认值 []）：按调用顺序排列的参数值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func moveto_party_actors(x: int, y: int) -> void
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func delete_move() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_transparent_actors(value: bool) -> void
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func get_characters_xy(index: int) -> Array
##     参数 index（int；必填）：集合或列表中的位置索引。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func set_characters(index: int, direction: int) -> void
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_characters_xy(index: int, x: int, y: int) -> void
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 x（int；必填）：横向坐标。
##     参数 y（int；必填）：纵向坐标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func validate_snapshot(value: Variant) -> String
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func restore_snapshot(value: Dictionary) -> void
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 公开常量：MAX_PARTY、CAT_GRAPHIC、DIAGONALS。
## 接口说明结束。

extends RefCounted
## 0332 Train_Actor by fukuyama / XRXS13, retained from www.66RPG.com.
## RuntimeState owns motions and the five-element action history. Map sprites
## are disposable views; they never hold the party's movement truth.
const Motion = preload("CharacterMotion.gd")
const Character = preload("MapCharacter.gd")
const MAX_PARTY = 4
const CAT_GRAPHIC = "152-Animal02"
const DIAGONALS = {1: Vector2i(-1, 1), 3: Vector2i(1, 1), 7: Vector2i(-1, -1), 9: Vector2i(1, -1)}
var motions: Array = []
var graphics: Array = []
var move_list: Array = []
var transparent_actors = false  # Source setter exists but its value is not used.
var _owner: WeakRef
var _player: WeakRef
var _map: WeakRef
var _views: Array = []
var _pending: Array = []


func _init(owner: Node) -> void:
	_owner = weakref(owner)
	reset()


func reset() -> void:
	motions.clear()
	graphics.clear()
	_pending.clear()
	for i in MAX_PARTY:
		var motion = Motion.new()
		motion.configure({"through": true})
		motions.append(motion)
		graphics.append({"id": 0, "name": "", "hue": 0})
		_pending.append([])
	move_list = [null, null, null, null, null]
	transparent_actors = false
	# Existing views can survive execution reset while their map is being restored.
	for i in _views.size():
		var view: Node = _views[i].get_ref()
		if view != null:
			view.motion = motions[i]


func bind(player: Node, map: Node) -> void:
	_player = weakref(player)
	_map = weakref(map)
	for reference in _views:
		var view: Node = reference.get_ref()
		if view != null:
			view.queue_free()
	_views.clear()
	for i in MAX_PARTY:
		var view = Character.new()
		view.motion = motions[i]
		view.map_runtime = map
		view.character_id = -100 - i
		view.fallback_visible = false
		map.ensure_character_layer().add_child(view)
		view.set_process(false)
		map.character_layer.move_child(view, 0)
		_views.append(weakref(view))
	moveto_party_actors(player.motion.cell.x, player.motion.cell.y)
	refresh()


func refresh() -> void:
	var state: Node = _owner.get_ref()
	var player: Node = _player.get_ref() if _player != null else null
	if state == null or player == null:
		return
	var roles: Array = state.custom_data.gameplay().role_actor_ids()
	for i in MAX_PARTY:
		var id = (
			int(roles[1])
			if i == 0 and int(roles[1]) > 0
			else int(state.party[i + 1]) if i + 1 < mini(MAX_PARTY, state.party.size()) else 0
		)
		var actor: RefCounted = state.actor(id) if id > 0 else null
		graphics[i] = {
			"id": id,
			"name": actor.character_name if actor != null else "",
			"hue": actor.character_hue if actor != null else 0
		}
	var flag: Variant = state.variables.get("226", 0)
	var cat = false
	if flag is Array:
		cat = flag.size() > 51 and flag[51] == 1
	elif flag is Dictionary:
		cat = flag.get("2:51", flag.get("51", flag.get(51, 0))) == 1
	if cat and not state.party.is_empty():
		for i in MAX_PARTY:
			if graphics[i].name.is_empty():
				graphics[i] = {
					"id": 0,
					"name": CAT_GRAPHIC,
					"hue": state.actor(int(state.party[0])).character_hue
				}
				break
	for i in MAX_PARTY:
		motions[i].configure(
			{
				"through": true,
				"move_speed": player.move_speed,
				"step_anime": player.step_anime,
				"transparent": player.transparent,
				"opacity": 0 if player._name.is_empty() else player.opacity,
				"blend_type": 0
			}
		)
		var view: Node = _views[i].get_ref() if i < _views.size() else null
		if view == null:
			continue
		if view._name != graphics[i].name or view._hue != graphics[i].hue:
			view.set_graphic(graphics[i].name, graphics[i].hue)
		_sync_view(view, player)


func advance(delta: float) -> void:
	refresh()
	var player: Node = _player.get_ref() if _player != null else null
	for i in motions.size():
		motions[i].advance(delta)
		if motions[i].is_idle() and not _pending[i].is_empty():
			_start(i, _pending[i].pop_front())
		var view: Node = _views[i].get_ref() if i < _views.size() else null
		if view != null and player != null:
			_sync_view(view, player)


func accept_action(type: int, args: Array = []) -> void:
	# Source first applies the previous history, then prepends the new action.
	# Guard initial nil entries instead of dereferencing nil.type on the first step.
	for i in mini(motions.size(), move_list.size()):
		if move_list[i] == null:
			continue
		if motions[i].is_idle():
			_start(i, move_list[i])
		else:
			_pending[i].append(move_list[i].duplicate(true))
	if not move_list.is_empty():
		move_list.push_front({"type": type, "args": args.duplicate(true)})
		move_list.pop_back()


func moveto_party_actors(x: int, y: int) -> void:
	for i in motions.size():
		motions[i].relocate(Vector2i(x, y))
		_pending[i].clear()
	move_list = [null, null, null, null, null]


func delete_move() -> void:
	move_list.clear()


func set_transparent_actors(value: bool) -> void:
	transparent_actors = value


func get_characters_xy(index: int) -> Array:
	return (
		[motions[index].target.x, motions[index].target.y]
		if index >= 0 and index < MAX_PARTY
		else []
	)


func set_characters(index: int, direction: int) -> void:
	motions[index].turn(direction, true)


func set_characters_xy(index: int, x: int, y: int) -> void:
	motions[index].relocate(Vector2i(x, y))
	_pending[index].clear()


func snapshot() -> Dictionary:
	var rows: Array = []
	for i in motions.size():
		rows.append({"motion": motions[i].persistent_data(), "graphic": graphics[i].duplicate()})
	return {
		"characters": rows,
		"move_list": move_list.duplicate(true),
		"pending": _pending.duplicate(true),
		"transparent_actors": transparent_actors
	}


static func validate_snapshot(value: Variant) -> String:
	if (
		not value is Dictionary
		or not value.get("characters") is Array
		or value.characters.size() != MAX_PARTY
		or not value.get("move_list") is Array
		or value.move_list.size() > 5
		or not value.get("pending") is Array
		or value.pending.size() != MAX_PARTY
		or not value.get("transparent_actors") is bool
	):
		return "跟随现场结构无效。"
	for row in value.characters:
		if (
			not row is Dictionary
			or not row.get("graphic") is Dictionary
			or not row.graphic.get("name") is String
			or not row.graphic.get("hue") is int
			or not Motion.decode(row.get("motion"), 100000, 100000).ok
		):
			return "跟随人物记录无效。"
	var actions: Array = value.move_list.duplicate()
	for queue in value.pending:
		if not queue is Array or queue.size() > 10000:
			return "跟随移动队列无效。"
		actions.append_array(queue)
	for action in actions:
		if action == null:
			continue
		if (
			not action is Dictionary
			or action.get("type") not in [1, 2, 3, 4, 5, 6, 7, 8, 9]
			or not action.get("args") is Array
		):
			return "跟随动作无效。"
		if (
			action.type == 5
			and (action.args.size() != 2 or not action.args[0] is int or not action.args[1] is int)
		):
			return "跟随跳跃参数无效。"
	return ""


func restore_snapshot(value: Dictionary) -> void:
	for i in MAX_PARTY:
		motions[i] = Motion.decode(value.characters[i].motion, 100000, 100000).value
		graphics[i] = value.characters[i].graphic
		var view: Node = _views[i].get_ref() if i < _views.size() else null
		if view != null:
			view.motion = motions[i]
	move_list = value.move_list
	_pending = value.pending
	transparent_actors = value.transparent_actors
	refresh()


func _start(index: int, action: Dictionary) -> void:
	var map: Node = _map.get_ref() if _map != null else null
	if map == null:
		return
	var motion: RefCounted = motions[index]
	var type = int(action.type)
	var args: Array = action.args
	if type == 5:
		var offset = Vector2i(int(args[0]), int(args[1]))
		var destination = motion.cell + offset
		if map.valid(destination.x, destination.y):
			motion.begin_jump(offset)
	elif DIAGONALS.has(type):
		var offset: Vector2i = DIAGONALS[type]
		var destination = motion.cell + offset
		if map.valid(destination.x, destination.y):
			motion.begin_diagonal(offset)
	elif Motion.DIRECTIONS.has(type):
		var destination = motion.cell + Motion.DIRECTIONS[type]
		if not map.valid(destination.x, destination.y):
			return
		motion.begin_move(type)
		if type in [4, 6]:
			# Train_Actor explicitly reads layer 1, rather than the top terrain tag.
			var tile = map.tile_id(destination.x, destination.y, 1)
			var tag = map._table_value(map.tileset.get("terrain_tags", {}), tile, 0, 0)
			if tag in [1, 2]:
				destination.y += (1 if tag == 1 else -1) * (1 if type == 4 else -1)
				if map.valid(destination.x, destination.y):
					motion.target = destination


func _sync_view(view: Node, player: Node) -> void:
	view._sync_position()
	# Same-cell followers sort behind the player without shifting their pixels.
	if view.motion.target == player.motion.target:
		view.position.y -= 0.01
		if view._sprite != null:
			view._sprite.position.y += 0.01
