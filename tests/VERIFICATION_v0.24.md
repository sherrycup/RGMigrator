# ver0.24 验证记录

日期：2026-10-07。Godot 4.7.2 Standard / Compatibility，Windows，纯GDScript。本轮接入图片、屏幕和天气事件；源RM工程及用户已验收输出未修改，没有新增生产演示场景或工具入口，文本增强继续暂缓。

## 实现与原生参数

- 221真实截图准备，222普通/蒙版过渡，使用请求身份查询实际完成和取消。界面/其他传送占用时等待重试；缺素材保持原画面，headless明确拒绝截图。旧协程/旧请求不能干扰新截图，取消所属解释器或重置场景释放截图。
- 223/224原Tone/Color、225强度/速度映射；231直接/变量显示、232移动、233旋转、234图片色调、235独立编号擦除、236雨/暴风雨/雪与渐变。原点/缩放/透明/混合参数和变量值先校验；缺素材不替换原图；空名称擦除，未显示图片的移动/旋转/色调保留原生空效果。
- 原生223/224/225/232/234在Interpreter里乘2，因此事件边界直接把参数/20转秒，不在底层重复乘2。236原脚本直接传入帧数，按参数/40转秒。233每帧增加速度/2，按40fps换成速度×20度/秒，正逆时针、0停止。
- 原生Scene_Map的222：空名称20帧、有蒙版40帧，分别0.5/1秒；不是把Godot底层默认0.2秒直接当原生事件规则。222期间暂停地图、人物、动画、自动图块、镜头、效果、天气、计时与调度，过渡本身继续渲染；221完成后可在冻结画面下继续逻辑。其他效果不隐式等待。
- 震动使用原生强度×2的峰值及速度/2的周期频率，沿用平滑正弦和结束包络以消除旧逐帧折返跳变；波形不宣称逐像素复刻，结束归零。

只读核对样板Game_Screen、Game_Picture、Interpreter 5、Scene_Map及后加载的Vendor扩展；小蛋挞的剧情跳过重写属于定制，未引入。原生参考40fps用于边界换算，不将样板Main60fps或小蛋挞配置帧率误称为原生固定基线。不执行Ruby，也不接回合制战斗或自定义魔塔结算。

## 天气归属与存档

ScreenState组合WeatherState，持有唯一运行天气；正式ScreenRenderer调用screen.advance一次推进。MapEffectsRenderer读取screen_model.weather_snapshot并显示粒子，只推进雾/计时；独立PresentationTools拥有自己的screen，预览时钟不污染正式地图。

天气换图保留进度、新游戏重置、普通菜单和222暂停。新schema1快照仅在screen.weather保存六字段；旧map_effects天气校验后迁入screen，归一化删除旧字段。相同双份可归一，冲突、部分字段、非法数值和不一致密度目标在恢复前拒绝。旧无天气字段存档默认中性。执行现场存档仍按0.27推进，瞬时截图/过渡由存档门禁保护。

## 冷迁移与完整回归

```powershell
./tests/Run-Headless.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe'
```

本轮重新导出至`.godot/test_exports_1850665/`，冷导入及45个阶段全部通过，确实未跳过迁移或导入。记录与各阶段日志保留于`.godot/test-logs/v024-cold/`，汇总为其中的`full-summary.json`。

| 工程 | 地图 | 数据文件 | 非RTP素材 | 解出的Ruby脚本 |
| --- | ---: | ---: | ---: | ---: |
| 黎之闪翼（开发中） | 36 | 50 | 4097 | 306 |
| 二律背反 | 19 | 34 | 2530 | 254 |

- EventScreenTests每工程137项通过，检查全部参数、原Tone/Color第四通道、缺素材/坏变量原子性、30/40/60/120FPS图片/色调/闪光/旋转/天气时间线、震动峰值、零时长、天气渐隐、旧/新存档恢复、正式单次推进、菜单暂停、换图保留及新游戏重绑。
- 导入器检查原Marshal Tone/Color转换和全部221–225、231–236命令不会误报未支持。DocumentationTests495项通过，80个生产脚本、557个公共方法。
- 0.21–0.23事件控制/取值/移动与标题、菜单、库存、技能动画、商店/State、成长、图片屏幕、缓存、碰撞、表现、编译、存档及跨进程恢复纳入完整回归。
- 两份生成工程各65个业务runtime脚本与最终模板哈希一致；RuntimeVersion.gd由生成器写出，VERSION常量均为ver0.24。

## 实际渲染

```powershell
./tests/Run-EventScreenRender.ps1 -GodotPath 'D:\GameEngine\Godot\Godot_v4.7.2-stable_win64.exe' -ProjectPath '<生成工程目录>' -CaptureName 'v024-screen-render-sample1-final'
```

OpenGL Compatibility / GTX1660Ti，640×480、800×480、768×768。使用既有Game/MovementFixture与私有测试数据覆盖；检查正式解释器和真实像素，未搭生产演示场景。

两份工程各225项通过、各39张PNG与result.json。检查图片坐标、加算/减算、独立色调、旋转条纹、移动插值、闪光层、摄像机震动、三种天气实际粒子/裁切/渐隐、普通与源工程蒙版过渡、暂停各时钟、消息占用重试、准备截图所属解释器取消、异步旧请求与替代请求、缺蒙版保留截图、222隐式准备及221→201→222换图组合。另验证无事件运行时仍禁止保存瞬时截图，底层SaveService拒绝时不创建目录/文件且不增加存档次数。

- `.godot/test-logs/v024-screen-render-sample1-final/`
- `.godot/test-logs/v024-screen-render-sample2-final/`

现有Run-PresentationRender的实际预览回归74项通过，记录`.godot/test-logs/v024-presentation-final/`；验证天气归属调整后，独立预览/真实地图应用仍使用正确状态和暂停边界，未开启Benchmark长测。

已检查最小窗口的独立图片/地图色调和天气裁切，以及方形窗口的真实蒙版半过渡截图。自动检查不代表完整源游戏通关、音频听感或本轮性能长测。
