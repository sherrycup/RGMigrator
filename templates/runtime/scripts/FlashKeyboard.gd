extends RefCounted
## 0266 full kboard / 66RPG, revised by 夏娜. The original repeat counter is
## counted per query (strictly >4), so this does not substitute OS key repeat.
const SOURCE_KEYS={"$Rmouse_BUTTON_L":1,"$Rmouse_BUTTON_R":2,"$Rmouse_BUTTON_M":4,"$Rmouse_BUTTON_4":5,"$Rmouse_BUTTON_5":6,"$R_Key_BACK":8,"$R_Key_TAB":9,"$R_Key_RETURN":13,"$R_Key_SHIFT":16,"$R_Key_CTLR":17,"$R_Key_ALT":18,"$R_Key_PAUSE":19,"$R_Key_CAPITAL":20,"$R_Key_ESCAPE":27,"$R_Key_SPACE":32,"$R_Key_PRIOR":33,"$R_Key_NEXT":34,"$R_Key_END":35,"$R_Key_HOME":36,"$R_Key_LEFT":37,"$R_Key_UP":38,"$R_Key_RIGHT":39,"$R_Key_DOWN":40,"$R_Key_SELECT":41,"$R_Key_PRINT":42,"$R_Key_SNAPSHOT":44,"$R_Key_INSERT":45,"$R_Key_DELETE":46,"$R_Key_0":48,"$R_Key_1":49,"$R_Key_2":50,"$R_Key_3":51,"$R_Key_4":52,"$R_Key_5":53,"$R_Key_6":54,"$R_Key_7":55,"$R_Key_8":56,"$R_Key_9":57,"$R_Key_A":65,"$R_Key_B":66,"$R_Key_C":67,"$R_Key_D":68,"$R_Key_E":69,"$R_Key_F":70,"$R_Key_G":71,"$R_Key_H":72,"$R_Key_I":73,"$R_Key_J":74,"$R_Key_K":75,"$R_Key_L":76,"$R_Key_M":77,"$R_Key_N":78,"$R_Key_O":79,"$R_Key_P":80,"$R_Key_Q":81,"$R_Key_R":82,"$R_Key_S":83,"$R_Key_T":84,"$R_Key_U":85,"$R_Key_V":86,"$R_Key_W":87,"$R_Key_X":88,"$R_Key_Y":89,"$R_Key_Z":90,"$R_Key_LWIN":91,"$R_Key_RWIN":92,"$R_Key_APPS":93,"$R_Key_NUMPAD0":96,"$R_Key_NUMPAD1":97,"$R_Key_NUMPAD2":98,"$R_Key_NUMPAD3":99,"$R_Key_NUMPAD4":100,"$R_Key_NUMPAD5":101,"$R_Key_NUMPAD6":102,"$R_Key_NUMPAD7":103,"$R_Key_NUMPAD8":104,"$R_Key_NUMPAD9":105,"$R_Key_MULTIPLY":106,"$R_Key_ADD":107,"$R_Key_SEPARATOR":108,"$R_Key_SUBTRACT":109,"$R_Key_DECIMAL":110,"$R_Key_DIVIDE":111,"$R_Key_F1":112,"$R_Key_F2":113,"$R_Key_F3":114,"$R_Key_F4":115,"$R_Key_F5":116,"$R_Key_F6":117,"$R_Key_F7":118,"$R_Key_F8":119,"$R_Key_F9":120,"$R_Key_F10":121,"$R_Key_F11":122,"$R_Key_F12":123,"$R_Key_NUMLOCK":144,"$R_Key_SCROLL":145,"$R_Key_LSHIFT":160,"$R_Key_RSHIFT":161,"$R_Key_LCONTROL":162,"$R_Key_RCONTROL":163,"$R_Key_L_ALT":164,"$R_Key_R_ALT":165,"$R_Key_SEP":188,"$R_Key_DASH":189,"$R_Key_DOTT":190}
var held: Dictionary={}
var repeats: Dictionary={}
var key=0
var input_provider: Callable
func reset() -> void: held.clear(); repeats.clear(); key=0
static func godot_key(vk: int) -> int:
	if vk>=0x30 and vk<=0x39 or vk>=0x41 and vk<=0x5a: return vk
	if vk>=0x70 and vk<=0x87: return KEY_F1+(vk-0x70)
	if vk>=0x60 and vk<=0x69: return KEY_KP_0+(vk-0x60)
	return {0x08:KEY_BACKSPACE,0x09:KEY_TAB,0x0d:KEY_ENTER,0x10:KEY_SHIFT,0x11:KEY_CTRL,0x12:KEY_ALT,0x13:KEY_PAUSE,0x14:KEY_CAPSLOCK,0x1b:KEY_ESCAPE,0x20:KEY_SPACE,0x21:KEY_PAGEUP,0x22:KEY_PAGEDOWN,0x23:KEY_END,0x24:KEY_HOME,0x25:KEY_LEFT,0x26:KEY_UP,0x27:KEY_RIGHT,0x28:KEY_DOWN,0x2c:KEY_PRINT,0x2d:KEY_INSERT,0x2e:KEY_DELETE,0x5b:KEY_META,0x5c:KEY_META,0x6a:KEY_KP_MULTIPLY,0x6b:KEY_KP_ADD,0x6d:KEY_KP_SUBTRACT,0x6e:KEY_KP_PERIOD,0x6f:KEY_KP_DIVIDE,0x90:KEY_NUMLOCK,0x91:KEY_SCROLLLOCK,0xa0:KEY_SHIFT,0xa1:KEY_SHIFT,0xa2:KEY_CTRL,0xa3:KEY_CTRL,0xa4:KEY_ALT,0xa5:KEY_ALT,0xba:KEY_SEMICOLON,0xbb:KEY_EQUAL,0xbc:KEY_COMMA,0xbd:KEY_MINUS,0xbe:KEY_PERIOD,0xbf:KEY_SLASH,0xc0:KEY_QUOTELEFT,0xdb:KEY_BRACKETLEFT,0xdc:KEY_BACKSLASH,0xdd:KEY_BRACKETRIGHT,0xde:KEY_APOSTROPHE}.get(vk,0)
func pressed(vk: int) -> bool:
	if input_provider.is_valid(): return bool(input_provider.call(vk))
	var mouse={1:MOUSE_BUTTON_LEFT,2:MOUSE_BUTTON_RIGHT,4:MOUSE_BUTTON_MIDDLE,5:MOUSE_BUTTON_XBUTTON1,6:MOUSE_BUTTON_XBUTTON2}
	if mouse.has(vk): return Input.is_mouse_button_pressed(mouse[vk])
	var code=godot_key(vk)
	return code!=0 and Input.is_key_pressed(code)
func snapshot() -> Dictionary: return {"held":held.duplicate(),"repeats":repeats.duplicate(),"key":key}
func install(value: Dictionary) -> void: held=value.held; repeats=value.repeats; key=int(value.key)
static func invoke(custom: RefCounted,name: String,args: Array) -> Variant:
	if not name in ["press?","repeat?","trigger?"] or args.size()!=1 or not args[0] is int or args[0]<0 or args[0]>255: return custom.reject("Kboard查询需要0—255的原键位编号。")
	var service: RefCounted=custom._owner.get_ref().flash_keyboard
	if custom.keyboard_draft.is_empty(): custom.keyboard_draft=service.snapshot()
	var draft: Dictionary=custom.keyboard_draft; var code=str(args[0]); var down=service.pressed(int(args[0])); var result=false
	match name:
		"press?": draft.key=int(args[0]); result=down
		"trigger?":
			result=down and not draft.held.get(code,false); draft.held[code]=down
			if result: draft.key=int(args[0])
		"repeat?":
			if not down: draft.repeats.erase(code); draft.held[code]=false
			elif not draft.repeats.has(code): draft.repeats[code]=0; draft.key=int(args[0]); result=true
			else:
				draft.repeats[code]+=1
				if draft.repeats[code]>4: draft.repeats[code]=0; draft.key=int(args[0]); result=true
	return result
