# ver0.2 地图表现与镜头接口

以下底层功能已于 ver0.19 验收，ver0.2 不扩展事件指令。完整运行时类与接口契约见迁移器仓库根目录的 `AGENTS.md`。天气目前仍由 `RuntimeState.map_effects` 持有；事件接入前需纳入 Game_Screen 对应层统一管理，不能复制出第二份天气状态。

这是 Godot 原生标准功能替代，不执行 Ruby，不新增事件命令，也不实现地图/事件编辑器。

## 地图区域与跟随中心

地图显示矩形和镜头跟随中心独立。`view_rect` 为逻辑窗口内 `[x,y,width,height]`，`follow_center` 为**相对于该地图区域左上角**的 `[x,y]`；跟随目标是角色所在格的中心。两者为空数组时自动使用全逻辑窗口和区域中心。单位是像素，不是旧 RGSS 128 单位。

例如 800×480 窗口左侧 UI 占 160px，在生成工程 `project.godot` 的 `[rgmigrator]` 段设置：

```ini
map_view_rect=[160, 0, 640, 480]
map_follow_center=[320, 240]
```

下次新游戏采用此配置；已有存档使用保存的运行状态。不会自动执行 Ruby 的 `center_x/center_y` 或推算自定义 UI。运行中可修改：

```gdscript
RuntimeState.configure_map_view({"view_rect": [160, 0, 640, 480], "follow_center": [240, 192]})
RuntimeState.scroll_map(6, 4, 1.0) # 向右4格，1秒；2下4左6右8上
RuntimeState.resume_map_follow()
```

大地图双轴平滑跟随，按**地图区域尺寸**限制边界，不把 UI 占用区当成可见地图。小地图在该区域居中；到边缘时角色不能始终处于跟随中心，这是边界约束。根窗口缩小时临时裁到有效范围，配置值不变。区域外遮住地图/天气，但 UI 和 Pictures 仍使用各自的全屏坐标；本版不自动生成侧栏 UI，不提供任意嵌套 Viewport 或同名 Ruby API。

手动滚图进入非跟随模式，保留完成后的镜头位置；重叠滚图明确拒绝。`resume_map_follow()` 取消当前滚动并平滑回到角色；换地图重新定位，跟随中心设置保留。只改变镜头，不移动玩家或增加步数。

## 全景、雾与天气

```gdscript
RuntimeState.configure_map_effects({"panorama_name": "原全景文件名", "panorama_hue": 0,
    "fog_name": "原雾文件名", "fog_hue": 0, "fog_opacity": 128,
    "fog_blend_type": 0, "fog_zoom": 150, "fog_sx": 2, "fog_sy": 1})
RuntimeState.map_effects.tint_fog([-40, 0, 20, 80], 1.0)
RuntimeState.map_effects.fade_fog(128, 1.0)
RuntimeState.map_effects.weather(3, 6, 1.0) # 0无/1雨/2暴风雨/3雪，强度0–9
```

全景按图块集名称/色相平铺，使用半速视差，透过空图块和透明像素显示；缺素材诊断并保留基础底色。雾叠在地图人物之上、屏幕图片之下，支持色相0–360、透明度0–255、混合0正常/1加算/2减算、缩放1–10000%、SX/SY及色调渐变。SX/SY保留 RMXP 数值含义，转换为每秒 `-5×SX/SY` 像素，不绑定40帧循环。材质按显示实例独立，纹理只读共享。

换地图重置全景/雾到新图块集，天气保留。类型非0时强度0是最低天气密度，关闭需类型0，两者不混淆。雨/暴风雨/雪为 Godot 批量绘制，不依赖 RTP，每个显示器最多256粒子；暴风雨附加地图变暗，不附带闪电/雷声。强度和关闭支持按秒渐变；菜单暂停真实地图、天气、雾和倒计时，背景音乐及音频淡出继续。图片和菜单不受地图雾/天气影响。

## 过渡与计时器

```gdscript
RuntimeState.timer.start(60) # 秒；到零发 expired 信号，不触发事件或战斗
RuntimeState.timer.stop() # 停止并隐藏
RuntimeState.fade_screen(255, 1.0) # 淡出至黑；传0淡入
var result = await RuntimeState.freeze_screen() # 等待真实渲染截图
if result.ok:
    # 在这里改变场景画面，然后执行过渡
    RuntimeState.transition_screen(1.0, "原过渡文件名", 40)
```

倒计时显示于地图区域右上，使用秒，不受渲染帧率影响；显示为向上取整的剩余分钟/秒，到零只通知一次。淡入淡出和过渡位于对话/菜单之下。冻结捕获当前 Viewport 的像素，截图仅属于当前场景；`transition_screen` 空名称为普通淡化，非空只从 Transitions 取原灰度素材，暗区域先显现、`vague` 0–255 控制边界。缺图保持冻结画面并返回失败，可调用 `RuntimeState.cancel_screen_transition()` 取消；重叠冻结拒绝，完成后释放截图和材质。headless 无真实画面，冻结接口明确失败，不伪造通过。

## 音频

```gdscript
RuntimeState.audio.play("BGM", {"name": "原文件名", "volume": 80, "pitch": 100})
RuntimeState.audio.fade_out("BGM", 2.0)
RuntimeState.audio.memorize()
RuntimeState.audio.restore_memory()
RuntimeState.audio.stop("BGM")
```

统一控制 BGM/BGS/ME/SE，音量0–100，音调50–150；空名称停止对应类别。BGM/BGS循环；ME暂停BGM并在停止/结束后恢复，BGS不受影响；SE独立并发（最多32个，超过上限释放最早的）。BGM/BGS/ME可淡出，记忆/恢复保存BGM/BGS的定义与位置。缺音频先校验再替换，旧曲不被错误请求中止，不补取 RTP。标题和地图自动播放设置使用同一服务；新图没有自动播放设置时保留原曲。解码器播放位置有精度限制，不承诺无缝循环或逐采样一致。

## 存档与测试入口

地图区域/跟随中心/手动滚图剩余时间、雾/天气及渐变、倒计时接入 schema1 新存档；旧新格式缺字段使用默认值。截图、淡入淡出、音频播放/记忆/淡出进度是瞬时状态，不保存。读档沿用原有工程/数据/测试定义校验，不读取 RM 旧存档。

勾选测试准备迁移后：新游戏 → Esc → F6 → **地图表现与镜头**。独立48×36大地图使用正式组件，方向键行走、Tab选择按钮、Z/Enter确认、Esc返回，鼠标编辑数值、切换页签，长列表可滚动。原素材按分类选择；工具绘制的全景/雾是对照图，非 RTP，仅供预览。预览不改变实际地图、坐标、背包、开关；只有“应用到真实地图”“真实地图10秒计时”显式改运行状态，不写数据库或项目配置，工具对照素材不能应用到真实地图。音频测试使用独立播放器，关闭页面释放。

工具预览缩小显示，不代表游戏真实尺寸质量。天气/滚图/计时器/过渡等事件命令仍留到 ver0.2–0.3 接通，强制路线、并行/完整自动调度及 Ruby 转换不在本版范围。
