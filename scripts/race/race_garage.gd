extends RefCounted
const CHARACTERS: Script = preload("res://scripts/profiles/character_catalog.gd")
# Each driver carries an independent balanced build, composed from base resources.
var selected: int = 0
var cards: Array[Button] = []
var preview_car: Node3D
const COLORS: Array[Color] = [Color("ef6546"),Color("4ba5c9"),Color("f1c44f"),Color("86bb5b")]
const COLOR_NAMES: Array[String] = ["RED","BLUE","GOLD","GREEN"]
const RIVAL_NAMES: Array[String] = ["RED ROCKET","BLUE COMET","GOLD RUSH","GREEN MACHINE"]
const DRIVERS: Array[String] = ["01 · ROXY ROCKET","02 · FINN FLYWHEEL","03 · KIT SPARK","04 · BEA BOLT"]
const MOTTO: Array[String] = ["Chase the chalk.","Keep it smooth.","Find your spark.","Hold your line."]

func setup(race: Node3D) -> void:
	var menu: Control = race.menu
	menu.position = Vector2(110,215)
	menu.size = Vector2(980,490)
	menu.get_node("Title").add_theme_font_size_override("font_size",32)
	menu.get_node("Subtitle").text = "BLACKJACK GRAND PRIX · CHOOSE YOUR DRIVER"
	menu.get_node("Description").visible = false
	menu.get_node("Difficulty").position = Vector2(34,92)
	menu.get_node("Subtitle").position = Vector2(34,66)
	menu.get_node("Subtitle").add_theme_font_size_override("font_size",16)
	menu.get_node("Controller").position = Vector2(34,465)
	menu.get_node("Start").position = Vector2(34,348)
	menu.get_node("Back").position = Vector2(34,420)
	var grid: HBoxContainer = HBoxContainer.new()
	grid.name = "DriverCards"
	grid.position = Vector2(34,130)
	grid.size = Vector2(570,155)
	grid.add_theme_constant_override("separation",8)
	menu.add_child(grid)
	for index: int in range(4):
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(136,155)
		card.toggle_mode = true
		card.tooltip_text = DRIVERS[index]+" · "+MOTTO[index]
		card.add_theme_font_size_override("font_size",16)
		card.add_theme_color_override("font_color",COLORS[index].lightened(0.3))
		card.pressed.connect(func() -> void:
			select(race,index)
			race.save_preferences()
			if race.menu_flow!=null and race.menu_flow.step==1: race.menu_flow.advance())
		grid.add_child(card)
		var portrait: TextureRect = TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = load("res://assets/drivers/driver_%d.svg"%index)
		portrait.position = Vector2(34,5)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.size = Vector2(68,65)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)

		var driver_caption: Label = Label.new()
		driver_caption.name = "DriverCaption"
		driver_caption.position = Vector2(2,77)
		driver_caption.size = Vector2(132,72)
		driver_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		driver_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		driver_caption.add_theme_font_size_override("font_size",16)
		driver_caption.add_theme_color_override("font_color",COLORS[index].lightened(0.3))
		card.add_child(driver_caption)
		cards.append(card)
	var course: OptionButton = OptionButton.new()
	course.name = "TrackSelect"
	course.position = Vector2(34,300)
	course.size = Vector2(280,32)
	course.add_item("BLACKJACK · BUGGY · 3 LAPS")
	menu.add_child(course)
	var viewport_box: SubViewportContainer = SubViewportContainer.new()
	viewport_box.name = "Diorama"
	viewport_box.position = Vector2(630,28)
	viewport_box.size = Vector2(320,265)
	viewport_box.stretch = true
	menu.add_child(viewport_box)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(320,265)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport_box.add_child(viewport)
	var world: Node3D = Node3D.new()
	viewport.add_child(world)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "DioramaSurface"
	var floor_shape: CylinderMesh = CylinderMesh.new()
	floor_shape.top_radius = 2.5
	floor_shape.bottom_radius = 2.5
	floor_shape.height = 0.18
	floor_mesh.mesh = floor_shape
	floor_mesh.material_override = preload("res://scripts/tracks/track_builder.gd").material(Color("168f78"))
	world.add_child(floor_mesh)
	var camera: Camera3D = preload("res://scripts/race/menu_course_flyover.gd").new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(3.5,3.2,4)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.5
	camera.near = 0.005
	camera.current = true
	build_course_preview(race,world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.name = "PreviewEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172c29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f4e8cb")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var bedroom: Node = world.get_node_or_null("CoursePropsPreview/BedroomDisplay")
	if bedroom != null: bedroom.configure_sky(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = 1.5
	world.add_child(light)
	var caption: Label = Label.new()
	caption.name = "CourseInfo"
	caption.position = Vector2(640,305)
	caption.size = Vector2(310,58)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = "8 gates · return within 5s if missed\nor +5s penalty and recovery."
	caption.add_theme_font_size_override("font_size",14)
	menu.add_child(caption)
	var map: TextureRect = TextureRect.new()
	map.name = "CourseMap"
	map.position = Vector2(850,220)
	map.size = Vector2(92,58)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(map)
	select(race,0)

func select(race: Node3D, index: int) -> void:
	selected = index
	apply_stats(race)
	# Reassign every slot from its default so repeated selections undo the last swap.
	for slot: int in range(race.all_cars.size()):
		var driver: int = driver_for_slot(slot)
		var character: int = CHARACTERS.portrait_for_slot(int(race.profile.data.identity.portrait_id),slot)
		var colour: Color = vehicle_colour(race,slot)
		var number: Label3D = race.all_cars[slot].visual.get_node("DriverNumber")
		number.text = "%02d" % (driver+1)
		number.modulate = Color("f6d65b") if slot==0 else Color("fff3d6")
		for mesh: MeshInstance3D in paint_meshes(race.all_cars[slot].visual):
			mesh.material_override = mesh.material_override.duplicate()
			preload("res://scripts/vehicles/imported_visual.gd").set_paint(mesh,colour)
			if slot==0 and int(race.profile.data.get("character_colour_id",-1))<0: apply_paint(mesh,race)
		race.all_cars[slot].set_meta("vehicle_colour",colour)
		var lamps: Node = race.all_cars[slot].get_node_or_null("VehicleLamps")
		if lamps!=null:
			for lamp: Node in lamps.get_children():
				if lamp is OmniLight3D: lamp.light_color = colour
		if slot>0: race.names[slot] = CHARACTERS.NAMES[character].to_upper()
	race.names[0] = race.profile.data.identity.name
	if race.identities!=null: race.identities.refresh_identity()
	for i: int in range(cards.size()):
		cards[i].button_pressed = i==index
		cards[i].get_node("DriverCaption").text = ("▶ " if i==index else "")+DRIVERS[i].replace(" · ","\n")+"\n"+MOTTO[i]
	race.play_sound("menu")
	preload("res://scripts/race/arcade_presentation.gd").refresh(race)

func paint_meshes(visual: Node3D) -> Array[MeshInstance3D]:
	return preload("res://scripts/vehicles/imported_visual.gd").paint_meshes(visual)

func vehicle_colour(race: Node3D, slot: int) -> Color:
	var character: int = CHARACTERS.portrait_for_slot(int(race.profile.data.identity.portrait_id),slot)
	if slot>0: return CHARACTERS.COLOURS[character]
	var explicit_colour: int = int(race.profile.data.get("character_colour_id",-1))
	if explicit_colour>=0: return CHARACTERS.COLOURS[CHARACTERS.id(explicit_colour)]
	if race.profile.data.gold_livery: return Color("e7ba52")
	var progression: Script = preload("res://scripts/vehicles/vehicle_progression.gd")
	var paint_index: int = progression.PAINTS.find(race.profile.vehicle().paint)
	return progression.COLORS[paint_index] if paint_index>0 else CHARACTERS.COLOURS[character]

func driver_for_slot(slot: int) -> int:
	return selected if slot==0 else (0 if slot==selected else slot)

func apply_paint(mesh: MeshInstance3D, race: Node3D) -> void:
	if race.profile.data.gold_livery: return
	var progression: Script = preload("res://scripts/vehicles/vehicle_progression.gd")
	var index: int = progression.PAINTS.find(race.profile.vehicle().paint)
	if index>0:
		preload("res://scripts/vehicles/imported_visual.gd").set_paint(mesh,progression.COLORS[index],0.9 if index==3 else 0.15,0.2 if index==3 else 0.6)

func build_course_preview(race: Node3D, world: Node3D) -> void:
	var floor_mesh: MeshInstance3D = world.get_node("DioramaSurface")
	floor_mesh.material_override = load("res://scripts/tracks/bedroom_art.gd").carpet_material() if race.track.definition.id=="carpet_cruise" else preload("res://scripts/tracks/track_builder.gd").material(Color("168f78"))
	if race.track.definition.id=="game_table": floor_mesh.material_override = preload("res://scripts/tracks/track_builder.gd").material(Color("30201e"))
	floor_mesh.visible = race.track.definition.id!="game_table"
	var bounds: AABB = AABB(race.track.starts[0],Vector3.ZERO)
	for point: Vector3 in race.track.starts: bounds = bounds.expand(point)
	var centre: Vector3 = bounds.get_center()
	var ratio: float = 4.0/maxf(bounds.size.x,bounds.size.z)
	var camera: Camera3D = world.get_node("PreviewCamera")
	camera.configure(race.track,centre,ratio)
	if race.track.definition.imported_surface:
		floor_mesh.hide()
		var imported: Node3D = race.course.entry.environment.instantiate()
		imported.name = "CoursePropsPreview"
		if race.course.entry.presentation == "bedroom":
			var display: Node3D = preload("res://scripts/tracks/bedroom_display.gd").new()
			display.configure(imported)
			imported.add_child(display)
			var lighting: WorldEnvironment = world.get_node_or_null("PreviewEnvironment")
			if lighting != null: display.configure_sky(lighting)
		imported.scale = Vector3.ONE*ratio
		imported.position = -centre*ratio+Vector3.UP*0.12
		world.add_child(imported)
		for body: Node in imported.find_children("*","StaticBody3D",true,false): body.free()
		return
	var route: SurfaceTool = SurfaceTool.new()
	route.begin(Mesh.PRIMITIVE_TRIANGLES)
	var builder: Script = preload("res://scripts/tracks/track_builder.gd")
	for index: int in range(race.track.starts.size()):
		var a: Vector3 = (race.track.starts[index]-centre)*ratio+Vector3.UP*0.11
		var b: Vector3 = (race.track.ends[index]-centre)*ratio+Vector3.UP*0.11
		a.y = race.track.starts[index].y*ratio+0.12
		b.y = race.track.ends[index].y*ratio+0.12
		var normal: Vector3 = Vector3(-(b-a).z,0,(b-a).x).normalized()*0.025
		builder.quad(route,a-normal,b-normal,b+normal,a+normal)
	builder.mesh_node(world,"Course",route,Color("e6dca5"))

	if race.track.definition.id=="game_table":
		var casino: Node3D = load("res://environments/casino/blackjack.tscn").instantiate()
		casino.name = "CoursePropsPreview"
		for child: Node in casino.get_children():
			if child.name not in ["ImportedCasino","CasinoProps","ExposedTimberBridge"]: child.free()
		for title: String in ["pPlane2","pPlane3","pCube3","pCube4","pCube5","pCube6"]:
			casino.get_node("ImportedCasino/"+title).free()
		casino.scale = Vector3.ONE*ratio
		casino.position = -Vector3(centre.x,0,centre.z)*ratio+Vector3.UP*0.12
		world.add_child(casino)
		return
	var art: Script = preload("res://scripts/tracks/blackjack_art.gd")
	var props: Node3D = Node3D.new()
	props.name = "CoursePropsPreview"
	props.scale = Vector3.ONE*0.25
	world.add_child(props)
	if race.track.definition.id in ["cereal_slalom","plate_rim","countertop_table"]:
		var kitchen: Script = load("res://scripts/tracks/kitchen_art.gd")
		kitchen.carton(art.group(props,"Carton",Vector3(-6,0,1.6)))
		if race.track.definition.id=="plate_rim":
			load("res://scripts/tracks/author_plate_rim.gd").plate(art.group(props,"Plate",Vector3(5,0,1.6)))
		elif race.track.definition.id=="countertop_table":
			kitchen.mug(art.group(props,"Mug",Vector3(5,0,1.6)))
			art.box(props,"TransferBoard",Vector3(0,0.5,1.6),Vector3(6,0.2,2),kitchen.WOOD)
		else: kitchen.bowl(art.group(props,"Bowl",Vector3(5,0,1.6)))
	elif race.track.definition.id=="desk_drawer":
		floor_mesh.material_override = load("res://scripts/tracks/kitchen_art.gd").surface_material()
		load("res://scripts/tracks/author_desk.gd").lamp(art.group(props,"DeskLamp",Vector3(-6,0,1.6)))
		load("res://scripts/tracks/bedroom_art.gd").books(art.group(props,"Books",Vector3(5,0,1.6)))
	elif race.track.definition.id=="toybox_trestle":
		floor_mesh.material_override = load("res://scripts/tracks/bedroom_art.gd").carpet_material()
		load("res://scripts/tracks/author_toybox.gd").toybox(art.group(props,"Toybox",Vector3(-6,0,1.6)))
		load("res://scripts/tracks/bedroom_art.gd").blocks(art.group(props,"ToyBlocks",Vector3(5,0,1.6)))
	elif race.track.definition.id=="carpet_cruise":
		var bedroom: Script = load("res://scripts/tracks/bedroom_art.gd")
		bedroom.blocks(art.group(props,"ToyBlocks",Vector3(-6,0,1.6)))
		bedroom.books(art.group(props,"Books",Vector3(5,0,1.6)))
	else:
		art.chips(props,Vector3(-6,0.36,1.6),Color("bf493d"),5)
		art.card(props,Vector3(5.5,0.4,1.6),0.2,0)
		art.card(props,Vector3(4.4,0.46,2.8),-0.15,-1)
	art.batch(props)

func refresh_course_preview(race: Node3D) -> void:
	var world: Node3D = race.menu.get_node("Diorama").get_child(0).get_child(0)
	for title: String in ["Course","CoursePropsPreview"]:
		var node: Node = world.get_node_or_null(title)
		if node!=null: node.free()
	build_course_preview(race,world)



func apply_stats(race: Node3D) -> void:
	var stats: Script = preload("res://scripts/vehicles/player_stats.gd")
	for slot: int in range(race.all_cars.size()):
		var car: CharacterBody3D = race.all_cars[slot]
		race.developer.apply_car(car)
		car.top_speed = car.tuning.top_speed
	if race.trial.race!=null: race.trial.refresh_signature()
