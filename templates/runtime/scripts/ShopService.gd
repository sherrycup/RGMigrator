extends RefCounted
## Database prices only. Flash trades share migrated script transactions.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Inventory = preload("res://runtime/scripts/InventoryService.gd")
const Decimal=preload("res://runtime/scripts/DecimalInteger.gd")
const KINDS := ["item", "weapon", "armor"]
const MAX_GOLD := 9999999
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")


static func integer(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and floor(float(value)) == float(value)


static func catalog(goods: Array) -> Dictionary:
	if goods.size() > 10000:
		return fail("商品列表过大。")
	var entries: Array[Dictionary] = []
	var seen := {}
	for index in goods.size():
		var raw: Variant = goods[index]
		if not raw is Array or raw.size() != 2 or not integer(raw[0], 0, 2) or not integer(raw[1], 1):
			return fail("商品 %d 不是 RMXP 的 [类型, ID] 定义。" % (index + 1), index)
		var kind: String = KINDS[int(raw[0])]
		var id := int(raw[1])
		var entry := item(kind, id)
		if not entry.ok:
			return fail("商品 %d：%s" % [index + 1, entry.message], index)
		var key := "%s:%d" % [kind, id]
		if not seen.has(key):
			entries.append(entry.entry)
			seen[key] = true
	return {"ok": true, "entries": entries}


static func item(kind: String, id: int) -> Dictionary:
	if kind not in KINDS or id <= 0:
		return fail("商品类型或 ID 无效。")
	var definition := Data.record(Inventory.DATABASES[kind], id)
	if definition.is_empty() or not integer(definition.get("price"), 0, Decimal.SAFE):
		return fail("%s[%d] 不存在或 price 不是有效价格。" % [Inventory.DATABASES[kind], id])
	return {"ok": true, "entry": {"kind": kind, "id": id, "price": int(definition.price), "name": str(definition.get("name", "")),
		"description": str(definition.get("description", "")), "icon_name": str(definition.get("icon_name", ""))}}


static func counters(state: Node, kind: String, id: int) -> Dictionary:
	var count: Variant = state.inventory.get("%s:%d" % [kind, id], 0)
	if not integer(count, 0, 99) or not state.custom_data.valid_currency(state.gold):
		return fail("背包数量或金币超出标准范围；未进行交易。")
	return {"ok": true, "owned": int(count)}


static func quote_buy(state: Node, goods: Array, kind: String, id: int) -> Dictionary:
	if _flash(state) and state.flash_temp_fields.get("shop_type",0)==2: return fail("原商店只允许出售。")
	var parsed := catalog(goods)
	if not parsed.ok:
		return parsed
	for entry in parsed.entries:
		if entry.kind == kind and entry.id == id:
			var counts := counters(state, kind, id)
			if not counts.ok:
				return counts
			var maximum: int = 99 - counts.owned
			if entry.price > 0:
				while maximum>0 and Decimal.compare(state.gold,maximum*entry.price)<0: maximum-=1
			return {"ok": true, "maximum": maximum, "unit_price": entry.price, "owned": counts.owned,
				"message": "金币不足或该商品已达 99 件。" if maximum == 0 else ""}
	return fail("此商品不在当前商店中。")


static func quote_sell(state: Node, kind: String, id: int) -> Dictionary:
	if _flash(state) and state.flash_temp_fields.get("shop_type",0)==1: return fail("原商店只允许购买。")
	var definition := item(kind, id)
	if not definition.ok:
		return definition
	var counts := counters(state, kind, id)
	if not counts.ok:
		return counts
	var price := int(definition.entry.price / 2)
	if _flash(state):
		# Source update_sell tests the original price, then uses integer half
		# price. A price-one object can be sold for zero; gain_gold still caps.
		return {"ok":true,"maximum":0 if definition.entry.price==0 else counts.owned,"unit_price":price,"owned":counts.owned,"message":"没有可出售数量或原商品价格为0。" if counts.owned==0 or definition.entry.price==0 else ""}
	var maximum: int = 0 if price == 0 else counts.owned
	while maximum>0 and Decimal.compare(Decimal.add(state.gold,maximum*price),state.custom_data.currency_maximum())>0: maximum-=1
	return {"ok": true, "maximum": maximum, "unit_price": price, "owned": counts.owned,
		"message": "没有可出售数量、售价为 0 或金币已达上限。" if maximum == 0 else ""}


static func buy(state: Node, goods: Array, kind: String, id: int, quantity: int) -> Dictionary:
	return transact(state, goods, kind, id, quantity, true)


static func sell(state: Node, kind: String, id: int, quantity: int) -> Dictionary:
	return transact(state, [], kind, id, quantity, false)


static func transact(state: Node, goods: Array, kind: String, id: int, quantity: int, buying: bool) -> Dictionary:
	if _flash(state): return _flash_transact(state,goods,kind,id,quantity,buying)
	var quote := quote_buy(state, goods, kind, id) if buying else quote_sell(state, kind, id)
	if not quote.ok:
		return quote
	if quantity <= 0 or quantity > quote.maximum:
		return fail(quote.message if not quote.message.is_empty() else "数量超出可交易范围；未进行交易。")
	var key := "%s:%d" % [kind, id]
	var paid: Dictionary=state.custom_data.gain_currency("gold",(-1 if buying else 1)*quantity*int(quote.unit_price))
	if not paid.ok: return paid
	state.inventory[key] = int(quote.owned) + (1 if buying else -1) * quantity
	state.state_changed.emit()
	return {"ok": true, "message": "%s %d 件，总价 %d。" % ["已购买" if buying else "已出售", quantity, quantity * int(quote.unit_price)]}


static func _flash(state: Node) -> bool:
	return state.get("custom_data")!=null and state.custom_data.get("manifest") is Dictionary and state.custom_data.manifest.get("profile")=="flash" and FileAccess.file_exists("res://data/flash_gameplay.json")


static func _flash_transact(state: Node,goods: Array,kind: String,id: int,quantity: int,buying: bool) -> Dictionary:
	var result: Dictionary=Scripts.call_transaction(state,{"source":"0259.update_number","operation":"buy" if buying else "sell"},func(env):
		# Requote inside the same transaction that stages payment, item hooks
		# and any resulting source handbook prediction/notification changes.
		var quote: Dictionary=quote_buy(state,goods,kind,id) if buying else quote_sell(state,kind,id)
		if not quote.ok: return env.fail(quote.message)
		if quantity<=0 or quantity>quote.maximum: return env.fail(quote.message if not quote.message.is_empty() else "数量超出可交易范围；未进行交易。")
		var payment: Dictionary=env._custom.gain_currency("gold",(-1 if buying else 1)*quantity*int(quote.unit_price))
		if not payment.ok: return env.fail(payment.message)
		if kind=="item":
			env._custom.party_call("gain_item" if buying else "lose_item",[id,quantity])
			if not env._custom.failure.is_empty(): return env.fail(env._custom.failure)
		else:
			# The source Scene_Shop calls missing weapon/armor backpack methods.
			# Use the existing typed inventory, with the same 0..99 semantics.
			env._custom.inventory_items["%s:%d" % [kind,id]]=int(quote.owned)+(1 if buying else -1)*quantity
		return {"unit_price":quote.unit_price,"quantity":quantity})
	if result.ok: result.message="%s %d 件，总价 %d。" % ["已购买" if buying else "已出售",quantity,quantity*int(result.value.unit_price)]
	return result


static func fail(message: String, goods_index: int = -1) -> Dictionary:
	var result := {"ok": false, "message": message}
	if goods_index >= 0:
		result["goods_index"] = goods_index
	return result
