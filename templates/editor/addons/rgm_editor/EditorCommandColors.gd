@tool
extends RefCounted
## Shared command classification and colors, independent of native payloads.
const DARK = {"text":"8ed9ff","flow":"b5b8ff","state":"f2be72","move":"8ed6a5","screen":"d6a9f0","audio":"80ddd1","actor":"f3afc4","inventory":"ead27b","scene":"c4d0e8","comment":"9eb9a3","unsupported":"eeaa86","end":"939cae"}
const LIGHT = {"text":"075f88","flow":"493a9b","state":"805010","move":"21653d","screen":"71348b","audio":"006a62","actor":"963859","inventory":"705800","scene":"3f506d","comment":"466447","unsupported":"a03e17","end":"596171"}

static func group(code: int, route: bool = false) -> String:
	if code == 0: return "end"
	if route:
		if code in [27,28]: return "state"
		if code == 44: return "audio"
		if code == 45: return "unsupported"
		return "move"
	if code in [108,408]: return "comment"
	if code in [355,655]: return "unsupported"
	if code in [101,103,104,105,401]: return "text"
	if code in [102,106,111,112,113,115,117,118,119,402,403,404,411,412,413]: return "flow"
	if code in [121,122,123,124,134,135]: return "state"
	if code in [201,202,203,208,209,210,509,116]: return "move"
	if code >= 204 and code <= 207 or code >= 221 and code <= 236: return "screen"
	if code >= 241 and code <= 251: return "audio"
	if code >= 125 and code <= 128 or code in [302,605]: return "inventory"
	if code == 129 or code >= 303 and code <= 322: return "actor"
	return "scene"

static func apply(tree: Tree, row: TreeItem, code: int, unsupported: bool = false, route: bool = false) -> void:
	var light = tree.get_theme_color("font_color").get_luminance() < 0.5
	var palette = LIGHT if light else DARK
	row.set_custom_color(0,Color(palette["unsupported" if unsupported else group(code,route)]))
	if tree.columns > 1 and unsupported: row.set_custom_color(1,Color(palette.unsupported))
	# Selection remains high contrast, including category-colored rows.
	var style = tree.get_theme_stylebox("selected")
	var background = style.bg_color if style is StyleBoxFlat else Color("35609a")
	var selected=Color("171b22") if background.get_luminance() > 0.45 else Color.WHITE
	if tree.get_theme_color("font_selected_color")!=selected: tree.add_theme_color_override("font_selected_color",selected)
