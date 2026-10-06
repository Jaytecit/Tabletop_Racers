extends Node
# Build explicit neighbours from the visible rows after container layout settles.
# Self neighbours stop Godot's automatic geometric search at row boundaries.
var race: Node3D
var signature: Array = []
var rows: Array = []
var preferred_x: float = 0.0
var vertical_input: bool = false

func active_panel() -> Control:
	if race.developer_menu!=null and race.developer_menu.root.visible:
		if race.developer_menu.dialog.visible or race.developer_menu.reset_dialog.visible: return null
		return race.developer_menu.root
	if race.profile_menu!=null and race.profile_menu.visible:
		# The name keyboard owns its focus loop; do not mix in profile controls.
		if race.profile_menu.name_keyboard.visible: return null
		return race.profile_menu
	for modal: Node in [race.controls_setup,race.setup_menu,race.stats_menu]:
		if modal != null and modal.panel.visible: return modal.panel
	if race.menu.visible: return race.menu
	if race.results_panel.visible: return race.results_panel
	return null

func _process(_delta: float) -> void:
	rebuild()
	vertical_input = false

func rebuild() -> void:
	var panel: Control = active_panel()
	if panel == null:
		signature.clear()
		rows.clear()
		return
	var controls: Array[Control] = []
	var next_signature: Array = [panel]
	for node: Node in panel.find_children("*","Control",true,false):
		var control: Control = node
		if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE: continue
		if control is BaseButton and control.disabled: continue
		controls.append(control)
		next_signature.append([control,control.get_global_rect()])
	if next_signature == signature: return
	signature = next_signature
	controls.sort_custom(func(a: Control,b: Control) -> bool:
		return a.get_global_rect().get_center().y < b.get_global_rect().get_center().y)
	rows.clear()
	for control: Control in controls:
		if rows.is_empty() or absf(control.get_global_rect().get_center().y-rows[-1][0].get_global_rect().get_center().y)>22.0:
			rows.append([])
		rows[-1].append(control)
		if not control.focus_entered.is_connected(focused.bind(control)):
			control.focus_entered.connect(focused.bind(control))
			if control.has_focus(): preferred_x = control.get_global_rect().get_center().x
	for row: Array in rows:
		row.sort_custom(func(a: Control,b: Control) -> bool:
			return a.get_global_rect().get_center().x < b.get_global_rect().get_center().x)
	update_neighbours()
	var current: Control = get_viewport().gui_get_focus_owner()
	if not controls.is_empty() and current not in controls: controls[0].grab_focus()

func focused(control: Control) -> void:
	if not vertical_input: preferred_x = control.get_global_rect().get_center().x
	update_neighbours()

func nearest(row: Array) -> Control:
	var result: Control = row[0]
	for control: Control in row:
		if absf(control.get_global_rect().get_center().x-preferred_x)<absf(result.get_global_rect().get_center().x-preferred_x): result = control
	return result

func update_neighbours() -> void:
	if race.profile_menu!=null and race.profile_menu.name_keyboard.visible: return
	# Dynamic menus can replace rows between layout and a focus-entered signal.
	var attached: Array = []
	for row: Array in rows:
		var live: Array = row.filter(func(control: Control) -> bool: return is_instance_valid(control) and control.is_inside_tree())
		if not live.is_empty(): attached.append(live)
	rows = attached
	var flat: Array = []
	for r: int in range(rows.size()):
		var row: Array = rows[r]
		for c: int in range(row.size()):
			var control: Control = row[c]
			control.focus_neighbor_left = control.get_path_to(row[maxi(c-1,0)])
			control.focus_neighbor_right = control.get_path_to(row[mini(c+1,row.size()-1)])
			control.focus_neighbor_top = control.get_path_to(nearest(rows[r-1]) if r>0 else control)
			control.focus_neighbor_bottom = control.get_path_to(nearest(rows[r+1]) if r+1<rows.size() else control)
			flat.append(control)
	for i: int in range(flat.size()):
		flat[i].focus_previous = flat[i].get_path_to(flat[posmod(i-1,flat.size())])
		flat[i].focus_next = flat[i].get_path_to(flat[(i+1)%flat.size()])

func _input(event: InputEvent) -> void:
	if active_panel() == null: return
	vertical_input = event.is_action_pressed("ui_up",true) or event.is_action_pressed("ui_down",true)
	if vertical_input:
		# Keep the last horizontal column through intermediate single-control rows.
		update_neighbours()
