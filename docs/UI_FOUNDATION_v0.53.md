# 0.53 共用图形与文本基础

本版整理标题、菜单和 Message 的共用显示能力，修复事件脚本方法名配色、通用命令列表内容滚动及字体后备问题。原气泡、标题和各菜单的完整图形还原继续按0.54—0.57实施。本版使用现有原素材与缓存，不新增替代美术。

## 原工程依据与画布

从原 RM 迁移出的 `legacy/ordered_scripts/` 保留实际加载源码。最终0337 Main使用640×640画布、60Hz，覆盖早先 Game.ini 尺寸；0111/0112定义窗口留白、光标和内容滚动，0023定义字体绘制，0149/0151/0153定义消息文字及行尺寸，0139/0203定义页面过渡。本版保留原顺序、数值与字体选择，不修改游戏公式和消息控制器。

`UILayout.DESIGN_SIZE` 是640×640逻辑像素。实际窗口缩放继续由Godot的canvas_items、保持宽高比及闪翼fractional设置完成，界面不重复乘操作系统缩放。地图HUD保留区为左侧224像素，由 `usable_rect(viewport_size, reserve_hud)` 统一计算；窄画布仍保留最少48像素的可用区域，再扣除各窗口留白。普通窗口四边留白16像素，内容和光标以同一内容区为准。

## 共用接口与调用

代码位于 `runtime/scripts/04_UI_Common/`，维护模板在迁移器 `templates/runtime/scripts/04_UI_Common/`。各 `.gd` 文件头含实际签名、参数、默认值和返回说明。

| 模块 | 用途与现有调用者 |
| --- | --- |
| `UILayout.gd` | 逻辑画布、HUD保留区、窗口内容矩形及矩形约束；WindowBase、WindowSelectable、Message布局 |
| `UITextLayout.gd` | 共享字体、真实度量、原生塑形和按宽高分页；UIResources、Message、TextRow、FlashTextDrawing、UITextBlock |
| `UITextBlock.gd` | 自身矩形内裁切绘制指定页，无自动计时；标题与主菜单的文字显示 |
| `UITransition.gd` | 位置、缩放和透明度过渡，替换、取消及目标失效；标题附页淡入 |
| `UIInput.gd` | 按键码、物理键回退和重复规则；标题、菜单协调器及Message |
| `WindowBase/Selectable/Command.gd` | 窗口皮肤、内容裁切、光标、列布局、可见行和实际文字滚动 |

例如创建一个文字区域：

```gdscript
var block = preload("res://runtime/scripts/04_UI_Common/UITextBlock.gd").new()
block.position = Vector2(16, 16)
block.size = Vector2(300, 120)
block.configure("中文和 English 会按实际可用区域换行。", {
    "font_name": "楷体", "font_size": 22, "line_space": 4,
    "font_color": Color.WHITE
})
add_child(block)
# 需要切换显示页时：block.set_page(index)，总页数为block.page_count()。
```

字体缓存按字体列表、粗体和斜体区分，最多128组，只读复用；标题和菜单原默认字体与Message楷体各自保留。为旧中文字体缺失的组合音标增加明确后备字体，避免基础字母和附加符号被拆开。测量与绘制使用同一Font及字号，资源缓存中的纹理保持共享只读，绘板仍持有独立Image。

## 换行、分页与裁切规则

- 按实际字体塑形结果换行，优先单词边界，超长词按字素边界换行；中文、混排、字距、组合字符由原生TextServer处理。
- `\n` 保留显式换行，`\f` 显式分页；自动页数由每行实际高度、行距和可用像素高度决定，不能把RM编辑器的四行当作显示容量。
- `UITextLayout.layout(text, style, maximum_width, maximum_height=INF)` 返回 `{ok,pages,overflow}`。每页含行及实际高度，行记录原字符串范围及绘制位置；零或非法区域明确失败。单个字素本身超过宽高时保留并标记overflow，由控件裁切，不丢弃文字或反复换行。
- `UITextBlock` 尺寸变化后自动重排并限制页号，绘制受自身矩形裁切；切页仅改变显示，不推进事件或发放奖励。页内 `TextParagraph` 是显示资源，不写入游戏存档。
- Message继续使用当前控制器、控制码和可保存的页面滚动；本版共用字体、度量及最大可用宽度，不将静态文字组件当成新的Message执行器。气泡全链路及翻页交互仍在0.54核对补齐。

## 窗口、输入与动画

通用命令窗口选到下方项目时，文字内容与光标一起滚动；改变窗口尺寸后重排可见行，空列表和停用状态立即隐藏光标。皮肤、光标、内容使用明确的相对层次，光标受内容区约束。已有自行绘制可见项目的列表继续使用 `scroll_row` 与 `item_rect`，不会再整体平移一次造成双重滚动。

标题和菜单由所属控制器转发键盘输入，确认/取消忽略echo重复，导航按指定列表接受重复；Message只允许上下导航重复。手动管理选择的主标题/主菜单按钮不抢键盘焦点，仍可鼠标点击。姓名输入及其他文本编辑焦点沿用原专用路径，Viewport仍由所属控制器标记输入已处理。

`UITransition.play(control, {"position":目标位置,"modulate":目标颜色}, seconds)` 从当前属性开始；所属页面每次 `_process` 调用 `advance(delta)`。同一实例在同一引擎帧只累计一次时间，再次play替换旧目标；取消保留当前画面。弱引用目标在释放、移出树或排队删除后失效，完成不通过旧页面回调修改新页面。标题附页保留16/60秒淡入时长。

## 事件脚本配色与验收

`Editor_EventScript.gd` 明确设置深色代码背景、普通文字、方法名、成员、数字、单/双引号字符串、注释及选择颜色。验收检查实际 `Actor_Init.load` 和 `ctx.set_variable` 的语法高亮结果，核对普通与选中状态，并在真实EditorPlugin中渲染、保存和重开。

自动验证记录见 `tests/VERIFICATION_v0.53.md` 和JSON。关键检查包括原字体度量、混排与组合字符、长文本末页、窗口内容与光标对齐、尺寸重排、重复按键、动画替换/取消、旧档、原生事件和普通战斗开门。完整剧情人工通关和后续页面图形还原不由这些检查替代。

原生API依据：[TextParagraph](https://docs.godotengine.org/en/4.5/classes/class_textparagraph.html)、[TextServer](https://docs.godotengine.org/en/4.5/classes/class_textserver.html)、[CodeHighlighter](https://docs.godotengine.org/en/4.5/classes/class_codehighlighter.html)。
