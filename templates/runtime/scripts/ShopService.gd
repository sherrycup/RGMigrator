extends RefCounted
## Database prices only. All validation finishes before gold/inventory writes.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const Inventory = preload("res://runtime/scripts/InventoryService.gd")
const KINDS := ["item", "weapon", "armor"]
const MAX_GOLD := 9999999


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
	if definition.is_empty() or not integer(definition.get("price"), 0, MAX_GOLD):
		return fail("%s[%d] 不存在或 price 不是有效价格。" % [Inventory.DATABASES[kind], id])
	return {"ok": true, "entry": {"kind": kind, "id": id, "price": int(definition.price), "name": str(definition.get("name", "")),
		"description": str(definition.get("description", "")), "icon_name": str(definition.get("icon_name", ""))}}


static func counters(state: Node, kind: String, id: int) -> Dictionary:
	var count: Variant = state.inventory.get("%s:%d" % [kind, id], 0)
	if not integer(count, 0, 99) or not integer(state.gold, 0, MAX_GOLD):
		return fail("背包数量或金币超出标准范围；未进行交易。")
	return {"ok": true, "owned": int(count)}


static func quote_buy(state: Node, goods: Array, kind: String, id: int) -> Dictionary:
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
				maximum = mini(maximum, int(state.gold / entry.price))
			return {"ok": true, "maximum": maximum, "unit_price": entry.price, "owned": counts.owned,
				"message": "金币不足或该商品已达 99 件。" if maximum == 0 else ""}
	return fail("此商品不在当前商店中。")


static func quote_sell(state: Node, kind: String, id: int) -> Dictionary:
	var definition := item(kind, id)
	if not definition.ok:
		return definition
	var counts := counters(state, kind, id)
	if not counts.ok:
		return counts
	var price := int(definition.entry.price / 2)
	var maximum: int = 0 if price == 0 else mini(counts.owned, int((MAX_GOLD - state.gold) / price))
	return {"ok": true, "maximum": maximum, "unit_price": price, "owned": counts.owned,
		"message": "没有可出售数量、售价为 0 或金币已达上限。" if maximum == 0 else ""}


static func buy(state: Node, goods: Array, kind: String, id: int, quantity: int) -> Dictionary:
	return transact(state, goods, kind, id, quantity, true)


static func sell(state: Node, kind: String, id: int, quantity: int) -> Dictionary:
	return transact(state, [], kind, id, quantity, false)


static func transact(state: Node, goods: Array, kind: String, id: int, quantity: int, buying: bool) -> Dictionary:
	var quote := quote_buy(state, goods, kind, id) if buying else quote_sell(state, kind, id)
	if not quote.ok:
		return quote
	if quantity <= 0 or quantity > quote.maximum:
		return fail(quote.message if not quote.message.is_empty() else "数量超出可交易范围；未进行交易。")
	var key := "%s:%d" % [kind, id]
	state.gold += (-1 if buying else 1) * quantity * int(quote.unit_price)
	state.inventory[key] = int(quote.owned) + (1 if buying else -1) * quantity
	state.state_changed.emit()
	return {"ok": true, "message": "%s %d 件，总价 %d。" % ["已购买" if buying else "已出售", quantity, quantity * int(quote.unit_price)]}


static func fail(message: String, goods_index: int = -1) -> Dictionary:
	var result := {"ok": false, "message": message}
	if goods_index >= 0:
		result["goods_index"] = goods_index
	return result
