extends RefCounted
## Separate, user-editable test overlay. Never changes the exported source databases.


func generate(output_root: String, enabled: bool) -> Dictionary:
	var item_id := _next_id(output_root, "Items")
	var weapon_id := _next_id(output_root, "Weapons")
	var armor_id := _next_id(output_root, "Armors")
	var skill_id := _next_id(output_root, "Skills")
	var animation_id := _next_id(output_root, "Animations")
	var state_id := _next_id(output_root, "States")
	var definitions := {"Items": [], "Weapons": [], "Armors": [], "Skills": [], "Animations": [], "States": []}
	var stock: Array[Dictionary] = []
	for index in 3:
		var item := {"id": item_id + index, "name": ["测试用·血瓶", "测试用·魔法药", "测试用·全队血瓶"][index],
			"description": ["单体恢复最大 HP 的 25%。测试物资，不来自原 RM 数据库。", "单体恢复最大 SP 的 25%。测试物资。", "全体存活队员恢复最大 HP 的 25%，只消耗一瓶。"][index],
			"scope": 4 if index == 2 else 3, "occasion": 2, "consumable": true, "hit": 100,
			"recover_hp_rate": 0 if index == 1 else 25, "recover_sp_rate": 25 if index == 1 else 0,
			"recover_hp": 0, "recover_sp": 0, "parameter_type": 0, "plus_state_set": [], "minus_state_set": [],
			"common_event_id": 0, "variance": 0, "price": 100 if index != 2 else 250, "icon_name": "@test_hp" if index != 1 else "@test_sp"}
		definitions.Items.append(item)
		stock.append({"kind": "item", "id": item.id, "quantity": 10})
	for index in 2:
		definitions.Weapons.append({"id": weapon_id + index, "name": "测试用·%s" % ["铁剑", "钢剑"][index],
			"description": "测试武器，攻击力 +%d；可供所有有效职业装备，但不绕过固定槽位。" % (10 + index * 10),
			"atk": 10 + index * 10, "pdef": 0, "mdef": 0, "price": 200 + index * 100, "icon_name": "@test_weapon"})
		stock.append({"kind": "weapon", "id": weapon_id + index, "quantity": 2})
	for index in 4:
		definitions.Armors.append({"id": armor_id + index, "name": "测试用·" + ["盾", "头盔", "铠甲", "护符"][index],
			"description": "标准槽位测试防具，物理防御 +5、魔法防御 +3。", "kind": index, "pdef": 5, "mdef": 3,
			"auto_state_id": 0, "price": 150 + index * 50, "icon_name": "@test_armor"})
		stock.append({"kind": "armor", "id": armor_id + index, "quantity": 2})
	for index in 3:
		definitions.Skills.append({"id": skill_id + index, "name": ["测试用·动画特技", "测试用·共用动画", "测试用·无动画特技"][index],
			"description": "只用于学习/遗忘、查询与动画预览，不执行效果，不消耗 SP。", "icon_name": "@test_sp",
			"animation1_id": animation_id if index < 2 else 0, "animation2_id": animation_id if index == 0 else 0,
			"scope": 0, "occasion": 3, "sp_cost": 10, "power": 0, "atk_f": 0, "eva_f": 0, "str_f": 0, "dex_f": 0,
			"agi_f": 0, "int_f": 0, "pdef_f": 0, "mdef_f": 0, "hit": 100, "variance": 0, "element_set": [],
			"plus_state_set": [], "minus_state_set": [], "common_event_id": 0, "menu_se": {"name": "", "volume": 100, "pitch": 100}})
	var frames: Array = []
	for index in 24:
		frames.append({"cell_max": 1, "cell_data": {"x_size": 1, "y_size": 8, "z_size": 1,
			"values": [index % 5, 0, 0, 40 + index * 3, index * 10, index % 2, 255 - index * 5, 1]}})
	definitions.Animations.append({"id": animation_id, "name": "RGMigrator 测试光环", "animation_name": "@test_animation", "animation_hue": 0,
		"position": 1, "frame_max": frames.size(), "frames": frames,
		"timings": [{"frame": 0, "condition": 0, "se": {"name": ""}, "flash_scope": 1, "flash_duration": 12,
			"flash_color": {"red": 100, "green": 180, "blue": 255, "alpha": 180}}]})
	for index in 2:
		definitions.States.append({"id": state_id + index, "name": "测试用·" + ["初始状态", "可增删状态"][index], "animation_id": 0,
			"rating": 5, "restriction": 0, "nonresistance": false, "zero_hp": false, "cant_get_exp": false, "cant_evade": false,
			"slip_damage": false, "hit_rate": 100, "maxhp_rate": 100, "maxsp_rate": 100, "str_rate": 100, "dex_rate": 100,
			"agi_rate": 100, "int_rate": 100, "atk_rate": 100, "pdef_rate": 100, "mdef_rate": 100, "eva": 0,
			"battle_only": false, "hold_turn": 0, "auto_release_prob": 0, "shock_release_prob": 0,
			"guard_element_set": [], "plus_state_set": [], "minus_state_set": []})
	var goods: Array = []
	for entry in stock:
		goods.append([["item", "weapon", "armor"].find(entry.kind), entry.id])
	var setup := {"schema_version": 3, "enabled": enabled,
		"note": "测试模式：仅新游戏发放。Esc → F6 可测试角色、商店、状态及图片/屏幕。改 enabled 为 false 可关闭；调整 stock.quantity 与初始 HP/SP 比例无需重新迁移。请勿修改已分配 ID。",
		"initial_hp_ratio": 0.5, "initial_sp_ratio": 0.5, "stock": stock, "definitions": definitions,
		"learn_skills": [skill_id, skill_id + 1, skill_id + 2], "toggle_skill_id": skill_id + 2,
		"initial_gold": 2000, "shop_goods": goods, "initial_states": [state_id], "toggle_state_id": state_id + 1}
	var path := output_root.path_join("data/test_setup.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "无法写入 data/test_setup.json"}
	file.store_string(JSON.stringify(setup, "\t") + "\n")
	file.close()
	return {"ok": true, "enabled": enabled, "config": "data/test_setup.json", "stock": stock, "definitions": definitions}


func _next_id(root: String, database: String) -> int:
	var path := root.path_join("data/database/%s.json" % database)
	if not FileAccess.file_exists(path):
		return 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return maxi(1, parsed.size()) if parsed is Array else 1
