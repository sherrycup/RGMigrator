extends RefCounted
## 0332 Train_Actor by fukuyama / XRXS13, retained from www.66RPG.com.
## RuntimeState owns motions and the five-element action history. Map sprites
## are disposable views; they never hold the party's movement truth.
const Motion=preload("CharacterMotion.gd")
const Character=preload("MapCharacter.gd")
const MAX_PARTY=4
const CAT_GRAPHIC="152-Animal02"
const DIAGONALS={1:Vector2i(-1,1),3:Vector2i(1,1),7:Vector2i(-1,-1),9:Vector2i(1,-1)}
var motions: Array=[]
var graphics: Array=[]
var move_list: Array=[]
var transparent_actors=false # Source setter exists but its value is not used.
var _owner: WeakRef
var _player: WeakRef
var _map: WeakRef
var _views: Array=[]
var _pending: Array=[]

func _init(owner: Node) -> void:
	_owner=weakref(owner); reset()

func reset() -> void:
	motions.clear(); graphics.clear(); _pending.clear()
	for i in MAX_PARTY:
		var motion=Motion.new(); motion.configure({"through":true})
		motions.append(motion); graphics.append({"id":0,"name":"","hue":0}); _pending.append([])
	move_list=[null,null,null,null,null]; transparent_actors=false
	# Existing views can survive execution reset while their map is being restored.
	for i in _views.size():
		var view: Node=_views[i].get_ref()
		if view!=null: view.motion=motions[i]

func bind(player: Node,map: Node) -> void:
	_player=weakref(player); _map=weakref(map)
	for reference in _views:
		var view: Node=reference.get_ref()
		if view!=null: view.queue_free()
	_views.clear()
	for i in MAX_PARTY:
		var view=Character.new(); view.motion=motions[i]; view.map_runtime=map
		view.character_id=-100-i; view.fallback_visible=false
		map.ensure_character_layer().add_child(view); view.set_process(false)
		map.character_layer.move_child(view,0); _views.append(weakref(view))
	moveto_party_actors(player.motion.cell.x,player.motion.cell.y)
	refresh()

func refresh() -> void:
	var state: Node=_owner.get_ref(); var player: Node=_player.get_ref() if _player!=null else null
	if state==null or player==null: return
	var roles: Array=state.custom_data.gameplay().role_actor_ids()
	for i in MAX_PARTY:
		var id=int(roles[1]) if i==0 and int(roles[1])>0 else int(state.party[i+1]) if i+1<mini(MAX_PARTY,state.party.size()) else 0
		var actor: RefCounted=state.actor(id) if id>0 else null
		graphics[i]={"id":id,"name":actor.character_name if actor!=null else "","hue":actor.character_hue if actor!=null else 0}
	var flag: Variant=state.variables.get("226",0)
	var cat=false
	if flag is Array: cat=flag.size()>51 and flag[51]==1
	elif flag is Dictionary: cat=flag.get("2:51",flag.get("51",flag.get(51,0)))==1
	if cat and not state.party.is_empty():
		for i in MAX_PARTY:
			if graphics[i].name.is_empty(): graphics[i]={"id":0,"name":CAT_GRAPHIC,"hue":state.actor(int(state.party[0])).character_hue}; break
	for i in MAX_PARTY:
		motions[i].configure({"through":true,"move_speed":player.move_speed,"step_anime":player.step_anime,"transparent":player.transparent,"opacity":0 if player._name.is_empty() else player.opacity,"blend_type":0})
		var view: Node=_views[i].get_ref() if i<_views.size() else null
		if view==null: continue
		if view._name!=graphics[i].name or view._hue!=graphics[i].hue: view.set_graphic(graphics[i].name,graphics[i].hue)
		_sync_view(view,player)

func advance(delta: float) -> void:
	refresh()
	var player: Node=_player.get_ref() if _player!=null else null
	for i in motions.size():
		motions[i].advance(delta)
		if motions[i].is_idle() and not _pending[i].is_empty(): _start(i,_pending[i].pop_front())
		var view: Node=_views[i].get_ref() if i<_views.size() else null
		if view!=null and player!=null: _sync_view(view,player)

func accept_action(type: int,args: Array=[]) -> void:
	# Source first applies the previous history, then prepends the new action.
	# Guard initial nil entries instead of dereferencing nil.type on the first step.
	for i in mini(motions.size(),move_list.size()):
		if move_list[i]==null: continue
		if motions[i].is_idle(): _start(i,move_list[i])
		else: _pending[i].append(move_list[i].duplicate(true))
	if not move_list.is_empty():
		move_list.push_front({"type":type,"args":args.duplicate(true)}); move_list.pop_back()

func moveto_party_actors(x: int,y: int) -> void:
	for i in motions.size(): motions[i].relocate(Vector2i(x,y)); _pending[i].clear()
	move_list=[null,null,null,null,null]

func delete_move() -> void: move_list.clear()
func set_transparent_actors(value: bool) -> void: transparent_actors=value
func get_characters_xy(index: int) -> Array:
	return [motions[index].target.x,motions[index].target.y] if index>=0 and index<MAX_PARTY else []
func set_characters(index: int,direction: int) -> void: motions[index].turn(direction,true)
func set_characters_xy(index: int,x: int,y: int) -> void: motions[index].relocate(Vector2i(x,y)); _pending[index].clear()
func snapshot() -> Dictionary:
	var rows: Array=[]
	for i in motions.size(): rows.append({"motion":motions[i].persistent_data(),"graphic":graphics[i].duplicate()})
	return {"characters":rows,"move_list":move_list.duplicate(true),"pending":_pending.duplicate(true),"transparent_actors":transparent_actors}

static func validate_snapshot(value: Variant) -> String:
	if not value is Dictionary or not value.get("characters") is Array or value.characters.size()!=MAX_PARTY or not value.get("move_list") is Array or value.move_list.size()>5 or not value.get("pending") is Array or value.pending.size()!=MAX_PARTY or not value.get("transparent_actors") is bool: return "跟随现场结构无效。"
	for row in value.characters:
		if not row is Dictionary or not row.get("graphic") is Dictionary or not row.graphic.get("name") is String or not row.graphic.get("hue") is int or not Motion.decode(row.get("motion"),100000,100000).ok: return "跟随人物记录无效。"
	var actions: Array=value.move_list.duplicate()
	for queue in value.pending:
		if not queue is Array or queue.size()>10000: return "跟随移动队列无效。"
		actions.append_array(queue)
	for action in actions:
		if action==null: continue
		if not action is Dictionary or action.get("type") not in [1,2,3,4,5,6,7,8,9] or not action.get("args") is Array: return "跟随动作无效。"
		if action.type==5 and (action.args.size()!=2 or not action.args[0] is int or not action.args[1] is int): return "跟随跳跃参数无效。"
	return ""

func restore_snapshot(value: Dictionary) -> void:
	for i in MAX_PARTY:
		motions[i]=Motion.decode(value.characters[i].motion,100000,100000).value
		graphics[i]=value.characters[i].graphic
		var view: Node=_views[i].get_ref() if i<_views.size() else null
		if view!=null: view.motion=motions[i]
	move_list=value.move_list; _pending=value.pending; transparent_actors=value.transparent_actors
	refresh()

func _start(index: int,action: Dictionary) -> void:
	var map: Node=_map.get_ref() if _map!=null else null
	if map==null: return
	var motion: RefCounted=motions[index]; var type=int(action.type); var args: Array=action.args
	if type==5:
		var offset=Vector2i(int(args[0]),int(args[1])); var destination=motion.cell+offset
		if map.valid(destination.x,destination.y): motion.begin_jump(offset)
	elif DIAGONALS.has(type):
		var offset: Vector2i=DIAGONALS[type]; var destination=motion.cell+offset
		if map.valid(destination.x,destination.y): motion.begin_diagonal(offset)
	elif Motion.DIRECTIONS.has(type):
		var destination=motion.cell+Motion.DIRECTIONS[type]
		if not map.valid(destination.x,destination.y): return
		motion.begin_move(type)
		if type in [4,6]:
			# Train_Actor explicitly reads layer 1, rather than the top terrain tag.
			var tile=map.tile_id(destination.x,destination.y,1)
			var tag=map._table_value(map.tileset.get("terrain_tags",{}),tile,0,0)
			if tag in [1,2]:
				destination.y+= (1 if tag==1 else -1)*(1 if type==4 else -1)
				if map.valid(destination.x,destination.y): motion.target=destination

func _sync_view(view: Node,player: Node) -> void:
	view._sync_position()
	# Same-cell followers sort behind the player without shifting their pixels.
	if view.motion.target==player.motion.target:
		view.position.y-=0.01
		if view._sprite!=null: view._sprite.position.y+=0.01
