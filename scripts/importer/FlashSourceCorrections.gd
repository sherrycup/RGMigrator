extends RefCounted
## Apply confirmed source defects to a migration copy only. No balance changes.
## Every edit retains line count and records the original text and location.
static func adapt(source: String,origin: Dictionary) -> Dictionary:
	var rules: Array=[]
	if origin.get("kind")=="map_event" and origin.get("map")=="Map024" and int(origin.get("event_id",0))==32 and source.contains("Message::TextRow.new"):
		rules.append(["\"\\c[","\"\\\\c[","text_row_literal_escape","原双引号\\c[5]在Ruby中是控制字符转义，意图是消息颜色码；迁移副本保留颜色码的字面反斜杠。"])
	if origin.get("kind")=="common_event":
		match int(origin.get("common_event_id",0)):
			2:
				rules.append(["POITON_ITEM_ID","POTION_ITEM_ID","potion_constant_typo","原常量实际名为POTION_ITEM_ID。"])
				rules.append(["id = $game_temp.actor_id","id = $game_temp.actor_id > 0 ? $game_temp.actor_id : _main_actor.id","hp_recipient_default","事件名驱动未设actor_id时按同事件的_main_actor目标补齐编号。"])
				if source.contains("_this.enemy.hp"):
					rules.append(["$game_temp.enemy_hp_addition","$game_temp.enemy_hp_addition if _this && _this.enemy","hp_non_enemy_guard","血瓶/路障及菜单也调用CE2；无事件/非怪物事件不能解引用nil。"])
			3:
				rules.append(["Storage::GEM_ATTR","Storage::gem_attr","gem_table_accessor","原Storage定义的是gem_attr访问方法。"])
				if int(origin.get("command_index",0))==14: rules.append(["$game_temp.potion_id","$game_temp.gem_id","gem_selector","宝石表必须用宝石编号查询。"])
			9: rules.append(["$game_temp_item_id","$game_temp.item_id","item_temp_field","原Game_Temp中定义item_id字段。"])
			14: rules.append(["if actor.exp >= actor.next_exp","if actor.next_exp && actor.exp >= actor.next_exp","growth_threshold_guard","源经验表用尽后next_exp为nil，停止升级判定并保留原阈值/增量。"])
			36:
				rules.append(["_this.enemy.battle_data.damage","_this.enemy.battle_result.enemy_damage","legacy_battle_result","0072已删除旧battle_data读取，原历史事件改读同一次真实普通预测的敌人受伤量，不重复begin扣血。"])
				rules.append(["_v[1]","_attack_actor.id","legacy_battle_role","0072主战已统一为PartyRoles/变量14；历史事件仍读旧变量1会得到无效角色编号。"])
	if origin.get("kind")=="script":
		match int(origin.get("load_order",0)):
			41: rules.append(["@door_type = 0","@door_id = 0","door_temp_field","公共事件及attr_accessor使用door_id。"])
			52:
				rules.append(["item_id = game_temp.item_id","item_id = $game_temp.item_id","item_default_global","默认值需要原Game_Temp全局对象。"])
				rules.append(["$game_system.set_map_page","$game_system.set_event_page","door_page_method","原Game_System定义set_event_page方法。"])
			68: rules.append(["@euqipment[index]","@equipment[index]","equipment_field_typo","装备真值字段为@equipment。"])
			70:
				rules.append(["DETAULT_MANOR_DAMAGE","DEFAULT_MANOR_DAMAGE","manor_default_typo","原全局常量实际名为DEFAULT_MANOR_DAMAGE。"])
				rules.append(["condition_trun_a","condition_turn_a","hook_action_field_typo","RPG::Enemy::Action字段为condition_turn_a。"])
				rules.append(["@elemeny","@element","enemy_element_field_typo","原初始化字段为@element。"])
	var corrected=source
	var records: Array=[]
	for rule in rules:
		var offset=corrected.find(rule[0])
		while offset>=0:
			var before=corrected.left(offset)
			records.append({"id":rule[2],"origin":origin,"line":before.count("\n")+1,"column":offset-before.rfind("\n"),"original":rule[0],"replacement":rule[1],"reason":rule[3]})
			corrected=corrected.left(offset)+rule[1]+corrected.substr(offset+str(rule[0]).length())
			offset=corrected.find(rule[0],offset+str(rule[1]).length())
	return {"source":corrected,"corrections":records}

static func native_adaptations(source: String,origin: Dictionary) -> Array:
	var rules: Array=[]
	match int(origin.get("load_order",0)):
		153:
			rules.append(["@text.bitmap.font.italic = (c[1][/[Ff]/]", "message_box_italic_flag", "文本框将FI[F]显示为斜体。", "按T开启、F关闭，与字号测量和控制码一致。", "FlashMessageText.gd::apply_style"])
			rules.append(["return if @state == 2", "message_pause_resume", "暂停状态立即return，没有内部按键恢复分支，且Message_Controller不调用continue，源消息使用\\!可能无法继续。", "暂停状态按确认恢复原打字状态；不提前结束事件或丢弃后续字符。", "FlashMessageBoxState.gd::confirm"])
			rules.append(["event = $game_map.events[$1.to_i]", "message_player_anchor", "显式P[0]在setup中被当作事件0解引用，update却按玩家处理。", "P[0]与缺省位置使用实际玩家；正事件ID使用当前地图事件。", "FlashMessageLayout.gd::anchor"])
		155:
			rules.append(["@text.bitmap.font.italic = (c[1][/[Ff]/]", "message_hint_italic_flag", "提示框将FI[F]显示为斜体。", "按T开启、F关闭，与文本框共用样式处理。", "FlashMessageText.gd::apply_style"])
			rules.append(["event = $game_map.events[$1.to_i]", "hint_player_anchor", "提示P[0]在setup中被当作事件0解引用。", "提示与对话共用实际玩家/事件定位。", "FlashMessageLayout.gd::anchor"])
			rules.append(["return if @state == 2", "hint_pause_resume", "HintBox暂停后立即返回，没有恢复分支。", "确认键恢复已暂停提示，提示仍不阻塞地图或吞掉该键的普通用途。", "FlashMessageController.gd::confirm"])
		157: rules.append(["@index = (@index + 1) % @message_max", "message_empty_history", "空历史按上下键会对0取模。", "没有条目时保持0/0且不移动索引。", "FlashMessageMemoryPage.gd::handle_key"])
		46:
			rules.append(["def load_config","config_run_field","运行模式读取到未使用的@run_volume，导致已保存的模式失效。","按global_variables[4]读取run_mode；保留原两种设置，不补造源未接入的奔跑处理。","FlashPreferences.gd::run_mode"])
			rules.append(["$game_music.unlock(i)","music_unlock_missing","BGM播放调用Game_Music未定义的unlock。","将原music_name对应槽设置为true，仅登记已听音乐，不补造源音乐室缺失的切歌实现。","FlashPreferences.gd::unlock_music"])
		52:
			rules.append(["def strike","strike_consumption","圣锤成功后误扣BOMB_ITEM_ID。","按原分派STRIKE_ITEM_ID扣减圣锤。","FlashItemEffects.gd::_map_effect"])
			rules.append(["def gem(gem_id)","typed_gem_increment","抗性数组插值为Ruby Array.to_s后丢失分量结构。","能力增量按原数值/数组类型直接计算，不执行Ruby字符串。","FlashItemEffects.gd::invoke"])
			rules.append(["def symcraft","symcraft_center_owner","Storage没有@map_center，原字段定义于Game_System。","读取共享system.map_center，保留对称坐标公式。","FlashItemEffects.gd::_map_effect"])
		53: rules.append(["def initialize(key, id, filename, path)","object_default_initialization","外部文件存在但缺少该ID块时load_data提前返回，@name/@price/@description未初始化；Game_Item随后对nil名称做正则。","读取已导入数据前按load_default的原默认值初始化；缺块时保留空名、零价格、空描述/setting，数据库getter仍按原rescue回退。","FlashObjectCatalog.gd::construct/value"])
		65: rules.append(["def resist=(resist)","resist_setter_vector","@resist_plus += 数组会拼接，bwise返回值被丢弃。","按五分量增减并保存截断后的结果。","FlashActorState.gd::set_resist"])
		68: rules.append(["def animation1_id","actor_weapon_animation","方法仍读未初始化@weapon_id，实际武器存于equipment[0]。","按原武器槽读取动画字段，未装备或缺失返回源默认0。","CustomDataState.gd::invoke"])
		78: rules.append(["def equipment","party_equipment_receiver","@actors是Array，遍历actor后仍误读@actors.equipment。","使用当前actor的六个装备槽，保留四类去重集合。","CustomDataState.gd::party_call"])
		91: rules.append(["def open_door_list","door_macro_label","读到动画标签前return，且直接改写原公共事件指令缩进。","跳过标签前内容，从副本提取并归一化动画指令，再绑定原_this.die尾部。","ScriptMigrationInventory.gd::_flash_door_macro"])
		98: rules.append(["def hook_deal","hook_skill_guard","对所有相邻怪物直接读取hook参数，普通怪物会解引用nil。","仅按HOOK_SKILL_ID及已有hook参数处理退敌怪物。","FlashMapDamage.gd::invoke"])
		108: rules.append(["def load_links","floor_link_fields","读取不存在的events_name/events_position并用n/p覆盖原事件，第二数字调用未定义to_id，阻断楼层链接。","使用已定义event_name/event_position覆盖，未设置时保留原事件名/位置；两数字转整数，有限坐标数组直接解析，不执行eval。","FlashFloor.gd::load_links"])
		214:
			rules.append(["def unlock(index)","blastic_unlock_cell","@lock是两条链，@lock[index]=true会覆盖整条链。","按原窗口的flat index换算circle/column后解锁孔位。","FlashBlastic.gd::invoke"])
			rules.append(["def have_crystal?(index)","blastic_undefined_data","@data未定义，实际结晶存储为@equip。","读取对应链和孔位的equip。","FlashBlastic.gd::invoke"])
			rules.append(["def equip_crystal(index,id)","blastic_replace_sum","直接覆盖已占孔位时未扣除旧结晶元素。","先扣旧元素再加新元素，与原Scene_Map的先cancel后equip顺序一致。","FlashBlastic.gd::_equip"])
		202: rules.append(["def update_bc","crystal_return_overflow","返还旧结晶时背包99上限可能使其丢失。","背包无法容纳返还物品时拒绝整笔交换。","FlashBlastic.gd::exchange"])
		200: rules.append(["@window_mapname.x = 768 - 128","mapname_outside_canvas","地图名x=640在原640宽画布之外，窗口完全不可见。","从实际画布右侧内缩128，保留16帧滑入、48帧停留、16帧滑出。","FlashPlayerHUD.gd::draw_hud"])
		30: rules.append(["if x - rect.x < rect.width and y - rect.y < rect.height","shape_lower_bounds","Shape.include?未检查左/上边界，矩形左上方的无限区域也被判定为内部。","使用Rect2i.has_point同时检查上下界，右/下边界仍为排除。","FlashShape.gd::includes"])
		209: rules.append(["def setSkill(input=0)","skill_turn_receiver","指定回合时调用Game_Party不存在的turn_have?，实际定义位于当前Game_Actor。","读取同一当前角色的回合槽，保留原替换/交换及被动分支规则。","FlashSkillConfig.gd::set_skill"])
		221: rules.append(["if c == CRYSTAL_NAME","crystal_110_category_missing","原RPG物品110结晶回路(刃牙)描述为空、缺少@结晶回路分类，但Storage.crystal已定义其类型/功能/元素，原选择窗口会漏掉它。","仅对ID110、原名匹配且描述仍为空时允许作为已定义回路选择；其他物品依原RPG分类，不改变元素/功能公式。","FlashBlasticPage.gd::refresh"])
		232: rules.append(["when 1..3 || 5","sight_door_five","Ruby的1..3 || 5只返回Range，门5不会匹配此描述分支。","显式匹配1、2、3、5，其他门保留原空描述。","FlashSightModel.gd::description"])
		259: rules.append(["def update_number","shop_equipment_inventory","原Game_Party只有物品背包，商店却调用未定义的gain/lose_weapon及gain/lose_armor。","武器、防具交易使用同一RuntimeState.inventory草稿；道具继续走gain/lose_item，保留提示与刷新。","ShopService.gd::transact"])
		332:
			rules.append(["case @move_list[i].type","follower_initial_nil","首步移动读取尚为空的移动历史nil.type，队列初始化后即报错。","跳过空历史槽，保留五格移动历史及逐步滞后规则。","FlashFollowers.gd::accept_action"])
			rules.append(["@characters[i].set_xy(x,y)","follower_missing_set_xy","原跟随角色和最终Game_Character都未定义set_xy。","以对应角色的moveto/relocate更新坐标，其他跟随者及队列不移动。","FlashFollowers.gd::set_characters_xy"])
		310:
			rules.append(["@origin.dispose","blur_undefined_origin","取消模糊时释放未定义的@origin，循环中还复用已dispose的位图。","持有独立截图纹理，以着色器半径更新显示，退出时释放对应实例引用。","FlashScreenEffects.gd::_tick"])
		330:
			rules.append(["@thex = @picture.screen_x","picture_unravel_character_fields","图片消散复制角色代码，引用图片不存在的screen_x/screen_y及未定义@cw/@ch。","使用当前图片精灵实际纹理区域、画面变换和弱引用，显式unravel_picture(number,args)指定图片。","FlashScreenEffects.gd::_unravel_target"])
			rules.append(["self.opacity = 0","unravel_opacity_refresh","消散仅在首帧将精灵opacity置0，随后基础Sprite_Character刷新按人物opacity覆盖，未透明的人物原图再次出现。","仅隐藏当前精灵实例，取消/重置释放隐藏标记；不清除或改写其他实例共享的行走图。","FlashScreenEffects.gd::unravel_sprite"])
		331: rules.append(["@sprite_datas.delete_at(index)","unravel_delete_iteration","正向each中删除粒子会跳过紧邻的下一粒子更新。","逆序遍历，一帧内每个存活粒子只推进一次。","FlashUnravel.gd::advance_ticks"])
		329:
			rules.append(["hue_change(hue)","snapshot_undefined_hue","航拍图块色相分支读取未定义的hue。","在拥有的图块Image副本上使用传入hue_change值；不修改共享Cache。","FlashMapSnapshot.gd::render"])
			rules.append(["src, rect, opacity","snapshot_undefined_rect","航拍缩放/混合分支读取未定义的rect。","采用已定位的图块区域和独立Image合成，再按原比例缩放导出PNG。","FlashMapSnapshot.gd::_tile"])
		169: rules.append(["actor - actors[i]","archive_actor_assignment","双角色档案读取将赋值误写成减法，actor尚未赋值。","按原队伍顺序读取相同两位角色；使用同一角色状态生成只读展示数据。","FlashArchiveData.gd::from_state"])
		315:
			rules.append(["text.insert(i,temp)","adapt_text_nested_lines","显式换行被插入为嵌套数组，下游绘制会收到Array而非文本行。","将实际换行拆成平行文本行，保留原数字整体和字号计数规则。","FlashUtils.gd::adapt_text"])
			rules.append(["when \"pic\" || \"picture\"","picture_alias_branch","Ruby的字符串或表达式只匹配pic，声明的picture别名永远不匹配。","原生GDScript入口显式匹配两个声明的别名；返回独立可绘制位图，不修改Cache。","FlashUtils.gd::get_pic"])
		23:
			rules.append(["colors[0].rgba, [i, j, w, h]","gradient_corner_channels","gradate_rect将单个角的RGBA数组当作同一通道的四角色，跨通道错误插值。","同一通道按左上/右上/左下/右下插值，保留原x/w、y/h比例。","FlashBitmap.gd::gradate_rect"])
			rules.append(["/ (width - 1)","gradient_single_pixel","单像素渐变宽度/高度为1时除以0。","单像素使用首端颜色，其他尺寸及逆向插值保持原端点比例。","FlashBitmap.gd::gradation_rect"])
	var records: Array=[]
	for rule in rules:
		var offset=source.find(rule[0])
		if offset<0: continue
		records.append({"id":rule[1],"origin":origin,"line":source.left(offset).count("\n")+1,"original":rule[2],"replacement":rule[3],"applied_by":("res://scripts/importer/" if str(rule[4]).begins_with("ScriptMigrationInventory.gd") else "res://runtime/scripts/")+rule[4],"treatment":"native_adapter_correction"})
	return records

static func adapt_commands(commands: Array,origin: Dictionary) -> Array:
	var records: Array=[]
	if origin.get("kind")!="common_event" or int(origin.get("common_event_id",0))!=9: return records
	for index in commands.size():
		var command: Dictionary=commands[index]
		if command.get("code")==119 and command.get("parameters")==["消耗物品"]:
			command.parameters=["<消耗物品>"]
			records.append({"id":"item_consumption_label","origin":origin.merged({"command_index":index+1}),"original":"消耗物品","replacement":"<消耗物品>","reason":"原119跳转名与118实际标签不一致。","applied_by":"res://scripts/importer/FlashSourceCorrections.gd::adapt_commands"})
	return records
