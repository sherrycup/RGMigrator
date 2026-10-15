extends SceneTree
var Text: Script
var Row: Script
const Scripts=preload("res://runtime/scripts/ScriptRuntime.gd")
const Data=preload("res://runtime/scripts/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Text=load("res://runtime/scripts/FlashMessageText.gd"); Row=load("res://runtime/scripts/FlashTextRow.gd")
	var state=root.get_node("RuntimeState"); state.party=[2]; state.variables["10"]="\\V[11]"; state.variables["11"]=8
	var parsed=Text.parse("\\m[艾蕾]\\p[384,304]\\al\\mo[1]\\n[2]：\\v[10]\\c[5]★\\w[20]\\.\\t[10]",state)
	expect(parsed.ok and parsed.metadata.m=="艾蕾" and parsed.metadata.p=="384,304" and parsed.metadata.mo=="1" and parsed.metadata.has("al"),"source box name/position/arrow/mode metadata is extracted before row drawing")
	expect(parsed.text.begins_with(state.actor(2).actor_name+"：8") and parsed.tokens.any(func(token):return token is Array and token==[String.chr(1),5]),"actual actor name and recursive variables resolve beside original color token")
	expect(parsed.tokens.has([String.chr(5),20]) and parsed.tokens.has([String.chr(7)]) and parsed.tokens.has([String.chr(29),10]),"source wait/wake/terminate controls retain ordered values")
	var encoded=Text.parse(String.chr(1)+"[5]甲"+String.chr(27)+"[1]"+String.chr(28)+"[8]乙",state,false)
	expect(encoded.ok and encoded.tokens[0]==[String.chr(1),5] and Row.new(encoded.text,state).halign==1 and Row.new(encoded.text,state).line_space==8,"already transcoded RGSS control bytes use the same native row parser and metrics")
	var flag=Text.parse("\\FB[yes]甲\\FI[wrong]乙",state)
	var punctuation=Text.parse("甲!乙\\!丙",state)
	expect(punctuation.ok and punctuation.text.begins_with("甲!乙") and punctuation.tokens.has([String.chr(16)]),"literal exclamation remains text while escaped exclamation retains the source pause control")
	expect(flag.ok and flag.text=="\\FB[yes]甲\\FI[wrong]乙","source FB/FI only recognizes literal T/F flags and leaves other strings visible")
	expect(Text.frame_duration(20)==30 and Text.frame_duration(1)==2 and Text.frame_duration(20,40)==20,"rxdata message authoring40 scales source delays at actual60 rather than using different Scripts mirror clocks")
	parsed=Text.parse("\\\\V[10]\\unknown[z]",state)
	expect(parsed.ok and parsed.text=="\\V[10]\\unknown[z]","escaped variable and unknown control remain literal, not evaluated or discarded")
	state.variables["10"]="\\V[11]"; state.variables["11"]="\\V[10]"
	expect(not Text.parse("\\V[10]",state).ok,"cyclic recursive source substitutions fail explicitly instead of freezing engine")
	state.variables["10"]=[1,2]
	expect(not Text.parse("\\V[10]",state).ok,"unadapted Ruby collection string semantics do not silently turn a variable into zero")
	parsed=Text.parse("\\I[2]",state)
	expect(parsed.ok and parsed.text.ends_with("蓝钥匙") and parsed.tokens[0][0]==String.chr(24),"source RPG item code expands its native icon/name rather than external object wrapper")
	var style=Text.defaults(); Text.apply_style(style,[String.chr(25),"T"]); Text.apply_style(style,[String.chr(26),"T"])
	expect(style.bold and style.italic,"corrected source TextBox/HintBox FI agrees with original row metrics and T/F bold flags")
	Text.apply_style(style,[String.chr(26),"F"])
	expect(not style.italic and Text.color(3)==Color8(0,170,170,128) and Text.color(-1)==Color.BLACK,"source alpha colors and default black are preserved")
	var row=Row.new("\\A[1]\\LS[8]\\C[5]玄鸟暴打屑蛋",state)
	expect(row.failure.is_empty() and row.halign==1 and row.valign==1 and row.line_space==8 and row.text_width>0 and row.text_height==Text.font(Text.defaults()).get_string_size("玄",HORIZONTAL_ALIGNMENT_LEFT,-1,20).y,"original TextRow setup, source dual alignment and measured Chinese glyphs")
	expect(row.peer()==[String.chr(1),5] and row.getchar()==[String.chr(1),5] and row.peer()=="玄","per-row cursor distinguishes peek from read and source parameter-array token")
	row.goto_tail(); var eof=row.eof(); row.shift(-2)
	expect(eof and row.getchar()=="屑" and row.getchar()=="蛋" and row.getchar()==null,"source head/tail and signed displacement clamp around final Unicode glyphs")
	row.goto_head(); row.shift(-9)
	expect(row.cursor==0 and not row.eof(),"source row cursor never moves before head")
	var large=Row.new("a\\FS[40]b\\EX[12]",state)
	expect(large.text_height>row.text_height and large.text_width>Row.new("ab",state).text_width+12,"font size and source explicit blank fill affect measured row geometry")
	expect(Row.new("a\\~hidden",state).text_width==Row.new("a",state).text_width and Row.new("\\FS[40]",state).text_height==0,"source close ends measurement and unpainted font control does not add a glyph height")
	expect(Row.new("\\ic[]",state).text_width==36 and Row.new("\\ic[]",state).text_height==32,"source empty bitmap reserves original32px icon plus4px spacing")
	state.variables["10"]=42
	var native=Scripts.new_object("Message::TextRow",["\\C[5]玄鸟"],state)
	expect(native.ok and native.value.__custom_ref=="flash_text_row","actual source Message::TextRow.new resolves to verified native GDScript adapter without loading unsafe window Ruby")
	var first=Scripts.call_method(native.value,"getchar",[],state); var second=Scripts.call_method(native.value,"peer",[],state)
	expect(first.ok and first.value==[String.chr(1),5] and second.ok and second.value=="玄","actual native source row calls share the same transactional cursor")
	Scripts.call_method(native.value,">>",[1],state)
	expect(Scripts.call_method(native.value,"getchar",[],state).value=="鸟","source native right-shift changes next character without a second row")
	var value=Scripts.call_transaction(state,{"source":"text-row-draft"},func(env):
		env.index_set({"__state_table":"variable"},10,99)
		var result=env.invoke(env.type_ref("Message::TextRow"),"new",["\\V[10]"])
		return env.invoke(result,"text",[]))
	expect(value.ok and value.value=="99" and state.variables["10"]==99,"source row expansion reads earlier writes in the same draft transaction")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MESSAGE TEXT: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
