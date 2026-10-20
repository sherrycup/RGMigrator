## 职责：统一640×640逻辑画布、地图HUD保留区、窗口边距及可见区域约束。
##
## 调用方式：
##   所有坐标均为逻辑画布像素；原闪翼画布640×640，地图HUD宽224。
##   usable_rect按实际Viewport返回可用区域；fit_rect限制矩形而不改变地图或输入坐标。
##
## 调用接口：
##   static func usable_rect(viewport_size: Vector2, reserve_hud: bool = false) -> Rect2
##     用途：计算当前画布的可用区域。
##     参数 viewport_size（Vector2；必填）：当前Viewport的逻辑像素尺寸，不是操作系统窗口尺寸。
##     参数 reserve_hud（bool；默认值 false）：是否为左侧地图HUD保留224像素；窄画布至少保留48像素可用宽度。
##     返回：非负可用矩形；保留HUD时从其右侧开始。
##
##   static func fit_rect(rect: Rect2, bounds: Rect2) -> Rect2
##     用途：缩小并平移矩形使其位于可用区域内。
##     参数 rect（Rect2；必填）：目标矩形的位置与尺寸。
##     参数 bounds（Rect2；必填）：容纳目标矩形的可用逻辑区域。
##     返回：宽高非负且包含在bounds中的矩形。
##
##   static func content_rect(window_size: Vector2, margin: float = WINDOW_MARGIN) -> Rect2
##     用途：计算扣除四边留白后的窗口内容区域。
##     参数 window_size（Vector2；必填）：窗口的逻辑像素宽高。
##     参数 margin（float；默认值 WINDOW_MARGIN）：四边内容留白，逻辑像素；默认16。
##     返回：Rect2 类型的对象或值，供调用方继续使用。
##
## 公开常量：DESIGN_SIZE、MAP_HUD_WIDTH、WINDOW_MARGIN、LAYER_FRAME、LAYER_CURSOR、LAYER_CONTENTS。
## 接口说明结束。

extends RefCounted

const DESIGN_SIZE = Vector2(640, 640)
const MAP_HUD_WIDTH = 224.0
const WINDOW_MARGIN = 16.0
const LAYER_FRAME = 0
const LAYER_CURSOR = 1
const LAYER_CONTENTS = 2


static func usable_rect(viewport_size: Vector2, reserve_hud: bool = false) -> Rect2:
	var size = viewport_size.max(Vector2.ZERO)
	var left = minf(MAP_HUD_WIDTH, maxf(0, size.x - 48)) if reserve_hud else 0.0
	return Rect2(left, 0, size.x - left, size.y)


static func fit_rect(rect: Rect2, bounds: Rect2) -> Rect2:
	var size = rect.size.max(Vector2.ZERO).min(bounds.size.max(Vector2.ZERO))
	return Rect2(
		Vector2(
			clampf(rect.position.x, bounds.position.x, bounds.end.x - size.x),
			clampf(rect.position.y, bounds.position.y, bounds.end.y - size.y)
		),
		size
	)


static func content_rect(window_size: Vector2, margin: float = WINDOW_MARGIN) -> Rect2:
	var inset = maxf(0, margin)
	return Rect2(Vector2.ONE * inset, (window_size - Vector2.ONE * inset * 2).max(Vector2.ZERO))
