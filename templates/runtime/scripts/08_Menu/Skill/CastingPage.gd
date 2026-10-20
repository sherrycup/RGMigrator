## 职责：展示闪翼可施放技能和目标，校验消耗后调用技能业务。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/Skill/CastingPage.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends "SkillScene.gd"
## 0257 standalone learned-skill screen is separate from 0202 configuration.
## Final source lacks legacy skill_effect; native common-event uses stay explicit.
var page = "flash_casting"


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()
	elif key in [KEY_UP, KEY_LEFT]:
		navigate(-1)
	elif key in [KEY_DOWN, KEY_RIGHT]:
		navigate(1)
	elif (
		key in [KEY_PAGEUP, KEY_PAGEDOWN]
		and not RuntimeState.party.is_empty()
		and _target_selection == null
	):
		var index = RuntimeState.party.find(actor_id)
		actor_id = int(
			RuntimeState.party[posmod(
				index + (-1 if key == KEY_PAGEUP else 1), RuntimeState.party.size()
			)]
		)
		selected = 0
		_selection_id = 0
		refresh()
		sound_requested.emit("cursor_se")
