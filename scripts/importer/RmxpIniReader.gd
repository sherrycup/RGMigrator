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
		result[section][line.left(separator).strip_edges()] = line.substr(separator + 1).strip_edges()
	return result

