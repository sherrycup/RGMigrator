## 职责：处理闪翼颜色值的构造、转换及通道操作。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/04_UI_Common/Color.gd").方法名(...)。
##
## 调用接口：
##   static func rgba(color: Color) -> Array
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func rgb(color: Color) -> Array
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func add(first: Color, second: Variant) -> Color
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 second（Variant；必填）：第二个值或参与操作的对象。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   static func subtract(first: Color, second: Variant) -> Color
##     参数 first（Color；必填）：第一个值、对象或起始位置。
##     参数 second（Variant；必填）：第二个值或参与操作的对象。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   static func multiply(color: Color, value: Variant) -> Color
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：Color 类型的对象或值，供调用方继续使用。
##
##   static func divide(color: Color, value: Variant) -> Variant
##     参数 color（Color；必填）：绘制或效果使用的颜色。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 接口说明结束。

extends RefCounted


## 0022 Color arithmetic, using Godot's normalized channels and source clamps.
static func rgba(color: Color) -> Array:
	return [color.r * 255, color.g * 255, color.b * 255, color.a * 255]


static func rgb(color: Color) -> Array:
	return [color.r * 255, color.g * 255, color.b * 255]


static func add(first: Color, second: Variant) -> Color:
	return (first + second).clamp() if second is Color else first


static func subtract(first: Color, second: Variant) -> Color:
	return (first - second).clamp() if second is Color else first


static func multiply(color: Color, value: Variant) -> Color:
	return (color * float(value)).clamp() if value is int or value is float else color


static func divide(color: Color, value: Variant) -> Variant:
	return (
		null
		if value == 0
		else multiply(color, 1.0 / float(value)) if value is int or value is float else color
	)
