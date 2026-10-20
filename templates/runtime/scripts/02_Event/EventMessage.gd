## 职责：连接事件解释器与消息界面，提交文章、选择及数字输入请求并接收结果。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/02_Event/EventMessage.gd").方法名(...)。
##
## 调用接口：
##   static func format(text: String) -> Dictionary
##     参数 text（String；必填）：需要解析、显示或保存的文本。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 公开常量：COLORS。
## 接口说明结束。

extends RefCounted
const COLORS := [
	Color.WHITE,
	Color("8080ff"),
	Color("ff8080"),
	Color("80ff80"),
	Color("80ffff"),
	Color("ff80ff"),
	Color("ffff80"),
	Color("c0c0c0")
]


static func format(text: String) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var color := 0
	var buffer := ""
	var gold := false
	var index := 0
	while index < text.length():
		if text[index] != "\\" or index + 1 >= text.length():
			buffer += text[index]
			index += 1
			continue
		var tag := text[index + 1].to_upper()
		if tag == "\\":
			buffer += "\\"
			index += 2
			continue
		if tag == "G":
			gold = true
			index += 2
			continue
		var end := text.find("]", index + 3)
		if (
			tag in ["V", "N", "C"]
			and index + 2 < text.length()
			and text[index + 2] == "["
			and end >= 0
		):
			var digits := text.substr(index + 3, end - index - 3)
			if not digits.is_empty() and digits.is_valid_int() and int(digits) >= 0:
				var id := int(digits)
				match tag:
					"V":
						buffer += str(int(RuntimeState.variables.get(str(id), 0)))
					"N":
						if not (
							preload("res://runtime/scripts/00_Game/RuntimeData.gd")
							. record("Actors", id)
							. is_empty()
						):
							var actor: RefCounted = RuntimeState.actor(id)
							if actor != null:
								buffer += actor.actor_name
					"C":
						if not buffer.is_empty():
							pieces.append({"text": buffer, "color": color})
						buffer = ""
						if id < COLORS.size():
							color = id
				index = end + 1
				continue
		buffer += "\\"
		index += 1
	if not buffer.is_empty():
		pieces.append({"text": buffer, "color": color})
	var plain := ""
	for piece in pieces:
		plain += piece.text
	return {"pieces": pieces, "text": plain, "gold": gold}
