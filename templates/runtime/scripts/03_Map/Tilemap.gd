## 职责：提供闪翼自定义地图图块查询与修改接口，通知地图刷新。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/03_Map/Tilemap.gd").方法名(...)。
##
## 调用接口：
##   static func parts(variant: int) -> Array
##     参数 variant（int；必填）：当前处理的变体或扩展值。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
## 公开常量：ANIMATION_SECONDS、AUTO_XY。
## 接口说明结束。

extends RefCounted
## Original 0026 AUTO_XY and ANI_T, including its repeated variant 14.
## These differ from the standard RM table used by other profiles.
const ANIMATION_SECONDS = 20.0 / 60.0
const AUTO_XY = [
	[8, 8, 8, 8],
	[3, 8, 8, 8],
	[8, 3, 8, 8],
	[3, 3, 8, 8],
	[8, 8, 8, 3],
	[3, 8, 8, 3],
	[8, 3, 8, 3],
	[3, 3, 8, 3],
	[8, 8, 3, 8],
	[3, 8, 3, 8],
	[8, 3, 3, 8],
	[3, 3, 3, 8],
	[8, 8, 3, 3],
	[3, 8, 3, 3],
	[8, 8, 3, 3],
	[3, 3, 3, 3],
	[7, 7, 7, 7],
	[7, 3, 7, 7],
	[7, 7, 7, 3],
	[7, 3, 7, 3],
	[5, 5, 5, 5],
	[5, 5, 5, 3],
	[5, 5, 3, 5],
	[5, 5, 3, 3],
	[9, 9, 9, 9],
	[9, 9, 3, 9],
	[3, 9, 9, 9],
	[3, 9, 3, 9],
	[11, 11, 11, 11],
	[3, 11, 11, 11],
	[11, 3, 11, 11],
	[3, 3, 11, 11],
	[7, 9, 7, 9],
	[5, 5, 11, 11],
	[4, 4, 4, 4],
	[4, 4, 4, 3],
	[6, 6, 6, 6],
	[6, 6, 3, 6],
	[12, 12, 12, 12],
	[3, 12, 12, 12],
	[10, 10, 10, 10],
	[10, 3, 10, 10],
	[4, 6, 4, 6],
	[4, 4, 10, 10],
	[10, 12, 10, 12],
	[6, 6, 12, 12],
	[4, 6, 10, 12],
	[1, 1, 1, 1]
]


static func parts(variant: int) -> Array:
	var result: Array = []
	for quadrant in 4:
		var tile = int(AUTO_XY[variant][quadrant]) - 1
		result.append(
			(int(tile / 3) * 2 + int(quadrant / 2)) * 6 + (tile % 3) * 2 + (quadrant % 2) + 1
		)
	return result
