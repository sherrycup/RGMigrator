## 职责：读取 RM 工程 INI 配置并提取游戏标题、脚本及窗口等迁移参数。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/RmxpIniReader.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(text_codec: RmxpTextCodec) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 text_codec（RmxpTextCodec；必填）：处理原工程文本编码的解码服务。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func read(path: String) -> Dictionary
##     用途：读取指定文件或记录。
##     参数 path（String；必填）：待读取、写入或定位的文件路径。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 接口说明结束。

class_name RmxpIniReader
extends RefCounted

var codec: RmxpTextCodec


func _init(text_codec: RmxpTextCodec) -> void:
	codec = text_codec


func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := codec.decode(file.get_buffer(file.get_length()))
	file.close()
	var result: Dictionary = {}
	var section := ""
	for raw_line in text.replace("\r\n", "\n").split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			if not result.has(section):
				result[section] = {}
			continue
		var separator := line.find("=")
		if separator < 0:
			continue
		if not result.has(section):
			result[section] = {}
		result[section][line.left(separator).strip_edges()] = (
			line.substr(separator + 1).strip_edges()
		)
	return result
