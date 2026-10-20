## 职责：按原标题逻辑像素计算命令轮播、难度卡片和页签的16帧过渡。
##
## 调用方式：
##   静态纯计算接口，由FlashTitleScreen绘制时调用；不读取运行现场，也不推进时钟。
##   坐标以原640×640逻辑画布为基准；visibility为0—16帧，movement为选项移动的槽位插值。
##
## 调用接口：
##   static func command_pose( relative: int, movement: float, visibility: int, canvas: Vector2 ) -> Dictionary
##     用途：计算命令中心坐标、缩放和透明度。
##     参数 relative（int；必填）：相对旧选中命令的槽位，通常为-2—2。
##     参数 movement（float；必填）：本次轮播已移动的槽位量，正值向右选中、图片向左移动。
##     参数 visibility（int；必填）：入场或退场已显示的帧数，取0—16。
##     参数 canvas（Vector2；必填）：当前逻辑画布的宽高，单位为像素。
##     返回：position为中心像素坐标；zoom为缩放倍数；opacity为0—1透明度。
##
##   static func mode_pose(id: int, selection: float, visibility: int, canvas: Vector2) -> Dictionary
##     用途：计算难度卡片斜向位置和透明度，EX沿用原半透明规则。
##     参数 id（int；必填）：原难度卡片编号，0—3分别为Normal、Hard、Lunatic、EX。
##     参数 selection（float；必填）：难度索引的连续插值，0—3分别为四张原卡片。
##     参数 visibility（int；必填）：入场或退场已显示的帧数，取0—16。
##     参数 canvas（Vector2；必填）：当前逻辑画布的宽高，单位为像素。
##     返回：position为中心像素坐标，opacity为0—1透明度。
##
##   static func tag_rect(visibility: int, canvas: Vector2) -> Rect2
##     用途：计算从画布右边进入的原320×48页签矩形。
##     参数 visibility（int；必填）：入场或退场已显示的帧数，取0—16。
##     参数 canvas（Vector2；必填）：当前逻辑画布的宽高，单位为像素。
##     返回：Rect2 类型的对象或值，供调用方继续使用。
##
## 接口说明结束。

extends RefCounted
## 最终0139—0142的逻辑像素与16帧插值；本类只计算，不拥有输入或时钟。


static func command_pose(
	relative: int, movement: float, visibility: int, canvas: Vector2
) -> Dictionary:
	var slot = float(relative) - movement
	var distance = absf(slot)
	var zoom = 1.0 - distance * 0.2 if distance <= 1 else 0.8 - (distance - 1) * 0.4
	var opacity = maxf(0, 256 - distance * 128) * clampf(visibility / 16.0, 0, 1) / 255
	var center = Vector2(canvas.x / 2 + slot * canvas.x / 4, canvas.y - 96 + 6 * (16 - visibility))
	return {"position": center, "zoom": maxf(0.0, zoom), "opacity": clampf(opacity, 0, 1)}


static func mode_pose(id: int, selection: float, visibility: int, canvas: Vector2) -> Dictionary:
	var relative = id - selection
	var center = Vector2(
		canvas.x / 2 + 224 * relative, 320 + 192 * relative + 6 * (16 - visibility)
	)
	var emphasis = maxf(0, 1 - absf(relative)) if id != 3 else 0.0
	return {
		"position": center,
		"opacity": clampf((128 + 128 * emphasis) / 255 * visibility / 16.0, 0, 1)
	}


static func tag_rect(visibility: int, canvas: Vector2) -> Rect2:
	return Rect2(canvas.x - 20 * visibility, 0, 320, 48)
