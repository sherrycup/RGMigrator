extends Control
## Owns a set of menu portraits; textures are shared by UIResources.
const CharacterSprite = preload("res://runtime/scripts/CharacterSprite.gd")


func add_character(view: Dictionary, rectangle: Rect2) -> TextureRect:
	var sprite := CharacterSprite.new()
	sprite.position = rectangle.position
	sprite.size = rectangle.size
	sprite.configure(str(view.character_name), int(view.character_hue))
	add_child(sprite)
	return sprite
