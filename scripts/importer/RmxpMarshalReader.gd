class_name RmxpMarshalReader
extends RefCounted

const RmxpTextCodec = preload("res://scripts/importer/RmxpTextCodec.gd")
const RAW_STRING_KEY := "_rmxp_raw_string"

var _bytes := PackedByteArray()
var _position := 0
var _objects: Array = []
var _symbols: Array[String] = []
var _codec: RmxpTextCodec
var failed := false
var error_message := ""


func _init(text_codec: RmxpTextCodec) -> void:
	_codec = text_codec


func read_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("无法打开数据文件：%s" % path)
		return null
	var value: Variant = read_bytes(file.get_buffer(file.get_length()))
	file.close()
	return value


func read_bytes(bytes: PackedByteArray) -> Variant:
	_bytes = bytes
	_position = 0
	_objects.clear()
	_symbols.clear()
	failed = false
	error_message = ""
	if _read_byte() != 4 or _read_byte() != 8:
		_fail("不是 Ruby Marshal 4.8 数据。")
		return null
	return _read_value()


func _read_value() -> Variant:
	if failed:
		return null
	var tag := _read_byte()
	match tag:
		48: # 0 nil
			return null
		84: # T true
			return true
		70: # F false
			return false
		105: # i fixnum
			return _read_fixnum()
		108: # l bignum
			return _read_bignum()
		102: # f float
			return _read_float()
		58: # : symbol
			return _read_symbol()
		59: # ; symbol link
			return _read_symbol_link()
		34: # " string
			return _read_string()
		91: # [ array
			return _read_array()
		123, 125: # { hash / } hash with default
			return _read_hash(tag == 125)
		111: # o object
			return _read_object()
		83: # S struct
			return _read_struct()
		117: # u: _dump / _load raw payload (RGSS Table, Color, Tone)
			return _read_user_defined()
		85: # U: marshal_dump / marshal_load object payload
			return _read_user_marshaled()
		73: # I ivar wrapper
			return _read_ivar()
		64: # @ object link
			return _read_object_link()
		47: # / regexp
			return _read_regexp()
		99, 109, 77: # class, module, old module
			return _read_named_value(tag)
		101: # e extended object
			return _read_extended()
		67: # C user class
			return _read_user_class()
		100: # d data object
			return _read_data_object()
		_:
			_fail("不支持的 Ruby Marshal 标记 0x%02X（偏移 %d）。" % [tag, _position - 1])
			return null


func _read_fixnum() -> int:
	var prefix := _read_signed_byte()
	if prefix == 0:
		return 0
	if prefix > 4:
		return prefix - 5
	if prefix < -4:
		return prefix + 5
	var count := absi(prefix)
	var value := 0 if prefix > 0 else -1
	for index in count:
		var byte := _read_byte()
		if prefix > 0:
			value |= byte << (index * 8)
		else:
			value &= ~(0xff << (index * 8))
			value |= byte << (index * 8)
	return value


func _read_bignum() -> Dictionary:
	var sign := _read_byte()
	var words := _read_fixnum()
	var raw := _read_raw(max(0, words) * 2)
	var result := {"_rmxp_bignum": "-" if sign == 45 else "+", "bytes": raw.hex_encode()}
	_objects.append(result)
	return result


func _read_float() -> Variant:
	var value := _codec.decode(_read_raw(_read_fixnum()))
	var result: Variant = {"_rmxp_float": value} if value in ["nan", "inf", "-inf"] else value.to_float()
	_objects.append(result)
	return result


func _read_symbol() -> String:
	var symbol := _codec.decode(_read_raw(_read_fixnum()))
	_symbols.append(symbol)
	return symbol


func _read_symbol_link() -> String:
	var index := _read_fixnum()
	if index < 0 or index >= _symbols.size():
		_fail("无效的 Ruby symbol 链接：%d" % index)
		return ""
	return _symbols[index]


func _read_string() -> Dictionary:
	var length := _read_fixnum()
	var value := {RAW_STRING_KEY: _read_raw(length)}
	_objects.append(value)
	return value


func _read_array() -> Array:
	var result: Array = []
	_objects.append(result)
	var count := _read_fixnum()
	for _index in max(0, count):
		result.append(_read_value())
	return result


func _read_hash(has_default: bool) -> Dictionary:
	var result := {"_rmxp_hash": []}
	_objects.append(result)
	var entries: Array = result["_rmxp_hash"]
	var count := _read_fixnum()
	for _index in max(0, count):
		entries.append([_read_value(), _read_value()])
	if has_default:
		result["_rmxp_hash_default"] = _read_value()
	return result


func _read_object() -> Dictionary:
	var ruby_class := str(_read_value())
	var result := {"_rmxp_object": ruby_class, "_rmxp_ivars": {}}
	_objects.append(result)
	_read_instance_variables(result["_rmxp_ivars"])
	return result


func _read_struct() -> Dictionary:
	var ruby_class := str(_read_value())
	var result := {"_rmxp_struct": ruby_class, "_rmxp_members": {}}
	_objects.append(result)
	_read_instance_variables(result["_rmxp_members"])
	return result


func _read_user_marshaled() -> Dictionary:
	var ruby_class := str(_read_value())
	var result := {"_rmxp_user_marshaled": ruby_class}
	_objects.append(result)
	result["payload"] = _read_value()
	return result


func _read_user_defined() -> Dictionary:
	var ruby_class := str(_read_value())
	var result := {"_rmxp_user_defined": ruby_class, "payload": _read_raw(_read_fixnum())}
	_objects.append(result)
	return result


func _read_ivar() -> Variant:
	var value: Variant = _read_value()
	var ivars := {}
	_read_instance_variables(ivars)
	if value is Dictionary:
		value["_rmxp_string_ivars"] = ivars
	return value


func _read_object_link() -> Variant:
	var index := _read_fixnum()
	if index < 0 or index >= _objects.size():
		_fail("无效的 Ruby object 链接：%d" % index)
		return null
	return _objects[index]


func _read_regexp() -> Dictionary:
	var result := {"_rmxp_regexp": _read_raw(_read_fixnum()), "options": _read_byte()}
	_objects.append(result)
	return result


func _read_named_value(tag: int) -> Dictionary:
	var kind := "class" if tag == 99 else "module"
	var result := {("_rmxp_%s" % kind): _codec.decode(_read_raw(_read_fixnum()))}
	_objects.append(result)
	return result


func _read_extended() -> Variant:
	var extension: Variant = _read_value()
	var value: Variant = _read_value()
	if value is Dictionary:
		value["_rmxp_extended_by"] = extension
	return value


func _read_user_class() -> Variant:
	var ruby_class: Variant = _read_value()
	var value: Variant = _read_value()
	if value is Dictionary:
		value["_rmxp_user_class"] = ruby_class
	return value


func _read_data_object() -> Dictionary:
	var ruby_class: Variant = _read_value()
	var result := {"_rmxp_data": ruby_class}
	_objects.append(result)
	result["value"] = _read_value()
	return result


func _read_instance_variables(target: Dictionary) -> void:
	var count := _read_fixnum()
	for _index in max(0, count):
		var name := str(_read_value())
		target[name] = _read_value()


func _read_raw(length: int) -> PackedByteArray:
	if length < 0 or _position + length > _bytes.size():
		_fail("Ruby Marshal 数据在偏移 %d 截断。" % _position)
		return PackedByteArray()
	var result := _bytes.slice(_position, _position + length)
	_position += length
	return result


func _read_byte() -> int:
	if _position >= _bytes.size():
		_fail("Ruby Marshal 数据在偏移 %d 截断。" % _position)
		return 0
	var value := _bytes[_position]
	_position += 1
	return value


func _read_signed_byte() -> int:
	var value := _read_byte()
	return value - 256 if value >= 128 else value


func _fail(message: String) -> void:
	if not failed:
		failed = true
		error_message = message
