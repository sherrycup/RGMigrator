## 职责：回归验证：验证闪翼特殊演出接口、等待与状态推进。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var Bitmap: Script
const Shape=preload("res://runtime/scripts/04_UI_Common/Shape.gd")
const Palette=preload("res://runtime/scripts/04_UI_Common/Palette.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	Bitmap=load("res://runtime/scripts/04_UI_Common/Bitmap.gd")
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); root.size=Vector2i(640,640)
	var bitmap=Bitmap.new(48,48); bitmap.fill_rounded_rect(Rect2i(4,4,20,16),8,Color.RED)
	var pixels=Bitmap.new(4,4); pixels.image.fill(Color8(10,20,30,128)); var clone=pixels.copy(); clone.invert()
	expect(pixels.get_pixel(0,0)==Color8(10,20,30,128) and clone.get_pixel(0,0)==Color8(245,235,225,128),"native bitmap clone and inversion preserve source alpha and never mutate caller image")
	clone.change_tone(20,-250,60)
	expect(clone.get_pixel(0,0)==Color8(255,0,255,128),"native tone shifts clamp channel endpoints while alpha stays unchanged")
	var bytes=pixels.get_pixel_data(); var restored=Bitmap.new(4,4); var decoded=restored.set_pixel_data(bytes)
	expect(decoded.ok and bytes.slice(0,4)==PackedByteArray([30,20,10,128]) and restored.get_pixel(0,0)==pixels.get_pixel(0,0),"TKTK BGRA pixel data round-trips losslessly through native owned images")
	var mask=Image.create(2,2,false,Image.FORMAT_RGBA8); mask.fill(Color8(255,255,255,128)); pixels.clip_mask(mask,1,1)
	expect(pixels.get_pixel(0,0).a8==0 and pixels.get_pixel(1,1).a8==64,"source clip-mask multiplies alpha at explicit offset and clears outside default mask")
	var impulse=Bitmap.new(3,3); impulse.set_pixel(1,1,Color.WHITE); impulse.blur2(1)
	expect(impulse.get_pixel(0,0).a8==28 and impulse.get_pixel(2,2).a8==28,"portable separable blur produces symmetric owned-image kernel")
	var mosaic=Bitmap.new(4,2); mosaic.image.fill(Color.RED); mosaic.fill_rect(Rect2i(2,0,2,2),Color.BLUE); mosaic.mosaic_rect(Rect2i(0,0,4,2),2,2)
	expect(mosaic.get_pixel(0,1)==Color.RED and mosaic.get_pixel(3,1)==Color.BLUE,"mosaic keeps independent source cell averages and rectangular bounds")
	var utils=preload("res://runtime/scripts/10_Support/Utilities/Utils.gd")
	expect(utils.adapt_text(80,20,"你好12.5%世界",true)==["你好","12.5%世","界"] and utils.adapt_text(80,20,"甲\\n乙\n丙",true)==["甲","乙","丙"],"source text adapter retains numeric grouping and flattens explicit/literal newlines")
	expect(bitmap.image.get_pixel(4,4).a==0 and bitmap.image.get_pixel(14,4)==Color.RED and bitmap.image.get_pixel(14,19)==Color.RED,"source rounded fill stays inside its explicit rectangle and has symmetric corners")
	bitmap.clear(); bitmap.gradient(Rect2i(2,2,1,8),Color.RED,Color.BLUE)
	expect(bitmap.image.get_pixel(2,2)==Color.RED,"single-pixel gradient has a defined color instead of dividing by zero")
	bitmap.draw_line2(Vector2i(1,1),Vector2i(9,9),1,[Color.RED,Color.BLUE])
	expect(bitmap.image.get_pixel(1,1)==Color.RED and bitmap.image.get_pixel(9,9)==Color.BLUE,"diagonal multi-color raster line reaches both source endpoints")
	bitmap.clear(); bitmap.draw_h8_background(Rect2i(0,0,48,48),160,8)
	expect(bitmap.image.get_pixel(24,24)==Color8(0,16,32,130) and bitmap.image.get_pixel(24,0).a>0,"source H8 layered fill uses original alpha values and deep-blue center")
	expect(bitmap.image.get_pixel(9,9).g8==255 and bitmap.image.get_pixel(9,9).a8==255,"source H8 corner glow is cyan-green at clamped opacity")
	bitmap.clear(); bitmap.draw_h8_bulge(Vector2i(4,20),Vector2i(44,20),false,8,0)
	expect(bitmap.image.get_pixel(24,12).a>0 and bitmap.image.get_pixel(4,12).a==0 and bitmap.image.get_pixel(24,20)==Color8(0,16,32,255),"source H8 bulge has inset45-degree edges, bright cap and opaque shared seam")
	bitmap.clear(); bitmap.draw_h8_inner_line(Vector2i(0,24),Vector2i(47,24),2)
	expect(bitmap.image.get_pixel(24,24).a==0 and bitmap.image.get_pixel(15,24).a>0,"source broken inner divider leaves its central gap")
	bitmap.clear(); bitmap.draw_hud_line(Rect2i(4,4,20,4),5,10,Color.RED,Color.BLUE)
	expect(bitmap.image.get_pixel(13,4).a>0 and bitmap.image.get_pixel(14,4).a==0 and bitmap.image.get_pixel(4,7).a8==183,"HUD meter retains half-width fill and per-row source24alpha falloff")
	bitmap.clear(); bitmap.draw_trapezoid_meter(Rect2i(4,4,32,8),1,2,Color.RED,Color.BLUE)
	expect(bitmap.image.get_pixel(4,4).a==0 and bitmap.image.get_pixel(4,12).a>0 and bitmap.image.get_pixel(20,4).a>0 and bitmap.image.get_pixel(21,4).a==0,"source experience trapezoid clips its slope and fills against full original width")
	var shape=Shape.new(20,20); shape.set_hexagon(8)
	expect(shape.rects.size()==11 and shape.includes(Vector2i(20,20)) and not shape.includes(Vector2i(-100,-100)),"source hexagon scanlines preserve integer construction and correct lower-bound containment")
	var original=shape.rects.duplicate(); shape.twist(10)
	expect(shape.phase==10 and shape.rects==original,"last loaded Hexagon.twist changes phase while source scanline rendering stays unrotated")
	shape.set_origin(Vector2i(24,28))
	expect(shape.includes(Vector2i(24,28)) and shape.rects[0].position==original[0].position+Vector2i(4,8),"shape coordinate setter translates all original rectangles together")
	expect(Palette.color(3)==Color8(128,255,128) and Palette.color(19).a8==128 and Palette.color_type(9).is_empty(),"Storage palette is separate from message colors and preserves source undefined gradient9")
	var style=Bitmap.panel_style(Vector2i(160,80)); var cache_bytes=style.texture.get_image().get_data()
	expect(Bitmap.panel_style(Vector2i(160,80))==style and style.texture.get_image().get_data()==cache_bytes,"source panel drawing reuses an immutable cached texture")
	var topic=load("res://runtime/scripts/03_Map/Topic.gd").new(); topic.base_position=Vector2(488,8); root.add_child(topic); topic.set_process(false); topic._process(8.0/60)
	expect(topic.text=="角色技能" and topic.window_process==8 and topic.position==Vector2(488,8) and topic.modulate.a==1,"source topic reaches its title and exact eight-step entry endpoint")
	topic.set_title(1); topic.fade=true; topic._process(8.0/60)
	expect(topic.text=="角色装备" and topic.position==Vector2(552,8) and topic.modulate.a==0,"source topic title switch and eight-step exit retain64px shift")
	topic.queue_free()
	var sight=load("res://runtime/scripts/08_Menu/Sight/SightPage.gd")
	expect(sight.hp_opacities(0)==[239,16] and sight.hp_opacities(15)==[0,255] and sight.hp_opacities(48)==[16,239] and sight.hp_opacities(63)==[255,0] and sight.hp_opacities(96)==[239,16],"enemy HP presentation preserves actual sixteen-frame crossfades and96-frame cycle")
	state.map_id=10; state.party=[1,2]; state.variables["14"]=[2,1]; state.switches["160"]=true
	state.actor(2).set_project_parameter("maxhp",300); state.actor(2).hp=240
	state.actor(2).project_fields.equip_skills={"-1":[24],"1":31,"2":32,"3":33}
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame
	game.reset_event_execution(); game._events_enabled=false; game.set_process(false); game._player.set_process(false)
	var hud: Node=game._flash_hud; hud.set_process(false); hud._process(8.0/60)
	expect(hud.rows[0].id==2 and hud.rows[1].id==1 and hud.rows[0].hp==240 and hud.rows[0].skills==[24,31,32,33],"actual map HUD displays formal role actors and original passive/first-three skill slots")
	expect(hud.window_process==8 and hud.visible_target(),"source PlayerData completes eight60Hz steps from below the canvas")
	state.variables["14"]=[1,2]; hud.refresh_rows()
	expect(hud.layout_flipped and hud.rows[0].id==1 and hud.rows[1].id==2,"actual role swap flips main/support portrait and meter layout while attribute panel follows new main")
	state.switches["160"]=false; hud.refresh_rows()
	expect(hud.rows[1].is_empty(),"source partner recruitment switch controls HUD support visibility")
	state.custom_data.values.system.show_playerdata=false; hud._process(8.0/60)
	expect(hud.window_process==0 and not hud.visible_target(),"original system.show_playerdata hides the actual state panel with its source slide")
	state.custom_data.values.system.show_playerdata=true; state.switches["6"]=true; hud._process(8.0/60)
	expect(hud.window_process==0,"source DATA_FADE hides player data independently of system flag")
	state.switches["6"]=false; hud._process(8.0/60)
	state.switches["5"]=true; hud.map_changed(10); hud._process(16.0/60)
	expect(hud.mapname_frame==16 and not hud.mapname.is_empty(),"actual transfer map name uses source16-frame entrance and current map-info name")
	hud._process(48.0/60); expect(hud.mapname_frame==64,"transfer name keeps original48-frame hold")
	hud._process(16.0/60); expect(hud.mapname_frame==80,"transfer name finishes16-frame exit without a permanent stale label")
	paused=true; var frame=hud.window_process; hud._process(1); expect(hud.window_process==frame,"paused map menus do not advance HUD motion a second time"); paused=false
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH PRESENTATION: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
