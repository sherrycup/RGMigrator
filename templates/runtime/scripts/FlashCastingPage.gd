extends "SkillScene.gd"
## 0257 standalone learned-skill screen is separate from 0202 configuration.
## Final source lacks legacy skill_effect; native common-event uses stay explicit.
var page="flash_casting"
func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: back()
	elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_Z,KEY_SPACE]: activate()
	elif key in [KEY_UP,KEY_LEFT]: navigate(-1)
	elif key in [KEY_DOWN,KEY_RIGHT]: navigate(1)
	elif key in [KEY_PAGEUP,KEY_PAGEDOWN] and not RuntimeState.party.is_empty() and _target_selection==null:
		var index=RuntimeState.party.find(actor_id); actor_id=int(RuntimeState.party[posmod(index+(-1 if key==KEY_PAGEUP else 1),RuntimeState.party.size())]); selected=0; _selection_id=0; refresh(); sound_requested.emit("cursor_se")
