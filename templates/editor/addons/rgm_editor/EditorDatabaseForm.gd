@tool
extends "EditorValueForm.gd"
## Named controls replace the generic tree; unknown extension fields stay detached.
const GROUPS = {
	"Actors":[["基础",["name","class_id","initial_level","final_level","exp_basis","exp_inflation","character_hue","battler_hue"]],["初始装备",["weapon_id","weapon_fix","armor1_id","armor1_fix","armor2_id","armor2_fix","armor3_id","armor3_fix","armor4_id","armor4_fix"]],["成长",["parameters"]]],
	"Classes":[["基础",["name","position"]],["装备与有效度",["weapon_set","armor_set","element_ranks","state_ranks"]]],
	"Items":[["基础与使用",["name","description","price","consumable","scope","occasion","common_event_id","menu_se"]],["恢复与效果",["recover_hp_rate","recover_hp","recover_sp_rate","recover_sp","parameter_type","parameter_points","hit","pdef_f","mdef_f","variance"]],["属性与状态",["animation1_id","animation2_id","element_set","plus_state_set","minus_state_set"]]],
	"Skills":[["基础与使用",["name","description","sp_cost","scope","occasion","common_event_id","menu_se"]],["威力与效果",["power","atk_f","eva_f","str_f","dex_f","agi_f","int_f","hit","pdef_f","mdef_f","variance"]],["属性与状态",["animation1_id","animation2_id","element_set","plus_state_set","minus_state_set"]]],
	"Weapons":[["基础",["name","description","price"]],["能力",["atk","pdef","mdef","str_plus","dex_plus","agi_plus","int_plus"]],["属性与状态",["animation1_id","animation2_id","element_set","plus_state_set","minus_state_set"]]],
	"Armors":[["基础",["name","description","price","kind"]],["能力",["pdef","mdef","eva","str_plus","dex_plus","agi_plus","int_plus"]],["防护与状态",["auto_state_id","guard_element_set","guard_state_set"]]],
	"Enemies":[["基础与能力",["name","battler_hue","maxhp","maxsp","str","dex","agi","int","atk","pdef","mdef","eva"]],["奖励与掉落",["exp","gold","item_id","weapon_id","armor_id","treasure_prob"]],["动画与有效度",["animation1_id","animation2_id","element_ranks","state_ranks"]]],
	"States":[["基础与限制",["name","animation_id","restriction","nonresistance","zero_hp","cant_get_exp","cant_evade","slip_damage","battle_only"]],["能力倍率",["maxhp_rate","maxsp_rate","str_rate","dex_rate","agi_rate","int_rate","atk_rate","pdef_rate","mdef_rate","hit_rate","eva"]],["状态与元数据",["rating","hold_turn","auto_release_prob","shock_release_prob","guard_element_set","plus_state_set","minus_state_set"]]],
	"Animations":[["基础与素材",["name","animation_hue","position"]]],
	"CommonEvents":[["触发设置",["name","trigger","switch_id"]]],
	"System":[["基础与图像",["party_members","battler_hue"]],["界面用语",["words"]],["音乐与音效",["title_bgm","battle_bgm","battle_end_me","gameover_me","cursor_se","decision_se","cancel_se","buzzer_se","equip_se","shop_se","save_se","load_se","battle_start_se","escape_se","actor_collapse_se","enemy_collapse_se"]]]
}
const WORD_LABELS = {"gold":"货币","level":"等级","hp":"HP","sp":"SP","str":"力量","dex":"灵巧","agi":"速度","int":"魔力","atk":"攻击力","pdef":"物理防御","mdef":"魔法防御","weapon":"武器","armor1":"盾","armor2":"头部防具","armor3":"身体防具","armor4":"饰品","attack":"攻击","skill":"特技","guard":"防御","item":"物品","equip":"装备"}
var _tabs: TabContainer
var _controls: Dictionary={}
var _known: Dictionary={}
var _signature=""
var _syncing=false
var _names: Dictionary={}
var _learnings: Control
var _animation: Control
var _extensions: Button
var _extension_dialog: ConfirmationDialog
var _extension_form: VBoxContainer
var _start_picker: VBoxContainer

func _build() -> void:
	if _tabs!=null: return
	super._build(); _tree.hide(); get_child(0).hide()
	_tabs=TabContainer.new(); _tabs.use_hidden_tabs_for_min_size=false; _tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(_tabs)
	_extensions=Button.new(); _extensions.text="自定义兼容字段…"; _extensions.tooltip_text="仅原工程的额外字段；常规设置均在主界面。未知字段保留原样，不会自动执行Ruby。"; add_child(_extensions); _extensions.pressed.connect(_open_extensions)

func _make_page(title_text: String) -> VBoxContainer:
	var scroll=ScrollContainer.new(); scroll.name=title_text; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _tabs.add_child(scroll)
	var box=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(box); return box

func _refresh() -> void:
	super._refresh()
	if _tabs==null: return
	var category=str(_hints.get("",{}).get("database_category",""))
	_tree.visible=_read_only; get_child(0).hide()
	if _read_only: _tabs.hide(); _asset_scroll.hide(); _extensions.hide(); return
	var signature=category+str(_value.keys() if _value is Dictionary else [])+str(_value.get("words",{}).keys() if _value is Dictionary and _value.get("words") is Dictionary else [])
	if signature!=_signature: _signature=signature; _rebuild(category)
	_tabs.show()
	_syncing=true
	for entry in _controls.values():
		var value: Variant=_read_at(entry.path); var control: Control=entry.control
		if control is SpinBox: control.value=float(value)
		elif control is CheckBox: control.set_pressed_no_signal(bool(value))
		elif control is LineEdit:
			if control.text!=str(value): control.text=str(value)
		elif control is TextEdit:
			if control.text!=str(value): control.text=str(value)
		elif control is OptionButton:
			control.clear(); var options: Dictionary=_hint(entry.path).get("options",{}); var found=false
			for key in options:
				var native: Variant=str(key) if value is String else int(key); control.add_item(str(options[key])); control.set_item_metadata(control.item_count-1,native)
				if native==value: control.select(control.item_count-1); found=true
			if not found: control.add_item("保留原值："+str(value)); control.set_item_metadata(control.item_count-1,value); control.select(control.item_count-1)
		elif control is Button:
			control.text=_summary(value,entry.path); control.tooltip_text=control.text
		elif control is Label: control.text=_summary(value,entry.path)
	for key in _names: _names[key].configure(_value[key],key,_documents)
	if _learnings!=null: _learnings.configure(_value.learnings,_documents)
	if _animation!=null: _animation.configure(_value,_documents)
	if _start_picker!=null: _start_picker.configure(_documents,int(_value.get("start_map_id",0)),Vector2i(int(_value.get("start_x",0)),int(_value.get("start_y",0))))
	if category=="CommonEvents" and _controls.has(str(["switch_id"])): _controls[str(["switch_id"])].control.disabled=int(_value.get("trigger",0))==0
	_extensions.visible=not _extra().is_empty(); _syncing=false

func _rebuild(category: String) -> void:
	# Reuse the established image previews and pickers, without a second field UI.
	var show_assets=_asset_scroll.visible; _asset_scroll.hide(); _tabs.hide()
	if _asset_scroll.get_parent()!=self: _asset_scroll.reparent(self)
	for child in _tabs.get_children(): _tabs.remove_child(child); child.queue_free()
	_controls.clear(); _names.clear(); _learnings=null; _animation=null; _start_picker=null; _known={"id":true,"_class":true}
	if not _value is Dictionary: return
	var base: VBoxContainer
	for group in GROUPS.get(category,[]):
		var box=_make_page(group[0]); if base==null: base=box
		var grid=GridContainer.new(); grid.columns=2; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_child(grid)
		for key in group[1]:
			_known[key]=true
			if _value.has(key): _field(grid,[key])
	if base==null: base=_make_page("基本设置")
	for path in _asset_paths(_value): _known[path[0]]=true
	_asset_scroll.reparent(base); base.move_child(_asset_scroll,0); _asset_scroll.visible=show_assets
	if category=="Classes" and _value.get("learnings") is Array:
		_known.learnings=true; _learnings=preload("EditorLearningsEditor.gd").new(); _learnings.name="习得特技"; _tabs.add_child(_learnings)
		_learnings.changed.connect(func(value: Array) -> void: _put(["learnings"],value)); _learnings.edit_requested.connect(edit_path)
	if category=="Animations":
		_known.frames=true; _known.timings=true; _known.frame_max=true
		_animation=preload("EditorAnimationEditor.gd").new(); _animation.name="动画编辑"; _tabs.add_child(_animation)
		_animation.changed.connect(func(value: Dictionary) -> void: _put([],value)); _animation.edit_requested.connect(edit_path)
	if category=="System":
		for key in ["start_map_id","start_x","start_y"]: _known[key]=true
		_start_picker=preload("EditorMapLocationPicker.gd").new(); _start_picker.name="玩家起点"; _tabs.add_child(_start_picker); _tabs.move_child(_start_picker,1)
		_start_picker.chosen.connect(func(map_id: int, cell: Vector2i) -> void:
			var value: Dictionary=draft(); value.start_map_id=map_id; value.start_x=cell.x; value.start_y=cell.y; _put([],value))
		for key in ["switches","variables","elements"]:
			_known[key]=true
			if not _value.get(key) is Array: continue
			var editor=preload("EditorNamesEditor.gd").new(); editor.name={"switches":"开关名称","variables":"变量名称","elements":"属性名称"}[key]; _tabs.add_child(editor); _names[key]=editor
			editor.changed.connect(func(names: Array) -> void: _put([key],names))
		for key in ["edit_map_id","magic_number","test_troop_id","test_battlers","battle_transition"]: _known[key]=true
	if category=="Enemies": _known.actions=true
	_tabs.current_tab=0

func _caption_for(path: Array) -> String:
	var key=str(path[-1]); return str(WORD_LABELS.get(key,key)) if path.size()>1 and path[0]=="words" else str(preload("EditorDatabaseSchema.gd").LABELS.get(key,LABELS.get(key,key)))

func _field(parent: Node, path: Array) -> void:
	var value: Variant=_read_at(path); var hint=_hint(path)
	if value is Dictionary and not _is_table(value) and _audio_info(path).is_empty():
		var box=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(box)
		var heading=Label.new(); heading.text=_caption_for(path); box.add_child(heading)
		for key in value:
			if str(key).begins_with("_"): continue
			if path[0]=="words" and not value[key] is String: continue
			_field(box,path+[key])
		return
	var row=HBoxContainer.new(); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(row)
	var label=Label.new(); label.text=_caption_for(path); label.custom_minimum_size.x=125; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; row.add_child(label)
	var control: Control
	if _is_table(value) or not _audio_info(path).is_empty() or value is Array and hint.has("set") or hint.has("db") or hint.has("asset"):
		var button=Button.new(); button.clip_text=true; button.custom_minimum_size.x=90; button.pressed.connect(edit_path.bind(path)); control=button
	elif hint.has("options"):
		var choice=OptionButton.new(); choice.clip_text=true; control=choice; choice.item_selected.connect(func(index: int) -> void: if not _syncing: _put(path,choice.get_item_metadata(index)))
	elif value is bool:
		var check=CheckBox.new(); check.text="启用"; control=check; check.toggled.connect(func(on: bool) -> void: if not _syncing: _put(path,on))
	elif value is int or value is float:
		var spin=SpinBox.new(); control=spin; spin.min_value=float(hint.get("min",-99999999)); spin.max_value=float(hint.get("max",99999999)); spin.allow_greater=true; spin.allow_lesser=true; spin.step=1 if float(value)==floor(float(value)) else 0.01
		if str(path[-1]).ends_with("_rate") or path[-1] in ["hit","variance","treasure_prob","volume","pitch"]: spin.suffix="%"
		elif str(path[-1]).ends_with("_hue"): spin.suffix="°"
		spin.value_changed.connect(func(n: float) -> void: if not _syncing: _put(path,int(n) if spin.step==1 else n))
	elif value is String:
		if path[-1]=="description":
			var text=TextEdit.new(); control=text; text.custom_minimum_size.y=70; text.text_changed.connect(func() -> void: if not _syncing: _put(path,text.text))
		else:
			var text=LineEdit.new(); control=text; text.text_changed.connect(func(text_value: String) -> void: if not _syncing: _put(path,text_value))
	else: control=Label.new()
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(control); _controls[str(path)]={"path":path,"control":control}

func _summary(value: Variant, path: Array) -> String:
	if not _audio_info(path).is_empty(): return "%s · 音量%d%% · 声调%d%%" % ["无音频" if str(value.get("name","")).is_empty() else str(value.name),int(value.get("volume",100)),int(value.get("pitch",100))]
	if _is_table(value): return "编辑 %s…" % ("99级 × 6项能力" if path[-1]=="parameters" else "具名有效度 A…F" if path[-1] in ["element_ranks","state_ranks"] else "表格")
	if value is Array:
		var names: Array=[]
		for id in value.slice(0,3): names.append(_documents.reference_label(str(_hint(path).get("set","")),int(id)))
		return "%d项 · %s%s" % [value.size(),"、".join(names),"…" if value.size()>3 else ""]
	return _display(value,path)

func _extra() -> Dictionary:
	var result: Dictionary={}
	if _value is Dictionary:
		for key in _value:
			if not _known.has(key) and not str(key).begins_with("_"): result[key]=_value[key]
	return result.duplicate(true)

func _open_extensions() -> void:
	var extra=_extra()
	if extra.is_empty(): return
	if _extension_dialog==null:
		_extension_dialog=ConfirmationDialog.new(); _extension_dialog.title="自定义兼容字段 · 来自原工程，常规设置在主界面"; _extension_dialog.get_ok_button().text="应用兼容字段"; add_child(_extension_dialog)
		_extension_form=preload("EditorValueForm.gd").new(); _extension_form.custom_minimum_size=Vector2(650,430); _extension_dialog.add_child(_extension_form)
		_extension_dialog.confirmed.connect(func() -> void:
			var edited: Dictionary=_extension_form.draft(); var current: Dictionary=draft()
			for key in _extra():
				if edited.has(key): current[key]=edited[key]
			_put([],current))
	_extension_form.configure(extra,{},_documents); _extension_dialog.popup_centered(Vector2i(750,590))

