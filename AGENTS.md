# RGMigrator ver0.2 — 开发代理与运行时接口契约

本文件是后续事件阶段的单一接入文档，按 ver0.2 实际源码整理。先读本文件即可定位现有类、调用入口、参数、等待条件、存档边界和测试；修改类内部实现时仍需阅读该类源码。不要凭 RGSS 同名类猜测已有方法。

ver0.2 仅统一版本并归档已验收的 ver0.11–ver0.19 基础，不新增事件命令、不改变默认运行行为。以下“待接入”是开发约束，不是已完成的功能。接口改变时必须同步本文件并运行文档一致性检查。

## 1. 工作范围和禁止事项

- 仅修改 RGMigrator 仓库；父目录 rm_template/ 是只读输入，output/ 等用户已验收工程不得覆盖。
- Godot 4.5+ 标准版、Windows、纯 GDScript、Compatibility。4.7.2 是当前测试引擎；版本号 ver0.2 不是 Godot 引擎版本。
- 不执行/自动转换 Ruby，不迁移 RTP 或 RM 旧存档，不恢复自定义魔塔战斗/公式/窗口，不添加默认回合制战斗。
- 不进行 Git 提交/发布，不破坏用户已有修改。新增事件功能必须在用户明确的版本范围内。
- 正式运行状态与独立预览分开；不得把预览按钮当成实际事件已接通的证据。
- 数据库定义和共享纹理按只读使用；运行状态、色相/色调材料、动画进度归各实例。
- 命令失败须给出地图、事件、页、公共事件和命令位置；不能静默忽略不支持的参数、半执行交易或伪造缺失数值。

## 2. 路径、加载和实际结构

源模板为 templates/runtime/scripts/*.gd；生成工程内为 res://runtime/scripts/*.gd。模板中的 res://runtime 路径只在生成工程里成立，不能在迁移器主工程直接运行这些类。场景模板位于 templates/runtime/scenes/，生成到 res://scenes/。

多数文件是 Script 资源，不声明 class_name；通过 preload/load 实例化，不假设存在 Game_Actor 等全局类。唯一游戏运行状态入口是生成工程的 Autoload RuntimeState，继承 Node；其子节点 audio 独立于地图场景。迁移器自身不注册这个 Autoload。

```text
迁移器 Main -> Validator -> MigrationPipeline
                         -> AssetCopier / DataConverter / TestSetupGenerator
                         -> ProjectGenerator / MigrationReportWriter

生成工程
  RuntimeData（静态只读定义＋独立测试覆盖层）
  RuntimeState（Autoload，统一状态与服务入口）
    actors[id] -> ActorState -> ActorParameters
    party / inventory / gold / switches / variables / self_switches
    player_motion -> CharacterMotion
    screen -> ScreenState -> PictureState[]
    map_view -> MapViewState
    map_effects -> MapEffectsState（目前包含天气）
    timer -> GameTimer
    audio -> AudioRuntime
  Title.tscn -> Title
  Game.tscn -> Game（组合协调，不继承 RGSS Scene_Map）
    MapRuntime -> MapTileRow[] / MapEvent[]
    PlayerController --继承--> MapCharacter <--继承-- MapEvent
                       motion -> CharacterMotion
    MapCamera -> MapViewState
    ScreenRenderer -> PictureSprite[]
    MapEffectsRenderer -> 全景 / 雾 / WeatherRenderer / 计时文字
    TransitionRenderer
    EventInterpreter <信号/恢复> DialogueOverlay / 商店
    MenuCoordinator -> MenuScene -> InventoryScene / SkillScene / SaveSlots / ShopScene
                                  -> 测试工具
  WindowCommand --继承--> WindowSelectable --继承--> WindowBase
  CharacterSprite / UISpriteset / RmxpAnimationPlayer
  RmxpCache -> UIResources + RuntimeData.asset_index
  SaveService -> SaveCodec -> 脱离现场校验 -> RuntimeState.restore_prepared
```

这是组合关系与继承关系的区别：只有箭头明确写“继承”的人物链、窗口链属于脚本继承，其余主要为持有/调用关系。技能、职业、装备、State 定义目前是数据库 Dictionary，不是已经存在的 SkillState/StateState/游戏战斗类。

### 2.1 RGSS 职责对应与 Game_Screen 约束

- Game_Actors/Game_Actor：RuntimeState.actors + actor(id) / ActorState。
- Game_Party/Game_Switches/Game_Variables/Game_SelfSwitches：RuntimeState 的对应字段，目前未拆成独立同名类。
- Game_Character/Game_Player/Game_Event：MapCharacter / PlayerController / MapEvent，加独立 CharacterMotion。
- Game_Map/Spriteset_Map/Tilemap：MapRuntime 加 MapTileRow、MapCamera 和各显示组件；非一个 RGSS 式主循环。
- Scene_*：Title / Game / MenuScene / 各功能页面，MenuCoordinator 协调暂停与返回；状态页在 MenuScene 内，没有独立 StatusScene 类。
- Window_*：WindowBase / WindowSelectable / WindowCommand；Sprite/Spriteset 菜单角色显示由 CharacterSprite / UISpriteset 提供。
- Game_Screen 已有部分：ScreenState 管图片、色调、闪光、震动。当前天气仍存于 MapEffectsState，不存在 ScreenState.weather()，不能写成已经统一的接口。
- 用户已明确：天气必须由 Game_Screen 对应层统一管理。后续接入天气事件前，先把天气纳入屏幕层的统一控制/生命周期（可以组合子模块），保证只有一份状态；同时处理新游戏重置、换图保留、菜单暂停和存读档。不能给事件或渲染器另建天气副本。
- 全景/雾来自地图图块集；显示矩形/跟随中心属于地图视图；音频属于独立音频服务；不要仅因“看起来是画面效果”就把一切塞到 Game_Screen。
- 本次版本整理未执行上述天气归属重构。当前可调用接口仍是 map_effects.weather(type,power,seconds)。

## 3. 所有调用共享的约定

- 数据库名称区分大小写：Actors、Classes、Items、Weapons、Armors、Skills、States、Animations、Tilesets、CommonEvents。源 ID 保留，正整数；0 在装备/动画等特定接口表示空，不是有效角色。
- JSON 数字可能是 float；ID 先验证为整数再 int()，不能依赖 Array.has 对 1 和 1.0 的相等判定。
- 方向数字 2/4/6/8 = 下/左/右/上；地图底层 can_move 用 Vector2i 单位方向，而人物 move_straight 用方向数字。
- 地图一格 32px，格坐标与平滑显示位置分开；real_x/real_y 是像素，不是旧 RGSS 的 128 单位。
- 时长一律秒，推进 delta 也是秒。RM 命令的旧帧数在解释器接入边界换算（标准 40 帧/秒），不能让底层再次 /40。动画数据帧按 0.05 秒一帧（20 动画帧/秒）。
- 普通动作结果为 Dictionary，至少 ok；失败含 message。先检查 ok，再读其他字段。有的成功没有 message/changed，不要无条件取值。
- 查询可以返回 null、{}、[] 或 false，按各类契约判断；null 表示无法计算，不能擅自当作 0。
- decode() 不修改现场；ScreenState 返回 {ok,screen}，PictureState 返回 {ok,picture}，MapViewState/MapEffectsState/GameTimer 返回 {ok,value}，不要混用。
- 动画、音频、过渡开始成功不代表执行完成。等待用实际状态/完成信号，不用阻塞 sleep，不在每帧重复 start/play。
- 带前导下划线的方法/字段是内部实现；附录只列非下划线方法及带参数构造器。Godot 自带生命周期回调不作为事件接入 API。
- state_changed 用于刷新界面；角色 changed 已转发。现有开关/变量/背包命令有直接写字段的路径，未来统一写入口需兼容现有格式，不能在 UI 或解释器维护第二份状态。

## 4. RuntimeState：事件优先调用的入口

### 4.1 全局状态和初始化

字段：actors（整数ID→ActorState）、party（整数ID列表）、inventory（"item:ID"/"weapon:ID"/"armor:ID"→0..99）、gold、steps、play_seconds、switches/variables（字符串ID键）、self_switches（"地图ID:事件ID:A..D"键）、save_disabled、menu_disabled、playing、testing_enabled、diagnostics。

player_x/player_y/player_direction 代理 player_motion 的逻辑坐标/方向。register_player/register_game 持弱引用，player()/game() 无有效地图节点时返回 null。不要缓存跨标题/新游戏的节点引用。

begin_new_game(system,testing_override={}) 重置所有运行状态、角色注册表、屏幕/镜头/表现/计时器，停止音频，读取起点并只发放一次测试物资。重复看菜单用 actor(id)，不是 begin_new_game 或 actor(id,true)。change_party(id,true,initialize) 的 initialize=true 才重建该角色；移出队伍不抹去其注册状态。record_step() 只用于成功走完普通一格。

self_switch_key(map,event,letter) 生成上述键。report_diagnostic(message) 去重存储并发送 diagnostic_added，但不会自动弹出对话或停止事件，解释器需要负责这一层。

### 4.2 角色、背包、装备与商店

actor(id,reset=false) 返回同一个注册对象，缺记录返回 null 并诊断。party_snapshots() 返回脱离数据库的显示快照，跳过缺失成员。actor_parameter_sources(id,key) 返回来源字典或 {}。

change_actor_parameter 增加的是永久 plus，不是最终值增量；set_actor_parameter 设置精确最终值；set_actor_parameter_plus 设置永久 plus。set/change_actor_experience、set/change_actor_level、set/change_actor_vital 是设置/增量对，vital key 仅 hp/sp。recover_actor_vitals 只回满，不清状态。rename_actor、change_actor_class、set_actor_graphic 提供身份变更；不要直接写 class_id/equipment 绕过回收和校验。

change_skill(id,skill,learning)、has_skill、skill_ids；change_state(id,state,adding)、has_state、state_ids_for(include_equipment=true)、clear_states。角色不在队伍也可以通过注册表操作；无效引用返回失败。状态附加/解除仅登记，不等于状态底层战斗逻辑已实现。

inventory_entries() 返回 [{kind,id,count,name,description,icon_name,missing}]；inventory_count 查询。use_item(item,target_actor) 只支持菜单可用、存活队友单体/全体的确定性 HP/SP 恢复；不执行技能效果/公共事件/伤害/复活/状态/随机效果，失败不消耗。

equip_preview(actor,slot,id) 返回 {ok,before,after,equipment}，不提交；equip 提交库存交换。slot=0武器、1盾、2头部防具、3身体防具、4饰品；id=0卸下，仍须满足固定槽位/回收库存要求。测试装备只豁免有效职业装备表，不豁免槽位固定。

shop_buy(goods,kind,id,quantity)/shop_sell(kind,id,quantity) 原子交易。goods 是 [[0物品/1武器/2防具,ID],...]，不包含自定义价格；kind 用 item/weapon/armor。购买数据库价格，出售半价取整；库存99、商店金币9999999；出售背包物品，不出售身上装备。

### 4.3 人物、屏幕、地图与音频

configure_player(value) 原子部分更新：move_speed=1..6（默认4）、walk_anime、step_anime、direction_fix、through、transparent（布尔）、opacity=0..255、blend_type=0..2、idle_pattern=0..3。默认像素/秒10×2^速度；方向固定不禁移动，穿透不越地图边界。

show_picture(number,name,pose)、move_picture、rotate_picture、tint_picture、erase_picture：编号1..50。优先通过 RuntimeState，以校验素材存在、测试素材权限并保持缺素材时原图；不要事件直接调用 screen.show_picture 绕过素材预检。
pose={origin:0左上/1中心,x,y,zoom_x,zoom_y,opacity,blend_type}，x/y 为窗口逻辑像素（-1000000..1000000），缩放0..10000百分比，透明度0..255，混合0正常/1加算/2减算；部分更新允许省略字段。色调=[R,G,B,gray]，RGB=-255..255，gray=0..255；闪光RGBA=0..255。旋转-36000..36000度/秒，正数逆时针；震动振幅0..100px、频率0..60Hz。屏幕方法见 ScreenState 附录。

configure_map_view({view_rect:[],follow_center:[],follow_enabled:true}) 原子部分更新。view_rect=[x,y,w,h] 是窗口里的地图区域，follow_center=[x,y] 是区域内跟随点；[] 表示全窗口/区域中心，不是0,0。屏幕尺寸改变时显示区域裁切至合法范围。新游戏读取 project.godot 的 rgmigrator/map_view_rect、map_follow_center。
scroll_map(direction,tiles,seconds) 手动滚动、停止跟随，重复滚动未结束则拒绝；resume_map_follow() 取消剩余滚动并恢复跟随。等待观察 map_view.scroll_remaining；显示原点在 map_view.display（地图像素）。

configure_map_effects(changes) 先检查非空素材再提交；MapEffectsState.configure 只检查格式，不加载素材。可修改：panorama_name/hue、fog_name/hue/opacity/blend_type/zoom/sx/sy。name=""关该层；色相0..360，fog_zoom=1..10000%、sx/sy=-10000..10000，自动偏移每秒-5×sx/sy px。全景在透明图层后半速视差；不透明地图覆盖全景是正常遮挡。
map_effects.tint_fog(tone,seconds)、fade_fog(opacity,seconds)、weather(type,power,seconds) 目前是现有底层入口。天气0无/1雨/2暴风雨/3雪、强度0..9；强度0是最低天气，关闭必须type=0。天气换图保留，雾/全景换图按新图块集初始化；同地图 setup_map 不重置。

fade_screen(opacity,seconds) 的opacity0显示地图、255全黑；await freeze_screen() 获取实际截图；transition_screen(seconds,name="",vague=40) 揭示新画面，name来自 Transitions 分类，vague0..255。未完成 freeze、重复冻结、headless 截图均拒绝。缺蒙版保留冻结图并失败，可 cancel_screen_transition() 释放。当前未提供通用事件等待完成信号；若未来接入过渡等待，须新增正式查询/完成协议，不把 game()._transition 私有字段当新事件公共接口。

timer.start(seconds,show=true)、stop()；0..359999秒；remaining/running/visible 可查，text() 向上取整MM:SS；expired 只在运行倒计时归零时发一次，不触发战斗或事件。stop 不清剩余秒数但隐藏并停止。

audio.play(kind,{name,volume=100,pitch=100},position_seconds=0)：kind大写BGM/BGS/ME/SE，音量0..100、音调50..150；空name停止该类；缺失文件失败且不替换原频道。BGM/BGS循环，ME暂停/结束恢复BGM，SE独立并发上限32（释放最老）。fade_out仅BGM/BGS/ME；memorize返回BGM/BGS字典，不是ok结果；restore_memory返回ok。stop_all还清记忆。snapshot只反映BGM/BGS定义/当前位置，不等于持久存档。

## 5. 角色规则、查询快照和只读数据

ActorState 的九项：maxhp最大HP、maxsp最大SP、str力量、dex灵巧、agi速度、int魔力、atk攻击力、pdef物理防御、mdef魔法防御。

parameter_sources(key)={database,equipment,base,plus,state_rates,value,minimum,maximum,reason}；base 包含数据库+装备并先限幅，plus 只保存永久修正，不叠存装备。最终值按已有 State 倍率顺序取整再限幅。HP上限1..9999、SP上限0..9999；四项基础属性1..999，攻击/防御0..999；当前hp/sp可0。坏引用value/base可null且reason说明，不能伪造。

get_parameter/get_base_parameter/get_equipment_parameter/get_parameter_plus 对应上述层。动态属性 key、key_plus、base_key、equip_key、database_key 提供读取；key/key_plus、exp、name 可写，结果看 last_mutation_result。显式方法更适合事件，因为能返回失败；直接写 level/experience 不等于调用成长接口。

snapshot(equipment_override=[],level_override=-1,bonuses_override={}) 可用于纯预览，空覆盖参数表示当前值；返回 {id,name,class_name,level,hp,sp,parameters,parameter_sources,experience,next_experience,equipment,states,skill_ids,diagnostics,character_name,character_hue}。equipment条目为显示信息，不暴露数据库 definition；states 为名称列表，ID另用get_state_ids。最终等级next_experience=null；experience_for_level 返回升级到该级所需累计经验或null。set_parameter精确最终值若倍率/取整使目标不可达，整次拒绝。

set_experience/add_experience、set_level/add_level 按源 exp_basis/exp_inflation 曲线，累计经验0..9999999、等级1..final_level（至多99）；升级学习职业表，降级不遗忘，升级不治疗。persistent_data 保存角色运行字段/普通状态/特技/plus/图像；restore_persistent返回空字符串表示成功，非空为失败原因，不是ok字典。

State 的普通来源和防具auto_state来源分开：remove_state/clear_states只删除普通来源，自动状态仍有效。has_state/get_state_ids默认包含装备来源；include_equipment=false仅普通ID。保留倍率显示，但不执行死亡/中毒/概率/回合解除/状态动画，不调用战斗结算。Skills 定义保留标准字段（包括animation1_id、animation2_id可0）；无独立可变Skill对象，不执行效果/消耗。

RuntimeData.record 从测试覆盖层或源数据库取引用；source_record只取原定义；database返回原数组（下标就是ID，可能null/空洞）。这些结果不是深拷贝，调用方必须只读；需要改定义展示时duplicate(true)。configure_testing独立注册测试定义，不能覆盖源ID；install_testing仅存档整体校验后使用，不能再次发放物资。read_json有静态缓存，test_config有独立文件读取行为，不承诺修改磁盘后所有数据库热更新。

Table 数据：{_rmxp_type:"table",dimensions,x_size,y_size,z_size,values}，扁平下标x+y*x_size+z*x_size*y_size。角色参数表x为六项索引，y为等级（用level而不是level-1）；地图x/y/z为格/层。数据库值不直接塞进会改写的运动/画面对象。

## 6. 地图、人物与动画接入

MapRuntime.load_map(id) 从 RuntimeData读取，返回bool；load_definition(definition,tileset_definition) 为独立夹具入口，正式地图优先load_map。map_width/map_height为格，valid查询边界；tile_id层0..2，tile_priority依数据库；terrain_tag/is_bush/is_counter查询图层标志。tile IDs为0空、48..383自动图块、>=384图块集；绘制、通行和人物遮挡不可各维护不一致的规则。

can_move(from,unit_direction,through,ignore_event_id) 检查起点/终点双向通行及人物占位；can_stand检查跳跃落点；正在移动人物占据起点+终点。ignore_event_id=-1通常排除玩家；正ID排除自身事件。event_ids_at(x,y)返回当前占位事件ID。

MapCharacter.move_straight(direction) 为单格尝试，成功返回true；失败可能仍已转向，方向固定时不转。move_to(x,y) 是边界内立即重定位、不是寻路、不计步，不等同于经过通行检查的move_straight。jump(dx,dy) 相对格偏移，能跨障碍但落点须合法，不计步。turn/is_idle/moving/jumping/motion_snapshot，arrived("walk"/"jump") 表示已到终点。不要同时让节点_process和事件手动advance_motion推进两次。

PlayerController.configure(map) 绑定统一player_motion，队首Actor提供图像；input_enabled只禁玩家输入，运动组件仍可推进，菜单是真正pause。resume_after_menu避免确认键残留。MapEvent.configure(event_data,page,id,map_id)设置页图像和选项，未变页保留位置；移动路线/自主移动尚未执行。front_interaction描述当前是否在前方交互，不是事件触发器总开关。

MapRuntime.request_action处理脚下/前方/柜台隔格确认；trigger_player_touch处理现有触碰；event_requested(commands,event_id)交给Game串行解释器。event_page返回1起页号；refresh_events重评页并保持同页人物；autorun_event只返回一个trigger=3事件字典，不是完整自动/并行事件调度器。未来调度需明确并行/自动/擦除/刷新/触发锁语义，不把当前简化调度写成完整RGSS。

transfer(map_id,x,y) 先查落点再加载，成功立即重定位，返回bool；当前不处理完整淡入淡出/事件等待/方向参数语义，需事件阶段接入。显示节点随MapRuntime生命周期销毁；屏幕状态仍归RuntimeState，新游戏才重置。

MapRuntime.animation_target(character_id,current_event_id)的ID=-1玩家、0当前事件、正值指定事件；找不到null。play_animation(animation_id,character_id=-1,current_event_id=0,hit=true) 创建并追加独立播放器，返回{ok,empty,player}；0动画只返回ok+empty，无player。每次播放都是新实例，同一目标第二个动画不覆盖第一个，也不通过animation_id单值实现队列。

RmxpAnimationData.compile把原frames/cell_data转为至多16单元，每单元[pattern,x,y,zoom,angle,mirror,opacity,blend_type]，原sheet每格192px、每行5格；position=0头/1中/2脚/3画面。resolve校验ID/帧/素材边界，返回{ok,empty,id,position,hue,frames,timings,texture}或失败，0为空动画。
timings包含frame、se、flash_scope（0无/1目标/2画面/3隐藏）、flash_color（原数据的red/green/blue/alpha字典）、flash_duration（动画帧数，乘0.05秒）、condition（0总是/1命中/2未命中）；hit来自调用方，不计算战斗。finished/timing_reached可订阅，播放结束或目标失效会释放；等待动画时持有实例列表，不等待被覆盖的单一ID。不要再手动advance已在_process推进的播放器。

## 7. 场景、暂停、显示资源与存档

Game负责组装信号和节点，已有事件完成会延迟refresh_events；菜单/商店/对话与事件互斥。MenuCoordinator.can_open/open_menu是空闲地图入口；行走中按Esc等待本格完成。close_menu恢复同一地图，不重载、不重跑初始化。open_shop校验商品并暂停，close_shop恢复解释器的resume_shop；事件351唤菜单尚未接入，不直接new MenuScene绕开协调器。

所有页面navigate(direction)一般用-1/+1，activate执行、back返回；各页面的action(index)、number_action等是内部UI按钮契约，不是事件业务API。WindowBase负责皮肤和内容，Selectable负责index/item_count/scroll_row/row_height/active，Command配置[{text,enabled},...]。向上先移光标，越过可见上缘才滚动；不逐帧重建窗口全文。

DialogueOverlay.show_message(lines)、show_choices(choices,cancel_type)、show_number(variable_id,digits)、show_diagnostic(message)显示并发出完成信号；closed用于恢复输入，不等于所有解释器等待都用resume_message。当前取消选项约定需与解释器分支相配，不能根据数组下标臆造RM取消参数语义。

显示层：全景-10、雾/天气0、地图色调1、显示区域遮罩2、图片5、屏幕闪光8、计时9、测试标记10、过渡15、对话20、菜单50（CanvasLayer）。图片屏幕空间且不跟地图色调/震动；闪光覆盖地图和图片，不盖对话/菜单。图块/人物脚点排序在地图层内部，不能拿CanvasLayer与z_index混算。

ScreenRenderer推进screen；MapEffectsRenderer推进map_effects和timer；MapCamera推进map_view；AudioRuntime自推进。普通菜单暂停地图/运动/效果/倒计时，背景音乐和play_seconds继续；标题playing=false停止游戏时长，音频由标题逻辑切换。时间推进每帧仅一次；ScreenTools是推进真实屏幕效果的特殊测试页，PresentationTools则拥有独立预览对象，不能把两者混为一套逻辑。

RmxpCache分类严格映射Graphics/{Pictures,Icons,Titles,Windowskins,Characters,Animations,Tilesets,Autotiles,Panoramas,Fogs,Battlers,Gameovers,Transitions}，picture/icon/...只取本分类；缺失null、不补RTP，拒越界路径。categories返回13个预定义分类，list_names/list_assets从asset_index枚举分类素材，供编辑器预留：不加载图像、不列工具测试图，list_assets条目{category,name,source_key,path}。resolve返回生成工程资源路径，找不到""；exists同时检查索引解析和ResourceLoader.exists，不代表对应场景行为已实现。
UIResources内部缓存texture/AtlasTexture/SystemFont，RmxpCache调用它；不要改共享texture，也不要在新类另做相同路径缓存。clear仅放弃缓存引用，不销毁仍被节点持有的纹理、不触发磁盘重新导入。UIResources.word统一标准属性/槽名，其他读取System.words；play_sound是System键的UI音效路径，不是AudioRuntime的剧情播放入口。

SaveService四槽1..4，schema=1；版本字段标记来源，不因ver0.2而更改schema或无条件拒旧原生进度。工程ID、数据库/地图指纹、测试定义、格式与SHA256整体校验仍执行。正式目录user://rgmigrator_saves/<工程隔离目录>；directory_override仅供隔离测试。

capture(state)获取快照，prepare(snapshot)脱离现场整体校验，返回{ok,state,actors,test_records,screen,map_view,map_effects,timer}；prepare失败绝不调用restore_prepared。read_path/read_slot只校验不恢复；read_slot可返回recovered=true的备份候选，UI须确认；load_slot成功会提交，因此交互读档先检查备份确认，不能重复读取/提交导致测试物资发两次。
save_slot先写临时、校验、保存有效旧主件.bak再替换；坏主件保留.damaged副本；失败不删除原槽。Game.can_save还要求角色空闲、无事件/对话/商店、菜单正在save页。底层SaveService检查playing/save_disabled/运动空闲，但不会独自验证UI和解释器上下文，新事件存档不能只跳过Game门禁。

已保存：队伍/注册角色/背包/金币/开关变量独立开关/地图格坐标朝向/步数游戏时间/禁用标志/测试定义/图片与屏幕效果进度/玩家选项/镜头与滚动/地图表现与天气/计时器。
不保存：半格行走跳跃、正在执行的事件栈/并行调度、动画实例、事件人物运行位移、瞬时截图/淡化、当前音频进度和音频记忆。旧原生schema1缺可选扩展使用默认；不读取RM Marshal存档。天气归属迁移必须兼容旧map_effects字段，不能两份同时作为真值。

## 8. 事件开发的现状与接入清单

现有 EventInterpreter 是 RefCounted 串行执行器；start(commands,event_id,page=1)立即执行到等待，running表示活跃。命令对象{code,indent,parameters}；变量/开关键必须保持字符串。每次同步_run上限10000步、公共事件有调用栈限制，超限中断；未实现协程式逐帧等待和完整调度。

已接通的match路径（部分命令只支持所列参数）：

- 0结束；101+401文本、102+402/403/404选项、103数值；108/408注释。
- 111+411/412条件：开关、变量比较、独立开关、角色已学特技子类型（type4/subtype2）；其他类型诊断。
- 112/113/413循环/跳出，115退出，117调用公共事件，118/119标签/跳转。
- 121开关、122变量（操作数只常量/变量/随机，算术赋值/加减乘除余）、123独立开关。
- 125金币、126/127/128背包数量、129队员、134禁止存档、135禁止菜单。
- 201传送，207显示动画（并发，不等待），235擦除图片。
- 241BGM、245BGS、249ME、250SE、251停止SE。
- 302+605商店，318增减特技。

未接通示例：124计时器、106等待、202事件位置、203滚图、204/205地图表现、209/210移动路线/等待、221/222过渡、223/224/225色调闪光震动、231..234图片显示移动旋转色调、236天气、242/246音频淡出、247/248音频记忆恢复、角色参数/状态相关其他命令、351/352菜单存档、353游戏结束、355/655脚本、战斗。没有匹配的正code也会诊断。导入时的支持判定在RmxpDataConverter，新增指令必须与解释器同步，不能报告支持但运行时失败。

后续流程：解析并完整验证参数 -> 解析正确地图/事件/角色上下文 -> 调用正式RuntimeState/服务接口 -> 若等待则登记可取消的等待条件 -> 完成后继续解释器 -> 页条件/显示必要刷新 -> 精确诊断。
同一个事件命令涉及多个效果时先整体检查；等待不能阻塞主线程、不能误暂停需要完成的动画；退出地图/事件时清理等待引用，转场/读档不重复继续旧执行栈。

Game_Screen天气归属是天气命令接入的前置任务；没有做此重构前，不新增到处直接写map_effects.data的天气命令。当前文档不承诺不存在的屏幕weather API。

## 9. 测试、版本和文档维护

版本唯一源scripts/Version.gd；模板RuntimeVersion.gd同步，ProjectGenerator生成时还会从唯一源覆盖。project.godot标题同步；新报告、生成配置注释/README/存档runtime_version应显示当前版本。历史CHANGELOG和tests/VERIFICATION_v0.xx、ACCEPTANCE_v0.xx保留历史版本，不批量改写验收证据。

本机引擎传入D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe（这是目录）；PowerShell测试脚本自动找其中*_console.exe。直接执行Godot时使用该目录里的Godot_v4.7.2-stable_win64_console.exe。

```powershell
& 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/DocumentationTests.gd
./tests/Run-Headless.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe' -SkipMigration -RefreshRuntime -SkipImport
```

默认不SkipMigration会迁移两个只读样例到新的.godot/test_exports_*；RefreshRuntime只更新.godot/test-results.json列出的隔离输出，不改已验收工程。新增接口至少覆盖独立标准夹具、无效引用/原子失败、样例集成、菜单暂停和存档；render必须用真实Compatibility，不能headless代替画面。

测试定位：RuntimeTests/EventInterpreter基础；MenuTests互斥与返回；InventoryTests物品装备；SkillAnimationTests学习及独立并发动画；ShopStateTests商店状态；ActorMutationTests成长；ScreenTests图片屏幕；GraphicsCacheTests分类；MovementTests人物碰撞；PresentationTests镜头/天气/雾/计时/音频；SaveTests及SaveRestartTests保存/跨进程；RuntimeCompileTests类加载。Run-Render、Run-MenuRender、Run-MovementRender、Run-PresentationRender为实际画面；后者-Benchmark为768×768/60秒负载，不把历史性能数值当本版重测。

DocumentationTests校验附录覆盖全部68个生产脚本、非下划线函数签名、带参数构造器、信号、继承声明、字段/常量清单与版本。附录包含内部UI辅助公共方法是为了完整索引，不意味着这些方法获准作为事件业务入口。公开字段清单也不表示可绕过业务方法任意赋值；初始化依赖字段和可写选项见各类说明。添加方法/类后先同步描述与附录，再测。

## 10. 按文件的全部接口索引

下列签名逐字对应源码；static func为脚本静态调用，其余为实例调用，_init参数作为.new(...)参数。继承类也拥有父类接口，附录只列当前文件自己声明的部分。Godot生命周期、前导下划线辅助实现以及继承自Godot的通用方法不重复罗列。每节说明调用者、作用和已知限制；详细业务参数遵守第3–8节。

### ActorParameters.gd

公开字段：无。

常量（不含依赖脚本引用）：`KEYS`、`TABLE_KEYS`、`MAX_EXPERIENCE`。

源文件：templates/runtime/scripts/ActorParameters.gd。纯计算服务；integer/minimum/maximum校验/上下限，calculate返回values/sources且不修改输入，apply_bonus按plus/倍率/限幅计算。不保存角色、不执行状态战斗效果。

```gdscript
extends RefCounted
static func integer(value: Variant, minimum: int = -9007199254740991, maximum: int = 9007199254740991) -> bool
static func maximum(key: String) -> int
static func minimum(key: String) -> int
static func calculate(database: Dictionary, equipment: Array[Dictionary], states: Array[Dictionary], bonuses: Dictionary, invalid_equipment: bool) -> Dictionary
static func apply_bonus(key: String, base: int, bonus: int, rates: Array) -> int
```

### ActorState.gd

公开字段：`id`、`actor_name`、`class_id`、`level`、`final_level`、`experience`、`character_name`、`character_hue`、`last_mutation_result`、`equipment`、`state_ids`、`diagnostics`、`hp`、`sp`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/ActorState.gd。角色唯一运行对象由RuntimeState.actor获取；changed通知。configure仅初始化/重置，查询与修改、State来源、成长和persistent_data/restore_persistent契约见第5节；snapshot覆盖参数只预览，职业/库存交换必须通过RuntimeState/InventoryService。

```gdscript
extends RefCounted
signal changed
func configure(actor_id: int, definition: Dictionary, lookup: Callable) -> void
func learn_skill(skill_id: int) -> Dictionary
func forget_skill(skill_id: int) -> Dictionary
func has_skill(skill_id: int) -> bool
func get_skill_ids() -> Array[int]
func add_state(state_id: int) -> Dictionary
func remove_state(state_id: int) -> Dictionary
func clear_states() -> Dictionary
func has_state(state_id: int) -> bool
func get_state_ids(include_equipment: bool = true) -> Array[int]
func persistent_data() -> Dictionary
func restore_persistent(saved: Dictionary) -> String
func slot_fixed(slot: int) -> bool
func snapshot(equipment_override: Array = [], level_override: int = -1, bonuses_override: Dictionary = {}) -> Dictionary
func parameter_sources(key: String) -> Dictionary
func get_parameter(key: String) -> Variant
func get_base_parameter(key: String) -> Variant
func get_equipment_parameter(key: String) -> Variant
func get_parameter_plus(key: String) -> Variant
func set_parameter_plus(key: String, value: Variant) -> Dictionary
func add_parameter_plus(key: String, amount: Variant) -> Dictionary
func set_parameter(key: String, value: Variant) -> Dictionary
func experience_for_level(value: int) -> Variant
func next_level_experience() -> Variant
func set_experience(value: Variant) -> Dictionary
func add_experience(amount: Variant) -> Dictionary
func set_level(value: Variant) -> Dictionary
func add_level(amount: Variant) -> Dictionary
func set_vital(key: String, value: Variant) -> Dictionary
func add_vital(key: String, amount: Variant) -> Dictionary
func recover_vitals() -> Dictionary
func rename(value: Variant) -> Dictionary
func set_graphic(value: Variant, hue: Variant = 0) -> Dictionary
```

### ActorTools.gd

公开字段：`actor_id`、`parameter`、`selected`、`message`。

常量（不含依赖脚本引用）：`ACTIONS`。

源文件：templates/runtime/scripts/ActorTools.gd。F6角色成长测试UI，actor_id/parameter/selected选择当前对象/属性/按钮；refresh/paint_selection/update身份表单，action/identity_action执行已定义按钮，text_edit/parameter_name为UI辅助。navigate/activate/back/handle_key由菜单路由，has_text_focus防止编辑文本被快捷键截获，不是剧情事件入口。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func parameter_name(key: String) -> String
func paint_selection() -> void
func navigate(direction: int) -> void
func activate() -> void
func action(index: int) -> void
func open_identity() -> void
func text_edit(caption: String, value: String, y: float) -> LineEdit
func identity_action(index: int) -> void
func close_identity() -> void
func has_text_focus() -> bool
func back() -> void
func handle_key(key: int) -> void
```

### AnimationLab.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/AnimationLab.gd。原动画并发测试UI；play_at目标索引0/1，animation_id=0取当前选择而非正式播放的空动画语义。action/navigate/activate路由测试按钮，stop_all停止该页实例，back返回。独立目标，不代替当前地图的animation_target。

```gdscript
extends Control
signal back_requested
func play_at(target_index: int, animation_id: int = 0) -> Dictionary
func action(value: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func stop_all() -> void
func back() -> void
```

### AudioRuntime.gd

公开字段：`channels`、`definitions`、`fades`、`memory`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/AudioRuntime.gd。RuntimeState.audio持有的长寿命Node；播放参数、ME协调、SE上限、fade_out、memorize/restore_memory/snapshot返回差异见第4.3节。菜单不暂停音频，不把memory/播放进度存进现有存档。

```gdscript
extends Node
func play(kind: String, audio: Dictionary, position_seconds: Variant = 0.0) -> Dictionary
func stop(kind: String) -> void
func stop_all() -> void
func fade_out(kind: String, seconds: Variant) -> Dictionary
func memorize() -> Dictionary
func restore_memory() -> Dictionary
func snapshot() -> Dictionary
```

### CharacterMotion.gd

公开字段：`cell`、`target`、`visual_cell`、`direction`、`pattern`、`options`、`jump_height`。

常量（不含依赖脚本引用）：`DIRECTIONS`、`DEFAULTS`。

源文件：templates/runtime/scripts/CharacterMotion.gd。纯运动状态；cell/target格，visual_cell浮点格，direction/pattern/options/jump_height。validate可partial或complete，configure原子更新；begin_move/begin_jump仅启动运动，不查地图碰撞（先由MapCharacter校验）。advance返回空字符串或完成类型walk/jump；relocate立即定位，reset默认重置，snapshot给像素real_x/y。

```gdscript
extends RefCounted
static func validate(value: Variant, complete: bool = false) -> bool
func configure(value: Dictionary) -> Dictionary
func reset() -> void
func relocate(destination: Vector2i) -> void
func is_idle() -> bool
func moving() -> bool
func jumping() -> bool
func turn(value: int, force: bool = false) -> bool
func pixels_per_second() -> float
func begin_move(value: int) -> bool
func begin_jump(offset: Vector2i) -> bool
func advance(delta: float) -> String
func snapshot() -> Dictionary
```

### CharacterSprite.gd

公开字段：无。

常量（不含依赖脚本引用）：`HUE_SHADER`。

源文件：templates/runtime/scripts/CharacterSprite.gd。菜单TextureRect角色图；configure使用Characters四方向四帧、独立色相，set_frame方向2/4/6/8和pattern0..3。没有地图碰撞/运行角色状态，纹理共享但实例材料独立。

```gdscript
extends TextureRect
func configure(character_name: String, hue: int = 0, direction: int = 2, pattern: int = 0) -> void
func set_frame(direction: int, pattern: int) -> void
```

### DialogueOverlay.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/DialogueOverlay.gd。CanvasLayer20，show_*与is_open及信号连接见第7节。数字输入完成返回数值，不负责直接修改变量。诊断显示不提供Ruby执行或完整RM文本控制码。

```gdscript
extends CanvasLayer
class_name DialogueOverlay
signal message_confirmed
signal choice_selected(index: int)
signal number_confirmed(value: int)
signal closed
func is_open() -> bool
func show_message(lines: Array) -> void
func show_choices(choices: Array, cancel_type: int) -> void
func show_number(variable_id: int, digits: int) -> void
func show_diagnostic(message: String) -> void
```

### EventInterpreter.gd

公开字段：`map_runtime`、`running`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/EventInterpreter.gd。RefCounted单个串行上下文；map_runtime指向当前MapRuntime，running查询。start立即运行到等待；resume_message/choice/number/shop只解除相应等待，reject_shop输出精确诊断并中断。信号与已接通指令见第8节；禁止额外创建天气/角色真值。

```gdscript
extends RefCounted
class_name EventInterpreter
signal message_requested(lines: Array)
signal choices_requested(choices: Array, cancel_type: int)
signal number_requested(variable_id: int, digits: int)
signal shop_requested(goods: Array)
signal diagnostic_requested(message: String)
signal completed
func start(commands: Array, event_id: int, page: int = 1) -> void
func resume_message() -> void
func resume_choice(choice: int) -> void
func resume_number(value: int) -> void
func resume_shop() -> void
func reject_shop(message: String) -> void
```

### Game.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/Game.gd。Game.tscn组装者，自动创建地图、玩家、相机、显示层、解释器、对话和菜单；无通用Scene栈公共API。can_save为完整上下文门禁，save_slot成功委托SaveService。_map/_interpreter/_transition等属内部，未来事件统一入口不要绕过门禁。

```gdscript
extends Node2D
func can_save() -> bool
func save_slot(slot: int) -> Dictionary
```

### GameTimer.gd

公开字段：`remaining`、`running`、`visible`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/GameTimer.gd。RuntimeState.timer持有的纯计时状态；remaining/running/visible，expired信号、start/stop/text、decode见第4.3节。由MapEffectsRenderer推进，不能再在解释器每帧advance。

```gdscript
extends RefCounted
signal expired
func start(seconds: Variant, show: bool = true) -> Dictionary
func stop() -> void
func advance(delta: float) -> void
func text() -> String
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### InventoryScene.gd

公开字段：`mode`、`actor_id`、`page`、`list_index`、`target_index`、`slot_index`、`candidate_index`、`active_item_id`、`message`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/InventoryScene.gd。Control，mode为inventory/equipment、actor_id选角色；refresh按当前页面重建内容，navigate/activate/back按列表→角色→槽位→候选→确认层级路由。back_requested/sound_requested交MenuScene处理；业务修改仅通过InventoryService/RuntimeState。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### InventoryService.gd

公开字段：无。

常量（不含依赖脚本引用）：`DATABASES`。

源文件：templates/runtime/scripts/InventoryService.gd。静态确定性物品/装备事务；entries/item_reason/equip_reason查询不提交，空reason表示可尝试。use_item成功含targets数量，equip_preview返回before/after/equipment，equip正式交换；failure为统一失败包装。限制和参数见第4.2节。

```gdscript
extends RefCounted
static func entries(state: Node) -> Array[Dictionary]
static func item_reason(item_id: int) -> String
static func use_item(state: Node, item_id: int, target_id: int) -> Dictionary
static func equip_reason(state: Node, actor_id: int, slot: int, equipment_id: int) -> String
static func equip_preview(state: Node, actor_id: int, slot: int, equipment_id: int) -> Dictionary
static func equip(state: Node, actor_id: int, slot: int, equipment_id: int) -> Dictionary
static func failure(message: String) -> Dictionary
```

### MapCamera.gd

公开字段：`model`、`map`、`player`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapCamera.gd。Camera2D，必须在add_child前设model(MapViewState)、map(MapRuntime)、player(MapCharacter)；sync计算当前尺寸/边界/跟随，snap仅强制定位；scroll委托model且提供地图尺寸。震动offset来自ScreenRenderer，不让第二套相机逻辑覆盖display。

```gdscript
extends Camera2D
func sync(delta: float = 0.0, snap: bool = false) -> void
func scroll(direction: int, tiles: Variant, seconds: Variant) -> Dictionary
```

### MapCharacter.gd

公开字段：`motion`、`map_runtime`、`character_id`、`fallback_visible`、`tile_position`、`facing`、`move_speed`、`through`、`direction_fix`、`walk_anime`、`step_anime`、`transparent`、`opacity`、`blend_type`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapCharacter.gd。Node2D共用人物显示/运动父类；map_runtime、motion、character_id，派生PlayerController/MapEvent。set_graphic(name,hue,tile_id)可Characters或图块；tile_position/facing与选项属性代理motion。move_straight/move_to/jump、occupied_cells、arrived、advance_motion见第6节；animation_bounds给本人物局部图像范围。

```gdscript
extends Node2D
signal arrived(kind: String)
signal occupancy_changed
func set_graphic(name_value: String, hue: int = 0, tile_id: int = 0) -> void
func is_idle() -> bool
func moving() -> bool
func motion_snapshot() -> Dictionary
func jumping() -> bool
func configure_motion(value: Dictionary) -> Dictionary
func turn(direction: int) -> bool
func move_straight(direction: int) -> bool
func move_to(x: int, y: int) -> bool
func jump(x: int, y: int) -> bool
func occupied_cells() -> Array[Vector2i]
func advance_motion(delta: float) -> String
func animation_bounds() -> Rect2
```

### MapEffectsRenderer.gd

公开字段：`model`、`view_model`、`timer_model`、`preview`、`map`、`camera`、`texture_overrides`、`panorama`、`fog`、`weather`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapEffectsRenderer.gd。Node持有全景/雾/天气/边界/计时显示组；add_child前设置model、view_model，选填timer_model/map/camera。sync既推进模型又同步显示，不能重入重复计时；preview=true仅隔离预览，texture_overrides只用于工具对照图。不是天气状态拥有者。

```gdscript
extends Node
func sync(delta: float) -> void
```

### MapEffectsState.gd

公开字段：`data`、`revision`。

常量（不含依赖脚本引用）：`DEFAULTS`。

源文件：templates/runtime/scripts/MapEffectsState.gd。当前地图表现纯模型，data包含map_id、全景/雾和天气/渐变，revision记录配置变化。configure仅接受9个素材/静态参数，validate检查完整快照；setup_map同图保留、换图重置雾并保留天气。weather/tint_fog/fade_fog/advance/snapshot/decode见第4.3节；天气待纳入Game_Screen，不误写已有screen.weather。

```gdscript
extends RefCounted
static func validate(value: Variant) -> bool
func configure(changes: Dictionary) -> Dictionary
func setup_map(id: int, tileset: Dictionary) -> Dictionary
func tint_fog(tone: Array, seconds: Variant = 0.0) -> Dictionary
func fade_fog(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
func weather(type: int, power: Variant, seconds: Variant = 0.0) -> Dictionary
func advance(delta: float) -> void
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### MapEvent.gd

公开字段：`event_id`、`map_id`、`trigger`、`commands`、`blocking`、`page_index`、`tile_id`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapEvent.gd。继承MapCharacter，event_id/map_id/trigger/commands/blocking/page_index/tile_id；configure根据选定页设置图像和运动选项。front_interaction用于交互与碰撞类型判断。没有自主/强制移动路线执行器、并行事件解释器或erase公共接口。

```gdscript
extends "res://runtime/scripts/MapCharacter.gd"
class_name MapEvent
func configure(event_data: Dictionary, page: Dictionary, id: int, current_map_id: int) -> void
func front_interaction() -> bool
```

### MapRuntime.gd

公开字段：`map_data`、`tileset`、`player_character`、`character_layer`、`background_visible`。

常量（不含依赖脚本引用）：`TILE_SIZE`、`AUTOTILE_PARTS`。

源文件：templates/runtime/scripts/MapRuntime.gd。Node2D地图容器；map_data/tileset/通行与优先级表，player_character指向玩家。载入、查询、碰撞、触发、传送、动画接口见第6节。ensure_character_layer提供人物与前景同组排序；set_background_visible/draw_tile供显示组使用。show_picture/move_picture是遗留参数适配辅助且未接通231/232，未来接入需完整解析变量坐标/时间，不直接复用当已兼容；play_audio只接受现有241/245/249/250，stop_sound_effect只停SE。

```gdscript
extends Node2D
class_name MapRuntime
signal event_requested(commands: Array, event_id: int)
signal map_changed(map_id: int)
func load_map(map_id: int) -> bool
func ensure_character_layer() -> Node2D
func load_definition(definition: Dictionary, tileset_definition: Dictionary) -> void
func map_width() -> int
func map_height() -> int
func valid(x: int, y: int) -> bool
func tile_id(x: int, y: int, layer: int) -> int
func tile_priority(id: int) -> int
func terrain_tag(x: int, y: int) -> int
func is_bush(x: int, y: int) -> bool
func is_counter(x: int, y: int) -> bool
func event_ids_at(x: int, y: int) -> Array[int]
func can_move(from: Vector2i, direction: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool
func can_stand(cell: Vector2i, through: bool = false, ignore_event_id: int = -1) -> bool
func request_action(position: Vector2i, facing: Vector2i) -> bool
func trigger_player_touch(position: Vector2i, blocked: bool = false) -> bool
func autorun_event() -> Dictionary
func event_page(event_id: int) -> int
func refresh_events() -> void
func animation_target(character_id: int, current_event_id: int = 0) -> CanvasItem
func play_animation(animation_id: int, character_id: int = -1, current_event_id: int = 0, hit: bool = true) -> Dictionary
func transfer(map_id: int, x: int, y: int) -> bool
func show_picture(parameters: Array) -> void
func move_picture(parameters: Array) -> void
func erase_picture(number: int) -> void
func play_audio(code: int, audio: Variant) -> void
func stop_sound_effect() -> void
func set_background_visible(value: bool) -> void
func draw_tile(canvas: CanvasItem, id: int, destination: Vector2) -> void
```

### MapTileRow.gd

公开字段：`map_runtime`、`cells`、`animated`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MapTileRow.gd。Node2D图块前景行，map_runtime/cells/animated在创建时设置，自动_draw调用map_runtime.draw_tile；cells的Vector3i分别为格x/y和tile_id。无自定义非下划线函数，生命周期由MapRuntime管理。不是Godot TileMap编辑器。

```gdscript
extends Node2D
# 本类未声明自定义公共方法。
```

### MapViewState.gd

公开字段：`options`、`display`、`scroll_target`、`scroll_remaining`、`initialized`、`revision`。

常量（不含依赖脚本引用）：`DEFAULTS`。

源文件：templates/runtime/scripts/MapViewState.gd。地图区域/镜头純模型，options/display/scroll_target/scroll_remaining/initialized。valid_options完整校验，configure部分更新，view_rect/follow_center/bounded查询，advance推进跟随，scroll启动手动滚动，resume_follow取消并跟随。snapshot/decode详见第4.3节；extent/focus/window_size都是像素。

```gdscript
extends RefCounted
static func valid_options(value: Variant) -> bool
func configure(changes: Dictionary) -> Dictionary
func view_rect(window_size: Vector2) -> Rect2
func follow_center(window_size: Vector2) -> Vector2
func bounded(point: Vector2, extent: Vector2, window_size: Vector2) -> Vector2
func advance(delta: float, focus: Vector2, extent: Vector2, window_size: Vector2, snap: bool = false) -> void
func scroll(direction: int, tiles: Variant, seconds: Variant, extent: Vector2, window_size: Vector2) -> Dictionary
func resume_follow() -> void
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### MenuCoordinator.gd

公开字段：`game`、`menu`、`shop`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MenuCoordinator.gd。CanvasLayer50，game由Game绑定，menu/shop当前显示节点；can_open/open_menu/close_menu保持原地图，return_to_title停止playing并切Title，open_shop返回ok并暂停，close_shop续解释器。输入焦点与等待整格开菜单由该层统一负责。

```gdscript
extends CanvasLayer
func can_open() -> bool
func open_menu() -> bool
func close_menu() -> void
func return_to_title() -> void
func open_shop(goods: Array) -> Dictionary
func close_shop() -> void
```

### MenuScene.gd

公开字段：`save_callback`、`page`、`actor_index`、`command_index`、`scene_stack`、`content_rebuilds`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MenuScene.gd。Menu.tscn的Control脚本；page保存页名、save_callback来自Game.save_slot。navigate/activate/back/handle_back负责主菜单与子页；open_test_*及open_*_tools仅测试模式入口。状态页/结束页在本类实现；所有操作用统一RuntimeState，不重新初始化角色。

```gdscript
extends Control
signal close_requested
signal title_requested
signal quit_requested
signal sound_requested(key: String)
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
func handle_back() -> void
func open_test_shop() -> void
func open_state_tools() -> void
func open_test_tools() -> void
func open_actor_tools() -> void
func open_screen_tools() -> void
func open_movement_tools() -> void
```

### MovementFixture.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/MovementFixture.gd。纯测试夹具生成器：table生成x-fastest表，build生成原创地图/图块/检查点，event构造测试事件定义。只用独立验收区，不写源数据库、不把fixture触发当剧情执行。

```gdscript
extends RefCounted
static func table(values: Array, width: int, height: int = 1, depth: int = 1) -> Dictionary
static func build() -> Dictionary
static func event(x: int, y: int, name_value: String, trigger: int, text: String) -> Dictionary
```

### MovementTools.gd

公开字段：`map`、`avatar`、`selected`。

常量（不含依赖脚本引用）：`ACTIONS`。

源文件：templates/runtime/scripts/MovementTools.gd。F6独立移动UI；settings读取表单，apply_preview只改隔离人物，action按钮中显式“应用到玩家”才configure_player。update_labels显示结果；handle_key/navigate/activate/back/has_text_focus用于菜单路由，不替换真实地图或角色坐标。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func settings() -> Dictionary
func apply_preview() -> void
func has_text_focus() -> bool
func update_labels() -> void
func action(index: int) -> void
func handle_key(key: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### PictureSprite.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/PictureSprite.gd。Sprite2D显示PictureState快照，apply返回是否成功，按number设置z层、共享纹理、独立材料；shader_for按blend缓存Shader。该类不拥有/推进图片状态，不根据RM命令修改背包等数据。

```gdscript
extends Sprite2D
static func shader_for(blend: int) -> Shader
func apply(view: Dictionary) -> bool
```

### PictureState.gd

公开字段：无。

常量（不含依赖脚本引用）：`POSE`。

源文件：templates/runtime/scripts/PictureState.gd。一张图片的纯状态；create编号1..50失败null，decode失败字典/成功picture。pose_snapshot只当前姿态，snapshot加目标/剩余时长/旋转/色调进度；move/rotate/start_tone_change启动效果，advance每帧秒推进；numeric/vector_valid/valid_name/pose_valid/fail为校验工具。取值/单位见第4.3节。

```gdscript
extends RefCounted
static func numeric(value: Variant, minimum: float, maximum: float) -> bool
static func vector_valid(value: Variant, tone: bool = true) -> bool
static func valid_name(value: Variant) -> bool
static func pose_valid(value: Variant, partial: bool = false) -> bool
static func create(number: int, name_value: String, pose: Dictionary = {}) -> RefCounted
static func decode(value: Variant) -> Dictionary
func pose_snapshot() -> Dictionary
func snapshot() -> Dictionary
func move(pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
func rotate(degrees_per_second: Variant) -> Dictionary
func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary
func advance(delta: float) -> void
static func fail(message: String) -> Dictionary
```

### PlayerController.gd

公开字段：`input_enabled`、`stop_after_step`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/PlayerController.gd。继承MapCharacter，configure绑定RuntimeState.player_motion与地图，configure_motion转统一配置；input_enabled/stop_after_step供协调器门禁，resume_after_menu抑制残留按键。继承人物方法，成功普通行走才record_step；jump/撞墙/原地转向不计步。

```gdscript
extends "res://runtime/scripts/MapCharacter.gd"
class_name PlayerController
func configure(runtime: Node) -> void
func configure_motion(value: Dictionary) -> Dictionary
func resume_after_menu() -> void
```

### PresentationTools.gd

公开字段：`view`、`effects`、`timer`、`map`、`avatar`、`camera`、`renderer`、`transition`、`audio`、`viewport`、`tabs`、`fields`、`choices`、`buttons`、`selected`、`status`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/PresentationTools.gd。F6独立48×36地图表现预览，持独立view/effects/timer/transition/audio。navigate/activate/back/handle_key/has_text_focus仅UI入口；普通按钮不自动写回当前地图。只有显式真实地图应用/计时按钮连接RuntimeState；工具对照全景/雾禁止应用，当前会连天气一并拒绝。用户已接受保持此预览边界，事件后续走正式运行接口。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func has_text_focus() -> bool
func handle_key(key: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### RmxpAnimationData.gd

公开字段：无。

常量（不含依赖脚本引用）：`FRAME_SECONDS`。

源文件：templates/runtime/scripts/RmxpAnimationData.gd。静态原动画解码/校验服务；compile不加载纹理，resolve再查Animations和分类素材，返回数据契约见第6节；failure带动画ID定位。并非Godot Animation资源转换器。

```gdscript
extends RefCounted
static func resolve(animation_id: int) -> Dictionary
static func compile(definition: Dictionary) -> Dictionary
static func failure(id: int, message: String) -> Dictionary
```

### RmxpAnimationPlayer.gd

公开字段：`frame_index`、`elapsed`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/RmxpAnimationPlayer.gd。每次play生成独立Node2D，parent控制生命周期，target_provider每次返回有效CanvasItem目标；0无动画无player，失败不创建实例。finished/timing_reached信号，advance由_process调用，stop释放并完成；同目标/不同位置皆可并发，不共享animation_id状态。

```gdscript
extends Node2D
signal finished
signal timing_reached(frame: int, timing: Dictionary)
static func play(parent: Node, animation_id: int, target_provider: Callable, hit: bool = true) -> Dictionary
func advance(delta: float) -> void
func stop() -> void
```

### RmxpCache.gd

公开字段：无。

常量（不含依赖脚本引用）：`CATEGORIES`、`IMAGE_EXTENSIONS`。

源文件：templates/runtime/scripts/RmxpCache.gd。静态分类素材Facade，所有方法和13分类见第7节；asset_key是合法Graphics分类键，resolve是索引资源路径，texture/region共享缓存，list_assets/list_names仅枚举。各shortcut接受原分类内文件名（可含子目录/扩展名），不接受任意外部路径。

```gdscript
extends RefCounted
static func categories() -> Array[String]
static func asset_key(category: String, name: String) -> String
static func resolve(category: String, name: String) -> String
static func exists(category: String, name: String) -> bool
static func texture(category: String, name: String) -> Texture2D
static func region(category: String, name: String, rectangle: Rect2) -> Texture2D
static func list_assets(category: String) -> Array[Dictionary]
static func list_names(category: String) -> Array[String]
static func picture(name: String) -> Texture2D
static func icon(name: String) -> Texture2D
static func title(name: String) -> Texture2D
static func windowskin(name: String) -> Texture2D
static func character(name: String) -> Texture2D
static func animation(name: String) -> Texture2D
static func tileset(name: String) -> Texture2D
static func autotile(name: String) -> Texture2D
static func panorama(name: String) -> Texture2D
static func fog(name: String) -> Texture2D
static func battler(name: String) -> Texture2D
static func gameover(name: String) -> Texture2D
static func transition(name: String) -> Texture2D
static func clear() -> void
```

### RuntimeData.gd

公开字段：`testing_enabled`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/RuntimeData.gd。静态JSON缓存/数据库入口；返回定义引用必须只读，record含测试覆盖而source_record不含。manifest/system/map/database/read_json、测试覆盖操作、asset_index/asset_path、field安全取值契约见第5节。没有全局Actor实例或State效果逻辑。

```gdscript
extends RefCounted
class_name RuntimeData
static func read_json(path: String, fallback: Variant = {}) -> Variant
static func manifest() -> Dictionary
static func system() -> Dictionary
static func map(map_id: int) -> Dictionary
static func database(name: String) -> Variant
static func record(name: String, id: int) -> Dictionary
static func source_record(name: String, id: int) -> Dictionary
static func test_config() -> Dictionary
static func configure_testing(override: Dictionary = {}) -> Dictionary
static func is_test_record(database: String, id: int) -> bool
static func testing_snapshot() -> Dictionary
static func install_testing(enabled: bool, records: Dictionary) -> void
static func asset_index() -> Dictionary
static func asset_path(rmxp_path: String) -> String
static func field(value: Variant, key: String, fallback: Variant = null) -> Variant
```

### RuntimeState.gd

公开字段：`switches`、`variables`、`self_switches`、`inventory`、`gold`、`party`、`map_id`、`player_motion`、`player_x`、`player_y`、`player_direction`、`resume_from_save`、`save_disabled`、`menu_disabled`、`actors`、`diagnostics`、`steps`、`play_seconds`、`playing`、`testing_enabled`、`screen`、`map_view`、`map_effects`、`timer`、`audio`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/RuntimeState.gd。生成工程唯一Autoload，字段/方法的调用、空引用、诊断、事务、初始化和生命周期见第4节；restore_prepared仅接受SaveCodec.prepare已验证结果。register_*不拥有场景生命周期，request_quit先停止/释放音频后延迟退出。不能在解释器/UI重新建同一份游戏状态。

```gdscript
extends Node
signal state_changed
signal diagnostic_added(message: String)
func request_quit() -> void
func begin_new_game(system: Dictionary, testing_override: Dictionary = {}) -> void
func inventory_entries() -> Array[Dictionary]
func change_skill(actor_id: int, skill_id: int, learning: bool) -> Dictionary
func has_skill(actor_id: int, skill_id: int) -> bool
func skill_ids(actor_id: int) -> Array[int]
func use_item(item_id: int, target_id: int) -> Dictionary
func change_state(actor_id: int, state_id: int, adding: bool) -> Dictionary
func has_state(actor_id: int, state_id: int) -> bool
func state_ids_for(actor_id: int, include_equipment: bool = true) -> Array[int]
func clear_states(actor_id: int) -> Dictionary
func shop_buy(goods: Array, kind: String, id: int, quantity: int) -> Dictionary
func shop_sell(kind: String, id: int, quantity: int) -> Dictionary
func inventory_count(kind: String, id: int) -> int
func equip_preview(actor_id: int, slot: int, equipment_id: int) -> Dictionary
func equip(actor_id: int, slot: int, equipment_id: int) -> Dictionary
func actor_parameter_sources(actor_id: int, key: String) -> Dictionary
func change_actor_parameter(actor_id: int, key: String, amount: Variant) -> Dictionary
func set_actor_parameter(actor_id: int, key: String, value: Variant) -> Dictionary
func set_actor_parameter_plus(actor_id: int, key: String, value: Variant) -> Dictionary
func set_actor_experience(actor_id: int, value: Variant) -> Dictionary
func change_actor_experience(actor_id: int, amount: Variant) -> Dictionary
func set_actor_level(actor_id: int, value: Variant) -> Dictionary
func change_actor_level(actor_id: int, amount: Variant) -> Dictionary
func set_actor_vital(actor_id: int, key: String, value: Variant) -> Dictionary
func change_actor_vital(actor_id: int, key: String, amount: Variant) -> Dictionary
func recover_actor_vitals(actor_id: int) -> Dictionary
func rename_actor(actor_id: int, value: Variant) -> Dictionary
func set_actor_graphic(actor_id: int, value: Variant, hue: Variant = 0) -> Dictionary
func change_actor_class(actor_id: int, value: Variant) -> Dictionary
func actor(actor_id: int, reset: bool = false) -> RefCounted
func party_snapshots() -> Array[Dictionary]
func change_party(actor_id: int, adding: bool, initialize: bool = false) -> void
func record_step() -> void
func configure_player(value: Dictionary) -> Dictionary
func register_player(controller: Node) -> void
func player() -> Node
func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary
func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
func rotate_picture(number: int, degrees_per_second: Variant) -> Dictionary
func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary
func erase_picture(number: int) -> Dictionary
func report_diagnostic(message: String) -> void
func register_game(instance: Node) -> void
func game() -> Node
func configure_map_view(changes: Dictionary) -> Dictionary
func configure_map_effects(changes: Dictionary) -> Dictionary
func scroll_map(direction: int, tiles: Variant, seconds: Variant = 0.0) -> Dictionary
func resume_map_follow() -> void
func fade_screen(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
func freeze_screen() -> Dictionary
func transition_screen(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary
func cancel_screen_transition() -> void
func self_switch_key(map_value: int, event_id: int, letter: String) -> String
func restore_prepared(prepared: Dictionary) -> void
```

### RuntimeVersion.gd

公开字段：无。

常量（不含依赖脚本引用）：`VERSION`。

源文件：templates/runtime/scripts/RuntimeVersion.gd。运行时版本常量VERSION=ver0.2；无业务方法。ProjectGenerator由迁移器Version同步生成，不与存档SCHEMA混用。

```gdscript
extends RefCounted
# 本类未声明自定义公共方法。
```

### SaveCodec.gd

公开字段：无。

常量（不含依赖脚本引用）：`MAX_INTEGER`。

源文件：templates/runtime/scripts/SaveCodec.gd。静态快照校验器，capture/prepare/返回结构见第7节。integer/positive_key/id_list校验JSON整数和数据库ID，testing_records校验存档测试定义且不安装，fail包装错误。只构造脱离现场的对象，不恢复场景节点/事件/音频。

```gdscript
extends RefCounted
static func integer(value: Variant, minimum: int = 0, maximum: int = MAX_INTEGER) -> bool
static func capture(state: Node) -> Dictionary
static func prepare(value: Variant) -> Dictionary
static func testing_records(value: Variant) -> Dictionary
static func id_list(value: Variant, database: String, lookup: Callable) -> String
static func positive_key(key: String) -> bool
static func fail(message: String) -> Dictionary
```

### SaveService.gd

公开字段：`directory_override`。

常量（不含依赖脚本引用）：`SLOT_COUNT`、`FORMAT`、`SCHEMA`、`MAX_BYTES`。

源文件：templates/runtime/scripts/SaveService.gd。静态四槽磁盘服务；project_id/directory/slot_path/fingerprint查询，save_slot提交磁盘，read_slot/read_path不恢复，load_slot会restore_prepared，slot_info/has_valid_save供标题/槽列表。write_text是内部文件辅助非事件API，fail包装错误；权限/备份确认/格式见第7节。

```gdscript
extends RefCounted
static func project_id() -> String
static func directory() -> String
static func slot_path(slot: int) -> String
static func fingerprint() -> String
static func save_slot(slot: int, state: Node) -> Dictionary
static func read_slot(slot: int) -> Dictionary
static func read_path(path: String) -> Dictionary
static func load_slot(slot: int, state: Node) -> Dictionary
static func slot_info(slot: int) -> Dictionary
static func has_valid_save() -> bool
static func write_text(path: String, content: String) -> Error
static func fail(message: String) -> Dictionary
```

### SaveSlots.gd

公开字段：`mode`、`save_callback`、`selected`、`message`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/SaveSlots.gd。Control，mode=save/load、save_callback是保存Callable；load_requested由标题处理实际读档，back_requested/sound_requested交父页面。refresh/window构建显示，navigate/activate/execute/back包含备份或覆盖确认流程，不能绕过确认直接调用load_slot。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
signal load_requested(slot: int)
func window(script: Script, rect: Rect2) -> Control
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func execute() -> void
func back() -> void
```

### ScreenRenderer.gd

公开字段：`camera`、`sprites`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/ScreenRenderer.gd。Node组装地图色调、图片与闪光显示，读取RuntimeState.screen，camera用于震动偏移。sync同步显示，full_rect创建ColorRect辅助；正常_process推进screen一次，普通菜单暂停，ScreenTools特例见第7节。它不是Game_Screen状态对象。

```gdscript
extends Node
func full_rect(parent: Node) -> ColorRect
func sync() -> void
```

### ScreenState.gd

公开字段：`revision`。

常量（不含依赖脚本引用）：`DEFAULTS`。

源文件：templates/runtime/scripts/ScreenState.gd。当前Game_Screen对应的纯状态，拥有1..50图片和tone/flash/shake，不含weather接口。show/move/rotate/tint/erase操作图片，picture可null、picture_ids升序，effects_snapshot不含图片，snapshot含pictures，decode返回screen；advance推进时长。正式显示图片优先RuntimeState校验素材；天气统一归属为待接入任务。

```gdscript
extends RefCounted
func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary
func picture(number: int) -> RefCounted
func picture_ids() -> Array
func erase_picture(number: int) -> Dictionary
func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
func rotate_picture(number: int, speed: Variant) -> Dictionary
func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary
func start_tone_change(tone: Array, seconds: Variant = 0.0) -> Dictionary
func start_flash(color: Array, seconds: Variant) -> Dictionary
func start_shake(power: Variant, speed: Variant, seconds: Variant) -> Dictionary
func advance(delta: float) -> void
func effects_snapshot() -> Dictionary
func snapshot() -> Dictionary
static func decode(value: Variant) -> Dictionary
```

### ScreenTools.gd

公开字段：`selected`、`number`、`asset_name`、`assets`、`message`。

常量（不含依赖脚本引用）：`ACTIONS`。

源文件：templates/runtime/scripts/ScreenTools.gd。F6图片测试Control；number/asset_name/selected按钮状态，select_asset选原Pictures，display_at调用真实RuntimeState.show_picture，action测试变换/屏幕效果，neutral_tone作比较；refresh/update_labels/navigate/activate/back供UI。与PresentationTools不同，该页效果修改当前screen，工具图只在测试模式有效。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func select_asset(name_value: String) -> void
func update_labels() -> void
func display_at(id: int, x: float) -> Dictionary
func action(index: int) -> void
func navigate(direction: int) -> void
func neutral_tone(tone: Array) -> bool
func activate() -> void
func back() -> void
```

### ShopScene.gd

公开字段：`goods`、`mode`、`command_index`、`selected`、`actor_index`、`quantity`、`message`、`content_rebuilds`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/ShopScene.gd。Control，goods由MenuCoordinator设置，mode/command_index/selected/quantity/actor_index驱动列表/数量窗与装备比较。refresh/build_list/build_number/window辅助显示，number_action与navigate/activate/back/handle_key处理数量、确认和返回，change_actor切装备比较角色。业务通过ShopService，返回发back_requested而非直接恢复地图。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func window(script: Script, rect: Rect2) -> Control
func refresh() -> void
func build_list() -> void
func build_number() -> void
func number_action(value: int) -> void
func change_actor(direction: int) -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
func handle_key(key: int) -> void
```

### ShopService.gd

公开字段：无。

常量（不含依赖脚本引用）：`KINDS`、`MAX_GOLD`。

源文件：templates/runtime/scripts/ShopService.gd。静态交易服务；catalog把RM goods解析为entries并去重，失败可含goods_index；item返回entry，counters返回owned或失败；quote_buy/sell返回maximum/unit_price/owned/message而不提交；buy/sell/transact原子提交，integer/fail辅助。金币库存/种类/价格见第4.2节。

```gdscript
extends RefCounted
static func integer(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool
static func catalog(goods: Array) -> Dictionary
static func item(kind: String, id: int) -> Dictionary
static func counters(state: Node, kind: String, id: int) -> Dictionary
static func quote_buy(state: Node, goods: Array, kind: String, id: int) -> Dictionary
static func quote_sell(state: Node, kind: String, id: int) -> Dictionary
static func buy(state: Node, goods: Array, kind: String, id: int, quantity: int) -> Dictionary
static func sell(state: Node, kind: String, id: int, quantity: int) -> Dictionary
static func transact(state: Node, goods: Array, kind: String, id: int, quantity: int, buying: bool) -> Dictionary
static func fail(message: String, goods_index: int = -1) -> Dictionary
```

### SkillScene.gd

公开字段：`actor_id`、`selected`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/SkillScene.gd。Control，actor_id对应列表；refresh/navigate/activate/back及信号交父菜单。普通技能列表只读，测试模式可学习/遗忘/预览/进入原动画并发实验；无技能效果/SP消耗/战斗处理。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### StateTools.gd

公开字段：`actor_id`、`selected_state`、`message`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/StateTools.gd。F6状态登记测试Control；refresh/selector显示角色与状态选择，action增删/查询/清空，navigate/activate/back路由。selector的actors布尔区分角色列表和状态列表；改变普通状态不清装备来源，不增加剧情事件指令。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
func refresh() -> void
func selector(position_value: Vector2, ids: Array[int], actors: bool) -> OptionButton
func action(value: int) -> void
func navigate(_direction: int) -> void
func activate() -> void
func back() -> void
```

### TestTools.gd

公开字段：`selected`。

常量（不含依赖脚本引用）：`PAGES`。

源文件：templates/runtime/scripts/TestTools.gd。F6工具目录Control；refresh刷新选择，navigate/activate/back通过tool_requested(page)让MenuScene开对应页。当前角色/商店/状态/图片/移动/表现/原动画入口只在测试模式可见，不是完整编辑器。

```gdscript
extends Control
signal back_requested
signal sound_requested(key: String)
signal tool_requested(page: String)
func refresh() -> void
func navigate(direction: int) -> void
func activate() -> void
func back() -> void
```

### Title.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/Title.gd。Title.tscn脚本，仅Godot生命周期与内部回调，无自定义公共方法。使用System标题素材/音乐，提供新游戏、继续游戏、退出；新游戏begin_new_game后切Game，继续先SaveService验证/确认备份/restore_prepared，不读取Ruby Scene_Title。

```gdscript
extends Control
# 本类未声明自定义公共方法。
```

### TransitionRenderer.gd

公开字段：`preview`、`rect`、`remaining`、`duration`、`frozen`、`busy`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/TransitionRenderer.gd。CanvasLayer15瞬时画面服务，fade/freeze_screen/transition/cancel契约见第4.3节；必须add_child后使用，freeze需await真实post_draw。状态remaining/busy/frozen目前内部接入用，未来事件应建立正式等待协议；取消/退出释放截图，不序列化。

```gdscript
extends CanvasLayer
func fade(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
func freeze_screen() -> Dictionary
func transition(seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40) -> Dictionary
func cancel() -> void
```

### UIResources.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/UIResources.gd。静态内部纹理/区域/字体共享缓存；texture接收Graphics全路径，业务首选RmxpCache分类接口。region创建AtlasTexture，font系统中文回退，word读取System并固定标准标签，play_sound播放System指定UI SE，clear释放缓存引用；不热导入文件。

```gdscript
extends RefCounted
static func texture(name: String) -> Texture2D
static func region(name: String, rectangle: Rect2) -> Texture2D
static func font() -> SystemFont
static func word(key: String, fallback: String) -> String
static func play_sound(parent: Node, key: String) -> void
static func clear() -> void
```

### UISpriteset.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/UISpriteset.gd。Control菜单成组生命周期；add_character(view,rectangle)用快照character_name/hue创建CharacterSprite并返回TextureRect，父节点释放时整组释放。不是地图Spriteset或角色状态拥有者。

```gdscript
extends Control
func add_character(view: Dictionary, rectangle: Rect2) -> TextureRect
```

### WeatherRenderer.gd

公开字段：`area`、`type`、`power`、`density`、`display`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WeatherRenderer.gd。Node2D批量显示，area逻辑像素、type/power/density/display由MapEffectsRenderer赋值。advance只移动/裁切粒子并queue_redraw，particle_count查询；至多256，不提供天气命令或保存，不能把粒子反向作为Game_Screen真值。

```gdscript
extends Node2D
func advance(delta: float) -> void
func particle_count() -> int
```

### WindowBase.gd

公开字段：`content`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WindowBase.gd。Control皮肤窗口；label创建Label返回实例，clear_content清掉内容，select_rect更新选择光标。192×128窗口皮肤背景/边框/光标，缺皮肤替代并诊断，content是窗口内容容器；无RGSS同名Ruby API运行能力。

```gdscript
extends Control
func label(text: String, rectangle: Rect2, color: Color = Color.WHITE, font_size: int = 20) -> Label
func clear_content() -> void
func select_rect(rectangle: Rect2, active: bool = true) -> void
```

### WindowCommand.gd

公开字段：`commands`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WindowCommand.gd。继承WindowSelectable，commands数组，configure(entries,selected) entries需text/enabled，current_enabled查当前项是否启用。父类select/move_selection负责滚动索引；disabled不表示业务已实现。

```gdscript
extends "res://runtime/scripts/WindowSelectable.gd"
func configure(entries: Array, selected: int = 0) -> void
func current_enabled() -> bool
```

### WindowSelectable.gd

公开字段：`index`、`item_count`、`row_height`、`active`、`scroll_row`。

常量（不含依赖脚本引用）：无。

源文件：templates/runtime/scripts/WindowSelectable.gd。继承WindowBase，index/item_count/row_height/active/scroll_row，select夹取索引并保持最小滚动，move_selection用方向增量并环绕，selection_changed发索引。父页面按选择/数据变化刷新，不逐帧重绘全部文字。

```gdscript
extends "res://runtime/scripts/WindowBase.gd"
signal selection_changed(index: int)
func select(value: int) -> void
func move_selection(direction: int) -> void
```

### AudioProbe.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/AudioProbe.gd。独立Godot SceneTree子进程入口，接收AssetCopier传入的命令行音频路径并隔离解码，成功标记/退出码由AssetCopier检查；没有可实例化的公共业务方法。不要在游戏事件中运行探针。

```gdscript
extends SceneTree
# 本类未声明自定义公共方法。
```

### MigrationPipeline.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/MigrationPipeline.gd。迁移流程run(preflight,progress)；preflight.ok且输出目录空才写，progress回调字符串。协调素材/脚本镜像/数据/模板/测试物资/报告，返回{ok,messages,output_path,report}；保留Ruby源码，不自动转GDScript。

```gdscript
extends RefCounted
class_name MigrationPipeline
func run(preflight: Dictionary, progress: Callable = Callable()) -> Dictionary
```

### MigrationReportWriter.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/MigrationReportWriter.gd。write(output_root,details)写JSON/中文Markdown报告，返回写入warnings数组；版本由Version引用，details来自Pipeline含统计/不支持命令/测试配置。调整事件支持后同步报告，不能只改文档宣称支持。

```gdscript
extends RefCounted
class_name MigrationReportWriter
func write(output_root: String, details: Dictionary) -> Array[String]
```

### ProjectGenerator.gd

公开字段：`warnings`。

常量（不含依赖脚本引用）：`EXTRA_README`。

源文件：scripts/importer/ProjectGenerator.gd。generate复制runtime/scripts/scenes/MAP_PRESENTATION文档并写project.godot、RuntimeVersion、输出README，返回warnings/width/height。窗口从INI取合法值，否则640×480；Compatibility/安全串行导入，RuntimeState Autoload，空地图区域/中心默认。生成器本身不保证外部调用的覆盖门禁，由Validator/Pipeline先检查。

```gdscript
extends RefCounted
class_name ProjectGenerator
func generate(output_root: String, project_title: String, ini: Dictionary, progress: Callable = Callable(), source_id: String = "") -> Dictionary
```

### RmxpAssetCopier.gd

公开字段：`warnings`、`errors`、`copied_assets`、`copied_legacy_files`。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/RmxpAssetCopier.gd。copy将非RTP Graphics/Audio写到assets/rmxp并建立asset_index，错误扩展名修正副本，音频隔离probe失败保留legacy/unsupported_assets；其他文件保留legacy。copy_scripts_mirror优先保留源Scripts，返回copied/count；warnings/errors/counter为本次结果。绝不修改源素材。

```gdscript
extends RefCounted
class_name RmxpAssetCopier
func copy(source_root: String, output_root: String, progress: Callable = Callable()) -> Dictionary
func copy_scripts_mirror(source_root: String, output_root: String) -> Dictionary
```

### RmxpDataConverter.gd

公开字段：`warnings`、`errors`、`unsupported_commands`、`converted_files`、`converted_maps`、`exported_scripts`。

常量（不含依赖脚本引用）：`RAW_STRING_KEY`。

源文件：scripts/importer/RmxpDataConverter.gd。new(codec)，set_asset_index映射素材，convert解析.rxdata/地图/系统/数据库/脚本并写JSON/legacy，export_scripts_from_data控制是否从Scripts.rxdata解压；返回统计/errors/warnings/unsupported_commands。原ID保留，未知Ruby类数据保留而非执行；新增事件支持同时修改这里的命令判定。

```gdscript
extends RefCounted
class_name RmxpDataConverter
func _init(text_codec: RmxpTextCodec) -> void
func set_asset_index(asset_index: Dictionary) -> void
func convert(source_root: String, output_root: String, progress: Callable = Callable(), export_scripts_from_data: bool = true) -> Dictionary
```

### RmxpIniReader.gd

公开字段：`codec`。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/RmxpIniReader.gd。new(codec)，read(path)按编码解析INI并返回章节Dictionary，供标题/分辨率/游戏设置读取；不执行INI指向的Ruby库。

```gdscript
extends RefCounted
class_name RmxpIniReader
func _init(text_codec: RmxpTextCodec) -> void
func read(path: String) -> Dictionary
```

### RmxpMarshalReader.gd

公开字段：`failed`、`error_message`。

常量（不含依赖脚本引用）：`RAW_STRING_KEY`。

源文件：scripts/importer/RmxpMarshalReader.gd。new(codec)，read_file/read_bytes返回Variant数据，failed/error_message标记解析失败，Ruby对象/用户自定义负载保留中间标识以供Converter处理。支持Marshal引用表，但不实例化执行Ruby。

```gdscript
extends RefCounted
class_name RmxpMarshalReader
func _init(text_codec: RmxpTextCodec) -> void
func read_file(path: String) -> Variant
func read_bytes(bytes: PackedByteArray) -> Variant
```

### RmxpTableDecoder.gd

公开字段：无。

常量（不含依赖脚本引用）：`RAW_STRING_KEY`。

源文件：scripts/importer/RmxpTableDecoder.gd。decode对用户自定义Table负载解析为dimensions/x_size/y_size/z_size/values（有符号16位）；非Table原样返回，坏Table返回_rmxp_table_error。下标规范见第5节，不把Ruby二进制留给地图渲染器。

```gdscript
extends RefCounted
class_name RmxpTableDecoder
static func decode(value: Variant) -> Variant
```

### RmxpTextCodec.gd

公开字段：`codepage`、`error_message`。

常量（不含依赖脚本引用）：`AUTO_CODEPAGE`、`GBK_CODEPAGE`、`SHIFT_JIS_CODEPAGE`。

源文件：scripts/importer/RmxpTextCodec.gd。new(requested_codepage=0)，0自动Windows ANSI、936GBK、932Shift-JIS；UTF-8有效输入优先。resolve_codepage取实际代码页，label给显示名，decode返回String并通过error_message报告失败，ensure_ready检查/生成解码表。Windows PowerShell仅用于编码表，不执行源工程脚本。

```gdscript
extends RefCounted
class_name RmxpTextCodec
func _init(requested_codepage: int = AUTO_CODEPAGE) -> void
static func resolve_codepage(requested_codepage: int) -> int
func label() -> String
func decode(bytes: PackedByteArray) -> String
func ensure_ready() -> bool
```

### RmxpValidator.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/RmxpValidator.gd。preflight(source_path,export_root,requested_encoding)返回ok/messages/errors及source_path/output_path/project_title/encoding/ini/map_files/database_files/graphics_count/audio_count；源含Game.rxproj/Game.ini/Data/System.rxdata，禁止导出到源内部或非空目标。调用方可加test_mode，传给Pipeline，预检不写源。

```gdscript
extends RefCounted
class_name RmxpValidator
func preflight(source_path: String, export_root: String, requested_encoding: int) -> Dictionary
```

### TestSetupGenerator.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/importer/TestSetupGenerator.gd。generate(output_root,enabled)生成独立data/test_setup.json，避源ID冲突，包含测试物品装备/特技动画/状态/金币商品及初始比例；返回ok与配置摘要或message。默认准备不表示恢复样板Ruby自定义系统，不改原数据库。

```gdscript
extends RefCounted
func generate(output_root: String, enabled: bool) -> Dictionary
```

### Main.gd

公开字段：无。

常量（不含依赖脚本引用）：无。

源文件：scripts/Main.gd。迁移器Control UI，用户选择源/导出/编码/测试准备、预检、迁移与报告；只有Godot生命周期/内部回调，无自定义公共方法。不可把它当生成游戏的运行状态入口。

```gdscript
extends Control
# 本类未声明自定义公共方法。
```

### Version.gd

公开字段：无。

常量（不含依赖脚本引用）：`NAME`、`VERSION`、`DISPLAY_NAME`。

源文件：scripts/Version.gd。class_name RGMigratorVersion，NAME、VERSION、DISPLAY_NAME是迁移器唯一版本常量；无自定义函数。当前VERSION=ver0.2，生成器和报告引用此处。

```gdscript
extends RefCounted
class_name RGMigratorVersion
# 本类未声明自定义公共方法。
```
