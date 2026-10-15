# 闪翼0.45历史接口审计

2026-10-12。对应45-04、45-14，并附45-01基础方法复核。本记录区分原方法保留、数据提取、当前玩法适配和剩余验证；审计通过不等于旧算法已改写为GDScript。

## 调用证据与处理

检查339个原加载槽、144个原事件片段及49个原地图/数据库JSON。213条原生117调用没有以36为目标；Items/Skills也没有绑定公共事件36。144个片段中的脚本command_117只有公共事件23使用常量目标1、3、4。公共事件36的trigger为0。

0074中所有Battle_Data.new、Delay_Ctrl.new、load_proc、real_time_readdition旧循环位于L163—377的=begin/=end注释内；0234的battle_data窗口读取位于L1—207整段注释内。0062/0064定义仍加载，但全部有效库代码未出现include/extend Skill；唯一明确单例入口Skill.Load_StaticProc引用未定义Static_Hash。0072 L1964—1965对旧@battle_data只做惰性清除，并没有恢复旧getter。上述结论基于加载顺序、注释边界和调用扫描，不能仅凭“旧”“废弃”名称推出。

仍然存在一个可调用的历史入口：公共事件36 command8（event_000099 L8）读取_this.enemy.battle_data.damage。当前原普通战斗已经删除该getter，所以这也是源工程的遗留错误。编辑器保留流程控制117和公共事件36，用户能够添加调用，不能删除36或声称完全不会使用。

最小兼容采用同一当前普通预测结果：将该读修复为_this.enemy.battle_result.enemy_damage；旧_v[1]角色引用修复为_attack_actor.id，来源记录为legacy_battle_result和legacy_battle_role。CE36通过原CE2扣除双方HP，保留其耐心-1、奖励、CE14升级流程。这里不能调用begin_battle!，否则CE2将重复扣敌人HP；也不替CE36发明旧Battle_Data真值或悄悄套用CE1的finish流程。完整原命令链的运行检查通过。

0075/0076的原保留理由是识别RM旧Marshal档；本工程已明确不迁移RM旧存档，因此当前普通玩法不需要复活这些旧存档对象。所有原定义、方法、属性入口及疑点仍在本JSON中逐项保留。未来若编辑器新代码显式构造旧类，应新增明确适配或报来源诊断，不能自动冒充当前模拟器。

## 方法对应清单

| 原模块/类 | 方法或属性接口 | 来源行 | 当前处理 |
| --- | --- | --- | --- |
| Storage | `sucking_in` | [0060:L11](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:11>) | 原预设属性入口保留 |
| Storage | `sucking_in=` | [0060:L11](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:11>) | 原预设属性入口保留 |
| Storage | `sucking_ratio` | [0060:L12](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:12>) | 原预设属性入口保留 |
| Storage | `sucking_ratio=` | [0060:L12](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:12>) | 原预设属性入口保留 |
| Storage | `firmness` | [0060:L13](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:13>) | 原预设属性入口保留 |
| Storage | `firmness=` | [0060:L13](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:13>) | 原预设属性入口保留 |
| Storage | `offensive` | [0060:L14](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:14>) | 原预设属性入口保留 |
| Storage | `offensive=` | [0060:L14](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:14>) | 原预设属性入口保留 |
| Storage | `penetration` | [0060:L15](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:15>) | 原预设属性入口保留 |
| Storage | `penetration=` | [0060:L15](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:15>) | 原预设属性入口保留 |
| Storage | `critical` | [0060:L16](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:16>) | 原预设属性入口保留 |
| Storage | `critical=` | [0060:L16](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:16>) | 原预设属性入口保留 |
| Storage | `mirror` | [0060:L17](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:17>) | 原预设属性入口保留 |
| Storage | `mirror=` | [0060:L17](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:17>) | 原预设属性入口保留 |
| Storage | `resilience` | [0060:L18](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:18>) | 原预设属性入口保留 |
| Storage | `resilience=` | [0060:L18](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:18>) | 原预设属性入口保留 |
| Storage | `purge` | [0060:L19](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:19>) | 原预设属性入口保留 |
| Storage | `purge=` | [0060:L19](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:19>) | 原预设属性入口保留 |
| Storage | `delta_hatred` | [0060:L20](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:20>) | 原预设属性入口保留 |
| Storage | `delta_hatred=` | [0060:L20](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:20>) | 原预设属性入口保留 |
| Storage | `reduction` | [0060:L21](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:21>) | 原预设属性入口保留 |
| Storage | `reduction=` | [0060:L21](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:21>) | 原预设属性入口保留 |
| Storage | `stealing_ratio` | [0060:L22](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:22>) | 原预设属性入口保留 |
| Storage | `stealing_ratio=` | [0060:L22](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:22>) | 原预设属性入口保留 |
| Storage | `forgetting_ratio` | [0060:L23](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:23>) | 原预设属性入口保留 |
| Storage | `forgetting_ratio=` | [0060:L23](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:23>) | 原预设属性入口保留 |
| Storage | `actor_exp_next` | [0060:L31](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:31>) | 原数据提取 |
| Storage | `actor_init_exp` | [0060:L40](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:40>) | 原数据提取 |
| Storage | `actor_init_animation` | [0060:L46](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:46>) | 原数据提取 |
| Storage | `install_skill_parameters` | [0060:L53](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0060_-_Sotrage.rb:53>) | 原数据提取 |
| Storage | `skill_description` | [0061:L20](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0061_-_Storage(技能文本).rb:20>) | 原文本提取并运行验证 |
| Storage | `skill_easy_description` | [0061:L36](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0061_-_Storage(技能文本).rb:36>) | 原文本提取并运行验证 |
| Skill | `load_proc` | [0062:L9](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:9>) | 历史定义保留，非当前战斗实现 |
| Skill | `Skill.Load_StaticProc` | [0062:L38](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:38>) | 历史定义保留，非当前战斗实现 |
| Skill | `update_state` | [0062:L44](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:44>) | 历史定义保留，非当前战斗实现 |
| Skill | `end_turn` | [0062:L52](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:52>) | 历史定义保留，非当前战斗实现 |
| Skill | `rest` | [0062:L72](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:72>) | 历史定义保留，非当前战斗实现 |
| Skill | `pattack` | [0062:L85](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:85>) | 历史定义保留，非当前战斗实现 |
| Skill | `crazy_scratch` | [0062:L116](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:116>) | 历史定义保留，非当前战斗实现 |
| Skill | `double_hand` | [0062:L133](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:133>) | 历史定义保留，非当前战斗实现 |
| Skill | `repeat_slash` | [0062:L159](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:159>) | 历史定义保留，非当前战斗实现 |
| Skill | `insight_counter` | [0062:L200](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:200>) | 历史定义保留，非当前战斗实现 |
| Skill | `magic_box` | [0062:L233](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:233>) | 历史定义保留，非当前战斗实现 |
| Skill | `straight_hit` | [0062:L250](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:250>) | 历史定义保留，非当前战斗实现 |
| Skill | `excitement` | [0062:L285](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:285>) | 历史定义保留，非当前战斗实现 |
| Skill | `magic_attack` | [0062:L340](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0062_Skill 1.rb:340>) | 历史定义保留，非当前战斗实现 |
| Skill | `real_time_readdition` | [0064:L4](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0064_Skill 3.rb:4>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `base` | [0075:L11](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:11>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `maxhp` | [0075:L12](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:12>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `hp` | [0075:L13](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:13>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `atk` | [0075:L14](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:14>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `pdef` | [0075:L15](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:15>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `int` | [0075:L16](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:16>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `mdef` | [0075:L17](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:17>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `agi` | [0075:L18](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:18>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `eva` | [0075:L19](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:19>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `attack_times` | [0075:L21](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:21>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `attack_times=` | [0075:L21](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:21>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `attacked_times` | [0075:L22](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:22>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `attacked_times=` | [0075:L22](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:22>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `text` | [0075:L24](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:24>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `turn` | [0075:L25](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:25>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `turn=` | [0075:L25](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:25>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `damage` | [0075:L26](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:26>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `damage=` | [0075:L26](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:26>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `delay` | [0075:L27](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:27>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `delay=` | [0075:L27](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:27>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `buff` | [0075:L28](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:28>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `buff=` | [0075:L28](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:28>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `passive` | [0075:L29](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:29>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `passive=` | [0075:L29](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:29>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `battle_tag` | [0075:L30](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:30>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `battle_tag=` | [0075:L30](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:30>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `action_list` | [0075:L31](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:31>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `action_list=` | [0075:L31](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:31>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `t_damage` | [0075:L32](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:32>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `t_damage=` | [0075:L32](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:32>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `s_status` | [0075:L34](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:34>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `s_readdition` | [0075:L35](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:35>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `initialize` | [0075:L39](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:39>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `temp_hp` | [0075:L141](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:141>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `atk` | [0075:L145](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:145>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `pdef` | [0075:L149](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:149>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `int` | [0075:L153](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:153>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `mdef` | [0075:L157](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:157>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `agi` | [0075:L161](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:161>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `a_damage` | [0075:L165](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:165>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `d_damage` | [0075:L170](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:170>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `dead?` | [0075:L174](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:174>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `damage=` | [0075:L179](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:179>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `gain_buff` | [0075:L192](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:192>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `cost_buff` | [0075:L230](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:230>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `clear` | [0075:L246](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:246>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `reload` | [0075:L334](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:334>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `init_data` | [0075:L340](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:340>) | 历史定义保留，非当前战斗实现 |
| Battle_Data | `to_s` | [0075:L399](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0075_Battle_Data.rb:399>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `initialize` | [0076:L3](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:3>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `monitor_push_back` | [0076:L13](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:13>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `monitor_get_battlers` | [0076:L19](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:19>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `monitor_get_battler` | [0076:L23](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:23>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `monitor_next_battler` | [0076:L32](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:32>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `monitor_find_opposite` | [0076:L39](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:39>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `monitor_find_us` | [0076:L48](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:48>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `get_battler` | [0076:L59](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:59>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `get_battlers` | [0076:L67](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:67>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `push_back` | [0076:L71](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:71>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `find_opposite` | [0076:L76](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:76>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `find_us` | [0076:L85](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:85>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `next_battler` | [0076:L95](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:95>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `next_skill` | [0076:L110](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:110>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `have_enemies?` | [0076:L146](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:146>) | 历史定义保留，非当前战斗实现 |
| Delay_Ctrl | `end?` | [0076:L154](<D:/Dev/Godot_Trans/output/0.44/release/黎之闪翼（开发中）_Godot/legacy/ordered_scripts/0076_Delay_Ctrl.rb:154>) | 历史定义保留，非当前战斗实现 |

0060经验/初始经验/动画和战斗参数预设提取到flash_gameplay.json.storage。0061的skill_description含7条：[41,61,62,81,101,121,132]（L22—28）；skill_easy_description含1条61（L38）。已提取原文本，逐条精确字词与转义检查通过；描述132不代表源工程实际注册了132技能效果。当前普通技能效果以0072/0073实际定义为准，不能把0062旧闭包当作新预设的完成证据。

## 基础方法复核

| 来源 | 原方法 | 迁移结构 | 边界/剩余 |
| --- | --- | --- | --- |
| 0018 Object | `in?`、`to_param` | ScriptSemantics.invoke | in?按Ruby身份/数值相等检查；to_param供旧Win32调用的API本身仍属系统插件后续范围。 |
| 0019 Array | `[]`、`old_val`、`bwise`、`plus`、`-@`、`minus`、`-`、`prod`、`*`、`random_element` | ScriptSemantics.index_get/indexes_get/unary/binary/invoke; FlashValueExtensions.vector/bwise | bwise仅原有限算术/两种clamp模式；任意新Ruby表达式明确失败。动态精确范围外数值不伪造。 |
| 0021 Numeric | `plus`、`minus`、`prod`、`to_opc`、`_in`、`===` | ScriptSemantics.binary/invoke | 最后L49无参数to_opc覆盖L29有参数版本；===对Array逐项匹配。alias _in本身不代表额外公开玩法已走通。 |
| 0024 Hash | `[]`、`old_val` | ScriptSemantics.index_get/indexes_get/invoke | 多键返回数组；普通树形Hash与Ruby键类型采用明确标签。 |
| 0037 DataBase | `maptree`、`get_floor_type` | CustomDataImporter._floor_tree; CustomDataState floor_tree/floor_tree_entries/floor_tree_map | 原maptree混合[region,floor]与map_id键已接通，模板I/P等字段保持原平铺格式；根代理FlashBusinessTests验证混合索引和has_key?。原读取接口已适配，0108/0109整体地图行为仍归0.46。 |
| 0037 DataBase | `initialize`、`cre_maptree` | DataConverter; CustomDataImporter._floor_tree; FlashGameplayImporter._sync_database；0.46系统/地图刷新 | 初始数据库转换、地图树提取、0072 L1855覆盖的技能同步已执行；运行时重新初始化/重建树回调随0.46系统与半成品地图接入，不能把0037整文件勾为已移植。 |
| 0315 Utils | `Unit`、`h_to_i`、`Check_Area`、`MHT_Distance`、`Find_Event` | FlashUtils.invoke/integer_text | Unit原空方法保持nil；MHT_Distance参数顺序x1,x2,y1,y2；Find_Event正则重叠允许重复ID，Check_Area含边界、死亡过滤和玩家。 |
| 0315 Utils | `AdaptText`、`Get_Pic`、`Update_Mask`、`Sprite_Unravel` | 0.46页面/文本与0.47插件收尾 | 0157/0179/0207/0227/0232、0310实际调用；不因当前菜单尚未接入就登记为无调用。 |
| 0315 Utils | `DeepClone` | 0.46菜单实际树形数据复制；0.47共享/循环对象关系 | 0157/0182/0183/0216/0221实际调用；当前普通duplicate(true)或copy_value树形复制不证明Marshal对象图语义完全实现。 |

## 源缺陷与验证边界

- 0062 L38—39：Skill.Load_StaticProc读取Static_Hash，全部执行源码没有Static_Hash定义；不补造注册表。
- 0062 L72—80：rest闭包没有初始化attacker，并误用attack；只在被注释掉旧循环被分派。
- 0062 L116—128：crazy_scratch原闭包无伤害/动作；不得用注释补写新公式。
- 0062 L325—329：excitement百分比分支arracker拼写；其余多种kind分支为空；本轮当前13预设没有280—329注册。
- 0062 L340—345：magic_attack以Array作为damage并误用recevier，且不同于旧load_proc期待的Proc返回形式。
- 0075 L203：gain_buff用mu字符串作乘法/比较，而不是@buff[mu]，原旧算法本身含错误。
- 0076 L125—143：next_skill重写前面scope=0并有未实现的多目标分支；不能把新TargetResolver冒充此旧方法逐句迁移。

已完成静态交叉检查：339/144输入数量、完整原生117目标统计、无Items/Skills指向36、无有效include/extend Skill、唯一历史事件访问event_000099、36触发类型及旧循环注释范围。未执行原Ruby。精确文件哈希、反射候选、来源文本、原36命令列表见同名JSON。

`tests/runtime/FlashLegacyFlowTests.gd`在Godot4.7.2纯GDScript运行通过33项检查：完整原36→5/2/14公共事件命令链；存活与击败两支；双方HP各扣一次；无第二次pending开战/结算；原耐心减一/一次奖赏；原生成Level_Up；旧变量1为0仍使用当前主战；全部7+1描述精确文本。没有SCRIPT ERROR，只有当前环境的root certificate提示。独立私有夹具日志为`.godot/v045_legacy_flow_1791815418520069400/flash-legacy-flow.log`。原命令链与绑定来自原RM，数值输入用来区分两个分支，不等同全剧情或正式导出。

45-04的当前数据与文本、45-14的调用审计/历史事件兼容在本分工内没有已知阻断。旧算法定义作为历史源码保留，未宣称全方法GDScript改写已经完成；后续新代码显式使用旧类仍须明确适配或给出来源诊断。45-01中DataBase读取的混合键/平铺字段已适配，initialize/cre_maptree的运行时重建和页面/对象图继续按0.46/0.47接入。普通模拟器、页面、对象图的完成状态由各自实现记录负责。本报告没有修改版本、复写原工程或正式导出。
