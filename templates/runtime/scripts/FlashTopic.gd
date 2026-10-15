extends Panel
## 0187 Window_Topic: exact title IDs and eight-step8px/32alpha motion.
const Bitmap=preload("FlashBitmap.gd")
const Resources=preload("UIResources.gd")
var title_id=2
var text="角色技能"
var fade=false
var window_process=0
var base_position=Vector2.ZERO
var _label: Label
var _clock=0.0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; mouse_filter=Control.MOUSE_FILTER_IGNORE; size=Vector2(128,80)
	add_theme_stylebox_override("panel",Bitmap.panel_style(Vector2i(128,80),0))
	_label=Label.new(); _label.position=Vector2(8,20); _label.size=Vector2(112,32); _label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _label.add_theme_font_override("font",Resources.font()); _label.add_theme_font_size_override("font_size",20); add_child(_label); refresh(); _apply()
func set_title(id: int) -> void:
	if title_id==id: return
	if id in [0,1,2]: text=["","角色装备","角色技能"][id]
	title_id=id; refresh()
func refresh() -> void:
	if _label!=null: _label.text=text
func _process(delta: float) -> void:
	_clock+=maxf(0,delta)*60; var ticks=mini(120,int(_clock)); _clock-=ticks
	window_process=clampi(window_process+(-ticks if fade else ticks),0,8); _apply()
func _apply() -> void:
	position=base_position+Vector2((8-window_process)*8,0); modulate.a=clampf(window_process*32.0/255,0,1)
