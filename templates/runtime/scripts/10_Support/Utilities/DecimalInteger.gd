## 职责：实现超出安全浮点整数范围的十进制整数运算与比较。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/10_Support/Utilities/DecimalInteger.gd").方法名(...)。
##
## 调用接口：
##   static func normalize(value: Variant) -> String
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func compact(value: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func compare(a: Variant, b: Variant) -> int
##     参数 a（Variant；必填）：第一个操作数或参与比较的值。
##     参数 b（Variant；必填）：第二个操作数或参与比较的值。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   static func add(a: Variant, b: Variant) -> Variant
##     参数 a（Variant；必填）：第一个操作数或参与比较的值。
##     参数 b（Variant；必填）：第二个操作数或参与比较的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func negate(value: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func clamped_add(value: Variant, delta: Variant, maximum: Variant) -> Variant
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     参数 delta（Variant；必填）：本次推进的时间差，单位为秒。
##     参数 maximum（Variant；必填）：允许值的上限。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 公开常量：SAFE。
## 接口说明结束。

extends RefCounted
## Exact signed decimal arithmetic for project currencies, including Ruby Bignum caps.
const SAFE := 9007199254740991


static func normalize(value: Variant) -> String:
	if value is float:
		if not is_finite(value) or value != floor(value) or abs(value) > SAFE:
			return ""
		value = int(value)
	if not value is int and not value is String:
		return ""
	var s = str(value)
	var negative = s.begins_with("-")
	if negative:
		s = s.substr(1)
	if s.is_empty() or s.length() > 256:
		return ""
	for c in s:
		if c < "0" or c > "9":
			return ""
	while s.length() > 1 and s.begins_with("0"):
		s = s.substr(1)
	return "-" + s if negative and s != "0" else s


static func compact(value: Variant) -> Variant:
	var s = normalize(value)
	if s.is_empty():
		return null
	var magnitude = s.trim_prefix("-")
	return int(s) if _unsigned_compare(magnitude, str(SAFE)) <= 0 else s


static func compare(a: Variant, b: Variant) -> int:
	var x = normalize(a)
	var y = normalize(b)
	assert(not x.is_empty() and not y.is_empty())
	var xn = x.begins_with("-")
	var yn = y.begins_with("-")
	if xn != yn:
		return -1 if xn else 1
	return _unsigned_compare(x.trim_prefix("-"), y.trim_prefix("-")) * (-1 if xn else 1)


static func add(a: Variant, b: Variant) -> Variant:
	var x = normalize(a)
	var y = normalize(b)
	if x.is_empty() or y.is_empty():
		return null
	var xn = x.begins_with("-")
	var yn = y.begins_with("-")
	x = x.trim_prefix("-")
	y = y.trim_prefix("-")
	if xn == yn:
		return compact(("-" if xn else "") + _add(x, y))
	var order = _unsigned_compare(x, y)
	return (
		compact(("-" if xn else "") + _subtract(x, y))
		if order >= 0
		else compact(("-" if yn else "") + _subtract(y, x))
	)


static func negate(value: Variant) -> Variant:
	var s = normalize(value)
	if s.is_empty():
		return null
	return compact(s.substr(1) if s.begins_with("-") else "-" + s)


static func clamped_add(value: Variant, delta: Variant, maximum: Variant) -> Variant:
	var sum: Variant = add(value, delta)
	if sum == null or normalize(maximum).is_empty():
		return null
	if compare(sum, 0) < 0:
		return 0
	return compact(maximum) if compare(sum, maximum) > 0 else sum


static func _unsigned_compare(a: String, b: String) -> int:
	if a.length() != b.length():
		return -1 if a.length() < b.length() else 1
	return 0 if a == b else -1 if a < b else 1


static func _add(a: String, b: String) -> String:
	var result = ""
	var carry = 0
	var i = a.length() - 1
	var j = b.length() - 1
	while i >= 0 or j >= 0 or carry > 0:
		var n = (
			carry
			+ (a.unicode_at(i) - 48 if i >= 0 else 0)
			+ (b.unicode_at(j) - 48 if j >= 0 else 0)
		)
		result = str(n % 10) + result
		carry = n / 10
		i -= 1
		j -= 1
	return result


static func _subtract(a: String, b: String) -> String:
	var result = ""
	var borrow = 0
	var j = b.length() - 1
	for i in range(a.length() - 1, -1, -1):
		var n = a.unicode_at(i) - 48 - borrow - (b.unicode_at(j) - 48 if j >= 0 else 0)
		borrow = 1 if n < 0 else 0
		if n < 0:
			n += 10
		result = str(n) + result
		j -= 1
	return result
