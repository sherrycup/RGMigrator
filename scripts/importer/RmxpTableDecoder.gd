## 职责：解码 RM Table 的维度与整数单元，保持原 x、y、z 排列和取值。
##
## 调用方式：
##   静态接口：preload("res://scripts/importer/RmxpTableDecoder.gd").方法名(...)。
##
## 调用接口：
##   static func decode(value: Variant) -> Variant
##     用途：解析编码数据并返回对应原值或结构。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 公开常量：RAW_STRING_KEY。
## 接口说明结束。

class_name RmxpTableDecoder
extends RefCounted

const RAW_STRING_KEY := "_rmxp_raw_string"


static func decode(value: Variant) -> Variant:
	if not (value is Dictionary) or not value.has("_rmxp_user_defined"):
		return value
	if str(value.get("_rmxp_user_defined", "")) != "Table":
		return value
	var payload: Variant = value.get("payload")
	if not (payload is PackedByteArray):
		return value
	var bytes: PackedByteArray = payload
	if bytes.size() < 20:
		return {"_rmxp_table_error": "Table payload 太短。"}
	var dimensions := _i32(bytes, 0)
	var x_size := _i32(bytes, 4)
	var y_size := _i32(bytes, 8)
	var z_size := _i32(bytes, 12)
	var count := _i32(bytes, 16)
	if (
		dimensions < 1
		or dimensions > 3
		or x_size < 0
		or y_size < 0
		or z_size < 0
		or count != x_size * y_size * z_size
		or bytes.size() != 20 + count * 2
	):
		return {"_rmxp_table_error": "Table 元素数量无效。"}
	var values: Array[int] = []
	values.resize(count)
	for index in count:
		var raw := bytes[20 + index * 2] | (bytes[21 + index * 2] << 8)
		values[index] = raw - 65536 if raw >= 32768 else raw
	return {
		"_rmxp_type": "table",
		"dimensions": dimensions,
		"x_size": x_size,
		"y_size": y_size,
		"z_size": z_size,
		"values": values
	}


static func _i32(bytes: PackedByteArray, offset: int) -> int:
	var raw := (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)
	return raw
