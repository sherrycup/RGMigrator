## 职责：按指定代码页解码原工程文本，管理迁移所需的字符映射与编码诊断。
##
## 调用方式：
##   静态接口：preload("res://scripts/importer/RmxpTextCodec.gd").方法名(...)。
##   实例接口：先用 preload("res://scripts/importer/RmxpTextCodec.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func _init(requested_codepage: int = AUTO_CODEPAGE) -> void
##     用途：构造本实例并记录初始化依赖。
##     参数 requested_codepage（int；默认值 AUTO_CODEPAGE）：用户指定的原工程代码页。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   static func resolve_codepage(requested_codepage: int) -> int
##     参数 requested_codepage（int；必填）：用户指定的原工程代码页。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func label() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func decode(bytes: PackedByteArray) -> String
##     用途：解析编码数据并返回对应原值或结构。
##     参数 bytes（PackedByteArray；必填）：原始字节数据。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func ensure_ready() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 公开常量：AUTO_CODEPAGE、GBK_CODEPAGE、SHIFT_JIS_CODEPAGE。
## 接口说明结束。

class_name RmxpTextCodec
extends RefCounted

const AUTO_CODEPAGE := 0
const GBK_CODEPAGE := 936
const SHIFT_JIS_CODEPAGE := 932

var codepage: int = GBK_CODEPAGE
var error_message := ""
static var _tables: Dictionary = {}
var _table := PackedByteArray()


func _init(requested_codepage: int = AUTO_CODEPAGE) -> void:
	codepage = resolve_codepage(requested_codepage)


static func resolve_codepage(requested_codepage: int) -> int:
	if requested_codepage in [GBK_CODEPAGE, SHIFT_JIS_CODEPAGE]:
		return requested_codepage
	var output: Array = []
	var command := "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false); [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage"
	var status := OS.execute(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", command]),
		output,
		true
	)
	if status == 0 and not output.is_empty():
		var detected := str(output[0]).strip_edges().to_int()
		if detected in [GBK_CODEPAGE, SHIFT_JIS_CODEPAGE]:
			return detected
	return GBK_CODEPAGE


func label() -> String:
	match codepage:
		GBK_CODEPAGE:
			return "GBK / CP936"
		SHIFT_JIS_CODEPAGE:
			return "Shift-JIS / CP932"
		_:
			return "CP%d" % codepage


func decode(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	if _is_ascii(bytes):
		return bytes.get_string_from_ascii()
	# RMXP serializes database text as UTF-8, while Game.ini and some scripts
	# still use the Windows ANSI codepage. Validate before falling back.
	if _is_utf8(bytes):
		return bytes.get_string_from_utf8().trim_prefix("\ufeff")
	if not ensure_ready():
		return "�"
	var result := ""
	var index := 0
	while index < bytes.size():
		var first := int(bytes[index])
		var lead := (
			(first >= 0x81 and first <= 0xfe)
			if codepage == 936
			else ((first >= 0x81 and first <= 0x9f) or (first >= 0xe0 and first <= 0xfc))
		)
		var character := _table.decode_u16(first * 2)
		if lead:
			character = 0xfffd
			if index + 1 < bytes.size():
				var paired := _table.decode_u16((256 + first * 256 + int(bytes[index + 1])) * 2)
				if paired != 0:
					character = paired
					index += 1
		result += String.chr(character)
		index += 1
	return result


func _is_ascii(bytes: PackedByteArray) -> bool:
	for value in bytes:
		if value >= 0x80:
			return false
	return true


func _is_utf8(bytes: PackedByteArray) -> bool:
	var index := 0
	while index < bytes.size():
		var first := int(bytes[index])
		if first < 128:
			index += 1
			continue
		var count := 0
		var scalar := 0
		var minimum := 0
		if first >= 0xc2 and first <= 0xdf:
			count = 1
			scalar = first & 31
			minimum = 128
		elif first >= 0xe0 and first <= 0xef:
			count = 2
			scalar = first & 15
			minimum = 2048
		elif first >= 0xf0 and first <= 0xf4:
			count = 3
			scalar = first & 7
			minimum = 65536
		else:
			return false
		if index + count >= bytes.size():
			return false
		for offset in range(1, count + 1):
			var next := int(bytes[index + offset])
			if next < 0x80 or next > 0xbf:
				return false
			scalar = (scalar << 6) | (next & 63)
		if scalar < minimum or scalar > 0x10ffff or (scalar >= 0xd800 and scalar <= 0xdfff):
			return false
		index += count + 1
	return true


func ensure_ready() -> bool:
	if not _table.is_empty():
		return true
	if _tables.has(codepage):
		_table = _tables[codepage]
		return true
	# Build the Windows codepage lookup once, not one process per database string.
	# All source text stays local; only a codepage number is passed to PowerShell.
	var temp_root := str(
		ProjectSettings.get_setting(
			"rgmigrator/codec_temp_directory", OS.get_user_data_dir().path_join("codec")
		)
	)
	if DirAccess.make_dir_recursive_absolute(temp_root) != OK:
		error_message = "无法创建编码临时目录：%s" % temp_root
		return false
	var token := "%s_%s" % [Time.get_ticks_usec(), randi()]
	var result_path := temp_root.path_join("%s.bin" % token)
	var script := (
		"$ErrorActionPreference='Stop';$enc=[Text.Encoding]::GetEncoding(%d);$chars=New-Object 'UInt16[]' 65792;$pair=New-Object 'Byte[]' 2;for($i=0;$i -lt 256;$i++){$chars[$i]=[int][char]$enc.GetString([byte[]]@($i))[0]};for($i=0;$i -lt 65536;$i++){$pair[0]=$i -shr 8;$pair[1]=$i -band 255;$s=$enc.GetString($pair);if($s.Length -eq 1 -and [int][char]$s[0] -ne 65533){$chars[256+$i]=[int][char]$s[0]}};$data=New-Object 'Byte[]' 131584;[Buffer]::BlockCopy($chars,0,$data,0,$data.Length);[IO.File]::WriteAllBytes('%s',$data)"
		% [codepage, result_path.replace("'", "''")]
	)
	var output: Array = []
	var status := OS.execute(
		"powershell.exe",
		PackedStringArray(
			[
				"-NoProfile",
				"-NonInteractive",
				"-EncodedCommand",
				Marshalls.raw_to_base64(script.to_utf16_buffer())
			]
		),
		output,
		true
	)
	if status == 0 and FileAccess.file_exists(result_path):
		_table = FileAccess.get_file_as_bytes(result_path)
	if FileAccess.file_exists(result_path):
		DirAccess.remove_absolute(result_path)
	if _table.size() != 131584:
		_table.clear()
		error_message = "PowerShell 无法生成 CP%d 解码表（退出码 %d）：%s" % [codepage, status, str(output)]
		return false
	_tables[codepage] = _table
	return true
