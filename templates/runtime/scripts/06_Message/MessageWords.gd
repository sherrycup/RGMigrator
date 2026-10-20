## 职责：组织闪翼消息的词项与控制信息，供文本解析和逐字输出使用。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/06_Message/MessageWords.gd").方法名(...)。
##
## 调用接口：
##   static func item_fails(item_id: int, parameter: int, custom: RefCounted) -> Variant
##     参数 item_id（int；必填）：物品的原数据库编号。
##     参数 parameter（int；必填）：需要查询或修改的属性名称。
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted


## Source 0156 Message::Words.item_fails; original empty cases return null.
static func item_fails(item_id: int, parameter: int, custom: RefCounted) -> Variant:
	var constants: Dictionary = custom.gameplay().rules.constants
	var table = {
		"PICKAXE_ITEM_ID": ["对面不是墙体", "破墙镐对墙体不起作用"],
		"FREEZE_ITEM_ID": ["对面不是熔岩", "冰冻徽章对熔岩不起作用"],
		"SYMCRAFT_ITEM_ID": ["落点位置有干扰物", "当前区域无法使用中心对称飞行器"],
		"ICE_PICKAXE_ITEM_ID": ["对面不是冰墙", "破冰镐对冰墙不起作用"],
		"CRAFT_ITEM_ID": ["落点位置有干扰物", "当前区域无法使用飞行器"],
		"BOMB_ITEM_ID": ["对面没有怪物", "炸弹对该怪物无效"],
		"STRIKE_ITEM_ID": ["四周没有怪物", "圣锤对四周怪物无效"]
	}
	for key in table:
		if int(constants.get(key, -1)) == item_id:
			return table[key][parameter] if parameter in [0, 1] else null
	return null
