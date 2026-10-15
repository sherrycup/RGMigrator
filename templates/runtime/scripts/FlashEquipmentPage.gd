extends Control
## 0258 page uses the final source Game_Actor six-slot equip implementation;
## source 0123's obsolete five RGSS getters are adapted to this same array.
const Data=preload("RuntimeData.gd")
const Catalog=preload("FlashObjectCatalog.gd")
const Actions=preload("FlashActions.gd")
const Resources=preload("UIResources.gd")
const Bitmap=preload("FlashBitmap.gd")
const SLOT_NAMES=["主手","副手","防具一","防具二","饰品一","饰品二"]
const DATABASES=["Weapons","Deputies","Armors","Armors","Ornaments","Ornaments"]
signal back_requested
signal sound_requested(key: String)
var page="flash_equipment"
var actor_id=0
var slot=0
var index=0
var choosing=false
var candidates: Array=[]
var preview: Dictionary={}
var message=""
var _content: Control
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); refresh()
func candidate_rows() -> Array:
	var result: Array=[]; var actor=RuntimeState.actor(actor_id); var database: String=DATABASES[slot]
	var inventory_kind="weapon" if database=="Weapons" else "armor" if database=="Armors" else "ornament"
	if database!="Deputies":
		for entry in RuntimeState.inventory_entries():
			if entry.kind!=inventory_kind or entry.count<=0: continue
			var classes: Variant=Catalog.value(RuntimeState.custom_data,database,int(entry.id),"class_set")
			if classes is Array and not classes.is_empty() and not classes.has(actor.class_id): continue
			result.append({"id":entry.id,"name":entry.name,"description":entry.description,"count":entry.count})
	result.append({"id":0,"name":"卸下","description":"","count":0}); return result
func preview_equipment(id: int) -> Dictionary:
	var actor=RuntimeState.actor(actor_id); var selected=actor.equipment.duplicate(); selected[slot]=id; var values: Dictionary={}
	for key in actor.PROJECT_KEYS: values[key]=actor._parameter_with_states(key,actor.state_ids,selected)
	return values
func refresh() -> void:
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	var actor=RuntimeState.actor(actor_id)
	if actor==null: _label("没有可操作的角色",Rect2(16,16,608,40)); return
	_panel(Rect2(0,0,640,64)); _panel(Rect2(0,64,272,416)); _panel(Rect2(272,64,368,208)); _panel(Rect2(272,272,368,208))
	_label(message if not message.is_empty() else actor.actor_name+" · 角色装备",Rect2(16,16,608,32))
	var shown: Dictionary=preview_equipment(int(candidates[index].id)) if choosing and not candidates.is_empty() else {}
	preview=shown
	for i in actor.PROJECT_KEYS.size():
		var key: String=actor.PROJECT_KEYS[i]; var old=actor.get_parameter(key)
		_label("%s  %s%s" % [{"maxhp":"生命","maxsp":"魂量","patk":"物攻","pdef":"物防","matk":"魔攻","mdef":"魔防","agi":"速度","int":"智力"}[key],old," → "+str(shown[key]) if shown.has(key) else ""],Rect2(16,80+i*40,240,32))
	for i in 6:
		var id=int(actor.equipment[i]); var row=RuntimeState.custom_data.record(DATABASES[i],id)
		var button=Button.new(); button.position=Vector2(288,80+i*30); button.size=Vector2(336,28); button.text=SLOT_NAMES[i]+"  "+(str(row.get("name","")) if not row.is_empty() else "—"); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",16)
		if i==slot: button.modulate=Color("a9ffe1")
		button.pressed.connect(func():slot=i; choosing=false; refresh()); _content.add_child(button)
	if choosing:
		var start=maxi(0,index-4)
		for i in range(start,mini(candidates.size(),start+5)):
			var button=Button.new(); button.position=Vector2(288,288+(i-start)*32); button.size=Vector2(336,30); button.text=str(candidates[i].name); button.add_theme_font_override("font",Resources.font()); button.add_theme_font_size_override("font_size",16)
			if i==index: button.modulate=Color("a9ffe1")
			button.pressed.connect(func():index=i; refresh()); _content.add_child(button)
	_label("↑↓选择 · Enter确认 · PageUp/PageDown角色 · Esc返回",Rect2(16,496,608,56)); queue_redraw()
func activate() -> Dictionary:
	if not choosing: candidates=candidate_rows(); choosing=true; index=0; refresh(); return {"ok":true}
	var result=Actions.equip(RuntimeState,actor_id,slot,int(candidates[index].id)); message="" if result.ok else str(result.get("message",""))
	if result.ok: choosing=false
	refresh(); sound_requested.emit("equip_se" if result.ok else "buzzer_se"); return result
func back() -> void:
	if choosing: choosing=false; message=""; refresh()
	else: back_requested.emit()
func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: back()
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()
	elif key in [KEY_UP,KEY_DOWN]:
		if choosing: index=posmod(index+(-1 if key==KEY_UP else 1),candidates.size())
		else: slot=posmod(slot+(-1 if key==KEY_UP else 1),6)
		refresh()
	elif key in [KEY_PAGEUP,KEY_PAGEDOWN] and not choosing and not RuntimeState.party.is_empty(): actor_id=int(RuntimeState.party[posmod(RuntimeState.party.find(actor_id)+(-1 if key==KEY_PAGEUP else 1),RuntimeState.party.size())]); refresh()
func _panel(rect: Rect2) -> void:
	var panel=Panel.new(); panel.position=rect.position; panel.size=rect.size; panel.add_theme_stylebox_override("panel",Bitmap.panel_style(Vector2i(rect.size))); _content.add_child(panel)
func _label(text: String,rect: Rect2) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",17); _content.add_child(label)
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color("0b171e"))
