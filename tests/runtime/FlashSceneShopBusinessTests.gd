extends SceneTree
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Actions=preload("res://runtime/scripts/FlashActions.gd")
const Shop=preload("res://runtime/scripts/ShopService.gd")
const Decimal=preload("res://runtime/scripts/DecimalInteger.gd")
class Host extends Node:
	var map: Node
	func event_map() -> Node: return map
class NativeCurrency extends RefCounted:
	var manifest={"profile":"native"}
	var owner: WeakRef
	func valid_currency(value: Variant,key: String="gold") -> bool: return key=="gold" and not Decimal.normalize(value).is_empty() and Decimal.compare(value,0)>=0 and Decimal.compare(value,9999999)<=0
	func currency_maximum(_key: String="gold") -> int: return 9999999
	func gain_currency(key: String,amount: Variant) -> Dictionary:
		if key!="gold": return {"ok":false,"message":"invalid test currency"}
		owner.get_ref().gold=Decimal.clamped_add(owner.get_ref().gold,amount,9999999)
		return {"ok":true}
class NativeState extends Node:
	signal state_changed
	var inventory: Dictionary={}
	var gold: Variant=100
	var custom_data: RefCounted
var checks=0
var failures: Array[String]=[]
var notifications=0
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2,3]; state.variables["14"]=[2,3]; state.variables["3"]=1; state.variables["18"]=[[],[2,4,4]]
	state.variables["12"]=9; state.variables["13"]="old"; state.map_id=10
	for id in state.party:
		var actor=state.actor(id); actor.set_project_parameter("maxhp",100); actor.hp=100
		actor.set_project_parameter("agi",10); actor.set_project_parameter("patk",20); actor.set_project_parameter("pdef",5)
	var motion_before=JSON.stringify([state.map_id,state.player_x,state.player_y,state.party,state.variables["14"],state.custom_data.values.system.main_actor_index])
	var selected=Actions.choose_floor(state,4)
	expect(selected.ok and state.variables["13"]==4 and motion_before==JSON.stringify([state.map_id,state.player_x,state.player_y,state.party,state.variables["14"],state.custom_data.values.system.main_actor_index]),"0254 selection writes only original variable13 and does not invent a transfer")
	# Fatal case is covered in FlashFailureIsolationProbe: floor
	expect(Actions.cancel_floor(state).ok and state.variables["13"]=="stop","0254 cancel retains its original stop sentinel")
	selected=Actions.choose_character(state,2)
	expect(selected.ok and state.variables["12"]==1 and state.party==[2,3] and state.variables["14"]==[2,3] and state.custom_data.values.system.main_actor_index==0,"0255 selection writes actor.id-1 without changing party roles or current actor")
	expect(Actions.cancel_character(state).ok and state.variables["12"]==2,"0255 cancel writes actual PartyRoles.main_id, preserving the source asymmetry with selection")
	state.inventory={"item:2":1}; state.gold=100; state.flash_temp_fields.shop_type=0; state.flash_temp_fields.unblocking_text="old notice"
	state.custom_data.values.records["Items:2"]={"price":3}
	state.state_changed.connect(func():notifications+=1)
	var bought=Shop.buy(state,[[0,2]],"item",2,3)
	expect(bought.ok and state.gold==91 and state.inventory["item:2"]==4 and notifications==1,"Flash purchase commits payment, quantity and one notification through shared ScriptRuntime transaction")
	expect(str(state.flash_temp_fields.unblocking_text).contains("获得 "+str(Data.record("Items",2).name)+" x 3"),"Flash purchase retains source gain_item acquisition text rather than bypassing its hook")
	var before=JSON.stringify([state.gold,state.inventory,state.flash_temp_fields]); var signal_count=notifications
	# Invalid transaction is covered in an isolated fatal process: shop-quantity.
	state.custom_data.values.records["Items:2"].price=1
	var sell_quote=Shop.quote_sell(state,"item",2)
	expect(sell_quote.ok and sell_quote.maximum==4 and sell_quote.unit_price==0,"0259 price-one item may be sold at original integer half-price zero")
	var sold=Shop.sell(state,"item",2,1)
	expect(sold.ok and state.gold==91 and state.inventory["item:2"]==3 and state.flash_temp_fields.unblocking_text==null,"zero proceeds sale still removes the item and retains original lose_item message clearing")
	state.custom_data.values.records["Items:2"].price=0
	before=JSON.stringify([state.gold,state.inventory]); expect(Shop.quote_sell(state,"item",2).maximum==0,"source zero-price item has no sell quantity")
	expect(Shop.buy(state,[[0,2]],"item",2,1).ok and state.gold==91 and state.inventory["item:2"]==4,"source zero-price purchase remains valid")
	state.custom_data.values.records["Items:2"].price=10; state.flash_temp_fields.shop_type=1
	expect(not Shop.quote_sell(state,"item",2).ok and Shop.quote_buy(state,[[0,2]],"item",2).ok,"buy-only source shop has no sell quote")
	state.flash_temp_fields.shop_type=2
	expect(not Shop.quote_buy(state,[[0,2]],"item",2).ok and Shop.quote_sell(state,"item",2).ok,"sell-only source shop has no buy quote")
	state.flash_temp_fields.shop_type=0; state.gold=state.custom_data.currency_maximum()
	expect(Shop.quote_sell(state,"item",2).maximum==4 and Shop.sell(state,"item",2,2).ok and state.inventory["item:2"]==2 and Decimal.compare(state.gold,state.custom_data.currency_maximum())==0,"source sale quantity is the owned count and gain_gold saturates at its original cap")
	state.gold=100; state.custom_data.values.records["Weapons:1"]={"price":10}; state.custom_data.values.records["Armors:1"]={"price":8}
	expect(Shop.buy(state,[[1,1]],"weapon",1,2).ok and state.inventory["weapon:1"]==2 and state.gold==80,"Flash source missing weapon-backpack call is adapted to shared typed draft inventory")
	expect(Shop.sell(state,"weapon",1,1).ok and state.inventory["weapon:1"]==1 and state.gold==85,"Flash weapon sale commits its quantity and original half price")
	expect(Shop.buy(state,[[2,1]],"armor",1,2).ok and state.inventory["armor:1"]==2 and state.gold==69,"Flash armor purchase uses the same atomic typed inventory adapter")
	# A normal handbook purchase must refresh the source prediction catalog.
	var host=Host.new(); root.add_child(host); var map: Node=load("res://runtime/scripts/MapRuntime.gd").new(); host.add_child(map); host.map=map
	map.map_data=Data.map(10).duplicate(true); map._loaded_id=10
	var floor=state.custom_data._floor(10); var event_id=int(floor.entries.keys()[0])
	var enemy: Node=load("res://runtime/scripts/MapEvent.gd").new(); map.add_child(enemy); enemy.event_id=event_id; enemy.character_id=event_id; enemy.map_id=10; enemy.map_runtime=map; enemy.motion.relocate(Vector2i(floor.entries[str(event_id)].position[0],floor.entries[str(event_id)].position[1])); map._event_nodes.append(enemy)
	state._game_ref=weakref(host); state.custom_data.values.records["Items:4"]={"price":10}; state.inventory["item:4"]=0
	# Fatal case is covered in FlashFailureIsolationProbe: shop-catalog
	var refreshed=Shop.buy(state,[[0,4]],"item",4,1)
	expect(refreshed.ok and state.inventory["item:4"]==1 and state.custom_data.values.floors["10"].entries[str(event_id)].get("battle",{}).get("cache")==null,"source handbook acquisition succeeds and requests display refresh without computing the whole map")
	expect(state.custom_data.gameplay().predict(10,event_id)!=null,"subsequent source damage getter still computes the requested enemy on demand")
	state._game_ref=null; host.queue_free()
	native_regression(state)
	for message in failures: printerr("FAIL: ",message)
	print("FLASH SCENE/SHOP BUSINESS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func native_regression(state: Node) -> void:
	var cached: Dictionary=Data._cache.duplicate(true)
	state.custom_data.values.records={}
	Data._cache["res://data/database/Items.json"]=[null,{"id":1,"name":"native odd price","price":3},{"id":2,"name":"native zero price","price":0},{"id":3,"name":"native one price","price":1}]
	var native=NativeState.new(); native.inventory={"item:1":2,"item:3":2}; var currency=NativeCurrency.new(); currency.owner=weakref(native); native.custom_data=currency
	expect(Shop.quote_buy(native,[[0,1]],"item",1).maximum==33,"existing Native affordability uses database price")
	expect(Shop.buy(native,[[0,1]],"item",1,3).ok and native.gold==91 and native.inventory["item:1"]==5,"existing Native buy still commits its original balance and quantity")
	expect(Shop.sell(native,"item",1,2).ok and native.gold==93 and native.inventory["item:1"]==3,"existing Native sale retains integer half price")
	expect(Shop.quote_sell(native,"item",3).maximum==0 and not Shop.sell(native,"item",3,1).ok and native.inventory["item:3"]==2,"Native price-one sale remains refused while only Flash follows source price-one semantics")
	native.gold=9999999
	expect(Shop.quote_sell(native,"item",1).maximum==0 and not Shop.sell(native,"item",1,1).ok,"Native sale still refuses gold-cap overflow")
	native.gold=0
	expect(Shop.buy(native,[[0,2]],"item",2,99).ok and native.gold==0 and native.inventory["item:2"]==99,"existing Native free purchase behavior remains unchanged")
	var before=JSON.stringify([native.gold,native.inventory])
	expect(not Shop.buy(native,[[0,2]],"item",2,1).ok and not Shop.sell(native,"item",2,1).ok and JSON.stringify([native.gold,native.inventory])==before,"Native inventory cap and original-price-zero sale remain rejected without changes")
	Data._cache=cached; native.free()

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
