extends RefCounted
const Movement = preload("res://runtime/scripts/MovementFixture.gd")

static func command(code: int, parameters: Array = [], indent: int = 0) -> Dictionary:
	return {"code": code, "parameters": parameters, "indent": indent}

static func event(x: int, y: int, trigger: int, commands: Array, condition: Dictionary = {}, graphic: String = "@movement_character") -> Dictionary:
	var value := Movement.event(x, y, graphic, trigger, "")
	value.pages[0].condition = condition
	value.pages[0].list = commands
	return value

static func build() -> Dictionary:
	var fixture := Movement.build()
	fixture.map.events = {
		"1": event(5, 3, 0, [command(101, ["柜台确认成功。接下来调用公共事件，等待1秒后返回。"]), command(117, [2]), command(122, [9001, 9001, 1, 0, 1]), command(101, ["公共事件已返回：确认次数=\\V[9001]，后台并行=\\V[9002]。"]), command(0)]),
		"2": event(2, 7, 1, [command(101, ["玩家接触：关闭消息后暂时删除此事件，再刷新也不会复活。"]), command(116), command(122, [9004, 9004, 1, 0, 1]), command(0)], {}, ""),
		"3": event(7, 6, 4, [command(122, [9002, 9002, 1, 0, 1]), command(106, [10]), command(0)], {}, ""),
		"4": event(9, 6, 4, [command(122, [9003, 9003, 1, 0, 1]), command(106, [20]), command(0)], {}, ""),
		"5": event(8, 5, 3, [command(106, [20]), command(123, ["A", 0]), command(122, [9005, 9005, 1, 0, 1]), command(0)], {}, "")
	}
	fixture.map.events["5"].pages.append({"condition": {"self_switch_valid": true, "self_switch_ch": "A"}, "trigger": 0, "graphic": {}, "list": [command(0)]})
	fixture.common_events = [null,
		{"id": 1, "trigger": 2, "switch_id": 9008, "list": [command(122, [9006, 9006, 1, 0, 1]), command(106, [20]), command(0)]},
		{"id": 2, "trigger": 0, "switch_id": 0, "list": [command(106, [20]), command(0)]}]
	fixture.common_events.append({"id": 3, "trigger": 0, "switch_id": 0, "list": [command(106, [10]), command(122, [9011, 9011, 1, 0, 1]), command(122, [9012, 9012, 1, 1, 9011]), command(0)]})
	return fixture


static func scenario(name: String) -> Array:
	if name == "input":
		return [command(104, [0, 1]), command(101, ["\\C[3]顶部透明消息\\C[0]：角色\\N[1]，金币窗口\\G。"]), command(104, [1, 0]), command(105, [9013]), command(101, ["\\C[2]新按键编号=\\V[9013]\\C[0]（方向2/4/6/8，确认13，取消12）。"]), command(104, [2, 0]), command(101, ["底部普通窗口。这里是第1行。"]), command(401, ["第2行：变量9013=\\V[9013]。"]), command(401, ["第3行：反斜杠\\\\，文字[不是富文本标记]。"]), command(401, ["第4行：继续查看下一页。"]), command(401, ["第5行：分页完成后才继续事件。"]), command(0)]
	return [command(104, [2, 0]), command(101, ["0.21＋0.22联合验收：选择循环次数。"]), command(102, [["运行3次", "自行输入（1..5）"], 5]),
		command(402, [0]), command(122, [9010, 9010, 0, 0, 3], 1),
		command(402, [1]), command(101, ["输入1..5；每轮公共事件等待0.5秒并累加。"], 1), command(103, [9010, 2], 1),
		command(403), command(101, ["已走取消分支，数值未改。"], 1), command(115, [], 1), command(404),
		command(111, [1, 9010, 0, 1, 2]), command(101, ["输入小于1，改为3次。"], 1), command(122, [9010, 9010, 0, 0, 3], 1), command(412),
		command(111, [1, 9010, 0, 5, 3]), command(101, ["输入大于5，改为3次。"], 1), command(122, [9010, 9010, 0, 0, 3], 1), command(412),
		command(122, [9011, 9012, 0, 0, 0]), command(124, [0, 30]), command(112), command(117, [3], 1),
		command(101, ["\\C[3]第\\V[9011]/\\V[9010]轮\\C[0]：公共事件已等0.5秒，累计=\\V[9012]。"], 1), command(401, ["消息打开时，后台并行仍计数：\\V[9002]。"], 1),
		command(111, [1, 9011, 1, 9010, 1], 1), command(113, [], 2), command(412, [], 1), command(413),
		command(122, [9014, 9014, 0, 7, 5]), command(124, [1, 0]), command(101, ["循环已结束：共\\V[9011]轮，累计\\V[9012]，计时器余\\V[9014]秒。"]), command(0)]
