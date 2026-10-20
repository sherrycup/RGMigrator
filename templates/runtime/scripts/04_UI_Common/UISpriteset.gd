## 职责：组织界面精灵与显示节点的创建、更新和释放。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/04_UI_Common/UISpriteset.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func add_character(view: Dictionary, rectangle: Rect2) -> TextureRect
##     参数 view（Dictionary；必填）：显示对象或视图配置。
##     参数 rectangle（Rect2；必填）：绘制矩形的位置与尺寸。
##     返回：TextureRect 类型的对象或值，供调用方继续使用。
##
## 接口说明结束。

extends Control
## Owns a set of menu portraits; textures are shared by UIResources.
const CharacterSprite = preload("res://runtime/scripts/03_Map/CharacterSprite.gd")


func add_character(view: Dictionary, rectangle: Rect2) -> TextureRect:
	var sprite := CharacterSprite.new()
	sprite.position = rectangle.position
	sprite.size = rectangle.size
	sprite.configure(str(view.character_name), int(view.character_hue))
	add_child(sprite)
	return sprite
