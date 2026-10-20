## 职责：生成 Godot 工程配置，安装运行时和魔塔编辑器，并附带脚本工作区转换工具及开发说明。
##
## 调用方式：
##   迁移管线在数据转换后创建该服务并调用 generate(...)。
##   正式迁移使用全新非空检查通过的输出目录，历史用户工程保留。
##
## 调用接口：
##   func generate( output_root: String, project_title: String, ini: Dictionary, progress: Callable = Callable(), source_id: String = "" ) -> Dictionary
##     用途：安装运行模板、编辑器、工程配置和开发说明。
##     参数 output_root（String；必填）：全新生成工程的绝对输出根目录。
##     参数 project_title（String；必填）：从原工程读取的游戏标题。
##     参数 ini（Dictionary；必填）：原 INI 配置，包含可识别的窗口参数。
##     参数 progress（Callable；默认值 Callable()）：阶段提示回调；不提供时使用默认空回调。
##     参数 source_id（String；默认值 ""）：原工程的稳定来源标识，用于项目存档归属。
##     返回：包含 warnings、width、height 的生成结果字典。
##
##   func write_flash_source_guide(output_root: String) -> void
##     参数 output_root（String；必填）：生成工程的输出根目录。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 公开常量：EXTRA_README。
## 接口说明结束。

class_name ProjectGenerator
extends RefCounted

const RGMigratorVersion = preload("res://scripts/Version.gd")
const EXTRA_README := """
## 脚本工作区（ver0.48）

魔塔编辑器F8打开脚本工作区：原Ruby和生成GDScript只读查看，可编辑工作副本、跳转源码/诊断、保存后重新转换并更新实际事件绑定。专用GDScript服务通过覆盖树进入Godot内置编辑器。转换失败保留旧代码，手工改过的生成文件阻止覆盖。覆盖报告script_coverage.md和data/script_coverage.json分别记录解析/生成/绑定/服务分类，不能推算游戏完成率。项目自定义数据使用专用货币、初始选项、角色预设和楼层页面。修改成功后重新运行游戏。完整流程整体验收仍待0.49。

## 脚本解析与生成

script_inventory.md列出脚本ID、加载顺序、原事件片段和依赖候选。data/script_units.json分别记录解析、生成、接入及验证状态；data/script_ast保留完整节点。0.41只扩展AST，0.42生成已支持语义的GDScript函数；runtime/generated存放生成源码，data/script_source_map.json记录原脚本/类/方法到文件/函数/行号，data/script_semantics.json记录作用域、定义版本和alias。通过ScriptRuntime.execute_unit和call_method显式调用；依赖未加载时给出失败。0.43已接通355/655、脚本条件和路线脚本；按生成能力恢复原指令。运行时核对原文哈希，未迁移依赖或初始化会中断并报告源位置；生成单元不代表魔塔玩法已迁移。原Ruby不执行，完整源和镜像差异均保留。

事件列表的条件、选项和循环竖线贯穿其内部至结束，文章/注释竖线按嵌套层级内缩并贯通自己的续行；多行正文对齐与整条选择保持。

## 编辑器交互与指令配色（ver0.39）

数据库可设置最大编号并保留空槽位，列表每组100条，支持搜索和编号跳转。切换、关闭自动保留当前编辑到草稿，Ctrl+S才保存文件，撤销可恢复。动画切换保持编辑页，公共事件指令占主区域。图块属性标记按实际显示尺寸重绘并居中。绘制模式右键拾取当前层图块，顶部不再显示吸管按钮。地图事件、公共事件和移动路线按功能统一配色，脚本与未支持状态继续标明并保留原参数。

## 编辑器反馈修正（ver0.37）

事件模式左键拖动事件，松开提交一次，Esc取消；右键目标格设置玩家起点，工具栏原按钮删除。系统在左侧选择页；起点与直接场所移动显示实际地图供点格，滚轮缩放、中键平移；变量移动仍选具名变量。

数据库“音频素材”可浏览BGM/BGS/ME/SE，双击试听。所有音频选择窗口支持试听、停止、实时音量与声调；确认写回引用和参数，关闭停止，不改原音频。引用统一[0003] 名称，事件摘要如“开关 [0003] 3号开关 打开”、“金钱 +10”。

## 数据库与复杂数据（ver0.37）

F9打开数据库，常用字段按用途放在页签内直接编辑；具名图片预览双击更换，专用控件替换字段/值占位表。角色成长显示等级与六项能力的整数列；职业可逐项设置习得等级、具名特技，并增删及调整顺序。集合按名称勾选并显示选中数量，有效度按属性/状态名称选择A–F，原工程特殊值明确保留。

系统的开关、变量和属性各有名称管理页：搜索名称或编号，直接改名，新增只追加到末尾，编号0保留，清空名称不删除编号。应用后引用刷新；Ctrl+S才写文件。自定义兼容字段入口只提供有保留说明的实际额外字段，没有重复的常用属性。

动画页按帧和单元编辑图案、像素坐标、缩放、旋转、镜像、不透明度及混合方式；预览从192像素图案格取图，默认20动画帧/秒，可调整预览速度。时序页设置音效及闪光，界面帧号从1开始，保存仍用原RM的0起始编号。删除有时序的帧须先移动或删除时序。预览默认首帧播放一次，末帧结束，循环可选且默认关闭；按时序播放SE音量/声调与命中条件。关闭停止声音，不触发游戏；目标闪光以正式运行时为准。应用、保存后正式运行读取动画定义。图块属性画布默认放大到1.5倍（每格48显示像素），实际图块仍为32像素。

## 多素材图块集与扩展图层（ver0.36）

地图面板点击“编辑当前图块集…”或在数据库选择图块集，首页直接显示图块画布及右侧属性，使用“普通图块素材…”按顺序追加普通图块图片。规格宽256像素、高为32的倍数，使用原图虚拟纵向排列，不生成合成图片；自动图块独立配置。尾部追加保留旧编号，换序/尺寸替换会同步该图块集的所有地图与图块事件，并迁移属性；使用中的素材或行不能移除。组合确认会应用当前条目到草稿，可一次撤销，Ctrl+S后写文件。编号布局或图块集变化会重置旧编号笔刷与剪贴板，请重新选择或复制。

图块首页提供通行○/×、四方向、优先级★、草丛、柜台、地形模式，同一画布常驻，直接替换原字段占位表；切换模式保留滚动位置。点格或拖动涂改，优先级0–5和地形0–7循环；右侧可精确设置，自动图块可统一48种连接形状。地形按整数显示。右侧“自动图块与背景”双击更换7个自动图块、全景、雾和战斗背景，背景参数使用具名控件。原生标记对应实际通行和遮挡。

地图默认三层，点击“增加图块层”按需增加（最多32层）；地图属性可改层数和名称。事件编辑有独立按钮。“显示（仅编辑器）”控制图层可见性，隐藏层不能绘制；游戏仍显示全部层。绘制、复制、缩放、尺寸调整、撤销与保存按实际层数工作；新增层继续使用数据库通行/优先级，不按名称赋予装饰规则。缩图保护事件/起点，删除层须先清空，地图父子关系拒绝循环；新建、复制、属性修改一次撤销完整恢复。

## 事件编辑与素材选择（ver0.35）

事件窗口顶部使用事件页签，左侧分组设置出现条件、图形、自主移动、选项和触发方式，右侧编辑事件指令；混合方式直接设置，工程扩展字段只显示实际附加数据、没有扩展时隐藏。新增指令在三页分类菜单点击按钮，地图与公共事件共用同一组件。图片预览显示用途标题、简短说明及素材名，自动图块槽位按1–7标注，角色行走图与战斗图分开说明。事件图形可通过“当前地图图块…”从本地图绑定图块集中点选普通图块，双击图块预览定位原图块。双击带边框的图片预览更换素材，窗口定位当前素材，支持名称搜索、分页缩略图、适应窗口与原图滚动；行走图点击4×4网格选择方向和帧，色相/不透明度可预览。确认素材只改当前草稿，取消保留原图；应用事件后按Ctrl+S保存。完整指令配色后续在0.39统一完成。

## 地图制作工作区（ver0.33）

本版合并0.32地图编辑基础与0.33地图制作工具。进入“魔塔编辑器”默认绘图下层，地图列表、图块面板和画布同时显示。点击“新建地图”设置名称、尺寸和图块集；图块集可在面板顶部直接选择。模式/图层与绘制工具均为按钮。拖选图块面板可得到多图块笔刷，支持铅笔、矩形、填充、橡皮、选区复制/粘贴及吸管；右键取样，中键平移，滚轮缩放。B/R/F/E/S/V/I切换工具，Esc取消当前笔画，Ctrl+Z/Y撤销/重做，Ctrl+S显式保存。自动图块按相邻格连接，一次笔画作为一次撤销。事件编辑按钮切换到事件模式后双击格子编辑事件；编辑期间不运行游戏。保存后重新运行游戏读取新地图。

## 编辑器名称与事件可读性（ver0.31）

引用统一显示名称＋稳定编号，未命名与缺失引用分别标注；双击引用字段可以搜索名称或编号。地图事件、公共事件和移动路线的列表显示中文操作摘要、对象与参数含义，条件/选项/循环有层级标识，悬停可核对完整摘要和原编号/参数。开关、变量等名称从编辑草稿读取，改名或撤销后同步刷新；全体队员、卸下、无动画等编号0按上下文解释。

## 地图、数据库与公共事件编辑器（ver0.29）

打开project.godot后进入“魔塔编辑器”，无需运行游戏。地图树、三层绘制、自动图块、地图与事件制作沿用0.28；事件层双击打开事件页，209和自主路线使用专用移动动作窗口。F9或“数据库 / 公共事件”打开数据库窗口。

可编辑角色、职业、特技、物品、武器、防具、敌人、状态、动画、图块集和系统。双击普通字段选择素材/编号或输入数值；成长表、有效度、动画单元和图块标记打开表格；图块页可点原图像设置四方向通行、草丛/柜台、优先级与地形，自动图块48形状可统一修改；装备/属性/状态集合打开多选窗口。初始队伍支持排序；开关、变量、属性名称表保持编号，可追加名称。条目可新增/复制/清空，清空保留ID，不挪动其他编号。

公共事件有无/自动/并行三种触发方式，自动和并行通过指定开关启用。右侧使用与地图事件相同的指令编辑器，支持控制流、选项、移动路线等已完成的非脚本指令。切换条目自动应用到草稿，Ctrl+S保存；关闭放弃当前尚未应用字段，已经应用的其他草稿仍由统一保存/撤销管理。修改定义后重新运行游戏读取。物品和特技可按公共事件ID关联原生调用入口。

原生Troops战斗页只保留查看，不实现回合制；工程重载的$game_troop数据保留，自定义结算与Ruby转换暂缓。地图/公共事件Ruby代码和脚本条件保留为注释，路线脚本保留原数据后移除执行入口。外部冲突阻止覆盖，批量保存先验证并备份到.godot/rgm_editor/backups。编辑器不运行事件。

## 事件存档与公共事件使用（ver0.27）

事件352打开实际存档页；读档从它的后续指令继续，不重复奖励。当前地图所有事件保存实际位置、朝向、图形/色相、透明度、混合、速度、频度、动画/穿透/固定方向/置顶等属性，已完成移动路线的属性同样保留。保存前台/地图并行/公共并行的指针、调用栈、循环/分支和剩余等待，平滑运动及自主/强制路线现场，暂时删除和排队界面。离开再进入地图仍按原生重建，旧迁移器schema1缺新字段用默认。

普通存档遵守134，事件352可显式调用并保留禁止标志。背景事件可以保存，玩家行走仍等待完整格；传送/瞬时截图/场景终止和独立验收地图不能保存。公共事件物品/技能校验后扣库存/SP并返回地图执行一次预约；未知队友结算效果不会部分使用。Ruby和原生回合制战斗不执行，不读取RM旧存档。

## 人物移动与地图接口（ver0.18）

方向键平滑四方向行走，采用原 Characters 的四方向四帧；速度 1–6，像素/秒为 10×2^速度，默认 4。RuntimeState.player() 返回当前游戏的真实玩家节点（标题无玩家时为 null），提供 move_straight(2/4/6/8)、turn(direction)、move_to(x,y)、jump(dx,dy)、moving()、jumping()、is_idle()、motion_snapshot()。逻辑格坐标在到达后提交，real_x/real_y 用地图像素，不是旧 RGSS 的 128 单位；完成普通行走加一步，撞墙、原地转向和跳跃不计步。穿透仍受地图边界约束，跳跃可跨障碍但必须有合法落点；无自动寻路、斜向输入或战斗伤害。

RuntimeState.configure_player({move_speed, through, direction_fix, walk_anime, step_anime, transparent, opacity, blend_type, idle_pattern}) 接受部分更新，先校验后生效；玩家节点也提供前八项同名属性。角色运行图/色相继续来自队伍首位 Actor，纹理共享、显示材料独立。地图实例提供 valid、tile_id(x,y,layer)、terrain_tag、is_bush、is_counter、event_ids_at、can_move；支持起点/落点双向通行、人物占位、柜台隔格确认和草丛下半身半透明。图块按数据库优先级与人物脚点原生排序，地面和前景保留绘制数据；自动图块按时间更新，菜单暂停。

Esc/X 在行走途中会等到本格完成再开菜单，不截断人物在半格；对话/诊断期间不能打开。玩家选项接入 schema 1 存档，旧新格式缺字段使用默认选项；不保存半格移动、跳跃进度或事件人物的原生位移，直接存档也拒绝正在行走/跳跃。不读取 RM 旧存档，ver0.23已接自主/强制/随机/接近移动；不执行自定义Ruby魔塔钩子，ver0.21已接通106/116及五种地图触发、公共自动/并行。

测试准备开启后：Esc → F6 → 人物与地图。独立验收区直接使用正式移动/地图组件，包含草丛、地形7、单向红地块、柜台人物、触碰点和黄色遮挡图块；方向键行走、Z/Enter/Space 交互、Q 跳跃，按钮支持鼠标；Tab/F5 选择/执行按钮。速度、穿透、方向固定、踏步、行走动画可改；“应用到玩家”只修改真实玩家选项，不改其坐标/步数/背包/开关/变量。“恢复默认”只改预览，需应用才影响真实玩家。验收区报告触发结果，不运行它的事件命令，不替换原地图或数据库；关闭测试模式隐藏。

## ver0.21–ver0.26事件执行

测试模式Esc → F6 → 正式事件验收地图：正式调度器执行等待、公共调用、自动換页、双地图并行/公共并行与触碰删除。等待106参数20等于1秒，按delta推进；116仅本图暂时删除，前台列表继续。退出（F7）恢复原地图和运行进度。界面请求按所属实例排队；菜单/商店暂停地图。schema1已在ver0.27保存事件现场、并行与本图暂时删除；独立验收地图不写正式存档。回合制战斗排除，魔塔公共事件与自定义结算暂缓。

ver0.22接通104消息选项、105按键输入、124计时器，111/122全部非战斗条件与操作数。F6正式验收地图已有“联合流程”：选择/数值输入 → 公共事件等待 → 循环累加 → 变量文本结果；“文本与按键”验证三种位置、透明、颜色、金币、原生按键编号及分页。消息支持原生V/N/C/G和双反斜杠，文本按窗口宽度分页；数字输入支持直接键入。金币和库存使用原生上限，变量遵守Ruby整数除法/余数与±99999999上限。存档次数、消息选项随存档保存，旧schema1缺字段补默认；成功保存才增加次数。

ver0.23接通自主移动和完整非脚本路线209/509、全部强制路线等待210、位置202、玩家透明208；201支持变量/朝向/淡化/完成等待，同地图不重建事件；207绑定原人物并清理失效目标。路线支持阻挡重试/跳过、重复、覆盖后恢复、斜向/原地跳跃、频度、置顶/图形/色相/透明度/混合和SE。路线等待按参数/20秒换算，不额外乘2。事件人物/路线现场已在0.27保存；背景路线可随菜单暂停。本版不新增演示场景，全部目标事件完成后进行组合验收；完整文本增强暂缓，保留最大宽度与自动换行要求。

ver0.24接通221–225、231–236；天气唯一归RuntimeState.screen，旧schema1地图天气校验迁移，不重复保存/推进。普通/蒙版过渡分别0.5/1秒，按请求身份等待实际截图/完成和取消；222暂停地图时钟。图片/色调等时长/20秒，天气/40秒，旋转速度×20度/秒；震动映射原生振幅/周期并平滑归零。本版不新增演示场景，完整文本增强继续暂缓。

ver0.26接通129/135、311–322及303/351/353/354。角色单个/全体事务、变量增减、死亡/状态关联、原生全回复顺序、六能力值和强制装备/职业规则已接入；满库存回收整次拒绝避免丢装备。303使用系统输入法与Unicode限长，Esc删除字符；351可显式越过玩家菜单禁止。302/303/351共用排队与请求身份，关闭仅恢复原事件；353/354先清理旧事件/并行/路线再切换实际Gameover/Title。322战斗图仅保存元数据。352与执行现场存档已在0.27接通。没有新增演示场景，文本增强暂缓。

## 分类素材接口

const Cache = preload("res://runtime/scripts/10_Support/Cache/RmxpCache.gd")。Cache.picture(name)、icon(name)、title(name)、windowskin(name)、character(name)、animation(name)、tileset(name)、autotile(name)、panorama(name)、fog(name)、battler(name)、gameover(name)、transition(name) 各自只查对应 Graphics 分类；同名文件不跨库匹配，缺失返回 null，不读取 RTP，越界路径拒绝。素材共享纹理，位置/色相/色调等显示参数由各显示实例管理，不修改缓存纹理。

为未来编辑器预留 Cache.categories()、list_names(category)、list_assets(category)、resolve(category, name)、exists(category, name)。分类枚举读取 data/asset_index.json，不加载图片，不注入工具测试素材，不混合其他目录；列表用原文件名（含扩展名）去除索引别名，每条包含 category/name/source_key/path，保留中文、子目录及扩展名修正后的映射。F6 图片选择器已使用 Pictures 分类。Cache.clear() 释放缓存引用，不销毁显示节点持有的纹理；编辑文件后仍需 Godot 资源重新导入，clear 不执行磁盘刷新。

这是原生 GDScript 分类接口，不是 Ruby 执行层或已实现的编辑器。当前运行时已提供雾/全景和Gameover页面；Battlers仅保留角色战斗图元数据，不实现回合制战斗。

## 图片与屏幕接口

RuntimeState.show_picture(number, name, pose={})、move_picture(number, pose, seconds=0)、rotate_picture(number, degrees_per_second)、tint_picture(number, tone, seconds=0)、erase_picture(number)。地图图片编号 1–50，各自独立，编号越大层级越高；同号替换重置该图，缺失素材则保持原图并诊断，不补取 RTP。name 来自 Graphics/Pictures，pose 字段为 origin（0 左上/1 中心）、x/y（屏幕坐标）、zoom_x/zoom_y（百分比）、opacity（0–255）、blend_type（0 正常/1 加算/2 减算）。正旋转为逆时针；tone=[RGB −255..255, gray 0..255]。所有时长为秒，不接收旧帧数。

RuntimeState.screen 提供 picture(number)、picture_ids()、snapshot()、start_tone_change(tone, seconds)、start_flash([RGBA 0..255], seconds)、start_shake(power_px, speed_hz, seconds)。地图色调/震动只影响地图、角色和地图动画，图片不跟随摄像机；闪光覆盖地图及图片，对话和菜单保持清晰。时间驱动过渡，震动采用波形及结束包络，不照搬 RGSS 40 FPS 主循环。普通菜单/商店暂停效果，返回地图继续；传送保留状态，标题销毁显示层，新游戏清空。

测试准备开启时：Esc → F6 → 图片与屏幕。可以直接选择源图片并测试双图、变换、色调与屏幕效果；另有本工具绘制的测试色块，非 RTP。该页在暂停地图的同时推进效果预览，离开恢复普通菜单暂停；全部重置不改地图和角色。编号/素材下拉框用鼠标，操作按钮支持方向键与确认。显示状态、剩余过渡及旋转接入 schema 1 新存档；旧新格式缺少 screen 时默认空图片/中性效果，工程、数据与测试定义校验仍生效。

ver0.24已把231–236、221–225接入正式解释器，复用上述状态/素材/显示服务；天气统一由ScreenState持有并由屏幕时钟推进，地图表现只显示天气粒子。ver0.25已接131、203–206全景/雾、241–251及系统皮肤/音频存档，参见MAP_PRESENTATION.md。不执行Ruby。

## 商店与 State 接口

标准商店支持物品/武器/防具的购买、出售、数量确认与装备信息。原事件 302/605 可打开商店，离开后继续事件；测试模式主菜单底部“测试工具 · F6”统一进入角色成长、测试商店与状态接口。购买使用数据库 price，出售为半价取整，零价不能出售；库存上限 99，交易金币上限 9999999，失败/取消不部分修改，不出售身上装备。数量 ←→ 调整 1、↑↓ 调整 10，确认交易、Esc 取消。列表向上先移动光标，越过可见上缘才滚动。

State支持actor.add_state/remove_state/has_state/get_state_ids/clear_states与RuntimeState对应入口。普通来源和装备自动来源分开，zero_hp控制HP0/解除最后死亡状态恢复HP1，plus/minus关联与互斥先校验再提交；循环超过预算拒绝。保留倍率与存档，不执行中毒、概率/回合解除、状态动画或回合制战斗。

测试模式新游戏另给 2000 金币及两个中性状态（一个初始附加），在统一测试工具中直接增删查询。data/test_setup.json 的 initial_gold、shop_goods、initial_states、toggle_state_id 可编辑，读档不重复发放；关闭 enabled 隐藏工具。旧测试定义发生变化时旧测试存档可能拒绝读取，不自动覆盖原件。

## 角色数据与成长接口

RuntimeState.actor(id) 是唯一角色对象。九项 maxhp/maxsp/str/dex/agi/int/atk/pdef/mdef 支持 get_parameter、set_parameter（精确最终值）、get_parameter_plus、set_parameter_plus、add_parameter_plus（永久增量）、parameter_sources（独立来源快照）。base_str 等包含数据库与装备；str_plus 等仅为角色永久修正，不保存装备修正。最终值再应用已有状态倍率与上下限。HP 最小 1、SP 最小 0，上限均 9999；力量/灵巧/速度/魔力最小 1，攻击/防御最小 0，上限均 999。actor.str += 1、actor.maxhp += 1、actor.exp += 1 接入原生接口，不表示可执行原 Ruby。atk/pdef/mdef 可写修正是原生扩展；倍率取整使精确目标不可达时拒绝，不部分修改。

set_experience/add_experience、set_level/add_level 更新等级与经验，跨级学职业特技，降级不遗忘，升级不回满。set_vital/add_vital、recover_vitals 处理 HP/SP，不执行状态效果、不清除状态。RuntimeState 对应 set/change_actor_parameter、set_actor_parameter_plus、set/change_actor_experience、set/change_actor_level、set/change_actor_vital、recover_actor_vitals、rename_actor、change_actor_class、set_actor_graphic。换职业保留经验/等级/特技，原子收回不兼容装备（固定槽位不阻止职业解除）；背包收不下则整次拒绝。测试装备仍遵守现有测试职业豁免。角色图用四方向四帧素材与色相，共用菜单和地图缓存。

在测试工具“角色数据与成长”选择角色/属性，修改永久修正、经验、等级、HP/SP；“姓名/职业/角色图”打开身份表单。键盘方向选择按钮、确认执行，Q/E 切属性；文本框编辑时 X/空格不会误返回，Esc 关闭表单。这些是运行时测试，不是数据库/地图编辑器。改动接入 schema 1 存档；旧新格式缺字段用零修正及数据库图像，仍需数据指纹/测试定义一致；新游戏或初始化加入重置。数据库只读，不转换自定义成长公式，不新增地图事件指令或战斗。
"""

var warnings: Array[String] = []


func generate(
	output_root: String,
	project_title: String,
	ini: Dictionary,
	progress: Callable = Callable(),
	source_id: String = ""
) -> Dictionary:
	warnings.clear()
	if progress.is_valid():
		progress.call("生成 Godot 运行时模板")
	var template_root := ProjectSettings.globalize_path("res://templates/runtime")
	_copy_tree(template_root.path_join("scripts"), output_root.path_join("runtime/scripts"))
	_copy_tree(template_root.path_join("assets"), output_root.path_join("runtime/assets"))
	_copy_tree(template_root.path_join("scenes"), output_root.path_join("scenes"))
	_copy_tree(
		ProjectSettings.globalize_path("res://templates/editor/addons"),
		output_root.path_join("addons")
	)
	_copy_workspace_compiler(output_root)
	_copy_file(ProjectSettings.globalize_path("res://tools/script_renames_v059.json"), output_root.path_join("data/script_renames_v059.json"))
	_copy_file(
		template_root.path_join("script_layout.json"),
		output_root.path_join("data/script_layout.json")
	)
	_copy_file(
		template_root.path_join("MAP_PRESENTATION.md"), output_root.path_join("MAP_PRESENTATION.md")
	)
	var width := 640
	var height := 480
	var window: Dictionary = ini.get("Window", {})
	if int(window.get("width", 0)) > 0:
		width = int(window["width"])
	if int(window.get("height", 0)) > 0:
		height = int(window["height"])
	_write_project_file(
		output_root.path_join("project.godot"),
		project_title,
		width,
		height,
		(
			(source_id if not source_id.is_empty() else project_title)
			. replace("\\", "/")
			. to_lower()
			. sha256_text()
		)
	)
	var version_file := FileAccess.open(
		output_root.path_join("runtime/scripts/00_Game/RuntimeVersion.gd"), FileAccess.WRITE
	)
	if version_file == null:
		warnings.append("无法写入运行时版本。")
	else:
		var version_source := FileAccess.get_file_as_string(
			template_root.path_join("scripts/00_Game/RuntimeVersion.gd")
		)
		var version_line := RegEx.new()
		# Preserve the template's line ending while replacing the declaration.
		version_line.compile("(?m)^const VERSION := [^\r\n]*")
		version_file.store_string(
			version_line.sub(
				version_source, "const VERSION := " + JSON.stringify(RGMigratorVersion.VERSION)
			)
		)
		version_file.close()
	_write_readme(output_root.path_join("README.md"), project_title)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/SCRIPT_STRUCTURE_v0.51.md"),
		output_root.path_join("SCRIPT_STRUCTURE.md")
	)
	return {"warnings": warnings, "width": width, "height": height}


func _copy_workspace_compiler(output_root: String) -> void:
	var folder = output_root.path_join("addons/rgm_editor/compiler")
	DirAccess.make_dir_recursive_absolute(folder)
	var compiler_names = [
		"RubyLexer.gd",
		"RubyParser.gd",
		"RubyGDScriptCompiler.gd",
		"RubySubsetCompiler.gd",
		"RubySemanticModel.gd",
		"SourceCorrections.gd",
		"NativeEventImporter.gd",
		"EventBodyEmitter.gd",
		"ScriptEventIntegrator.gd",
		"ScriptMigrationInventory.gd"
	]
	for name in compiler_names:
		var source = FileAccess.get_file_as_string("res://scripts/importer/" + name).replace(
			"\r\n", "\n"
		)
		source = (
			source
			. replace('"res://scripts/importer/', '"res://addons/rgm_editor/compiler/')
			. replace('"res://scripts/Version.gd"', '"res://addons/rgm_editor/compiler/Version.gd"')
			. replace(
				'"res://templates/editor/addons/rgm_editor/03_Event/Editor_ScriptAdapter.gd"',
				'"res://addons/rgm_editor/03_Event/Editor_ScriptAdapter.gd"'
			)
			. replace('"res://templates/runtime/scripts/', '"res://runtime/scripts/')
		)
		# Shared importer sources keep their source names; editor copies and all
		# their imports use the same Editor_ prefix as the rest of the plugin.
		for dependency in compiler_names + ["Version.gd"]:
			source = source.replace(dependency, "Editor_" + dependency)
		var file = FileAccess.open(folder.path_join("Editor_" + name), FileAccess.WRITE)
		if file == null:
			warnings.append("无法附带脚本转换器：" + name)
			continue
		file.store_string(source.insert(source.find("\n\n") + 2, "@tool\n"))
		file.close()
	var version = FileAccess.open(folder.path_join("Editor_Version.gd"), FileAccess.WRITE)
	if version != null:
		(
			version
			. store_string(
				(
					'## 职责：声明魔塔编辑器附带的脚本转换工具版本。\n## 调用方式：通过 preload(本文件路径).VERSION 读取。\n## 调用接口：无公开方法，也没有构造参数。\n## 公开常量：VERSION，字符串形式的迁移器版本号。\n## 接口说明结束。\n\n@tool\nextends RefCounted\nconst VERSION := "%s"\n'
					% RGMigratorVersion.VERSION
				)
			)
		)
		version.close()


func write_flash_source_guide(output_root: String) -> void:
	var manifest_path = output_root.path_join("data/custom_data.json")
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("profile") != "flash":
		return
	_write_flash_readme(output_root)
	# Source 0337 overrides Game.ini's earlier dimensions and uses 60 Hz.
	var config = ConfigFile.new()
	if config.load(output_root.path_join("project.godot")) == OK:
		config.set_value("display", "window/size/viewport_width", 640)
		config.set_value("display", "window/size/viewport_height", 640)
		config.set_value("display", "window/size/window_width_override", 640)
		config.set_value("display", "window/size/window_height_override", 640)
		config.set_value("display", "window/stretch/scale_mode", "fractional")
		config.set_value("application", "run/max_fps", 60)
		config.save(output_root.path_join("project.godot"))
	for name in [
		"SCRIPT_MIGRATION_v0.47.md",
		"FLASH_LIFECYCLE_AUDIT_v0.47.md",
		"FLASH_LIFECYCLE_AUDIT_v0.47.json",
		"SCRIPT_MIGRATION_v0.45.md",
		"SCRIPT_MIGRATION_v0.46.md",
		"FLASH_UI_GDSCRIPT_v0.46.md",
		"FLASH_BATTLE_GDSCRIPT_v0.45.md",
		"FLASH_OBJECTS_AUDIT_v0.45.md",
		"MIGRATION_AUDIT_v0.58.md",
		"MIGRATION_AUDIT_v0.58.json",
		"MIGRATION_AUDIT_v0.59.md",
		"MIGRATION_AUDIT_v0.59.json",
		"INTEGRATION_v0.59.md",
		"FLASH_LEGACY_AUDIT_v0.45.md",
		"FLASH_LEGACY_AUDIT_v0.45.json",
		"FLASH_SCRIPT_CHECKLIST_v0.45_v0.47.md",
		"FLASH_SCRIPT_CHECKLIST_v0.45_v0.47.json"
	]:
		_copy_file(
			ProjectSettings.globalize_path("res://docs/" + name),
			output_root.path_join("migration_docs/" + name)
		)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/VERIFICATION_v0.45.md"),
		output_root.path_join("tests/VERIFICATION_v0.45.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/VERIFICATION_v0.46.md"),
		output_root.path_join("tests/VERIFICATION_v0.46.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/VERIFICATION_v0.47.md"),
		output_root.path_join("tests/VERIFICATION_v0.47.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/SCRIPT_MIGRATION_v0.48.md"),
		output_root.path_join("migration_docs/SCRIPT_MIGRATION_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/PERFORMANCE_FIX_v0.48.md"),
		output_root.path_join("migration_docs/PERFORMANCE_FIX_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/EVENT_PERFORMANCE_FIX_v0.48.md"),
		output_root.path_join("migration_docs/EVENT_PERFORMANCE_FIX_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/DIRECT_SCRIPT_EXECUTION_v0.48.md"),
		output_root.path_join("migration_docs/DIRECT_SCRIPT_EXECUTION_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/ENCOUNTER_DELAY_FIX_v0.48.md"),
		output_root.path_join("migration_docs/ENCOUNTER_DELAY_FIX_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/MENU_PERFORMANCE_FIX_v0.48.md"),
		output_root.path_join("migration_docs/MENU_PERFORMANCE_FIX_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/UI_OPTIMIZATION_v0.5.md"),
		output_root.path_join("migration_docs/UI_OPTIMIZATION_v0.5.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/EVENT_CONTINUATIONS_FIX_v0.48.md"),
		output_root.path_join("migration_docs/EVENT_CONTINUATIONS_FIX_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/AUDIO_FIX_v0.48.md"),
		output_root.path_join("migration_docs/AUDIO_FIX_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/VERIFICATION_v0.48.md"),
		output_root.path_join("tests/VERIFICATION_v0.48.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/SCRIPT_MIGRATION_v0.49.md"),
		output_root.path_join("migration_docs/SCRIPT_MIGRATION_v0.49.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/VERIFICATION_v0.49.md"),
		output_root.path_join("tests/VERIFICATION_v0.49.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://docs/PERFORMANCE_v0.5.md"),
		output_root.path_join("migration_docs/PERFORMANCE_v0.5.md")
	)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/VERIFICATION_v0.5.md"),
		output_root.path_join("tests/VERIFICATION_v0.5.md")
	)
	for name in [
		"SCRIPT_STRUCTURE_v0.51.md",
		"ROADMAP_v0.5.md",
		"EVENT_GDSCRIPT_v0.52.md",
		"UI_FOUNDATION_v0.53.md",
		"MESSAGE_v0.54.md",
		"TITLE_v0.55.md",
		"MENU_ARCHIVE_v0.56.md",
		"FUNCTION_WINDOWS_v0.57.md",
		"UI_FIXES_v0.58.md",
		"LOAD_FIXES_v0.58.md"
	]:
		_copy_file(
			ProjectSettings.globalize_path("res://docs/" + name),
			output_root.path_join("migration_docs/" + name)
		)
	for name in [
		"VERIFICATION_v0.51.md",
		"VERIFICATION_v0.51.json",
		"VERIFICATION_v0.52.md",
		"VERIFICATION_v0.52.json",
		"VERIFICATION_v0.53.md",
		"VERIFICATION_v0.53.json",
		"VERIFICATION_v0.54.md",
		"VERIFICATION_v0.54.json",
		"VERIFICATION_v0.55.md",
		"VERIFICATION_v0.55.json",
		"VERIFICATION_v0.56.md",
		"VERIFICATION_v0.56.json",
		"VERIFICATION_v0.57.md",
		"VERIFICATION_v0.57.json",
		"VERIFICATION_v0.58.md",
		"VERIFICATION_v0.58.json"
	]:
		_copy_file(
			ProjectSettings.globalize_path("res://tests/" + name),
			output_root.path_join("tests/" + name)
		)
	_copy_file(
		ProjectSettings.globalize_path("res://tests/verification/v052-native-editor.png"),
		output_root.path_join("tests/verification/v052-native-editor.png")
	)
	for name in [
		"VERIFICATION_v0.58_UI.md",
		"VERIFICATION_v0.58_UI.json",
		"VERIFICATION_v0.58_LOAD.md",
		"VERIFICATION_v0.58_LOAD.json",
		"VERIFICATION_v0.59.md",
		"VERIFICATION_v0.59.json"
	]:
		var source_path = "res://tests/" + name
		if FileAccess.file_exists(source_path):
			_copy_file(
				ProjectSettings.globalize_path(source_path), output_root.path_join("tests/" + name)
			)
	var verification = DirAccess.open("res://tests/verification")
	if verification != null:
		for name in verification.get_files():
			if (name.begins_with("v057-") or name.begins_with("v058-")) and name.ends_with(".png"):
				_copy_file(
					ProjectSettings.globalize_path("res://tests/verification/" + name),
					output_root.path_join("tests/verification/" + name)
				)
	for name in [
		"v053-editor.png",
		"v053-editor-selected.png",
		"v053-scroll.png",
		"v053-text.png",
		"v053-title.png",
		"v053-menu.png",
		"v053-message.png",
		"v054-dialogue.png",
		"v054-choice.png",
		"v054-number.png",
		"v054-hint.png",
		"v054-pages.png",
		"v054-history.png",
		"v055-carousel-half.png",
		"v055-continue.png",
		"v055-difficulty-ex.png",
		"v055-difficulty-hard.png",
		"v055-disabled-command.png",
		"v055-merit-book.png",
		"v055-merit.png",
		"v055-music-half.png",
		"v055-music.png",
		"v055-return-title.png",
		"v055-settings-1.png",
		"v055-settings-2.png",
		"v055-settings-3.png",
		"v055-title.png",
		"v056-archive-half.png",
		"v056-archive-load.png",
		"v056-archive-new.png",
		"v056-archive-save.png",
		"v056-archive-scroll.png",
		"v056-config.png",
		"v056-cursor-half.png",
		"v056-load-failure.png",
		"v056-locked.png",
		"v056-map.png",
		"v056-menu-half.png",
		"v056-menu.png",
		"v056-overwrite.png",
		"v056-return-map.png",
		"v056-title-continue.png",
		"v056-titlecheck-carousel-half.png",
		"v056-titlecheck-continue.png",
		"v056-titlecheck-difficulty-ex.png",
		"v056-titlecheck-difficulty-hard.png",
		"v056-titlecheck-disabled-command.png",
		"v056-titlecheck-merit-book.png",
		"v056-titlecheck-merit.png",
		"v056-titlecheck-music-half.png",
		"v056-titlecheck-music.png",
		"v056-titlecheck-return-title.png",
		"v056-titlecheck-settings-1.png",
		"v056-titlecheck-settings-2.png",
		"v056-titlecheck-settings-3.png",
		"v056-titlecheck-title.png"
	]:
		var source_path = "res://tests/verification/" + name
		if FileAccess.file_exists(source_path):
			_copy_file(
				ProjectSettings.globalize_path(source_path),
				output_root.path_join("tests/verification/" + name)
			)
	for name in [
		"Editor_ScriptWorkspaceTests.gd",
		"Editor_ScriptSourceFlowTests.gd",
		"Editor_ScriptUiTests.gd",
		"Editor_CompileTests.gd",
		"Editor_CustomDataTests.gd",
		"Editor_CommandBlockTests.gd",
		"Editor_NativeEventV052Tests.gd",
		"Editor_NativePluginV052Probe.gd",
		"Editor_UIContrastV053Tests.gd",
		"Editor_UIV053Probe.gd",
		"Editor_MigrationAuditV058Tests.gd",
		"Editor_MigrationAuditV058Probe.gd"
	]:
		_copy_file(
			ProjectSettings.globalize_path("res://tests/editor/" + name),
			output_root.path_join("tests/editor/" + name)
		)
	var tests = DirAccess.open("res://tests/runtime")
	if tests != null:
		for name in tests.get_files():
			if name.ends_with("Tests.gd"):
				_copy_file(
					ProjectSettings.globalize_path("res://tests/runtime/" + name),
					output_root.path_join("tests/runtime/" + name)
				)
	for name in [
		"FailureIsolationProbe.gd",
		"StartupV049Probe.gd",
		"SoakV049Probe.gd",
		"DamageOrderV050Probe.gd",
		"EncounterPerformanceProbe.gd",
		"NativeEventV052Tests.gd",
		"ReadableEventV052Tests.gd",
		"UICommonV053Tests.gd",
		"SupportUIPreviewTests.gd",
		"LoadAndSharedBarTests.gd",
		"NativeMigrationV052Tests.gd",
		"NativeFatalV052Probe.gd"
	]:
		_copy_file(
			ProjectSettings.globalize_path("res://tests/runtime/" + name),
			output_root.path_join("tests/runtime/" + name)
		)
	var readme = FileAccess.open(output_root.path_join("README.md"), FileAccess.READ_WRITE)
	if readme != null:
		readme.seek_end()
		(
			readme
			. store_string(
				"\n## 闪翼自定义源码\n\n0.45玩法和0.46页面、消息、地图半成品、演出与跟随使用同一份运行状态。原Ruby到GDScript的对应及开发示例见 [0.46源码入口](migration_docs/FLASH_UI_GDSCRIPT_v0.46.md)，阶段范围见 [0.46说明](migration_docs/SCRIPT_MIGRATION_v0.46.md)。说明中的 templates/runtime/scripts 对应本工程 runtime/scripts。普通技能定义可直接修改 runtime/generated/skill_catalog.gd；[战斗源码说明](migration_docs/FLASH_BATTLE_GDSCRIPT_v0.45.md)提供扩展示例。原公式保持，确认修正见 data/source_corrections.json。原缺失数据/资源和空分支照实记录，特殊BOSS战按用户要求排除。0.47完整关系存档、活动表现恢复、跨启动设置/解锁、自动记录/撤回和剩余插件入口见 [0.47说明](migration_docs/SCRIPT_MIGRATION_v0.47.md)。原依赖与缺口见 [生命周期审计](migration_docs/FLASH_LIFECYCLE_AUDIT_v0.47.md)，整体验收尚未进行。\n"
			)
		)
		readme.close()


func _copy_tree(source: String, destination: String) -> void:
	if not DirAccess.dir_exists_absolute(source):
		warnings.append("运行时模板目录不存在：%s" % source)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	var dir := DirAccess.open(source)
	if dir == null:
		warnings.append("无法读取运行时模板目录：%s" % source)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with(".") and not entry.ends_with(".uid"):
			var from := source.path_join(entry)
			var to := destination.path_join(entry)
			if dir.current_is_dir():
				_copy_tree(from, to)
			else:
				_copy_file(from, to)
		entry = dir.get_next()
	dir.list_dir_end()


func _copy_file(source_path: String, destination_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		warnings.append("无法读取模板文件：%s" % source_path)
		return
	DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		source.close()
		warnings.append("无法写入模板文件：%s" % destination_path)
		return
	destination.store_buffer(source.get_buffer(source.get_length()))
	destination.close()
	source.close()


func _write_project_file(
	path: String, title: String, width: int, height: int, project_id: String
) -> void:
	var config := ConfigFile.new()
	config.set_value("application", "config/name", title)
	config.set_value("application", "run/main_scene", "res://scenes/05_Title/Title.tscn")
	config.set_value(
		"application", "config/features", PackedStringArray(["4.5", "GL Compatibility"])
	)
	config.set_value(
		"editor_plugins", "enabled", PackedStringArray(["res://addons/rgm_editor/plugin.cfg"])
	)
	config.set_value("autoload", "RuntimeState", "*res://runtime/scripts/00_Game/RuntimeState.gd")
	config.set_value("rgmigrator", "project_id", project_id)
	# Empty arrays mean the complete logical screen and its center. Never parse Ruby UI code.
	config.set_value("rgmigrator", "map_view_rect", [])
	config.set_value("rgmigrator", "map_follow_center", [])
	for key in ["viewport_width", "window_width_override"]:
		config.set_value("display", "window/size/" + key, width)
	for key in ["viewport_height", "window_height_override"]:
		config.set_value("display", "window/size/" + key, height)
	config.set_value("display", "window/stretch/mode", "canvas_items")
	config.set_value("display", "window/stretch/aspect", "keep")
	config.set_value("display", "window/stretch/scale_mode", "integer")
	config.set_value("rendering", "renderer/rendering_method", "gl_compatibility")
	# Import-time safety only; does not serialize game rendering or runtime updates.
	config.set_value("editor", "import/use_multiple_threads", false)
	config.set_value("rendering", "textures/canvas_textures/default_texture_filter", 0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		warnings.append("无法写入 project.godot：%s" % path)
		return
	file.store_string(
		(
			"; Generated by %s\nconfig_version=5\n" % RGMigratorVersion.DISPLAY_NAME
			+ config.encode_to_text()
		)
	)
	file.close()


func _write_flash_readme(output_root: String) -> void:
	var content = (
		"""# 黎之闪翼（开发中）

本工程由 %s 从原 RM 重新迁移。当前0.58已进行内部自查，用户人工验收另记。

- 从标题进入新游戏或继续游戏，使用原图形标题、难度卡、主菜单和档案。地图Esc/X打开菜单，方向键选择，空格/Enter确认，Esc/X返回。
- 物品、技能配置、回路、笔记、灵视和商店使用恢复后的功能窗口。地图A打开灵视，M打开地图系统，L查看消息历史，1—9使用已配置的物品预设。原空装备/成就/合成分支、魔法和BUFF半成品保留。
- 物品页右侧1—9格快捷栏仅保留格框、图标、数量和光标，去掉外层背景。Godot调试运行时F7开关援护UI预览，显示在地图HUD及技能配置页；仅预览，重新开始或读档关闭，不改变队伍、战斗或存档。详见[本轮UI修正](migration_docs/UI_FIXES_v0.58.md)。
- 读档显示动态进度，后台预载只读资源，完整校验后只在新地图恢复一次事件现场。旧存档没有音乐记录时按地图自动播放；新存档明确停止的音乐保持静音。物品页直接复用地图右侧同一个物品栏，详情见[读档与物品栏修正](migration_docs/LOAD_FIXES_v0.58.md)。
- Message保留原特殊控制码、气泡/名字头像、暂停翻页、选项、数字输入、并行提示及历史。事件脚本在事件编辑器直接编辑实际GDScript正文，原Ruby只作迁移来源。
- 0.58补齐树冠/屋檐遮挡：进入相连上层区域时以160/255透明度显示，离开、改图或换图后恢复。新分辨率的窗口位置按用户安排后续统一调整。
- 普通魔塔战斗、物品和回路使用同一运行状态及原公式。脚本首错立即停止；已发生的状态变更保留。特殊BOSS、RM回合制战斗、RTP和RM旧存档仍在既有排除范围。
- 存档是Godot工程自己的进度，包含对象关系与可保存的事件/表现现场；完整校验后恢复。覆盖保留备份，恢复备份需确认。0.57进度兼容性见本版验证记录，不自动覆盖用户存档。
- 正式闪翼规则在data/flash_gameplay.json及运行GDScript中；data/test_setup.json属于原生兼容测试设置，不是额外迁移出的闪翼物品规则。

开发入口见[SCRIPT_STRUCTURE.md](SCRIPT_STRUCTURE.md)与[0.59后续开发说明](migration_docs/INTEGRATION_v0.59.md)。运行脚本在runtime/scripts，Game对象在前，窗口按功能分组；编辑器在addons/rgm_editor，保留Editor_前缀。每个GDScript文件头包含调用接口及参数说明。0.59已移除Flash文件名前缀；旧名到新名见data/script_renames_v059.json，内部保存字段保留兼容。

[本版缺口与来源审计](migration_docs/MIGRATION_AUDIT_v0.59.md)记录原脚本最终覆盖、服务入口、源未完成及缺素材；机器索引为data/migration_audit.json。脚本工作区区分职责审计与自动转换诊断，代码在审计后变化会显示需复验。历史转换unsupported不等于当前Godot服务未实现。

[0.59整合说明](migration_docs/INTEGRATION_v0.59.md)与[本轮自查](tests/VERIFICATION_v0.59.md)记录验证范围和结果。原资源在assets/rmxp，原Ruby在legacy；二者来源与缺失边界如实保留。完整剧情人工通关及所有地图长期性能不由本轮局部检查代替。
"""
		% RGMigratorVersion.DISPLAY_NAME
	)
	var file = FileAccess.open(output_root.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		warnings.append("无法写入闪翼当前使用说明。")
		return
	file.store_string(content)
	file.close()


func _write_readme(path: String, title: String) -> void:
	var content := (
		"# %s\n\n本工程由 %s 生成。\n\n- 启动后使用 Godot 原生标题界面进入新游戏。\n- 地图空闲时按 Esc/X 打开标准菜单，方向键选择，Enter/Space/Z 确认，Esc/X 返回；支持背包、基础恢复物品、装备更换与预览、角色状态及结束游戏。\n- 物品限菜单可用、确定性、对存活队友的单体/全体 HP/SP 恢复。公共事件已接通预约；复活、状态、永久属性、随机等未知队友效果不部分执行。技能列表可使用公共事件特技并扣SP，未知结算整次拒绝。菜单提供四槽位存档，标题继续游戏可恢复进度；禁止存档状态会禁用入口。\n- 测试准备由 `data/test_setup.json` 控制：`enabled` 为 true 时，新游戏自动准备测试血瓶、魔法药、全队血瓶和装备，HP/SP 默认一半。修改 stock 数量或恢复比例后重新开始游戏即可；设为 false 恢复原始开局。测试记录独立于原数据库，每次新游戏重置，不叠加。\n- 测试装备可供有效职业使用，但不绕过固定槽位；原装备遵守数据库职业限制。\n- 角色标准参数页使用原生数据库规则；0.44已导入的原始扩展属性可在状态详情的“扩展属性”查看，全部货币可点击金币查看。自定义成长、最终属性、魔塔公式与效果按0.45接入；测试物品不是源工程自定义效果的迁移结果。\n- 特技支持学习/遗忘/查询，事件 318、角色已学特技条件分支 111 与显示动画 207 已接通。独立动画播放器不计算伤害、不扣 SP；缺失动画/素材会诊断，不补取 RTP。\n- 测试准备同时授予三个测试特技。进入特技列表可点击预览动画、学习/遗忘测试特技；Esc 先关闭预览再返回。关闭测试模式后不显示这些测试按钮。另有原动画/并发入口，读取原 Animations 数据与素材，支持双位置和同一目标连续追加播放。\n- 新存档位于项目专属 user://rgmigrator_saves/ 子目录，使用格式版本、数据指纹和完整性校验；写入临时文件后替换，覆盖保留上一份备份。损坏文件或不兼容数据不会部分恢复；备份读取需确认。读档不重复发测试物资。数据库/地图或测试定义改变时可能拒绝旧进度。\n- 不读取 RM 旧存档，运行中事件已保存，动画或ME/SE瞬时音效不保存；BGM/BGS位置、记忆与淡出已保存。装备槽统一为武器、盾、头部防具、身体防具、饰品。\n- 输出关闭编辑器并行导入；未通过隔离解码检查的 MP3 或含辅助元数据 PCM WAV 保留至 legacy/unsupported_assets，图像扩展名错误修正导出副本与索引。其他原始音频仍可能需人工处理。\n- 迁移后的标准数据位于 `data/`，非 RTP 素材位于 `assets/rmxp/`。\n- 原始 Ruby 脚本与文件保留于 `legacy/`；已生成的纯GDScript位于 `runtime/generated/`，数据来源与当前覆盖见 `script_inventory.md`、`custom_data_inventory.md`及 `data/custom_data.json`。生成数量不表示所有玩法已迁移。\n- 不支持的事件命令会在游戏内显示诊断；详情见 `migration_report.md`。\n"
		% [title, RGMigratorVersion.DISPLAY_NAME]
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		warnings.append("无法写入输出 README：%s" % path)
		return
	(
		file
		. store_string(
			(
				content
				+ "\n## 0.52 原生事件 GDScript\n\n地图/公共事件、脚本条件和移动路线直接编辑实际GDScript，编译通过后应用并保存，重新运行生效。原Ruby仅作只读迁移来源，F8不会覆盖事件原生代码。上下文、取消、可保存重试和旧档边界见 [0.52使用说明](migration_docs/EVENT_GDSCRIPT_v0.52.md)，验证见 [0.52验收](tests/VERIFICATION_v0.52.md)。\n"
				+ "\n## 0.53 共用图形与文本基础\n\n标题、菜单与Message复用字体和度量，提供按逻辑像素宽高塑形、换行、分页与裁切的UITextBlock；通用命令窗口修复实际内容滚动，过渡可替换和取消，导航与确认重复规则统一。事件脚本方法名与选中文字采用清晰配色。接口及后续图形恢复边界见 [0.53说明](migration_docs/UI_FOUNDATION_v0.53.md)，验收见 [0.53验证](tests/VERIFICATION_v0.53.md)。\n"
				+ "\n## 0.57 功能窗口\n\n物品、技能配置、回路、笔记、灵视及商店恢复原窗口、素材、独立光标和富文本，继续使用同一运行状态。地图系统沿用原自绘并复核；原空分支保留。见[功能窗口说明](migration_docs/FUNCTION_WINDOWS_v0.57.md)和[内部验证](tests/VERIFICATION_v0.57.md)。0.56已通过用户验收，新分辨率窗口布局后续统一调整。\n"
				+ "\n## 0.56 主菜单与档案\n\n使用原错位菜单文字、独立选择层、锁定项与五色货币；恢复档案卡片、章节、人物、截图、四角光标和八帧进退，读写仍经正式SaveService。见[菜单档案说明](migration_docs/MENU_ARCHIVE_v0.56.md)及[内部验证](tests/VERIFICATION_v0.56.md)。标题、菜单、档案已于0.56通过用户验收，分辨率布局后续统一调整。\n"
				+ "\n## 0.55 标题原图恢复\n\n恢复原480帧背景、标志、七命令轮播、四张难度卡片及原设置、音乐、成就附页；过渡与输入门控沿用最终来源。音乐切曲与成就奖励在源工程未实现，保持边界；档案完整画面在0.56。见 [标题说明](migration_docs/TITLE_v0.55.md) 与 [内部验证](tests/VERIFICATION_v0.55.md)。\n"
				+ "\n## 0.54 Message 对话气泡\n\n恢复原素材气泡、人物锚点和边缘位置、名字头像、长文暂停翻页、多行选项光标和逐位数字输入；并行提示与富文本历史沿用原事件与记录，分页及数字光标随表现现场保存。接口与边界见 [Message说明](migration_docs/MESSAGE_v0.54.md)，内部验证见 [0.54记录](tests/VERIFICATION_v0.54.md)；用户人工验收集中到后续版本。\n"
				+ EXTRA_README
				+ "\n## 0.50—0.51 脚本整理\n\n运行代码与魔塔编辑器已按职责分组，Game对象在前，各窗口和场景按功能组织。请从 [当前源码结构与开发入口](SCRIPT_STRUCTURE.md) 查找要修改的代码，完整路径登记见data/script_layout.json；当前验证见 [0.51验证记录](tests/VERIFICATION_v0.51.md)。事件GDScript直接编辑已于0.52接通，Message补迁和原图形恢复继续按后续规划推进。\n"
			)
		)
	)
	file.close()
