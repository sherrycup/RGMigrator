extends SceneTree
const Catalog=preload("res://runtime/scripts/FlashObjectCatalog.gd")
const Data=preload("res://runtime/scripts/RuntimeData.gd")
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
class CatalogInput extends RefCounted:
	var definitions: Dictionary={}
	var values: Dictionary={"objects":{"equipment":{}}}
	var failure=""
	func record(database: String,id: int) -> Dictionary: return definitions.get(database+":"+str(id),{})
	func reject(message: String) -> Variant: failure=message; return null
	func data_ref(kind: String,id: int,database: String) -> Dictionary: return {"__custom_ref":kind,"id":id,"database":database,"event":0}
	static func _integer(value: Variant) -> bool: return value is int or value is float and is_finite(value) and value==floor(value)
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	var input=CatalogInput.new()
	var zero=Catalog.equipment_ref(input,0,0)
	expect(zero!=null and zero.id==0 and Catalog.value(input,"Weapons",0,"patk")==0 and Catalog.value(input,"Weapons",0,"name")=="","source equipment ID zero is a default weapon object, rather than nil")
	expect(Catalog.equipment_ref(input,0,1000)==null and input.failure.is_empty(),"source equipment alone bounds its cache lookup at 999")
	var missing=Catalog.construct(input,"Game_Item",[9999])
	expect(missing!=null and missing.id==9999 and Catalog.value(input,"Items",9999,"occasion")==3 and Catalog.value(input,"Items",9999,"scope")==0 and Catalog.value(input,"Items",9999,"consumable")==false,"standalone source objects retain rescue defaults when no RPG record exists")
	Catalog.construct(input,"Game_Deputy",[0])
	expect(input.failure.contains("Game_Deputy") and input.failure.contains("Deputy.exdata"),"missing source deputy is diagnosed even for ID zero")
	input.failure=""
	Catalog.construct(input,"Game_Armor",[1.5])
	expect(not input.failure.is_empty(),"fractional object identity is rejected explicitly")
	input.failure=""
	var item={"icon_name":"native_icon","occasion":2,"scope":1,"animation1_id":3,"animation2_id":4,"common_event_id":5,"consumable":true,"name":"native_name","description":"native_description","price":999,"_custom_data":{"external":{"settings":{"name":"药水<恢复>","price":7,"description":"first\nsecond\n\n","occasion":0,"scope":false,"consumable":false}}}}
	input.definitions["Items:1"]=item
	expect(Catalog.value(input,"Items",1,"name")=="药水" and Catalog.value(input,"Items",1,"type")=="恢复" and Catalog.value(input,"Items",1,"price")==7,"source item parses its external name tag and price")
	expect(Catalog.value(input,"Items",1,"description")==["first","second"],"source multiline description omits all trailing empty lines")
	expect(Catalog.value(input,"Items",1,"occasion")==0 and Catalog.value(input,"Items",1,"scope")==1 and Catalog.value(input,"Items",1,"consumable")==true,"Ruby truthiness preserves numeric zero overrides and falls back for literal false")
	expect([Catalog.value(input,"Items",1,"icon_name"),Catalog.value(input,"Items",1,"animation1_id"),Catalog.value(input,"Items",1,"animation2_id"),Catalog.value(input,"Items",1,"common_event_id")]==["native_icon",3,4,5],"all source item getters use their native database fallback")
	var weapon={"atk":9,"pdef":6,"agi_plus":4,"int_plus":3,"animation1_id":2,"animation2_id":8,"icon_name":"sword","_custom_data":{"external":{"settings":{"name":"weapon","class_set":[2],"patk":0,"resist_table":[0,1,2]}}}}
	input.definitions["Weapons:1"]=weapon
	expect([Catalog.value(input,"Weapons",1,"patk"),Catalog.value(input,"Weapons",1,"matk"),Catalog.value(input,"Weapons",1,"agi"),Catalog.value(input,"Weapons",1,"int_plus")]==[0,6,4,3],"weapon preserves zero patk override and original pdef-to-matk fallback plus both aliases")
	expect(Catalog.value(input,"Weapons",1,"class_set")==[2] and Catalog.value(input,"Weapons",1,"resist")==[0,1,2],"weapon class restriction and source three-component resist example are retained without inventing components")
	var settings=Catalog.value(input,"Weapons",1,"setting")
	expect(not settings.has("class_set") and not settings.has("name") and settings.patk==0 and weapon._custom_data.external.settings.class_set==[2],"wrapper setting excludes constructor fields without mutating source definitions")
	input.definitions["Armors:1"]={"kind":1,"pdef":7,"mdef":5,"agi_plus":2,"int_plus":1,"_custom_data":{"external":{"settings":{"hp":12}}}}
	expect([Catalog.value(input,"Armors",1,"kind"),Catalog.value(input,"Armors",1,"hp"),Catalog.value(input,"Armors",1,"hp_plus"),Catalog.value(input,"Armors",1,"pdef"),Catalog.value(input,"Armors",1,"mdef"),Catalog.value(input,"Armors",1,"agi_plus"),Catalog.value(input,"Armors",1,"int")]==[1,12,12,7,5,2,1],"armor exposes source kind, hp alias, defenses and native speed/personality")
	var expected: Array=[]
	for definition in Data.database("Classes"):
		if definition is Dictionary and definition.get("armor_set",[]).has(1): expected.append(int(definition.id))
	expect(Catalog.value(input,"Armors",1,"class_set")==expected,"armor class restrictions fall back to actual native Classes armor_set")
	input.definitions["Ornaments:1"]={"atk":99,"pdef":99,"agi_plus":99,"icon_name":"ignored_native","_custom_data":{"external":{"settings":{"patk":2,"hp":3,"agi":4,"class_set":[1]}}}}
	expect([Catalog.value(input,"Ornaments",1,"patk"),Catalog.value(input,"Ornaments",1,"hp_plus"),Catalog.value(input,"Ornaments",1,"agi"),Catalog.value(input,"Ornaments",1,"pdef"),Catalog.value(input,"Ornaments",1,"icon_name")]==[2,3,4,0,""],"ornament exclusively uses external values and source defaults")
	expect(Catalog.is_a("Ornaments","Game_Ornament") and Catalog.is_a("Ornaments","Game_Object") and Catalog.is_a("Ornaments","Object") and not Catalog.is_a("Ornaments","Game_Armor"),"typed source wrappers keep the declared superclass rather than treating ornament as armor")
	var created=Scripts.new_object("Game_Item",[1],state)
	expect(created.ok and created.value.get("__custom_ref")=="project_object" and created.value.database=="Items","source constructor is callable through the shared script transaction: "+str(created.get("message","")))
	if created.ok:
		var description=Scripts.call_method(created.value,"description",[],state)
		expect(description.ok and description.value==["第一行","第二行","第三行","第四行。"],"actual original external item description is available through the migrated object")
	for type_name in ["Game_Weapon","Game_Armor","Game_Ornament"]:
		var object=Scripts.new_object(type_name,[1],state)
		var kind=Scripts.call_method(object.value,"is_a?",[state.custom_data.named("Game_Object")],state) if object.ok else object
		expect(object.ok and kind.ok and kind.value==true and Catalog.class_name_for(object.value.database)==type_name,"actual source "+type_name+" constructor and Game_Object ancestry use the finite typed entry")
	# Fatal case is covered in FlashFailureIsolationProbe: deputy
	for message in failures: printerr("FAIL: ",message)
	print("FLASH OBJECTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
