@tool
extends RefCounted
## Human-readable labels only. Never changes IDs, payloads or runtime state.
const _DIRECTIONS := {0:"保持朝向",2:"下",4:"左",6:"右",8:"上"}
const _BLENDS := {0:"正常",1:"加算",2:"减算"}
const _COMPARE := {0:"等于",1:"大于等于",2:"小于等于",3:"大于",4:"小于",5:"不等于"}
const _ACTOR_DATA := ["等级","经验","HP","SP","最大HP","最大SP","力量","灵巧","速度","魔力","攻击力","物理防御","魔法防御","回避"]
const _CHARACTER_DATA := ["地图X","地图Y","朝向","屏幕X","屏幕Y","地形标记"]
const _OTHER_DATA := ["地图ID","队员数","金钱","步数","游戏时间（秒）","计时器剩余秒数","存档次数"]
const _ABILITIES := ["最大HP","最大SP","力量","灵巧","速度","魔力"]
const _SLOTS := ["武器","盾","头部防具","身体防具","饰品"]
const _KEYS := {2:"下",4:"左",6:"右",8:"上",11:"取消B",12:"确定C",13:"X",14:"Y",15:"Z",16:"L",17:"R",18:"A"}

static func reference_text(documents: RefCounted, category: String, value: Variant, empty: String = "") -> String:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)): return "无效编号「%s」" % str(value)
	if documents!=null: return documents.reference_label(category,int(value),empty)
	return "[%04d] %s" % [int(value),empty if int(value)==0 and not empty.is_empty() else "编号"]

static func character(value: Variant, characters: Dictionary = {}) -> String:
	var id=int(value)
	if id==-1: return "玩家"
	if id==0: return "本事件（由调用上下文确定）"
	return str(characters.get(str(id),"[%04d] 缺失或无当前地图上下文的事件" % id))

static func field(value: Variant, hint: Dictionary, documents: RefCounted = null) -> String:
	if value==null: return "空"
	if hint.has("db"): return reference_text(documents,str(hint.db),value,str(hint.get("empty","无" if int(hint.get("min",1))==0 else "")))
	if hint.has("options"):
		var key=str(int(value)) if value is float and is_finite(value) and value==floor(value) else str(value)
		return str(hint.options.get(key,"未知选项「%s」（保留）" % str(value)))
	if value is bool: return "是" if value else "否"
	if value is float and is_finite(value) and value==floor(value): return str(int(value))
	return str(value).replace("\n"," ↵ ")

static func summary(code: int, p: Array, name: String, documents: RefCounted = null, characters: Dictionary = {}) -> String:
	var ref=func(category: String,value: Variant,empty: String="") -> String: return reference_text(documents,category,value,empty)
	var actor=func(value: Variant,all_members: bool=false) -> String: return ref.call("Actors",value,"全体队员" if all_members else "")
	var target=func(value: Variant) -> String: return character(value,characters)
	match code:
		0: return "事件结束"
		101,401: return ("显示文章：" if code==101 else "")+str(p[0]).replace("\n"," ↵ ")
		108,408: return ("注释：" if code==108 else "")+str(p[0]).replace("\n"," ↵ ")
		102:
			var choices: Array=p[0]
			var cancel="禁止取消" if int(p[1])==0 else "取消进入独立分支" if int(p[1])==5 else "取消选择第%d项" % int(p[1])
			return "显示选项：%s；%s" % [" / ".join(choices.map(func(v: Variant) -> String: return str(v))),cancel]
		103: return "数值输入 → %s（%d位）" % [ref.call("variables",p[0]),int(p[1])]
		104: return "文章选项：%s；%s" % [_choice(p[0],["上方","中间","下方"]),_choice(p[1],["普通窗口","透明背景"])]
		105: return "等待新按键 → %s" % ref.call("variables",p[0])
		106: return "等待 %s" % _duration(p[0],20)
		111: return "如果 %s" % _condition(p,documents,characters)
		112: return "循环开始"
		113: return "跳出当前循环"
		115: return "结束本次事件执行"
		116: return "暂时删除本事件（本次地图内）"
		117: return "调用公共事件 %s" % ref.call("CommonEvents",p[0])
		118: return "标签「%s」" % p[0]
		119: return "跳转至标签「%s」" % p[0]
		121: return "开关 %s %s" % [_range_ref(documents,"switches",p[0],p[1]),"打开" if int(p[2])==0 else "关闭"]
		122: return "变量 %s %s %s" % [_range_ref(documents,"variables",p[0],p[1]),_choice(p[2],["=","+=","-=","×=","÷=","取余="]),_operand(p,documents,characters)]
		123: return "独立开关 %s %s" % [p[0],"打开" if int(p[1])==0 else "关闭"]
		124: return "计时器 开始 %d秒" % int(p[1]) if int(p[0])==0 else "计时器 停止"
		125: return "金钱 %s%s" % [_sign(p[0]),_amount(p[1],p[2],documents)]
		126,127,128: return "%s %s %s%s" % [{126:"物品",127:"武器",128:"防具"}[code],ref.call({126:"Items",127:"Weapons",128:"Armors"}[code],p[0]),_sign(p[1]),_amount(p[2],p[3],documents)]
		129: return "队员 %s %s%s" % [actor.call(p[0]),"加入" if int(p[1])==0 else "离开","；初始化角色" if int(p[1])==0 and int(p[2])==1 else ""]
		131: return "窗口皮肤 %s 更换" % _asset(p[0])
		134,135: return "%s %s" % ["存档" if code==134 else "菜单","禁止" if int(p[0])==0 else "允许"]
		201:
			var destination=ref.call("Maps",p[1]) if int(p[0])==0 else "地图由变量 %s 指定" % ref.call("variables",p[1])
			return "场所 %s 移动；%s；%s；%s" % [destination,_coordinates(p[0],p[2],p[3],documents),_enum(_DIRECTIONS,p[4]),"淡化" if int(p[5])==0 else "不淡化"]
		202:
			var position="与 %s 交换位置" % target.call(p[2]) if int(p[1])==2 else _coordinates(p[1],p[2],p[3],documents)
			return "位置 %s 设置：%s；%s" % [target.call(p[0]),position,_enum(_DIRECTIONS,p[4])]
		203: return "地图向%s滚动 %d格；速度%d" % [_enum(_DIRECTIONS,p[0]),int(p[1]),int(p[2])]
		204:
			if int(p[0])==0: return "全景 → %s；色相%d°" % [_asset(p[1]),int(p[2])]
			return "雾 → %s；色相%d°；不透明度%d；%s；缩放%d%%；速度(%d, %d)" % [_asset(p[1]),int(p[2]),int(p[3]),_enum(_BLENDS,p[4]),int(p[5]),int(p[6]),int(p[7])]
		205: return "雾色调 → %s；%s" % [_color(p[0]),_duration(p[1],20)]
		206: return "雾不透明度 → %d；%s" % [int(p[0]),_duration(p[1],20)]
		207: return "动画 %s 显示于 %s" % [ref.call("Animations",p[1],"无动画"),target.call(p[0])]
		208: return "玩家 %s" % ("隐藏" if int(p[0])==0 else "显示")
		209:
			var route: Dictionary=p[1]
			var actions: Array=route.get("list",[]).filter(func(c: Variant) -> bool: return int(c.get("code",0))!=0)
			return "移动路线 %s 执行%d个动作；%s；%s" % [target.call(p[0]),actions.size(),"重复执行" if route.get("repeat",false) else "执行一次","遇阻跳过" if route.get("skippable",false) else "遇阻等待"]
		210: return "等待所有强制移动路线完成"
		221: return "准备画面过渡（截取当前画面）"
		222: return "执行画面过渡：%s" % ("普通淡化" if str(p[0]).is_empty() else _asset(p[0]))
		223: return "画面色调 → %s；%s" % [_color(p[0]),_duration(p[1],20)]
		224: return "画面闪光：%s；%s" % [_color(p[0]),_duration(p[1],20)]
		225: return "画面震动：强度%d；速度%d；%s" % [int(p[0]),int(p[1]),_duration(p[2],20)]
		231: return "显示图片 #%d：%s；%s" % [int(p[0]),_asset(p[1]),_picture(p,documents)]
		232: return "移动图片 #%d：%s；%s" % [int(p[0]),_picture(p,documents),_duration(p[1],20)]
		233: return "旋转图片 #%d：速度%d（%s°/秒）" % [int(p[0]),int(p[1]),str(float(p[1])*20)]
		234: return "图片 #%d 色调 → %s；%s" % [int(p[0]),_color(p[1]),_duration(p[2],20)]
		235: return "删除图片 #%d" % int(p[0])
		236: return "天气 → %s；强度%d；%s" % [_choice(p[0],["无","雨","暴风雨","雪"]),int(p[1]),_duration(p[2],40)]
		241,245,249,250: return "%s：%s" % [name,_audio(p[0])]
		242,246: return "%s：%d秒" % [name,int(p[0])]
		247,248,251,351,352,353,354: return name
		302,605: return "%s：%s" % ["商店商品" if code==302 else "追加商品",ref.call(_choice(p[0],["Items","Weapons","Armors"]),p[1])]
		303: return "%s 姓名输入（最多%d字）" % [actor.call(p[0]),int(p[1])]
		311,312,315,316: return "%s %s %s%s%s" % [_choice({311:0,312:1,315:2,316:3}[code],["HP","SP","经验","等级"]),actor.call(p[0],true),_sign(p[1]),_amount(p[2],p[3],documents),"；允许死亡" if code==311 and bool(p[4]) else ""]
		313: return "状态 %s %s于 %s" % [ref.call("States",p[2]),"附加" if int(p[1])==0 else "解除",actor.call(p[0],true)]
		314: return "角色 %s 全回复" % actor.call(p[0],true)
		317: return "%s %s %s%s" % [_choice(p[1],_ABILITIES),actor.call(p[0]),_sign(p[2]),_amount(p[3],p[4],documents)]
		318: return "特技 %s %s；角色 %s" % [ref.call("Skills",p[2]),"学习" if int(p[1])==0 else "遗忘",actor.call(p[0])]
		319: return "装备 %s 更换为 %s；%s" % [actor.call(p[0]),ref.call("Weapons" if int(p[1])==0 else "Armors",p[2],"卸下"),_choice(p[1],_SLOTS)]
		320: return "角色 %s 改名为「%s」" % [actor.call(p[0]),p[1]]
		321: return "角色 %s 职业更换为 %s" % [actor.call(p[0]),ref.call("Classes",p[1])]
		322: return "角色 %s 行走图更换为 %s（色相%d°）；战斗图元数据 → %s（色相%d°）" % [actor.call(p[0]),_asset(p[1]),int(p[2]),_asset(p[3]),int(p[4])]
		402: return "当选择「%s」时（第%d项）" % [p[1],int(p[0])+1]
		403: return "当取消选择时"
		404: return "选项结束"
		411: return "否则"
		412: return "条件结束"
		413: return "循环结束（返回循环开始）"
		509: return "移动路线续行（随路线保留）"
	return name+"（原始参数保留）"

static func route_summary(code: int, p: Array, name: String, documents: RefCounted = null) -> String:
	match code:
		14: return "%s：横向%d格，纵向%d格" % [name,int(p[0]),int(p[1])]
		15: return "等待 %s" % _duration(p[0],20)
		27,28: return "开关 %s %s" % [reference_text(documents,"switches",p[0]),"打开" if code==27 else "关闭"]
		29,30: return "%s → %d" % [name,int(p[0])]
		41: return "行走图 → %s；色相%d°；朝%s；第%d帧" % [_asset(p[0]),int(p[1]),_enum(_DIRECTIONS,p[2]),int(p[3])+1]
		42: return "不透明度 → %d" % int(p[0])
		43: return "混合方式 → %s" % _enum(_BLENDS,p[0])
		44: return "演奏SE：%s" % _audio(p[0])
	return name.replace("ON","开启").replace("OFF","关闭")

static func _condition(p: Array, documents: RefCounted, characters: Dictionary) -> String:
	var ref=func(category: String,value: Variant) -> String: return reference_text(documents,category,value)
	match int(p[0]):
		0: return "开关 %s 为%s" % [ref.call("switches",p[1]),"开启" if int(p[2])==0 else "关闭"]
		1: return "变量 %s %s %s" % [ref.call("variables",p[1]),_enum(_COMPARE,p[4]),_amount(p[2],p[3],documents)]
		2: return "独立开关 %s 为%s" % [p[1],"开启" if int(p[2])==0 else "关闭"]
		3: return "计时器剩余时间 %s %d秒" % ["大于等于" if int(p[2])==0 else "小于等于",int(p[1])]
		4:
			var who=ref.call("Actors",p[1])
			match int(p[2]):
				0: return who+" 在队伍中"
				1: return "%s 姓名为「%s」" % [who,p[3]]
				2: return "%s 已学特技 %s" % [who,ref.call("Skills",p[3])]
				3,4: return "%s 已装备 %s" % [who,reference_text(documents,"Weapons" if int(p[2])==3 else "Armors",p[3],"无装备")]
				5: return "%s 具有状态 %s" % [who,ref.call("States",p[3])]
		6: return "%s 朝向%s" % [character(p[1],characters),_enum(_DIRECTIONS,p[2])]
		7: return "金钱 %s %d" % ["大于等于" if int(p[2])==0 else "小于等于",int(p[1])]
		8,9,10: return "持有 %s" % ref.call({8:"Items",9:"Weapons",10:"Armors"}[int(p[0])],p[1])
		11: return "按住按键 %s" % _enum(_KEYS,p[1])
	return "未支持的条件（保留）"

static func _operand(p: Array, documents: RefCounted, characters: Dictionary) -> String:
	match int(p[3]):
		0: return field(p[4],{})
		1: return "变量 %s" % reference_text(documents,"variables",p[4])
		2: return "随机整数 %d…%d" % [int(p[4]),int(p[5])]
		3: return "%s 的持有数量" % reference_text(documents,"Items",p[4])
		4: return "%s 的%s" % [reference_text(documents,"Actors",p[4]),_choice(p[5],_ACTOR_DATA)]
		6: return "%s 的%s" % [character(p[4],characters),_choice(p[5],_CHARACTER_DATA)]
		7: return _choice(p[4],_OTHER_DATA)
	return "未支持的操作数（保留）"

static func _range_ref(documents: RefCounted, category: String, first: Variant, last: Variant) -> String:
	var start=reference_text(documents,category,first)
	return start if int(first)==int(last) else "%s 至 %s（含中间编号）" % [start,reference_text(documents,category,last)]

static func _amount(mode: Variant, value: Variant, documents: RefCounted) -> String:
	return "变量 %s" % reference_text(documents,"variables",value) if int(mode)==1 else field(value,{})

static func _coordinates(mode: Variant, x: Variant, y: Variant, documents: RefCounted) -> String:
	return "X由变量 %s，Y由变量 %s" % [reference_text(documents,"variables",x),reference_text(documents,"variables",y)] if int(mode)==1 else "坐标(%d, %d)" % [int(x),int(y)]

static func _picture(p: Array, documents: RefCounted) -> String:
	return "%s；原点%s；缩放(%d%%, %d%%)；不透明度%d；%s" % [_coordinates(p[3],p[4],p[5],documents),_choice(p[2],["左上","中心"]),int(p[6]),int(p[7]),int(p[8]),_enum(_BLENDS,p[9])]

static func _duration(value: Variant, divisor: float) -> String:
	var seconds=float(value)/divisor
	return "%s秒（原值%s，1/%d秒）" % [str(int(seconds)) if seconds==floor(seconds) else str(seconds),field(value,{}),int(divisor)]

static func _color(value: Dictionary) -> String:
	return "RGB(%s, %s, %s)，%s%s" % [value.get("red",0),value.get("green",0),value.get("blue",0),"灰度" if value.has("gray") else "透明度",value.get("gray",value.get("alpha",255))]

static func _audio(value: Dictionary) -> String:
	return "%s；音量%s%%；音调%s%%" % [_asset(value.get("name","")),field(value.get("volume",100),{}),field(value.get("pitch",100),{})]

static func _asset(value: Variant) -> String:
	return "「%s」" % value if not str(value).is_empty() else "无素材"

static func _sign(value: Variant) -> String:
	return "+" if int(value)==0 else "−"

static func _choice(value: Variant, choices: Array) -> String:
	var i=int(value)
	return str(choices[i]) if i>=0 and i<choices.size() else "未知选项「%s」" % str(value)

static func _enum(choices: Dictionary, value: Variant) -> String:
	return str(choices.get(int(value),"未知选项「%s」" % str(value)))

static func parameter_hints(code: int, p: Array, characters: Dictionary = {}) -> Dictionary:
	var h: Dictionary = {}
	var minimum: int={102:2,111:1,122:4,201:1,202:2,204:1,209:1,231:4,232:4,319:2}.get(code,0)
	if p.size()<minimum: return h
	var opts = func(index: int,values: Dictionary) -> void: h[str(index)] = {"options":values}
	var db = func(index: int,name: String) -> void: h[str(index)] = {"db":name,"min":1}
	var toggle = {"0":"禁止","1":"允许"}
	var state = {"0":"开启（ON）","1":"关闭（OFF）"}
	var direction = {"0":"不改变","2":"下","4":"左","6":"右","8":"上"}
	var source = {"0":"常量","1":"变量"}
	var sign = {"0":"增加","1":"减少"}
	match code:
		102:
			var cancel = {"0":"禁止取消","5":"独立取消分支"}
			for i in p[0].size(): cancel[str(i+1)] = "选择第%d项" % (i+1)
			opts.call(1,cancel)
		103,105: db.call(0,"variables")
		104: opts.call(0,{"0":"上","1":"中","2":"下"}); opts.call(1,{"0":"普通窗口","1":"透明背景"})
		111:
			opts.call(0,{"0":"开关","1":"变量","2":"独立开关","3":"计时器","4":"角色","6":"人物朝向","7":"金钱","8":"物品","9":"武器","10":"防具","11":"按键"})
			match int(p[0]):
				0: db.call(1,"switches"); opts.call(2,state)
				1: db.call(1,"variables"); opts.call(2,source); opts.call(4,{"0":"等于","1":"大于等于","2":"小于等于","3":"大于","4":"小于","5":"不等于"})
				2: opts.call(1,{"A":"A","B":"B","C":"C","D":"D"}); opts.call(2,state)
				3,7: opts.call(2,{"0":"大于等于","1":"小于等于"})
				4: db.call(1,"Actors"); opts.call(2,{"0":"在队伍中","1":"姓名","2":"已学特技","3":"装备武器","4":"装备防具","5":"状态"})
				6: opts.call(2,{"2":"下","4":"左","6":"右","8":"上"})
				8: db.call(1,"Items")
				9: db.call(1,"Weapons")
				10: db.call(1,"Armors")
				11: opts.call(1,{"2":"下","4":"左","6":"右","8":"上","11":"取消B","12":"确定C","13":"X","14":"Y","15":"Z","16":"L","17":"R","18":"A"})
		117: db.call(0,"CommonEvents")
		121: db.call(0,"switches"); db.call(1,"switches"); opts.call(2,state)
		122:
			db.call(0,"variables"); db.call(1,"variables")
			opts.call(2,{"0":"代入","1":"加","2":"减","3":"乘","4":"除","5":"余数"})
			opts.call(3,{"0":"常量","1":"变量","2":"随机","3":"物品数量","4":"角色数据","6":"人物数据","7":"其他"})
			match int(p[3]):
				1: db.call(4,"variables")
				3: db.call(4,"Items")
				4:
					db.call(4,"Actors")
					opts.call(5,{"0":"等级","1":"经验","2":"HP","3":"SP","4":"最大HP","5":"最大SP","6":"力量","7":"灵巧","8":"速度","9":"魔力","10":"攻击力","11":"物防","12":"魔防","13":"回避"})
				6: opts.call(5,{"0":"地图X","1":"地图Y","2":"朝向","3":"屏幕X","4":"屏幕Y","5":"地形标记"})
				7: opts.call(4,{"0":"地图ID","1":"队员数","2":"金钱","3":"步数","4":"游戏秒数","5":"计时器秒数","6":"存档次数"})
		123: opts.call(0,{"A":"A","B":"B","C":"C","D":"D"}); opts.call(1,state)
		124: opts.call(0,{"0":"开始","1":"停止"})
		125: opts.call(0,sign); opts.call(1,source)
		126,127,128: db.call(0,{126:"Items",127:"Weapons",128:"Armors"}[code]); opts.call(1,sign); opts.call(2,source)
		129: db.call(0,"Actors"); opts.call(1,{"0":"加入","1":"离开"}); opts.call(2,{"0":"不初始化","1":"初始化"})
		134,135: opts.call(0,toggle)
		201: opts.call(0,source); db.call(1,"Maps" if int(p[0])==0 else "variables"); opts.call(4,direction); opts.call(5,{"0":"淡化","1":"不淡化"})
		202: opts.call(1,{"0":"常量坐标","1":"变量坐标","2":"交换人物"}); opts.call(4,direction)
		203: opts.call(0,{"2":"下","4":"左","6":"右","8":"上"})
		204: opts.call(0,{"0":"全景","1":"雾"}); h["1"] = {"asset":"Panoramas" if int(p[0])==0 else "Fogs"}
		207: db.call(1,"Animations")
		208: opts.call(0,{"0":"隐藏","1":"显示"})
		209:
			var targets = {"-1":"玩家","0":"本事件（由调用上下文确定）"}; targets.merge(characters,true)
			var target = str(int(p[0]))
			if not targets.has(target): targets[target] = "缺失或无当前地图上下文的事件 ["+target+"]"
			opts.call(0,targets)
		231,232: opts.call(2,{"0":"左上","1":"中心"}); opts.call(3,source); opts.call(9,{"0":"正常","1":"加算","2":"减算"})
		236: opts.call(0,{"0":"无","1":"雨","2":"暴风雨","3":"雪"})
		303,314,320: db.call(0,"Actors")
		311,312,315,316: db.call(0,"Actors"); opts.call(1,sign); opts.call(2,source)
		313: db.call(0,"Actors"); opts.call(1,{"0":"附加","1":"解除"}); db.call(2,"States")
		317: db.call(0,"Actors"); opts.call(1,{"0":"最大HP","1":"最大SP","2":"力量","3":"灵巧","4":"速度","5":"魔力"}); opts.call(2,sign); opts.call(3,source)
		318: db.call(0,"Actors"); opts.call(1,{"0":"学习","1":"遗忘"}); db.call(2,"Skills")
		319: db.call(0,"Actors"); opts.call(1,{"0":"武器","1":"盾","2":"头部防具","3":"身体防具","4":"饰品"}); db.call(2,"Weapons" if int(p[1])==0 else "Armors")
		321: db.call(0,"Actors"); db.call(1,"Classes")
		322: db.call(0,"Actors"); h["1"] = {"asset":"Characters"}; h["3"] = {"asset":"Battlers"}
	if code in [131,222,231]: h["1" if code==231 else "0"] = {"asset":{131:"Windowskins",222:"Transitions",231:"Pictures"}[code]}
	if code in [241,245,249,250]: h["0/name"] = {"asset":{241:"BGM",245:"BGS",249:"ME",250:"SE"}[code]}

	# Context determines whether a numeric value is a constant or a reference.
	if code==111 and p.size()>=3:
		if int(p[0])==1 and int(p[2])==1: db.call(3,"variables")
		if int(p[0])==4 and int(p[2]) in [2,3,4,5]:
			db.call(3,{2:"Skills",3:"Weapons",4:"Armors",5:"States"}[int(p[2])])
			if int(p[2]) in [3,4]: h["3"].merge({"min":0,"empty":"无装备"},true)
	var amount_index: int={125:2,126:3,127:3,128:3,311:3,312:3,315:3,316:3,317:4}.get(code,-1)
	if amount_index>=0 and p.size()>amount_index and int(p[amount_index-1])==1: db.call(amount_index,"variables")
	if code in [311,312,313,314,315,316]: h["0"].merge({"min":0,"empty":"全体队员"},true)
	if code==207: h["1"].merge({"min":0,"empty":"无动画"},true)
	if code==319: h["2"].merge({"min":0,"empty":"卸下"},true)
	if code==201 and p.size()>=4 and int(p[0])==1: db.call(2,"variables"); db.call(3,"variables")
	if code==202 and p.size()>=4 and int(p[1])==1: db.call(2,"variables"); db.call(3,"variables")
	if code in [231,232] and p.size()>=6 and int(p[3])==1: db.call(4,"variables"); db.call(5,"variables")
	var target_indices: Array=[]
	if code in [202,207,209]: target_indices.append(0)
	if code==202 and p.size()>1 and int(p[1])==2: target_indices.append(2)
	if code==111 and p.size()>0 and int(p[0])==6: target_indices.append(1)
	if code==122 and p.size()>3 and int(p[3])==6: target_indices.append(4)
	for index in target_indices:
		var choices={"-1":"玩家","0":"本事件（由调用上下文确定）"}; choices.merge(characters,true)
		if p.size()>index and not choices.has(str(int(p[index]))): choices[str(int(p[index]))]=character(p[index],characters)
		h[str(index)]={"options":choices}
	if code==204 and p.size()>0 and int(p[0])==1: opts.call(4,{"0":"正常","1":"加算","2":"减算"})
	if code==302:
		h[""]={"goods":true}
		for i in p.size():
			if p[i] is Array and p[i].size()==2:
				h[str(i)]={"goods":true}
				h["%d/0" % i]={"options":{"0":"物品","1":"武器","2":"防具"}}
				h["%d/1" % i]={"db":{0:"Items",1:"Weapons",2:"Armors"}.get(int(p[i][0]),"Items"),"min":1}
	return h
