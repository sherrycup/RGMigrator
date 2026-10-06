# RGMigrator ver0.2

RGMigrator 是一个面向 Windows 的 RMXP（RPG Maker XP）工程迁移工具。它由 Godot 4.5+ 标准版运行，使用纯 GDScript 编写，不依赖 Godot .NET。

## 使用方式

1. 在 Godot 中打开本目录的 `project.godot` 并运行。
2. 选择含有 `Game.rxproj`、`Game.ini` 与 `Data/` 的 RMXP 工程根目录。
3. 选择一个导出位置。工具会在其中创建 `项目名_Godot`，不会覆盖非空目录。
4. 默认勾选“准备测试物资”；正式迁移可取消。先点击“预检”，确认编码及兼容性警告，再点击“开始迁移”。

## ver0.2 范围

本次将已验收的 ver0.11–ver0.19 标准运行时基础归档为 ver0.2，不新增事件命令。后续事件阶段的类结构、现有接口、单位、状态归属、支持清单及开发约束统一记录在 [AGENTS.md](AGENTS.md)，可以先读这一份文档完成接口对接；修改内部实现时仍需核对对应源码与测试。文档覆盖 68 个生产脚本和 445 个公共方法，签名/字段/信号由 `tests/DocumentationTests.gd` 校验；本次验证见 [ver0.2 记录](tests/VERIFICATION_v0.2.md)。

- 优先识别合法 UTF-8 文本；旧编码文本支持 GBK 与 Shift-JIS，自动模式采用 Windows ANSI 代码页，也可手动切换。
- 导出标准数据库、地图、地图事件、图像音频资源以及可读的 Ruby 脚本镜像。
- 生成 Godot 原生标题界面、起始地图、32px 地图浏览、角色移动和非战斗事件解释器。
- 基础事件支持文本、选项、数值输入、开关/变量/独立开关、条件分支、循环、物品数量、传送、调用公共事件及音频播放。
- 默认风格主菜单、队伍摘要、角色状态、返回标题与退出；开放物品、装备、只读特技列表和四槽位存档，标题支持继续游戏。
- 背包显示物品/武器/防具图标、数量与说明；可使用确定性的存活队友单体/全体 HP/SP 恢复物品。
- 装备先选角色和槽位，再预览数值差异并确认交换，支持卸下；遵守职业资格、槽位类型、固定槽位和库存限制。
- 新游戏可自动准备独立测试物资，直接修改导出配置即可调整或关闭，无需编辑原 RM 工程。
- 新增独立角色运行状态、标准等级参数/经验曲线/初始装备加成；不修改作为定义使用的数据库缓存。
- 标准商店支持购买/出售与数量确认，接通 302 商店处理及 605 商品续行；State 提供状态登记与查询接口。
- 角色九项永久修正与来源查询、最终属性赋值、HP/SP、经验/等级成长、姓名/职业/角色图；新字段接入新格式存档，统一测试工具可直接验收。
- 原生图片状态与显示层：地图编号 1–50，显示/替换/擦除、屏幕坐标、原点、缩放、透明度、正常/加算/减算混合、独立旋转和色调；屏幕色调、闪光、震动，过渡进度接入新存档。
- 分类素材接口按 Pictures、Icons、Titles 等独立加载，预留未来编辑器的分类枚举、名称、路径及存在查询；不创建编辑器。
- 时间驱动平滑行走、原四方向四帧与色相，原生人物参数、跳跃、地形/草丛/柜台查询、双向碰撞、人物占位、图块优先级遮挡和边界镜头；F6 独立人物验收区，玩家选项接入存档。
- 图块集全景/雾、雨/暴风雨/雪、独立地图显示矩形与跟随中心、手动滚图/恢复跟随、淡入淡出/截图灰度图过渡、倒计时、共享音频服务。F6“地图表现与镜头”提供独立大地图、分类原素材与参数测试；详见[接口说明](templates/runtime/MAP_PRESENTATION.md)。
- 不包含 RTP、旧存档或战斗，不执行 Ruby 脚本。增减特技 318、显示动画 207 和角色已学特技条件分支已接通；其他未支持指令仍会明确诊断。

### 菜单操作与数据边界

地图空闲时按 **Esc / X** 打开菜单，方向键选择，**Enter / Space / Z** 确认，**Esc / X** 逐级返回。状态入口先选择角色，再查看详情；返回时恢复选中项。对话、诊断、正在执行的事件及“禁止菜单”状态会阻止打开菜单。

菜单暂停地图更新与玩家输入，但保留背景音乐，游戏时间继续累计；返回时使用同一个地图实例，不重跑地图初始化。步数只在成功移动时增加。返回标题后停止计时，再次新游戏重新初始化数据。

窗口使用 `System.windowskin_name` 对应的 192×128 皮肤、数据库用语及操作音效；属性和装备槽采用标准标签，槽位顺序为武器、盾、头部防具、身体防具、饰品。皮肤缺失时使用 Godot 简易样式并诊断，不读取 RTP。字体使用 Windows 系统回退，中文可显示，不追求与旧字体逐像素相同。

**标准功能替代不等于自定义脚本迁移。** 数据库属性按照 RMXP 默认规则解释，包括默认数值上限；Ruby 定义的额外货币、仇恨值、装备槽位、属性映射和魔塔伤害公式不参与计算。因此样板的状态数值可能与原游戏自定义界面不同，这不表示那些自定义规则已被迁移。缺失角色/职业/装备会报告引用位置，无法计算的数值显示 `—`，不编造数据。

当前运行时是迁移辅助模板，不是完整 RGSS 兼容层。图片/屏幕、人物移动及地图表现底层已提供原生接口，但 **本版不新增事件指令**；231–234、223–225、天气/滚图/计时器/准备过渡等未接通命令仍诊断并中断，保留已有擦除图片235。条件分支支持开关、变量、独立开关和角色已学特技，变量操作数仅支持常量、变量和随机数。尚未实现并行事件、完整自动事件调度、事件页自主移动、强制移动路线和自定义 Ruby 界面。缺失素材会报告，不补取 RTP。事件351唤出菜单仍未支持；事件系统安排在ver0.2–0.3，不自动执行自定义center_x/center_y或Ruby UI代码。

### 地图区域与跟随中心（ver0.19）

`map_view_rect` 控制窗口内地图区域，`map_follow_center` 控制区域内的镜头跟随点。默认都是自动中心；例如800×480窗口左侧UI占160px，可在生成工程`project.godot`的`[rgmigrator]`设`map_view_rect=[160,0,640,480]`、`map_follow_center=[320,240]`，下次新游戏生效。大地图双轴跟随并限制边界，小地图在地图区域内居中；地图边缘处不会为了保持角色居中而露出地图外部。原生运行时接口、完整范围及存档边界见[地图表现说明](templates/runtime/MAP_PRESENTATION.md)，验收步骤见[ver0.19清单](tests/ACCEPTANCE_v0.19.md)。

### 人物与地图（ver0.18）

方向键平滑四方向行走，默认速度 4（160px/秒，32px/格）；速度 1–6 的像素/秒为 `10 × 2^速度`。画面位置独立于逻辑格坐标，到达后提交一格并计一步；撞墙、转向、跳跃和直接重定位不计步。方向固定不限制行走方向，穿透不允许离开地图。跳跃采用原生抛物线，可跨过障碍但必须有可通行、未被人物占用的落点；不复制旧固定帧计算。

Esc/X 在移动途中会等待本格完成再打开菜单，不停在半格；普通菜单暂停真实地图、人物、自动图块和地图动画，音乐保留。关闭后继续原实例。地图使用保留的地面/前景绘制数据，前景按数据库优先级与人物脚点交给 Godot Y-sort 排序；只有动画图块按时间重绘。镜头受地图边界限制，小地图居中。

测试模式：新游戏 → Esc → F6 → **人物与地图**。独立 12×9 验收区使用正式地图/移动组件，含草丛（地形 7）、红色单向通行点、柜台人物、触碰点和黄色遮挡图块；程序绘制对照素材，非 RTP。方向键行走，Z/Enter/Space 确认，Q 跳两格；鼠标修改速度/穿透/方向固定/踏步/行走动画，Tab/F5 选择/执行按钮。测试区只显示触发结果，不执行它的事件命令，不改原地图、坐标、步数、背包或开关变量。“应用到玩家”才把五项选项应用到真实玩家；“恢复默认”只重置预览。关闭测试模式隐藏入口。

```gdscript
var player = RuntimeState.player() # 当前地图玩家；标题/已销毁场景返回 null
if player != null:
    player.move_speed = 4 # 也提供 through/direction_fix/walk_anime/step_anime
    player.move_straight(6) # 2 下、4 左、6 右、8 上，返回是否开始
    player.turn(8)
    player.jump(2, 0) # 相对落点；返回是否开始
    player.move_to(10, 8) # 地图内原生重定位，取消原过渡，不检查障碍
    var pose = player.motion_snapshot() # 分离的快照
    var map = player.map_runtime
    var terrain = map.terrain_tag(10, 8)
    var ids = map.event_ids_at(10, 8) # 返回 ID 列表副本
RuntimeState.configure_player({"through": false, "opacity": 255}) # 部分更新，返回 ok/原因
```

人物选项共九项：`move_speed` 1–6，`walk_anime/step_anime/direction_fix/through/transparent` 布尔值，`opacity` 0–255，`blend_type` 0/1/2，`idle_pattern` 0–3；除静止帧外也提供同名节点属性。无效更新原子拒绝。角色图继续来自队首 Actor；纹理共享、色相/混合/草丛材料按实例独立。草丛使下方 12px 半透明，跳跃期间不压低透明度。

地图提供 `valid(x,y)`、`tile_id(x,y,layer)`、`terrain_tag`、`is_bush`、`is_counter`、`event_ids_at`、`can_move(from,direction,through=false)`、`can_stand`。通行同时检查起点出口、落点反方向、人物占位；移动人物预留起点/终点，柜台确认可以多检查一格。现有传送、面对确认及触碰事件接入这些接口，不增加事件指令。事件人物也使用同一显示/移动组件，但本版不执行事件页随机/接近/自定义路线，不保存其原生位移。

玩家九项选项接入 schema 1 新存档；旧新格式缺 `player_options` 使用默认值，新游戏重新默认。只保存整格位置、朝向及选项，不保存走到半格或跳跃进度，直接调用存档也拒绝运动中保存。`motion_snapshot()` 的 real_x/real_y 单位为地图像素，不是旧 RGSS 128 单位；这些是原生 GDScript 接口，不执行 Ruby，不包含自动寻路、斜向输入、冲刺、队列跟随或魔塔移动钩子。

### 图片与屏幕（ver0.17）

迁移时保留“准备测试物资”，新游戏按 Esc → F6 → **图片与屏幕**。选编号和源 `Graphics/Pictures` 素材，直接测试显示/双图/移动/缩放/混合/旋转/原点/色调/闪光/震动/擦除，无需回 RM 修改。另有工具绘制的测试色块，非 RTP；未选择工具绘制素材时播放的是原图片，不是重新生成。按钮支持鼠标或方向键+确认，Esc/X 返回。测试页上方为控制区，下方为真实地图预览，图片尺寸先适配预览区域；“全部重置”清空全部图片和屏幕效果，不修改角色、地图与背包。

运行时 `RuntimeState.screen` 统一拥有状态。图片编号大的绘制在小编号上方；相同编号显示即替换并重置该图的旋转/色调/过渡，其他编号不变。图片固定在逻辑屏幕坐标，原点 0 为左上、1 为中心，百分比缩放，opacity 0–255，blend_type 0/1/2 为正常/加算/减算；色调 `[red, green, blue, gray]` 的 RGB 为 −255–255、灰度 0–255。原图片缺失时报告并保持该编号的原图片，不补取 RTP。

地图色调与震动影响地图/角色/地图动画，**不影响图片**；图片有自己的色调。屏幕闪光覆盖地图和图片，不覆盖对话、诊断、菜单和测试控件。普通菜单/商店暂停效果与地图输入，只有图片测试页显式推进预览；返回地图继续，不重载地图。地图传送保留图片与屏幕状态；返回标题销毁显示节点，再次新游戏清空状态。

```gdscript
# 原生 GDScript 接口，不是 Ruby 自动转换；时间单位为秒。
RuntimeState.show_picture(1, "原图片文件名", {"origin": 1, "x": 320, "y": 240})
RuntimeState.move_picture(1, {"x": 480, "zoom_x": 150, "opacity": 180}, 2.0)
RuntimeState.rotate_picture(1, 60.0) # 度/秒，正值逆时针；0 停止旋转
RuntimeState.tint_picture(1, [-50, 0, 30, 80], 1.0)
RuntimeState.screen.start_tone_change([-60, -30, 0, 100], 1.0)
RuntimeState.screen.start_flash([255, 255, 255, 160], 0.5)
RuntimeState.screen.start_shake(12, 3, 2.0) # 像素振幅、Hz、秒；结束归零
RuntimeState.erase_picture(1)
var ids = RuntimeState.screen.picture_ids() # 有序编号副本
var view = RuntimeState.screen.picture(2).snapshot() # 先检查对象是否非空
```

所有修改返回 `ok`/失败原因；数据范围和有限数校验先于修改。过渡按实际时间插值，不绑定旧 40 FPS 主循环；震动采用时间驱动波形与结束包络，不承诺旧波形逐帧一致。图片/屏幕与剩余过渡时间接入 schema 1 新存档，独立进程恢复后继续效果；旧新格式缺少 `screen` 字段时使用空图片/中性色调。仍要求工程、数据库和测试定义一致，不读取 RM 旧存档，也不序列化 Godot 节点/纹理。缺失已保存素材会在显示时诊断，不导致整个读档崩溃。

不兼容音频（例如 MIDI、WMA 和压缩 WAV）原样保留到 `legacy/unsupported_assets/` 并写入警告，不会伪装成已支持素材。MP3 与含辅助元数据的 PCM WAV 使用独立 Godot 进程检查，未通过者也会保留到上述目录；生成工程关闭编辑器并行导入，JPEG/PNG 扩展名不匹配时修正导出副本和索引。其他原始音频的标签或编码也可能触发 Godot 导入诊断，需要后续人工转码。`legacy/` 不参加 Godot 资源导入。错误中断后留下的输出目录用于排查，重试请使用新的空目录。

### 分类素材接口（为后续编辑器预留）

`RmxpCache` 提供类似 `RPG::Cache` 的分类入口，共用加载/缓存实现，但不混合素材库：`picture(name)` 只查 Pictures，`icon(name)` 只查 Icons，`title(name)` 只查 Titles，其他标准分类也有独立入口。同名素材不会跨目录匹配，缺失返回 `null`，不补取 RTP；相对子目录允许，越界路径拒绝。现有图片、图标、标题、窗口皮肤、角色、地图图块和动画均通过分类入口加载，不改变它们各自的显示/存档规则。

为未来的选择器提供 `categories()`、`list_names(category)`、`list_assets(category)`、`resolve(category, name)` 和 `exists(category, name)`。枚举只读迁移素材索引，不加载图片、不跨分类、不列出工具绘制的测试素材。列表保留原文件名及扩展名，去除索引别名，能区分同名不同扩展的文件；返回副本可供编辑器筛选。F6 图片下拉框已使用 `list_names("Pictures")`，未来物品图标选择器使用 `list_assets("Icons")` 即可。

```gdscript
const Cache = preload("res://runtime/scripts/RmxpCache.gd")
var picture_texture = Cache.picture("背景") # 仅 Graphics/Pictures
var item_icon = Cache.icon("血瓶") # 仅 Graphics/Icons
var title_texture = Cache.title("标题") # 仅 Graphics/Titles
var picture_choices = Cache.list_names("Pictures")
var icon_choices = Cache.list_assets("Icons") # category/name/source_key/path
```

纹理是共享的只读资源；色相、变换、色调与透明度由独立显示实例处理，不修改公共图片。不提供 Ruby API 直接执行兼容。拥有素材加载入口不代表雾、全景、战斗或 Gameover 场景行为已经实现；本次只预留接口，不创建素材编辑器或新增事件命令。

### 物品、装备与测试准备

迁移时默认开启测试准备。输出项目点击“新游戏”后，背包获得：测试血瓶、魔法药、全队血瓶各 10 瓶，铁剑和钢剑各 2 把，盾/头盔/铠甲/护符各 2 件。角色 HP/SP 默认为最大值的一半，方便立即观察恢复效果；不会自动替换原装备。标题、地图与菜单均有测试标识。

在导出项目的 `data/test_setup.json` 中修改：

- `enabled: false`：关闭测试准备，下一次新游戏按原始数据初始化，不注入物资，HP/SP 为满值。
- `stock` 中各条目的 `quantity`：测试库存，限制 0–99；每次新游戏重置，不累计。
- `initial_hp_ratio` / `initial_sp_ratio`：新游戏初始比例，0–1；HP 至少为 1。

保存配置后返回标题并重新开始即可，不必重新迁移。测试定义保存在独立 `definitions` 中，不改原数据库 ID；不要修改已分配 ID，碰撞会诊断并禁用测试覆盖层。测试装备对有效职业开放，但仍遵守槽位类型和固定限制；非测试装备按源数据库的职业允许列表判断。测试图标由本工具绘制，不引入 RTP。

物品流程：**物品 → 选择药品 → 选择角色 → 确认**。全队药品一次影响全部存活队员，但只消耗一瓶；未生效、满血/满蓝、数量不足和不支持效果都不会扣除物品。仅接受菜单可用、100% 命中、无随机波动、无防御/属性修正的 HP/SP 恢复。暂不支持复活、附加/解除状态、永久属性提升及物品公共事件；含这些效果的物品整件拒绝，不部分执行。源工程把“药品”效果写在 Ruby 中时，名字或图标相似不代表能直接使用。

装备流程：**装备 → 角色 → 槽位 → 候选装备 → 确认**。光标移动仅预览，Esc 取消不改数据；确认后收回原装备、扣除新装备，状态页同步。原装备收回后会超过 99 件时拒绝交换，避免丢失。装备自动状态的标准参数倍率参与预览和计算；最大 HP/SP 降低时截断当前值，提高上限不会自动治疗。不执行战斗状态时效或自定义公式。

建议本版人工验收：用血瓶看 HP 与数量变化；满血后再用确认不扣除；装备铁剑/钢剑看攻击力变化并卸下；逐级返回地图，再返回标题重开确认物资重置。原地图启动事件若出现不兼容提示，先关闭诊断再打开菜单；测试模式不跳过源事件、不修改出生地图。

## 特技与动画（ver0.13）

- 标准属性标签统一为 `str` 力量、`dex` 灵巧、`agi` 速度、`int` 魔力、`atk` 攻击力、`pdef` 物理防御、`mdef` 魔法防御。仅改变显示，不改原数据库及数值计算。
- 主菜单 → 特技 → 角色 → 已学列表，显示名称、说明、图标及 SP 参数；只读，不施放、不扣 SP。空队伍禁用入口，学习状态变化后刷新。
- 新游戏按职业学习表和初始等级初始化；重复查询不重置。支持离队角色学习，重新加入时遵守原有“初始化”参数。
- `actor.learn_skill(id)` / `forget_skill(id)` 返回 `{ok, changed, message}`；重复操作不叠加。`actor.has_skill(id)` 返回布尔，`actor.get_skill_ids()` 返回排序、去重的独立整数数组。
- 统一入口：`RuntimeState.change_skill(actor_id, skill_id, learning)`、`has_skill(actor_id, skill_id)`、`skill_ids(actor_id)`。事件 318 与条件分支 111 的角色/特技子类型共用这些状态。其他角色条件子类型仍诊断。
- `RuntimeData.record("Skills", id)` 查询源定义及测试覆盖层。保留标准 25 字段（含 ID），不执行威力、消耗、状态或公共事件；不得通过返回的数据库定义修改角色状态。修改导出 JSON 后需重启进程，不支持热编辑器或 Ruby 动态注册。
- 独立 `RmxpAnimationData` / `RmxpAnimationPlayer` 读取 `Animations.json`，每秒 20 帧，支持 192px 单元、坐标、缩放、旋转、镜像、透明度、普通/加法/减法混合、色相、头部/中心/脚部/画面定位、音效和闪光/暂时隐藏。按时间推进，卡顿跨帧不漏时序；不计算命中或伤害。
- `RmxpAnimationPlayer.play(parent, animation_id, target_provider, hit=true)` 返回成功/失败及播放实例；`target_provider` 是返回目标 CanvasItem 的 Callable。支持同一动画多个独立实例，结束/取消清理节点，目标闪光按实例管理并恢复原材质。hit 仅筛选命中/未命中时序，由调用方提供。
- 地图接口 `map.play_animation(animation_id, character_id=-1, current_event_id=0, hit=true)`；指令 207 的目标 -1 为玩家，0 为当前事件，正数为指定地图事件。非阻塞播放；菜单暂停地图动画，传送/返回标题取消。不会因事件结束刷新而重建未消失的事件节点。
- 技能通过 `animation1_id` / `animation2_id` 引用动画，可共用或填 0；未配置时不播放，不是错误。非零坏引用、坏帧数据、缺失素材会诊断；不补取 RTP。技能学习本身不自动播放动画。
- 测试准备额外提供三个特技（两个共用动画、一个无动画）和原创程序绘制光环。新游戏后直接进入特技列表，使用鼠标点击“预览动画1/2”“学习测试特技”“遗忘测试特技”。后两个按钮执行真实 318 指令；仅测试模式显示。无动画正常提示；预览不改变 HP/SP。Esc 先关闭预览，再返回角色选择。
- `data/test_setup.json` 的 `learn_skills` 控制测试授予列表，`toggle_skill_id` 控制测试按钮目标；enabled=false 时不注入测试定义/特技、不显示测试按钮。无须修改原 RM 工程。
- 本版不实现循环状态动画、自动技能施放流程、战斗公式或魔塔技能注册表。保留定义不代表自定义 Ruby 效果已迁移。

动画字段与标准行为参考 [RMXP 官方帮助内容镜像：RPG::Sprite](https://www.rpg-maker.fr/dl/monos/aide/xp/source/rgss/gc_rpg_sprite.html)。播放器使用 Godot 节点及共享素材，不模拟 Ruby 主循环。

## 存读档（ver0.14）

- 地图空闲时 Esc → 存档 → 选择槽位 → 确认。四个槽位显示队伍名称、地图、游戏时间和保存时间；已有槽位先显示覆盖确认，默认选中“取消”。禁止存档时入口灰显，底层也拒绝写入；事件/对话期间不开放菜单。
- 标题“继续游戏”先选槽位，再恢复地图。没有有效进度时灰显；损坏或不兼容文件会显示原因。主文件不可用但备份有效时，槽位标注“备份”，必须确认后才读取上一份进度；不会偷偷覆盖主文件。
- 保存地图 ID、坐标与朝向、金币、步数、游戏时间、队伍、背包、全部已初始化角色（包括离队角色）的姓名/职业/等级/经验/HP/SP/装备/已学特技/状态 ID、开关/变量/独立开关、菜单/存档禁用标志与测试覆盖层。
- 读档先创建并校验独立候选状态，再一次性替换运行状态；失败不修改当前进度或测试配置。读档不调用新游戏，不重新授予物资或初始化角色，也不重放地图入口的启动自动事件。恢复后事件页按保存的开关变量选择。
- 数据库存为只读定义。文件包含格式版本、工程 ID、数据库/地图指纹与 SHA-256 完整性校验；不使用 Godot 对象反序列化。更改 `data/system.json`、地图或数据库会拒绝原指纹存档。测试定义变化也会拒绝对应测试存档；只改测试 enabled、库存或 HP/SP 比例不改变已有进度。
- 存档路径为 `user://rgmigrator_saves/<工程标识>/slot1.json` 至 `slot4.json`，覆盖产生 `.bak`。通过 `ProjectSettings.globalize_path(SaveService.directory())` 获取本机绝对位置；不写原 RM 目录或导出工程素材目录。工程标识来自源路径哈希，不存明文源路径；同一源工程重新导出、数据未改时可以继续使用新格式存档，搬动源目录会改变标识。
- 写入并校验同目录临时文件后以重命名替换，不先删除主文件；保留上一份有效备份。覆盖损坏文件时将损坏原件保存为 `.damaged-*`，不拿它覆盖有效备份。这是恢复保护，不保证断电或磁盘故障绝不丢数据，也不是加密或防作弊。
- 本版不读取 RM 旧存档、不恢复自定义 Ruby 数据；运行中的事件、动画、瞬时音效以及当前 BGM/BGS 播放进度不保存。事件指令 352（唤出存档）仍诊断；不增加地图事件指令。

### 原动画与并发验收

测试模式下：特技列表 → 鼠标点击“原动画/并发”。选择器读取原 `Animations.json` 的 ID/名称；播放器使用原素材和帧数据，不是程序绘制测试光环。可使用“左侧播放”“右侧播放”“双位置同时”“同目标叠加”，或反复点击播放，观察活动实例数及独立进度。

每次指令 207 / `play_animation()` 创建新实例，即使同一事件收到连续两个不同动画 ID，也不会改写第一个实例。画面位置动画依定义在屏幕中心，目标位置动画才分别跟随左右目标；两者不要混淆。测试界面同时最多 32 个实例是防误操作限制，不是地图播放器单实例限制。停止/返回会清理测试实例，不改变 HP/SP；缺素材照常诊断，不读取 RTP。特技页原有“预览动画1/2”仍只保留一个单项预览，这不是地图播放限制。

## 角色数据与成长（ver0.16）

本次补齐运行时数据修改，不是 Ruby 脚本转换，也不是数据库编辑器。原数据库仍为只读定义；地图、菜单、装备、事件和存档共用 `RuntimeState.actor(id)` 的同一个角色对象。

九项属性为 `maxhp/maxsp/str/dex/agi/int/atk/pdef/mdef`。以力量为例：`database_str` 是当前等级参数表，`equip_str` 是当前装备加成，RM 风格的 `base_str` 包含前两者，`str_plus` **仅**保存角色永久修正。`str` 再应用永久修正、已有状态倍率、取整及上下限。装备的 `str_plus` 字段不是角色的 `str_plus`；卸下装备不会丢失永久提升，也不会把装备重复累计。

- `get_parameter(key)`、`get_base_parameter(key)`、`get_equipment_parameter(key)`、`get_parameter_plus(key)` 查询数值；`parameter_sources(key)` 返回独立的数据库/装备/base/plus/倍率/最终值/范围/错误来源快照。
- `add_parameter_plus(key, amount)` 是永久增量；`set_parameter_plus(key, value)` 设置永久修正；`set_parameter(key, target)` 设置**精确最终值**，通过永久修正实现。倍率取整使目标不可达时整次拒绝。例如力量 200% 时永久 +1 可令最终 +2，而最终值从 32 设为 33 可能不可达。
- 原生 GDScript 支持 `actor.str += 1`、`actor.atk += 1`、`actor.maxhp += 1`、`actor.exp += 1`、`actor.name = "新姓名"`。最终属性写入走上述精确接口；`atk/pdef/mdef` 可写永久修正是本运行时扩展，不承诺同名 Ruby API 直接执行。原 `level/class_id/experience` 存储字段不要直接赋值，使用成长/职业方法保证一致性。
- 最大 HP/SP 上限 9999，最小分别为 1/0；力量/灵巧/速度/魔力范围 1–999，攻击/物理防御/魔法防御为 0–999。永久修正范围是对应上限的正负值；非法、小数、NaN/无穷及坏引用明确拒绝。这里的最大 HP 最小值不是当前 HP：当前 HP 可以为 0。
- `set_experience/add_experience`、`set_level/add_level` 处理经验（0–9,999,999）与等级（1 至角色 final_level），等级调整将经验定位到对应阈值；升级按当前职业学习表学会跨过等级的全部特技，降级不遗忘。升级或提高上限不治疗；降低上限会截断现有 HP/SP。
- `set_vital("hp"/"sp", value)`、`add_vital` 及直接 HP/SP 赋值限制当前值在 0 至上限；`recover_vitals()` 仅回满 HP/SP，保留状态，不执行死亡/中毒或战斗规则，不冒充原 RM 的 `recover_all`。
- `rename` 修改姓名。`RuntimeState.change_actor_class` 保留经验/等级/已学特技，收回不符合新职业的装备；即使固定槽也可因职业被解除，与普通换装规则不同。库存收不下或引用错误时整次拒绝；测试装备沿用已有有效职业豁免。切职业不立即补学同级特技，不更改自定义公式。
- `RuntimeState.set_actor_graphic(id, name, hue)` 验证非空图像存在且为四方向四帧格式；空名称使用占位，色相 0–360（360 等同 0）。菜单和原地图玩家共用图像、缓存与运行状态，修改色相无需重新加载地图。

统一入口还有 `actor_parameter_sources`、`set/change_actor_parameter`、`set_actor_parameter_plus`、`set/change_actor_experience`、`set/change_actor_level`、`set/change_actor_vital`、`recover_actor_vitals`、`rename_actor`；方法以 actor_id 为首参数，返回 `{ok, changed, message}`（失败至少包含 ok/message）。

### 无需原 RM 编辑器的验收入口

勾选测试准备迁移 → 新游戏 → Esc/X → 点击底部 **“测试工具 · F6”** 或按 **F6**。统一入口包含“角色数据与成长”“测试商店”“状态接口”“图片与屏幕”；支持方向键及 Enter/Space/Z，Esc/X 逐级返回，正式模式隐藏。

角色工具可选择角色和属性，显示各层来源，调整永久修正/经验/等级/HP/SP；方向键选择按钮、确认执行，Q/E 切属性，也可鼠标点击。“姓名/职业/角色图”打开表单，各按钮分别应用对应修改；文本框可输入 X/Z/空格，Esc 关闭表单。样例数据库部分属性本来已达 999，+1 修正不会突破上限；优先测默认选中的 atk，或先将修正 −10 再 +1。工具不会替换原地图起点或跳过不兼容事件。

角色永久修正、运行时角色图/色相保存到 schema 1 的新增可选字段。ver0.14/0.15 **Godot 新格式**存档缺字段时按零修正/数据库图像恢复；仍必须工程标识、数据库/地图指纹与测试定义相符。不是读取 RM 存档，也不保证跨数据库修改兼容。新游戏/初始化加入重置，离队后普通加入保留。测试配置 schema 3 及物资定义没有因本版改变，读档不补发。

修复商店买卖、背包及特技列表：下滚后上键先上移光标，保留滚动偏移；只有越过可见上缘才滚动。重建内容和数量取消仍保留视口。没有新增地图事件指令、物品永久提升效果或战斗底层。

## 商店与 State 接口（ver0.15，入口于 ver0.16 统一）

标准商店通过原事件 302（商店处理）及其紧随的 605 商品续行打开。退出后继续下一条指令，地图/输入暂停期间仍保留音乐和游戏计时；关闭后恢复原地图实例。RMXP 商品格式是 `[类型, ID]`，类型 0/1/2 分别为物品/武器/防具，不采用 VX 等版本的自定义价格参数。

- 购买按数据库 `price`，出售按 `floor(price / 2)`；零价商品可购买但不可出售。购买不自动使用/装备，只出售背包数量，不自动卸下角色身上装备。
- 数量界面 ←/→ 调整 1，↑/↓ 调整 10；Enter/Space/Z 确认，Esc/X 取消。可用鼠标点击数量按钮。只选择商品或取消不改状态；实际确认再次检查金币、数量、商品定义，失败不部分交易。
- 单类单 ID 库存上限 99，标准交易金币范围 0–9,999,999；超出范围不静默截断，明确拒绝。商品定义/价格或引用无效时诊断，整份坏商品表不部分开放购买。
- 装备商品显示持有数量、队员职业资格与七项标准属性对比，‹/› 切换队员。固定槽位单独提示；购买资格不等于装备资格，交易不修改角色当前装备。
- 主菜单命令顺序不增加商店项。测试模式下通过底部“测试工具 · F6”进入测试商店，正式模式隐藏，原商店事件不依赖测试模式。

State 本次仅实现状态登记接口，不是完整状态效果引擎。原 RGSS 的核心方法位于 `Game_Battler`，由 `Game_Actor` 继承；此处直接放在原生 `ActorState` 及统一状态入口中，不建立尚未使用的战斗类空壳：

- `actor.add_state(id)` / `remove_state(id)` / `clear_states()` 返回 `{ok, changed, message}`；重复附加/解除不叠加，不存在的 ID 明确失败。
- `actor.has_state(id)`、`actor.get_state_ids(include_equipment=true)` 查询有效状态；返回排序、去重的独立数组。传 false 仅查询普通附加状态。
- `RuntimeState.change_state(actor_id, state_id, adding)`、`has_state(actor_id, state_id)`、`state_ids_for(actor_id, include_equipment=true)`、`clear_states(actor_id)` 是统一入口；离队角色状态保留，再次加入遵守已有初始化参数。
- 普通状态 ID 与装备自动状态来源分离：解除/清空仅移除普通来源；多件装备提供同一状态时只显示一次，卸下一件不会误删其他来源。存档只保存普通 ID，装备来源由恢复的装备重算。
- 原 28 个字段继续保留，已有属性倍率显示沿用；HP/SP 因已有上限降低而截断，不自动恢复。`zero_hp`、持续伤害、连锁增删、限制、抗性概率、回合/受击解除、经验/伤害结算和循环状态动画均不新增执行；不硬编码状态 1 为死亡，不新增状态事件指令。物品附加/解除状态仍整件拒绝，技能仍只读。

新游戏在测试模式下另准备 **2000 金币** 和两个中性测试状态：初始附加一个，另一个供增删查询。测试工具中的“状态接口”可选择角色和状态、附加/解除/查询/清空。这些按钮直接调用上述 GDScript 接口，不需原 RM 编辑器。

`data/test_setup.json` 新增 `initial_gold`、`shop_goods`、`initial_states`、`toggle_state_id`；仍只在新游戏发放，读档不补发。关闭 enabled 后没有测试金币、状态或工具入口。测试配置 schema 为 3；新版测试定义新增价格及 States，因此旧测试存档可能因定义不一致被拒绝，不自动修改用户存档。

接口：`ShopService.catalog(goods)` / `quote_buy(state, goods, kind, id)` / `quote_sell(state, kind, id)` 查询商品与数量限制；`RuntimeState.shop_buy(goods, kind, id, quantity)` / `shop_sell(kind, id, quantity)` 执行原子交易。kind 为 item/weapon/armor，`inventory_count(kind, id)` 查询数量。Godot 界面共用同一队伍/金币/背包，未恢复 Ruby 属性商店或额外货币。

## 输出目录

迁移完成后，输出工程会包含：

- `data/`：UTF-8 JSON 数据与素材索引。
- `data/test_setup.json`：可编辑的新游戏测试准备配置（与原数据库分离）。
- `assets/rmxp/`：从原工程复制的非 RTP 图像与音频。
- `runtime/`、`scenes/`：可直接由 Godot 打开的通用运行时。
- `legacy/`：Ruby 脚本和非标准原工程文件，供人工迁移时参考。
- `migration_report.md`、`migration_report.json`：迁移结果和兼容性诊断。

## 测试

在安装 Godot 4.5+ 后，可从本目录运行：

```powershell
.\tests\Run-Headless.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe'
```

`-GodotPath` 接受 Godot 可执行文件，或包含 `*_console.exe` 的解压目录。测试会读取相邻目录的 `../rm_template`，不会修改其中任何内容。完整测试生成的新工程在 `.godot/test_exports_*/`，日志和汇总在 `.godot/test-logs/`。首次导入几千个素材可能需要数分钟。

测试检查迁移器启动、两样例的地图/数据/素材/脚本数量、中文内容、拒绝覆盖、生成工程的素材导入、标题到新游戏切换、地图加载、碰撞及基础事件逻辑。另用独立标准数据夹具与真实键盘输入验证菜单、角色数据、禁用入口、暂停恢复及再次新游戏。`InventoryTests.gd` 覆盖药品消耗、拒绝不支持效果、换装原子交换/限制/预览、测试模式开关/重置、数据库不变与完整键盘流程。测试同时检查退出码、错误日志和完成标记；Godot 返回 0 并不一定意味着脚本没有错误。

只跑基础测试：`godot --headless --path . --script res://tests/TestRunner.gd`。已有测试输出时可以用 `-SkipMigration -RefreshRuntime` 更新模板并重测。`-SkipImport` 仅用于隔离运行时问题，不代表素材导入通过。测试脚本不会自动删除生成工程或日志。

`SkillAnimationTests.gd` 另覆盖学习/遗忘/查询、事件 318/111/207、同一事件连续不同动画 ID、只读列表、动画帧与时序、并发闪光及清理。`SaveTests.gd` 检查完整恢复、备份确认、写入失败与无效数据隔离；`SaveRestartTests.gd` 分独立写入/读取进程验证真正重启，包含永久修正/改名/色相及图片/屏幕的中途过渡。`ShopStateTests.gd` 覆盖买卖、限制、302/605 等待与继续、State 及存档一致性。`ActorMutationTests.gd` 另覆盖独立标准夹具、九项属性来源与写入、升级/降级/职业交换、非法数据原子拒绝、旧可选存档字段、键盘测试工具及三类列表滚动。`ScreenTests.gd` 检查独立图片/屏幕数据、非法值、剩余过渡保存、菜单暂停/工具预览、地图实例/数据不变、传送/标题/新游戏生命周期。可选的 `LegacyActorSaveTests.gd` / `LegacyScreenSaveTests.gd` 以 `--legacy-save=<旧测试文件绝对路径>` 读取实际 ver0.15/ver0.16 文件，不改写原件；不属于必须具备旧测试输出的默认测试。测试存档只写入 `.godot/` 可丢弃目录，不修改正式 user:// 槽位。Headless 不验证实际画面、听感和手感；参见 [ver0.17 测试记录](tests/VERIFICATION_v0.17.md)、[人工验收清单](tests/ACCEPTANCE_v0.17.md)及[历史测试记录](tests/VERIFICATION.md)。

针对包含 Map585 的“二律背反”导出工程，可额外运行真实渲染回归（需要显卡与桌面会话，不使用 `--headless`）：

```powershell
.\tests\Run-Render.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe' -ProjectPath '..\output\二律背反_Godot'
```

此检查用独立进程验证自动图块的实际像素、标题进入游戏和角色走出一格，截图及日志保存到 `.godot/test-logs/map585*`。Map585 原有事件 2 的命令 116 仍不支持，测试会核对诊断并点击实际“关闭”按钮后检查移动，不会静默跳过指令。测试只改变测试进程内的游戏状态，不保存或修改导出工程的地图和出生点设置。

菜单专项与 60 秒性能检查：

```powershell
$exports = Get-Content .godot/test-results.json -Raw | ConvertFrom-Json
.\tests\Run-MenuRender.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe' -ProjectPath $exports.exports[1] -Benchmark
```

三种实际尺寸（640×480、800×480、768×768）检查菜单、商店/State/角色工具、图片/屏幕及人物验收区；另有实际像素测试验证变换、分层、着色与暂停预览。默认重跑目录为 `.godot/test-logs/v018-menu-render/`；`menu-benchmark.json` 为预热后 60 秒限 60 FPS 的间隔/资源测量，包含 Map585 平滑四帧行走和十种菜单负载（含图片/屏幕及人物区）；`menu-uncapped.json` 补充 30 秒不限帧、P95/P99/最长间隔及独立渲染 CPU/GPU 时间。成绩仅代表本机场景；平均 ≥59 不等于逐帧稳定 60，渲染时间不包含全部脚本/子系统。

`Run-MenuRender.ps1 -CaptureName <目录名>` 可隔离不同样例的截图。迁移器本身的1000×720界面可用`Run-MigratorUI.ps1 -GodotPath <引擎路径>`检查；当前截图为`.godot/test-logs/v019-migrator.png`。

`MovementTests.gd` 检查运动帧率独立、六种速度、参数校验、格/像素分离、跳跃、双向通行、人物占位、柜台/触碰、菜单整格等待、独立测试区及存档默认值。`Run-MovementRender.ps1`检查实际人物像素。`PresentationTests.gd`覆盖地图区域、独立中心、滚图、表现/计时/音频、存档默认及菜单暂停；`SaveRestartTests.gd`检查新字段跨进程恢复。`Run-PresentationRender.ps1 -GodotPath <引擎路径> -ProjectPath <导出工程> -Benchmark`保存三尺寸画面及60秒Map585行走＋暴风雨统计，不接受headless冒充画面。当前结果见[ver0.19验证记录](tests/VERIFICATION_v0.19.md)，人工步骤见[ver0.19验收清单](tests/ACCEPTANCE_v0.19.md)；上面的ver0.18菜单基准保留为历史负载，不能直接比较两套性能数字。

## 运行时扩展入口

- `RuntimeState.actor(id, reset=false)`：读取或初始化角色；`party_snapshots()` 返回不包含可变数据库引用的显示快照。
- `RuntimeState.change_party(id, adding, initialize=false)`：与现有事件共用的增减队员入口；`state_changed` 通知界面数据变化。
- `RuntimeState.inventory_entries()`、`use_item(item_id, actor_id)`、`equip_preview(actor_id, slot, id)`、`equip(actor_id, slot, id)`：背包与装备的统一事务入口，返回 `ok` 及失败说明，避免 UI 各自改库存；slot 为 0–4，装备 ID 0 表示卸下。
- `MenuCoordinator` 管理菜单焦点、场景栈及暂停恢复；`WindowBase` / `WindowSelectable` / `WindowCommand` 提供复用窗口。
- `SaveService.save_slot(slot, state)` / `load_slot(slot, state)` / `slot_info(slot)` 返回成功或明确错误；实际界面通过 `Game.save_slot` 校验空闲上下文。`SaveCodec.prepare` 在独立候选对象上检查完整进度，`RuntimeState.restore_prepared` 只提交已校验结果。实际保存不序列化场景节点。
- `CharacterSprite` / `UISpriteset` 管理角色显示，`UIResources` 共享纹理和窗口皮肤。这些是 GDScript 接口，不是可直接执行 Ruby 的兼容 API。

本版不更新已导出的用户工程；请迁移到新的空目录。两个样例和已有 `output/` 均保持不变，不自动改起始地图。
