## 职责：持有唯一游戏运行状态，协调开关、变量、队伍、地图及各运行服务的生命周期。
##
## 调用方式：
##   本脚本作为 RuntimeState Autoload 使用，游戏场景和服务共享这一实例。
##   例如 RuntimeState.actor(角色编号)、RuntimeState.set_event_variable(变量编号, 值)。
##
## 调用接口：
##   func event_frame_deadline(budget_usec: int) -> int
##     参数 budget_usec（int；必填）：单次执行时间预算，单位为微秒。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func request_quit() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func set_event_switch(id: int, value: bool) -> bool
##     用途：写入原游戏开关并发送事件状态变化通知。
##     参数 id（int；必填）：原开关编号，使用正整数。
##     参数 value（bool；必填）：该开关新的开启状态。
##     返回：true 表示写入成功，false 表示编号或状态校验失败。
##
##   func set_event_variable(id: int, value: Variant) -> bool
##     用途：写入原游戏变量并通知依赖它的事件页刷新。
##     参数 id（int；必填）：原变量编号，使用正整数。
##     参数 value（Variant；必填）：新的变量值；自定义脚本允许的类型由运行服务验证。
##     返回：true 表示写入成功，false 表示编号或值不被当前运行规则接受。
##
##   func set_event_self_switch(map: int, event: int, letter: String, value: bool) -> bool
##     用途：写入指定地图事件的独立开关。
##     参数 map（int；必填）：原地图编号。
##     参数 event（int；必填）：该地图内的事件编号。
##     参数 letter（String；必填）：独立开关字母，如 A、B、C、D。
##     参数 value（bool；必填）：新的开启状态。
##     返回：是否成功完成写入。
##
##   func begin_new_game(system: Dictionary, testing_override: Dictionary = {}) -> void
##     用途：初始化正式新游戏状态。
##     参数 system（Dictionary；必填）：RuntimeData.system() 返回的原系统定义。
##     参数 testing_override（Dictionary；默认值 {}）：独立测试配置覆盖层；正常游戏使用默认值。
##     返回：无返回值；建立角色、地图和各运行服务。
##
##   func inventory_entries() -> Array[Dictionary]
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func common_event_reason(id: int) -> String
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func reserve_common_event( id: int, source: String = "", actor_id: int = 0, target_id: int = 0 ) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 source（String；默认值 ""）：待处理的原始文本、数据或状态。
##     参数 actor_id（int；默认值 0）：角色的原数据库编号。
##     参数 target_id（int；默认值 0）：目标对象的编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func use_skill(actor_id: int, skill_id: int, target_id: int = 0) -> Dictionary
##     用途：检查并执行技能使用效果。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 target_id（int；默认值 0）：目标对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func change_skill(actor_id: int, skill_id: int, learning: bool) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     参数 learning（bool；必填）：等级与技能编号组成的技能学习条目。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func has_skill(actor_id: int, skill_id: int) -> bool
##     用途：检查角色是否已学会指定技能。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 skill_id（int；必填）：技能的原数据库编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func skill_ids(actor_id: int) -> Array[int]
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func use_item(item_id: int, target_id: int) -> Dictionary
##     用途：检查并执行物品使用效果。
##     参数 item_id（int；必填）：物品的原数据库编号。
##     参数 target_id（int；必填）：目标对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func change_state(actor_id: int, state_id: int, adding: bool) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 state_id（int；必填）：状态的原数据库编号。
##     参数 adding（bool；必填）：是否处于新增模式。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func has_state(actor_id: int, state_id: int) -> bool
##     用途：检查对象是否具有指定状态。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 state_id（int；必填）：状态的原数据库编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func state_ids_for(actor_id: int, include_equipment: bool = true) -> Array[int]
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 include_equipment（bool；默认值 true）：计算时是否包含装备影响。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func clear_states(actor_id: int) -> Dictionary
##     用途：清除当前对象的状态集合。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func shop_buy(goods: Array, kind: String, id: int, quantity: int) -> Dictionary
##     参数 goods（Array；必填）：商店商品记录列表。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 quantity（int；必填）：本次购买、出售或使用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func shop_sell(kind: String, id: int, quantity: int) -> Dictionary
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 quantity（int；必填）：本次购买、出售或使用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func inventory_count(kind: String, id: int) -> int
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
##
##   func equip_preview(actor_id: int, slot: int, equipment_id: int) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     参数 equipment_id（int；必填）：装备的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func equip(actor_id: int, slot: int, equipment_id: int) -> Dictionary
##     用途：执行角色装备变更。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 slot（int；必填）：存档、装备或回路的槽位编号。
##     参数 equipment_id（int；必填）：装备的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func actor_parameter_sources(actor_id: int, key: String) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 key（String；必填）：查询或写入使用的键名。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func apply_actor_event(code: int, parameters: Array) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 parameters（Array；必填）：按对应接口或事件指令约定排列的参数。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func change_actor_parameter(actor_id: int, key: String, amount: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_actor_parameter(actor_id: int, key: String, value: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_actor_parameter_plus(actor_id: int, key: String, value: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_actor_experience(actor_id: int, value: Variant) -> Dictionary
##     用途：更新指定角色的对应状态。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 value（Variant；必填）：目标总经验。
##     返回：操作结果字典；先检查 ok，失败时读取 message。
##
##   func change_actor_experience(actor_id: int, amount: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_actor_level(actor_id: int, value: Variant) -> Dictionary
##     用途：更新指定角色的对应状态。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 value（Variant；必填）：目标等级。
##     返回：操作结果字典；先检查 ok，失败时读取 message。
##
##   func change_actor_level(actor_id: int, amount: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func set_actor_vital(actor_id: int, key: String, value: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func change_actor_vital(actor_id: int, key: String, amount: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func recover_actor_vitals(actor_id: int) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func rename_actor(actor_id: int, value: Variant) -> Dictionary
##     用途：更新指定角色的对应状态。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 value（Variant；必填）：新的角色名字。
##     返回：操作结果字典；先检查 ok，失败时读取 message。
##
##   func set_actor_graphic(actor_id: int, value: Variant, hue: Variant = 0) -> Dictionary
##     用途：更新指定角色的对应状态。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 value（Variant；必填）：新的行走图名称。
##     参数 hue（Variant；默认值 0）：素材色相参数。
##     返回：操作结果字典；先检查 ok，失败时读取 message。
##
##   func change_actor_class(actor_id: int, value: Variant) -> Dictionary
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func create_actor(actor_id: int, definition: Dictionary, lookup: Callable) -> RefCounted
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 definition（Dictionary；必填）：对象的只读定义或原数据库记录。
##     参数 lookup（Callable；必填）：按分类与编号查找只读数据库记录的回调。
##     返回：RefCounted 类型的对象或值，供调用方继续使用。
##
##   func actor(actor_id: int, reset: bool = false) -> RefCounted
##     用途：取得已注册角色，必要时按原数据初始化。
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 reset（bool；默认值 false）：true 时重新按定义初始化该角色；通常保持 false。
##     返回：同一编号对应的运行角色实例；无效引用按当前诊断规则处理。
##
##   func party_snapshots() -> Array[Dictionary]
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func change_party(actor_id: int, adding: bool, initialize: bool = false) -> void
##     参数 actor_id（int；必填）：角色的原数据库编号。
##     参数 adding（bool；必填）：是否处于新增模式。
##     参数 initialize（bool；默认值 false）：是否执行初始化步骤。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func record_step() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func configure_player(value: Dictionary) -> Dictionary
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func register_player(controller: Node) -> void
##     参数 controller（Node；必填）：消息、输入或人物控制器实例。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func player() -> Node
##     参数：无。
##     返回：Node 类型的对象或值，供调用方继续使用。
##
##   func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 name_value（String；必填）：待设置的名称文本。
##     参数 pose（Dictionary；默认值 {}）：人物或图形当前姿态。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 pose（Dictionary；必填）：人物或图形当前姿态。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func rotate_picture(number: int, degrees_per_second: Variant) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 degrees_per_second（Variant；必填）：每秒旋转的角度。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     参数 tone（Array；必填）：红、绿、蓝与灰度构成的色调参数。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func erase_picture(number: int) -> Dictionary
##     参数 number（int；必填）：当前操作使用的数值或编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func report_diagnostic(message: String) -> void
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fatal_script_error(message: String) -> void
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func register_game(instance: Node) -> void
##     参数 instance（Node；必填）：待操作的实际对象实例。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func game() -> Node
##     参数：无。
##     返回：Node 类型的对象或值，供调用方继续使用。
##
##   func map_time_paused() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func windowskin_name() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func set_windowskin(name_value: String) -> Dictionary
##     参数 name_value（String；必填）：待设置的名称文本。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func configure_map_view(changes: Dictionary) -> Dictionary
##     参数 changes（Dictionary；必填）：待应用的字段变化集合。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func configure_map_effects(changes: Dictionary) -> Dictionary
##     参数 changes（Dictionary；必填）：待应用的字段变化集合。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func scroll_map(direction: int, tiles: Variant, seconds: Variant = 0.0) -> Dictionary
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 tiles（Variant；必填）：地图或图块集的图块数据。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func scroll_map_native(direction: int, tiles: int, speed: int) -> Dictionary
##     参数 direction（int；必填）：当前操作使用的方向或选择移动量。
##     参数 tiles（int；必填）：地图或图块集的图块数据。
##     参数 speed（int；必填）：移动、播放或推进速度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func resume_map_follow() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fade_screen(opacity: Variant, seconds: Variant = 0.0) -> Dictionary
##     参数 opacity（Variant；必填）：透明度参数，取值按对应显示接口约定。
##     参数 seconds（Variant；默认值 0.0）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func freeze_screen() -> Dictionary
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func transition_screen( seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40 ) -> Dictionary
##     参数 seconds（Variant；默认值 0.2）：以秒计的时长。
##     参数 name_value（String；默认值 ""）：待设置的名称文本。
##     参数 vague（Variant；默认值 40）：过渡遮罩的模糊范围参数。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func cancel_screen_transition() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func self_switch_key(map_value: int, event_id: int, letter: String) -> String
##     参数 map_value（int；必填）：需要设置或显示的地图值。
##     参数 event_id（int；必填）：当前地图上的事件编号；0 的具体含义由调用入口约定。
##     参数 letter（String；必填）：独立开关字母，只接受 A/B/C/D。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func restore_prepared( prepared: Dictionary, preserve_audio: bool = false, restore_live_events: bool = true ) -> void
##     参数 prepared（Dictionary；必填）：已经过准备或校验的数据。
##     参数 preserve_audio（bool；默认值 false）：恢复现场时是否保留当前音频播放状态。
##     参数 restore_live_events（bool；默认值 true）：true在当前地图恢复事件现场；切换到新Game场景的读档使用false，将现场保留给新场景，避免在旧图重复恢复。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func gain_currency(key: String, amount: Variant) -> Dictionary
##     用途：按原上限规则增减对应货币。
##     参数 key（String；必填）：查询或写入使用的键名。
##     参数 amount（Variant；必填）：需要增加、扣除或应用的数量。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func commit_script_data(writes: Dictionary, draft: RefCounted) -> void
##     参数 writes（Dictionary；必填）：待发布的文件路径与文本内容集合。
##     参数 draft（RefCounted；必填）：调用方持有的独立编辑草稿。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func custom_record(database: String, id: int) -> Dictionary
##     参数 database（String；必填）：数据库分类或当前数据库定义。
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func custom_actor_attributes(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func evaluate_custom_expression(id: String) -> Dictionary
##     参数 id（String；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 对外信号：
##   system_settings_changed()：由持有方发出，通知对应状态或操作结果。
##   state_changed()：正式游戏状态已变化，关联界面可刷新。
##   event_state_changed(kind: String, key: String)：由持有方发出，通知对应状态或操作结果。
##     kind：消息、操作或对象的种类标识。
##     key：查询或写入使用的键名。
##   execution_reset()：由持有方发出，通知对应状态或操作结果。
##   diagnostic_added(message: String)：由持有方发出，通知对应状态或操作结果。
##     message：提示或诊断文本。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _exit_tree() -> void
##   func _notification(what: int) -> void
##     what：Godot 发出的通知编号。
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 注意：角色、背包、开关、变量和地图状态由同一实例持有；调用业务接口让原有通知与校验生效。
## 接口说明结束。

extends Node

const ActorState = preload("res://runtime/scripts/00_Game/ActorState.gd")
const RuntimeData = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const ActorEvents = preload("res://runtime/scripts/00_Game/ActorEventService.gd")
const InventoryService = preload("res://runtime/scripts/00_Game/InventoryService.gd")
const ShopService = preload("res://runtime/scripts/08_Menu/Shop/ShopService.gd")
const ScreenState = preload("res://runtime/scripts/00_Game/ScreenState.gd")
const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")
const CharacterMotion = preload("res://runtime/scripts/03_Map/CharacterMotion.gd")
const MapView = preload("res://runtime/scripts/00_Game/MapViewState.gd")
const MapEffects = preload("res://runtime/scripts/00_Game/MapEffectsState.gd")
const Settings = preload("res://runtime/scripts/00_Game/SystemSettings.gd")
const Countdown = preload("res://runtime/scripts/00_Game/GameTimer.gd")
const AudioService = preload("res://runtime/scripts/10_Support/Audio/AudioRuntime.gd")
const CustomData = preload("res://runtime/scripts/00_Game/CustomDataState.gd")
const Decimal = preload("res://runtime/scripts/10_Support/Utilities/DecimalInteger.gd")
signal system_settings_changed
signal state_changed
signal event_state_changed(kind: String, key: String)
signal execution_reset
signal diagnostic_added(message: String)

var switches: Dictionary = {}
var variables: Dictionary = {}
var self_switches: Dictionary = {}
var inventory: Dictionary = {}
var gold: Variant = 0
var custom_data: RefCounted = CustomData.new(self)
var save_count := 0
var message_position := 2
var message_frame := 0
var party: Array = []
var map_id := 1
var player_motion: RefCounted = CharacterMotion.new()
var _player_ref: WeakRef
var player_x: int:
	get:
		return player_motion.cell.x
	set(value):
		player_motion.relocate(Vector2i(value, player_motion.cell.y))
var player_y: int:
	get:
		return player_motion.cell.y
	set(value):
		player_motion.relocate(Vector2i(player_motion.cell.x, value))
var player_direction: int:
	get:
		return player_motion.direction
	set(value):
		player_motion.turn(value, true)
var resume_from_save := false
var pending_event_state: Dictionary = {}
var common_event_reservation: Dictionary = {}
var flash_temp_fields: Dictionary = CustomData.native_value(
	RuntimeData.read_json("res://data/flash_gameplay.json", {}).get("temp_defaults", {})
)
var save_disabled := false
var menu_disabled := false
var actors: Dictionary = {}
var diagnostics: Array[String] = []
var script_session: RefCounted
var steps := 0
var play_seconds := 0.0
var playing := false
var testing_enabled := false
var _clock_second := 0
var _quitting := false
var system_settings: RefCounted = Settings.new()
var screen: RefCounted = ScreenState.new()
var map_view: RefCounted = MapView.new()
var map_effects: RefCounted = MapEffects.new()
var timer: RefCounted = Countdown.new()
var audio: Node
var flash_preferences: RefCounted
var flash_messages: RefCounted
var flash_followers: RefCounted
var flash_effects: RefCounted
var flash_keyboard: RefCounted
var flash_archive_snapshot: Image
var pending_flash_presentation: Dictionary = {}
var flash_history: RefCounted
var _game_ref: WeakRef
var _event_budget_frame = -1
var _event_budget_deadline = 0
var _script_error_logger: Logger
var _fatal_script_message = ""
var _fatal_script_dialog: AcceptDialog


func event_frame_deadline(budget_usec: int) -> int:
	var frame = Engine.get_process_frames()
	if frame != _event_budget_frame:
		_event_budget_frame = frame
		_event_budget_deadline = Time.get_ticks_usec() + maxi(1, budget_usec)
	return _event_budget_deadline


func _ready() -> void:
	if custom_data.manifest.get("profile") == "flash":
		_script_error_logger = preload("../10_Support/Scripting/ScriptErrorLogger.gd").new(self)
		OS.add_logger(_script_error_logger)
	RuntimeData.bind_custom_data(custom_data)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if custom_data.manifest.get("profile") == "flash":
		flash_preferences = preload("Preferences.gd").new(self)
	if custom_data.manifest.get("profile") == "flash":
		flash_messages = load("res://runtime/scripts/06_Message/MessageController.gd").new(
			self
		)
		execution_reset.connect(flash_messages.reset)
		flash_followers = load("res://runtime/scripts/03_Map/Followers.gd").new(self)
		execution_reset.connect(flash_followers.reset)
		flash_effects = load("res://runtime/scripts/09_Effects/ScreenEffects.gd").new(self)
		execution_reset.connect(flash_effects.reset)
		flash_keyboard = load("res://runtime/scripts/10_Support/Utilities/Keyboard.gd").new()
		flash_history = load("res://runtime/scripts/10_Support/Persistence/History.gd").new(
			self
		)
		execution_reset.connect(flash_keyboard.reset)
		execution_reset.connect(func(): flash_archive_snapshot = null)
	audio = AudioService.new()
	add_child(audio)
	get_tree().auto_accept_quit = false


func _exit_tree() -> void:
	if _script_error_logger != null:
		OS.remove_logger(_script_error_logger)
	if flash_history != null:
		flash_history.flush_pending()
	preload("../01_Battle/BattleCache.gd").clear_conditions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func request_quit() -> void:
	if _quitting:
		return
	_quitting = true
	playing = false
	# Allow the audio server to release playback references before process shutdown.
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.2, true).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	if not _fatal_script_message.is_empty():
		return
	if flash_history != null:
		flash_history.poll()
	if playing:
		play_seconds += delta
		if int(play_seconds) != _clock_second:
			_clock_second = int(play_seconds)
			state_changed.emit()


func set_event_switch(id: int, value: bool) -> bool:
	if id <= 0:
		return false
	var key := str(id)
	if bool(switches.get(key, false)) == value:
		return true
	switches[key] = value
	event_state_changed.emit("switch", key)
	state_changed.emit()
	return true


func set_event_variable(id: int, value: Variant) -> bool:
	if id <= 0:
		return false
	if not CustomData.plain_reason(value).is_empty():
		return false
	var key := str(id)
	if CustomData.same_value(variables.get(key, 0), value):
		return true
	variables[key] = value
	event_state_changed.emit("variable", key)
	state_changed.emit()
	return true


func set_event_self_switch(map: int, event: int, letter: String, value: bool) -> bool:
	if event <= 0 or letter not in ["A", "B", "C", "D"]:
		return false
	var key := self_switch_key(map, event, letter)
	if bool(self_switches.get(key, false)) == value:
		return true
	self_switches[key] = value
	event_state_changed.emit("self", key)
	state_changed.emit()
	return true


func begin_new_game(system: Dictionary, testing_override: Dictionary = {}) -> void:
	if flash_history != null:
		flash_history.reset()
	script_session = null
	custom_data = CustomData.new(self)
	RuntimeData.bind_custom_data(custom_data)
	execution_reset.emit()
	pending_event_state.clear()
	pending_flash_presentation = {}
	common_event_reservation.clear()
	flash_temp_fields = (
		CustomData
		. native_value(
			RuntimeData.read_json("res://data/flash_gameplay.json", {}).get("temp_defaults", {})
		)
		. duplicate(true)
	)
	system_settings = Settings.new()
	system_settings_changed.emit()
	screen = ScreenState.new()
	map_view = MapView.new()
	var configured: Dictionary = map_view.configure(
		{
			"view_rect": ProjectSettings.get_setting("rgmigrator/map_view_rect", []),
			"follow_center": ProjectSettings.get_setting("rgmigrator/map_follow_center", [])
		}
	)
	map_effects = MapEffects.new()
	timer = Countdown.new()
	if audio != null:
		audio.stop_all()
	player_motion.reset()
	actors.clear()
	diagnostics.clear()
	if not configured.ok:
		report_diagnostic(configured.message)
	var setup := RuntimeData.configure_testing(testing_override)
	testing_enabled = bool(setup.get("enabled", false))
	for message in setup.get("errors", []):
		report_diagnostic(str(message))
	steps = 0
	play_seconds = 0.0
	_clock_second = 0
	playing = true
	switches.clear()
	variables.clear()
	self_switches.clear()
	inventory.clear()
	gold = 0
	save_count = 0
	message_position = 2
	message_frame = 0
	# JSON numbers are floats. Runtime IDs must be ints for Array.has/erase.
	party = []
	for raw_id in system.get("party_members", []):
		var actor_id := int(raw_id)
		if not party.has(actor_id):
			party.append(actor_id)
	map_id = int(system.get("start_map_id", 1))
	player_x = int(system.get("start_x", 0))
	player_y = int(system.get("start_y", 0))
	player_direction = 2
	resume_from_save = false
	save_disabled = false
	menu_disabled = false
	for actor_id in party:
		actor(int(actor_id))
	if (
		custom_data.manifest.get("profile") == "flash"
		and FileAccess.file_exists("res://data/flash_gameplay.json")
	):
		custom_data.gameplay().role_ids(true, true)
	if testing_enabled:
		_prepare_testing(setup)
	state_changed.emit()


func inventory_entries() -> Array[Dictionary]:
	return InventoryService.entries(self)


func common_event_reason(id: int) -> String:
	if id <= 0 or RuntimeData.record("CommonEvents", id).is_empty():
		return "公共事件%d不存在。" % id
	if game() == null or not playing:
		return "公共事件使用需要当前地图场景。"
	if not common_event_reservation.is_empty():
		return "已有公共事件等待执行，请先返回地图。"
	return ""


func reserve_common_event(
	id: int, source: String = "", actor_id: int = 0, target_id: int = 0
) -> Dictionary:
	var reason := common_event_reason(id)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	common_event_reservation = {
		"id": id, "source": source, "actor_id": actor_id, "target_id": target_id
	}
	return {"ok": true, "common_event": id}


func use_skill(actor_id: int, skill_id: int, target_id: int = 0) -> Dictionary:
	return preload("res://runtime/scripts/00_Game/CommonEventUse.gd").use_skill(
		self, actor_id, skill_id, target_id
	)


func change_skill(actor_id: int, skill_id: int, learning: bool) -> Dictionary:
	var instance := actor(actor_id)
	if instance == null:
		return {"ok": false, "message": "不存在的 Actors[%d]。" % actor_id}
	var result: Dictionary = (
		instance.learn_skill(skill_id) if learning else instance.forget_skill(skill_id)
	)
	if not result.ok:
		report_diagnostic(result.message)
	return result


func has_skill(actor_id: int, skill_id: int) -> bool:
	var instance := actor(actor_id)
	return instance != null and instance.has_skill(skill_id)


func skill_ids(actor_id: int) -> Array[int]:
	var instance := actor(actor_id)
	return instance.get_skill_ids() if instance != null else []


func use_item(item_id: int, target_id: int) -> Dictionary:
	return InventoryService.use_item(self, item_id, target_id)


func change_state(actor_id: int, state_id: int, adding: bool) -> Dictionary:
	var instance := actor(actor_id)
	if instance == null:
		return {"ok": false, "changed": false, "message": "不存在的 Actors[%d]。" % actor_id}
	var result: Dictionary = (
		instance.add_state(state_id) if adding else instance.remove_state(state_id)
	)
	if not result.ok:
		report_diagnostic(result.message)
	return result


func has_state(actor_id: int, state_id: int) -> bool:
	var instance := actor(actor_id)
	return instance != null and instance.has_state(state_id)


func state_ids_for(actor_id: int, include_equipment: bool = true) -> Array[int]:
	var instance := actor(actor_id)
	return instance.get_state_ids(include_equipment) if instance != null else []


func clear_states(actor_id: int) -> Dictionary:
	var instance := actor(actor_id)
	return (
		instance.clear_states()
		if instance != null
		else {"ok": false, "changed": false, "message": "不存在的 Actors[%d]。" % actor_id}
	)


func shop_buy(goods: Array, kind: String, id: int, quantity: int) -> Dictionary:
	return ShopService.buy(self, goods, kind, id, quantity)


func shop_sell(kind: String, id: int, quantity: int) -> Dictionary:
	return ShopService.sell(self, kind, id, quantity)


func inventory_count(kind: String, id: int) -> int:
	return int(inventory.get("%s:%d" % [kind, id], 0))


func equip_preview(actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	return InventoryService.equip_preview(self, actor_id, slot, equipment_id)


func equip(actor_id: int, slot: int, equipment_id: int) -> Dictionary:
	return InventoryService.equip(self, actor_id, slot, equipment_id)


func actor_parameter_sources(actor_id: int, key: String) -> Dictionary:
	var instance := actor(actor_id)
	return instance.parameter_sources(key) if instance != null else {}


func _actor_call(actor_id: int, method: String, arguments: Array) -> Dictionary:
	var instance := actor(actor_id)
	var result: Dictionary = (
		{"ok": false, "message": "不存在的 Actors[%d]。" % actor_id}
		if instance == null
		else instance.callv(method, arguments)
	)
	if not result.ok:
		report_diagnostic("Actors[%d]：%s" % [actor_id, result.message])
	return result


func apply_actor_event(code: int, parameters: Array) -> Dictionary:
	return ActorEvents.execute(self, code, parameters)


func change_actor_parameter(actor_id: int, key: String, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_parameter_plus", [key, amount])


func set_actor_parameter(actor_id: int, key: String, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_parameter", [key, value])


func set_actor_parameter_plus(actor_id: int, key: String, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_parameter_plus", [key, value])


func set_actor_experience(actor_id: int, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_experience", [value])


func change_actor_experience(actor_id: int, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_experience", [amount])


func set_actor_level(actor_id: int, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_level", [value])


func change_actor_level(actor_id: int, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_level", [amount])


func set_actor_vital(actor_id: int, key: String, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "set_vital", [key, value])


func change_actor_vital(actor_id: int, key: String, amount: Variant) -> Dictionary:
	return _actor_call(actor_id, "add_vital", [key, amount])


func recover_actor_vitals(actor_id: int) -> Dictionary:
	return _actor_call(actor_id, "recover_vitals", [])


func rename_actor(actor_id: int, value: Variant) -> Dictionary:
	return _actor_call(actor_id, "rename", [value])


func set_actor_graphic(actor_id: int, value: Variant, hue: Variant = 0) -> Dictionary:
	if value is String and not value.is_empty():
		var texture: Texture2D = Cache.character(value)
		if texture == null or texture.get_width() % 4 != 0 or texture.get_height() % 4 != 0:
			return {"ok": false, "message": "角色图缺失或不是四方向四帧格式；未修改。"}
	return _actor_call(actor_id, "set_graphic", [value, hue])


func change_actor_class(actor_id: int, value: Variant) -> Dictionary:
	var instance := actor(actor_id)
	if (
		instance == null
		or not ActorState.Parameters.integer(value, 1)
		or RuntimeData.record("Classes", int(value)).is_empty()
	):
		return {"ok": false, "message": "角色或目标职业不存在。"}
	var profession := RuntimeData.record("Classes", int(value))
	var proposed: Array = instance.equipment.duplicate()
	var stock := inventory.duplicate(true)
	for slot in 5:
		var equipment_id := int(proposed[slot])
		if equipment_id == 0:
			continue
		var database := "Weapons" if slot == 0 else "Armors"
		if RuntimeData.record(database, equipment_id).is_empty():
			return {"ok": false, "message": "当前装备引用缺失；职业和背包均未修改。"}
		var allowed: Array = profession.get("weapon_set" if slot == 0 else "armor_set", [])
		if (
			RuntimeData.is_test_record(database, equipment_id)
			or allowed.any(func(id: Variant) -> bool: return int(id) == equipment_id)
		):
			continue
		var key := "%s:%d" % ["weapon" if slot == 0 else "armor", equipment_id]
		var count: Variant = stock.get(key, 0)
		if not ActorState.Parameters.integer(count, 0, 98):
			return {"ok": false, "message": "不兼容装备无法收回（数量无效或已达 99）；职业和装备均未修改。"}
		stock[key] = int(count) + 1
		proposed[slot] = 0
	var preview: Dictionary = instance.snapshot(proposed)
	if preview.parameters.values().has(null):
		return {"ok": false, "message": "变更后属性无法计算；职业未修改。"}
	var modified: bool = instance.class_id != int(value) or instance.equipment != proposed
	instance.class_id = int(value)
	instance.equipment.assign(proposed)
	inventory = stock
	instance._clamp_vitals(preview.parameters)
	if modified:
		instance.changed.emit()
	return {"ok": true, "changed": modified, "message": "职业已更新，不兼容装备已收回；保留经验、等级和已学特技。"}


func _prepare_testing(setup: Dictionary) -> void:
	var initial_gold: Variant = setup.get("initial_gold", 0)
	if ShopService.integer(initial_gold, 0, ShopService.MAX_GOLD):
		gold = int(initial_gold)
	else:
		report_diagnostic("测试 initial_gold 必须为 0–9999999 的整数；未发放金币。")
	for entry in setup.get("stock", []):
		if (
			not entry is Dictionary
			or not entry.get("id", 0) is float and not entry.get("id", 0) is int
		):
			report_diagnostic("测试 stock 条目必须包含数值 id。")
			continue
		var kind := str(entry.get("kind", ""))
		var id := int(entry.get("id", 0))
		var database := str(InventoryService.DATABASES.get(kind, ""))
		if database.is_empty() or not RuntimeData.is_test_record(database, id):
			report_diagnostic("测试 stock 引用未注册的测试物资：%s:%d" % [kind, id])
			continue
		var quantity: Variant = entry.get("quantity", 0)
		if not quantity is int and not quantity is float:
			report_diagnostic("测试物资数量必须为数字：%s:%d" % [kind, id])
			continue
		inventory["%s:%d" % [kind, id]] = clampi(int(quantity), 0, 99)
	for actor_id in party:
		var instance := actor(int(actor_id))
		if instance == null:
			continue
		for skill_id in setup.get("learn_skills", []):
			if skill_id is int or skill_id is float:
				change_skill(int(actor_id), int(skill_id), true)
		for state_id in setup.get("initial_states", []):
			if ShopService.integer(state_id, 1):
				change_state(int(actor_id), int(state_id), true)
		var view: Dictionary = instance.snapshot()
		var hp_ratio: Variant = setup.get("initial_hp_ratio", 0.5)
		var sp_ratio: Variant = setup.get("initial_sp_ratio", 0.5)
		if not hp_ratio is int and not hp_ratio is float:
			hp_ratio = 0.5
		if not sp_ratio is int and not sp_ratio is float:
			sp_ratio = 0.5
		if view.parameters.maxhp != null:
			instance.hp = maxi(1, int(int(view.parameters.maxhp) * clampf(float(hp_ratio), 0, 1)))
		if view.parameters.maxsp != null:
			instance.sp = int(int(view.parameters.maxsp) * clampf(float(sp_ratio), 0, 1))


func create_actor(actor_id: int, definition: Dictionary, lookup: Callable) -> RefCounted:
	var actor_type: Script = (
		preload("res://runtime/scripts/00_Game/Game_ActorState.gd")
		if (
			custom_data.manifest.get("profile") == "flash"
			and FileAccess.file_exists("res://data/flash_gameplay.json")
		)
		else ActorState
	)
	var instance: RefCounted = actor_type.new()
	instance.configure(actor_id, definition, lookup)
	return instance


func actor(actor_id: int, reset: bool = false) -> RefCounted:
	if actors.has(actor_id) and not reset:
		return actors[actor_id]
	var definition := RuntimeData.record("Actors", actor_id)
	if definition.is_empty():
		report_diagnostic("队伍引用了不存在的 Actors[%d]。" % actor_id)
		return null
	var instance := create_actor(actor_id, definition, RuntimeData.record)
	if instance.has_method("attach_project_fields"):
		if reset:
			custom_data.values.actors.erase(str(actor_id))
		instance.attach_project_fields(custom_data.actor_attributes(actor_id))
	instance.changed.connect(func() -> void: state_changed.emit())
	actors[actor_id] = instance
	for message in instance.diagnostics:
		report_diagnostic(message)
	return instance


func party_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor_id in party:
		var instance := actor(int(actor_id))
		if instance != null:
			var view: Dictionary = instance.snapshot()
			view["custom_attributes"] = custom_actor_attributes(int(actor_id))
			result.append(view)
			for message in view.diagnostics:
				report_diagnostic(message)
	return result


func change_party(actor_id: int, adding: bool, initialize: bool = false) -> void:
	if adding:
		if actor(actor_id, initialize) == null:
			return
		if not party.has(actor_id):
			party.append(actor_id)
	else:
		party.erase(actor_id)
	state_changed.emit()


func record_step() -> void:
	steps += 1
	state_changed.emit()


func configure_player(value: Dictionary) -> Dictionary:
	var result: Dictionary = player_motion.configure(value)
	if result.ok:
		state_changed.emit()
	return result


func register_player(controller: Node) -> void:
	_player_ref = weakref(controller)


func player() -> Node:
	var controller: Node = null if _player_ref == null else _player_ref.get_ref()
	if not is_instance_valid(controller) or not controller.is_inside_tree():
		return null
	var ancestor := controller
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return null
		ancestor = ancestor.get_parent()
	return controller


func show_picture(number: int, name_value: String, pose: Dictionary = {}) -> Dictionary:
	if (
		number < 1
		or number > 50
		or not ScreenState.Picture.valid_name(name_value)
		or not ScreenState.Picture.pose_valid(pose, true)
	):
		return _screen_result({"ok": false, "message": "图片编号、文件名或显示参数无效。"})
	if name_value.begins_with("@test_") and not testing_enabled:
		return _screen_result({"ok": false, "message": "测试图片只能在测试模式使用。"})
	if Cache.picture(name_value) == null:
		return _screen_result(
			{
				"ok": false,
				"message":
				"Pictures[%d] 素材缺失：Graphics/Pictures/%s；原图片未替换，不补取 RTP。" % [number, name_value]
			}
		)
	return _screen_result(screen.show_picture(number, name_value, pose))


func move_picture(number: int, pose: Dictionary, seconds: Variant = 0.0) -> Dictionary:
	return _screen_result(screen.move_picture(number, pose, seconds))


func rotate_picture(number: int, degrees_per_second: Variant) -> Dictionary:
	return _screen_result(screen.rotate_picture(number, degrees_per_second))


func tint_picture(number: int, tone: Array, seconds: Variant = 0.0) -> Dictionary:
	return _screen_result(screen.tint_picture(number, tone, seconds))


func erase_picture(number: int) -> Dictionary:
	return _screen_result(screen.erase_picture(number))


func _screen_result(result: Dictionary) -> Dictionary:
	if not result.ok:
		report_diagnostic(result.message)
	return result


func report_diagnostic(message: String) -> void:
	if not diagnostics.has(message):
		diagnostics.append(message)
		push_warning(message)
	diagnostic_added.emit(message)


func fatal_script_error(message: String) -> void:
	if not _fatal_script_message.is_empty():
		return
	if script_session != null and not script_session.execution_context.is_empty():
		var context: Dictionary = script_session.execution_context
		message = (
			"Map%03d / 事件%d / 公共事件%d / 第%d条\n%s"
			% [
				context.get("map_id", map_id),
				context.get("event_id", 0),
				context.get("common_id", 0),
				int(context.get("index", 0)) + 1,
				message
			]
		)
	_fatal_script_message = message
	get_tree().paused = true
	call_deferred("_show_fatal_script_error")


func _script_engine_error(message: String) -> void:
	if script_session != null and script_session.failure.is_empty():
		script_session.failure = {
			"ok": false,
			"message": message,
			"origin": script_session.origin,
			"span": script_session.span
		}
	fatal_script_error(message)


func _show_fatal_script_error() -> void:
	printerr("FATAL SCRIPT ERROR: ", _fatal_script_message)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	_fatal_script_dialog = AcceptDialog.new()
	_fatal_script_dialog.title = "脚本错误：游戏已停止"
	_fatal_script_dialog.dialog_text = "脚本执行出错，游戏将关闭。\n\n" + _fatal_script_message
	_fatal_script_dialog.ok_button_text = "关闭游戏"
	_fatal_script_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_fatal_script_dialog.exclusive = true
	_fatal_script_dialog.confirmed.connect(func(): get_tree().quit(1))
	_fatal_script_dialog.canceled.connect(func(): get_tree().quit(1))
	add_child(_fatal_script_dialog)
	_fatal_script_dialog.popup_centered_clamped(Vector2i(760, 480), 0.85)


func register_game(instance: Node) -> void:
	_game_ref = weakref(instance)


func game() -> Node:
	var instance: Node = _game_ref.get_ref() if _game_ref != null else null
	if instance == null or not instance.is_inside_tree() or instance.is_queued_for_deletion():
		return null
	return instance


func map_time_paused() -> bool:
	return (
		get_tree().paused
		or (flash_effects != null and flash_effects.busy())
		or (
			game() != null
			and (
				not game()._event_checkpoint.is_empty()
				or game().event_screen_transition_active()
				or game().event_scene_transition_active()
			)
		)
	)


func windowskin_name() -> String:
	return system_settings.windowskin_name()


func set_windowskin(name_value: String) -> Dictionary:
	var parsed := Settings.decode({"windowskin_name": name_value})
	if not parsed.ok:
		return parsed
	if not name_value.is_empty():
		var skin: Texture2D = Cache.windowskin(name_value)
		if skin == null or skin.get_width() != 192 or skin.get_height() != 128:
			return {"ok": false, "message": "Windowskins/%s 缺失或不是192×128；原皮肤保持。" % name_value}
	system_settings = parsed.value
	system_settings_changed.emit()
	return {"ok": true}


func configure_map_view(changes: Dictionary) -> Dictionary:
	var result: Dictionary = map_view.configure(changes)
	if result.ok and game() != null:
		game()._camera.sync(0)
	return _screen_result(result)


func configure_map_effects(changes: Dictionary) -> Dictionary:
	for key in ["fog_name", "panorama_name"]:
		if changes.has(key) and changes[key] is String and not changes[key].is_empty():
			var texture: Texture2D = (
				Cache.fog(changes[key]) if key == "fog_name" else Cache.panorama(changes[key])
			)
			if texture == null:
				return _screen_result(
					{"ok": false, "message": "%s 素材缺失：%s；原显示保持，不补取 RTP。" % [key, changes[key]]}
				)
	return _screen_result(map_effects.configure(changes))


func scroll_map(direction: int, tiles: Variant, seconds: Variant = 0.0) -> Dictionary:
	if game() == null:
		return {"ok": false, "message": "当前没有地图。"}
	return game()._camera.scroll(direction, tiles, seconds)


func scroll_map_native(direction: int, tiles: int, speed: int) -> Dictionary:
	if game() == null:
		return {"ok": false, "message": "当前没有地图。"}
	return game().scroll_event_map(direction, tiles, speed)


func resume_map_follow() -> void:
	map_view.resume_follow()


func fade_screen(opacity: Variant, seconds: Variant = 0.0) -> Dictionary:
	if game() == null:
		return {"ok": false, "message": "当前没有地图画面。"}
	return game()._transition.fade(opacity, seconds)


func freeze_screen() -> Dictionary:
	if game() == null:
		return {"ok": false, "message": "当前没有地图画面。"}
	return await game()._transition.freeze_screen()


func transition_screen(
	seconds: Variant = 0.2, name_value: String = "", vague: Variant = 40
) -> Dictionary:
	if game() == null:
		return {"ok": false, "message": "当前没有地图画面。"}
	return game()._transition.transition(seconds, name_value, vague)


func cancel_screen_transition() -> void:
	if game() != null:
		game().cancel_event_transfer()
		game().cancel_event_screen_transition()


func self_switch_key(map_value: int, event_id: int, letter: String) -> String:
	return "%d:%d:%s" % [map_value, event_id, letter]


func restore_prepared(
	prepared: Dictionary, preserve_audio: bool = false, restore_live_events: bool = true
) -> void:
	script_session = null
	custom_data = CustomData.new(self)
	RuntimeData.bind_custom_data(custom_data)
	custom_data.restore(prepared.state.get("custom_data", custom_data.snapshot()))
	if prepared.state.has("script_data"):
		script_session = (
			preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd").new(self)
		)
		script_session.globals = prepared.state.script_data.globals
		script_session.constants = prepared.state.script_data.constants
		for field in ["classes", "methods", "loaded_units"]:
			if prepared.state.script_data.has(field):
				script_session.set(field, prepared.state.script_data[field])
		script_session._regex_data = prepared.state.script_data.get("regex")
	execution_reset.emit()
	screen = prepared.screen
	pending_flash_presentation = prepared.get("flash_presentation", {})
	map_view = prepared.map_view
	map_effects = prepared.map_effects
	timer = prepared.timer
	system_settings = prepared.system_settings
	if audio != null and not preserve_audio:
		audio.restore_prepared(prepared.audio)
	# SaveCodec has validated every field and built detached actors before commit.
	var saved: Dictionary = prepared.state
	pending_event_state = saved.get("event_state", {})
	flash_temp_fields = saved.get(
		"flash_temp_fields",
		CustomData.native_value(
			RuntimeData.read_json("res://data/flash_gameplay.json", {}).get("temp_defaults", {})
		)
	)
	common_event_reservation = saved.get("common_event_reservation", {}).duplicate(true)
	player_motion.reset()
	player_motion.configure(saved.player_options)
	RuntimeData.install_testing(saved.testing.enabled, prepared.test_records)
	testing_enabled = saved.testing.enabled
	actors = prepared.actors
	for instance in actors.values():
		if instance.has_method("attach_project_fields"):
			instance._lookup = custom_record
			instance.attach_project_fields(custom_data.actor_attributes(instance.id))
		instance.changed.connect(func() -> void: state_changed.emit())
	for field in ["switches", "variables", "self_switches", "inventory", "party"]:
		set(field, saved[field])
	gold = Decimal.compact(saved.gold)
	for field in [
		"map_id",
		"player_x",
		"player_y",
		"player_direction",
		"steps",
		"save_count",
		"message_position",
		"message_frame"
	]:
		set(field, int(saved[field]))
	play_seconds = float(saved.play_seconds)
	_clock_second = int(play_seconds)
	save_disabled = saved.save_disabled
	menu_disabled = saved.menu_disabled
	diagnostics.clear()
	playing = true
	resume_from_save = true
	system_settings_changed.emit()
	state_changed.emit()
	if (
		restore_live_events
		and not preserve_audio
		and game() != null
		and not pending_event_state.is_empty()
	):
		game().restore_event_state()


func gain_currency(key: String, amount: Variant) -> Dictionary:
	var result = custom_data.gain_currency(key, amount)
	if result.ok:
		state_changed.emit()
	return result


func commit_script_data(writes: Dictionary, draft: RefCounted) -> void:
	# All script validation is complete. Publish notifications after every write.
	if draft != null:
		if not draft.preference_data.is_empty() and flash_preferences != null:
			flash_preferences.vars = draft.preference_data.vars
			flash_preferences.music_lock = draft.preference_data.music_lock
			flash_preferences.apply_audio()
			flash_preferences.apply_window()
		if draft.script_variables != null:
			variables = draft.script_variables
		flash_temp_fields = draft.temp_fields
		party = draft.party_ids
		inventory = draft.inventory_items
		custom_data.install(draft)
		for actor_id in actors:
			if actors[actor_id].has_method("attach_project_fields"):
				actors[actor_id].attach_project_fields(custom_data.actor_attributes(actor_id))
		for actor_id in draft.actor_edits:
			if actors.has(actor_id):
				actors[actor_id].set_block_signals(true)
				actors[actor_id].commit_event_state(draft.actor_edits[actor_id])
				actors[actor_id].set_block_signals(false)
			else:
				actors[actor_id] = draft.actor_edits[actor_id]
				# A newly staged actor must not retain the expiring transaction lookup.
				actors[actor_id]._lookup = custom_record
				actors[actor_id].attach_project_fields(custom_data.actor_attributes(actor_id))
				actors[actor_id].changed.connect(func() -> void: state_changed.emit())
	for key in writes:
		var parts: PackedStringArray = str(key).split(":")
		if parts[0] == "variable":
			variables[parts[1]] = writes[key]
		elif parts[0] == "self":
			self_switches[str(key).trim_prefix("self:")] = writes[key]
		else:
			switches[parts[1]] = writes[key]
	if draft != null:
		for key in draft.pending_effects:
			if key == "common_event":
				common_event_reservation = draft.pending_effects[key]
			else:
				flash_temp_fields[key] = draft.pending_effects[key]
		preload("../03_Map/CharacterBridge.gd").commit(draft.character_edits)
		if flash_effects != null:
			flash_effects.install(draft.screen_edits)
		if flash_keyboard != null and not draft.keyboard_draft.is_empty():
			flash_keyboard.install(draft.keyboard_draft)
	for key in writes:
		var parts: PackedStringArray = str(key).split(":")
		event_state_changed.emit(parts[0], str(key).trim_prefix(parts[0] + ":"))
	state_changed.emit()


func custom_record(database: String, id: int) -> Dictionary:
	return custom_data.record(database, id)


func custom_actor_attributes(id: int) -> Dictionary:
	return custom_data.actor_attributes(id).duplicate(true)


func evaluate_custom_expression(id: String) -> Dictionary:
	return (
		preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
		. evaluate_data_expression(id, self)
	)
