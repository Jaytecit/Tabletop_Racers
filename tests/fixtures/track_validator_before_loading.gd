extends RefCounted

static func validate(definition: Resource, vehicle_width: float = 0.77, vehicle_height: float = 0.6) -> Array[String]:
	var errors: Array[String] = []
	if definition==null or not is_instance_of(definition,preload("res://scripts/tracks/track_definition.gd")):
		errors.append("Unsupported track resource")
		return errors
	if definition.sections.is_empty():
		errors.append("Track needs a non-empty closed route")
		return errors
	if not is_finite(definition.start_station) or definition.gate_count<2:
		errors.append("Invalid start station or checkpoint count")
	var ids: Dictionary = {}
	var anchors: int = 0
	var surfaces: Dictionary = preload("res://scripts/tracks/surface_definition.gd").presets()
	for section: Resource in definition.sections:
		if section==null or not is_instance_of(section,preload("res://scripts/tracks/route_section.gd")):
			errors.append("Missing route section")
			return errors
		if section.id.is_empty() or ids.has(section.id): errors.append("Section IDs must be unique and non-empty")
		ids[section.id] = true
		if not section.start.is_finite() or not section.end.is_finite() or not section.before.is_finite() or not section.after.is_finite(): errors.append("Non-finite section: "+section.id)
		if not is_finite(section.width) or section.width<vehicle_width*2.0+0.3: errors.append("Insufficient vehicle clearance: "+section.id)
		if Vector2(section.start.x-section.end.x,section.start.z-section.end.z).length()<0.01: errors.append("Zero-length section: "+section.id)
		if not surfaces.has(section.surface): errors.append("Unsupported surface: "+section.surface)
		if section.edge not in ["shoulder","raised","guarded","water"]: errors.append("Unsupported edge: "+section.id)
		var samples: PackedFloat32Array = section.height_samples if section.height_samples!=null else PackedFloat32Array()
		for height: float in samples:
			if not is_finite(height): errors.append("Non-finite sampled height: "+section.id)
		if not samples.is_empty() and (samples.size()<2 or absf(samples[0]-section.start.y)>0.10 or absf(samples[-1]-section.end.y)>0.10):
			errors.append("Sampled heights must match section endpoints: "+section.id)
		var centers: PackedVector3Array = section.center_samples if section.center_samples!=null else PackedVector3Array()
		var left_edge: PackedVector3Array = section.left_samples if section.left_samples!=null else PackedVector3Array()
		var right_edge: PackedVector3Array = section.right_samples if section.right_samples!=null else PackedVector3Array()
		if not centers.is_empty() or not left_edge.is_empty() or not right_edge.is_empty():
			if centers.size()!=25 or left_edge.size()!=25 or right_edge.size()!=25:
				errors.append("Measured corridor requires 25 centre and edge samples: "+section.id)
			else:
				for j: int in range(25):
					if not centers[j].is_finite() or not left_edge[j].is_finite() or not right_edge[j].is_finite():
						errors.append("Non-finite measured corridor: "+section.id)
					if section.width_at(float(j)/24.0)<vehicle_width*2.0+0.3:
						errors.append("Measured corridor lacks clearance: "+section.id)
				if centers[0].distance_to(section.start)>0.01 or centers[24].distance_to(section.end)>0.01:
					errors.append("Measured centres must match section endpoints: "+section.id)
		if section.anchor and section.surface!="water": anchors += 1
	for i: int in range(definition.sections.size()):
		var section: Resource = definition.sections[i]
		var next: Resource = definition.sections[(i+1)%definition.sections.size()]
		if section==null or next==null: continue
		if section.next_id!=next.id or Vector2(section.end.x-next.start.x,section.end.z-next.start.z).length()>0.01: errors.append("Disconnected route: "+section.id)
		if absf(section.end.y-next.start.y)>0.10 and not section.jump_exit: errors.append("Height discontinuity needs jump exit: "+section.id)
		if section.has_measured_edges() and next.has_measured_edges():
			if section.left_samples[-1].distance_to(next.left_samples[0])>0.01 or section.right_samples[-1].distance_to(next.right_samples[0])>0.01:
				errors.append("Disconnected measured boundaries: "+section.id)
	if anchors==0: errors.append("No reachable recovery anchors")
	if not errors.is_empty(): return errors
	# Validate the actual sampled curves, rather than chords between control points.
	var spans: Array[Dictionary] = []
	for i: int in range(definition.sections.size()):
		var section: Resource = definition.sections[i]
		for step: int in range(24):
			spans.append({"section":i,"a":section.point(float(step)/24.0),"b":section.point(float(step+1)/24.0)})
	for i: int in range(spans.size()):
		var a: Dictionary = spans[i]
		var left: Resource = definition.sections[a.section]
		var a2: Vector2 = Vector2(a.a.x,a.a.z)
		var b2: Vector2 = Vector2(a.b.x,a.b.z)
		for j: int in range(i+1,spans.size()):
			var b: Dictionary = spans[j]
			var separation: int = abs(a.section-b.section)
			if separation<=1 or separation==definition.sections.size()-1: continue
			var right: Resource = definition.sections[b.section]
			var c2: Vector2 = Vector2(b.a.x,b.a.z)
			var d2: Vector2 = Vector2(b.b.x,b.b.z)
			var cross: Variant = Geometry2D.segment_intersects_segment(a2,b2,c2,d2)
			if cross!=null:
				var ta: float = a2.distance_to(cross)/maxf(a2.distance_to(b2),0.001)
				var tb: float = c2.distance_to(cross)/maxf(c2.distance_to(d2),0.001)
				if left.layer==right.layer or absf(lerpf(a.a.y,a.b.y,ta)-lerpf(b.a.y,b.b.y,tb))<vehicle_height+0.25:
					errors.append("Crossing lacks layer/vertical clearance: "+left.id)
					return errors
			# Also check road corridors around a stacked crossing, not only its centre.
			if left.layer!=right.layer:
				var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(a2,c2,d2)
				if a2.distance_to(nearest)<(left.width+right.width)*0.5:
					var t: float = c2.distance_to(nearest)/maxf(c2.distance_to(d2),0.001)
					if absf(a.a.y-lerpf(b.a.y,b.b.y,t))<vehicle_height+0.25:
						errors.append("Overlapping road corridors lack clearance: "+left.id)
						return errors
	return errors
