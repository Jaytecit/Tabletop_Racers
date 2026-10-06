extends Node2D
var half_width: float = 84.0
var lap_target: int = 3
var raised: bool = true
var road_color: Color = Color("#606963")
var track_title: String = "Room Run"
var track_id: String = "room-run"
var points: PackedVector2Array = PackedVector2Array()
var lengths: PackedFloat32Array = PackedFloat32Array()
var total_length: float = 0.0
var corners: PackedVector2Array = PackedVector2Array([Vector2(1050,500),Vector2(1700,500),Vector2(2180,570),Vector2(2620,1000),Vector2(2650,1610),Vector2(2290,1970),Vector2(1710,1970),Vector2(1390,1630),Vector2(970,1540),Vector2(620,1720),Vector2(350,1330),Vector2(350,840),Vector2(620,500)])

func _ready() -> void:
	build()
	queue_redraw()

func apply_definition(data: Dictionary) -> void:
	corners = data.corners
	half_width = data.half_width
	lap_target = data.laps
	raised = data.raised
	road_color = data.road_color
	track_title = data.title
	track_id = data.id
	build()
	queue_redraw()

func build() -> void:
	points.clear()
	lengths.clear()
	total_length = 0.0
	var n: int = corners.size()
	for i in range(n):
		var a: Vector2 = corners[(i+n-1)%n]
		var b: Vector2 = corners[i]
		var c: Vector2 = corners[(i+1)%n]
		var d: Vector2 = corners[(i+2)%n]
		for step in range(20):
			var t: float = step / 20.0
			var p: Vector2 = 0.5 * ((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t)
			if points.size()>0:
				total_length += p.distance_to(points[points.size()-1])
			points.append(p)
			lengths.append(total_length)
	total_length += points[points.size()-1].distance_to(points[0])
	points.append(points[0])
	lengths.append(total_length)

func segment(station: float) -> int:
	var s: float = fposmod(station,total_length)
	var low: int = 0
	var high: int = lengths.size()-2
	while low < high:
		var mid: int = int((low+high+1)/2.0)
		if lengths[mid] <= s: low = mid
		else: high = mid-1
	return low

func sample(station: float) -> Vector2:
	var s: float = fposmod(station,total_length)
	var i: int = segment(s)
	var t: float = (s-lengths[i])/maxf(lengths[i+1]-lengths[i],0.001)
	return points[i].lerp(points[i+1],t)

func direction(station: float) -> Vector2:
	return (sample(station+8.0)-sample(station-8.0)).normalized()

func elevation(station: float) -> float:
	var p: Vector2 = sample(station)
	if raised and p.y < 650.0:
		return minf(clampf((p.x-490.0)/130.0,0.0,1.0),clampf((2170.0-p.x)/220.0,0.0,1.0))
	return 0.0

func project(pos: Vector2) -> Vector3:
	var closest: float = INF
	var station: float = 0.0
	for i in range(points.size()-1):
		var edge: Vector2 = points[i+1]-points[i]
		var t: float = clampf((pos-points[i]).dot(edge)/maxf(edge.length_squared(),0.001),0.0,1.0)
		var d: float = pos.distance_squared_to(points[i]+edge*t)
		if d < closest:
			closest = d
			station = lerpf(lengths[i],lengths[i+1],t)
	return Vector3(station,sqrt(closest),elevation(station))

func _draw() -> void:
	if points.size()<2: return
	draw_rect(Rect2(0,0,3100,2300),Color("#bea080"))
	for y in range(0,2300,90):
		draw_line(Vector2(0,y),Vector2(3100,y),Color("#a78b6f"),2)
		for x in range(0,3100,350):
			draw_line(Vector2(x+(y%180),y),Vector2(x+(y%180),y+90),Color("#af9476"),1)
	draw_rect(Rect2(45,45,3010,2210),Color("#795d47"),false,16)
	# Rug, couch, shelving and dining table at toy scale.
	draw_rect(Rect2(1060,910,1250,530),Color("#917573"))
	draw_rect(Rect2(1080,930,1210,490),Color("#b7a09a"),false,12)
	for x in range(1110,2270,70):
		draw_line(Vector2(x,948),Vector2(x,1402),Color("#a38c87"),2)
	draw_rect(Rect2(1820,75,1020,270),Color("#5b655b"))
	draw_rect(Rect2(1850,105,960,175),Color("#7a897a"))
	for x in range(1850,2780,240):
		draw_rect(Rect2(x+8,112,222,158),Color("#8d9b87"))
	draw_rect(Rect2(75,1780,340,380),Color("#7d5038"))
	for y in range(1810,2120,80):
		draw_rect(Rect2(95,y,300,55),Color("#bd7349"))
		for x in range(108,378,28):
			draw_rect(Rect2(x,y+4,20,47),Color("#657e84") if x%3==0 else Color("#e5c88b"))
	draw_rect(Rect2(595,208,1365,565),Color(0.19,0.14,0.1,0.25))
	draw_rect(Rect2(575,170,1365,565),Color("#a5693d"))
	draw_rect(Rect2(585,180,1345,545),Color("#c38a51"))
	for y in range(198,730,48):
		draw_line(Vector2(590,y),Vector2(1920,y),Color("#b47b45"),2)
	# Breakfast remnants and a tiny pit garage.
	draw_circle(Vector2(1480,320),90,Color("#f5ebd1"))
	draw_arc(Vector2(1480,320),78,0,TAU,64,Color("#9aacaa"),4,true)
	draw_circle(Vector2(1480,320),55,Color("#e2d5b7"))
	draw_rect(Rect2(1080,205,130,150),Color("#e58a4c"))
	draw_rect(Rect2(1090,216,110,28),Color("#f8d27d"))
	draw_circle(Vector2(1145,289),34,Color("#f3ce80"))
	draw_rect(Rect2(1270,225,80,130),Color("#f0eee0"))
	draw_rect(Rect2(1270,265,80,60),Color("#6ba6b2"))
	draw_circle(Vector2(1645,312),37,Color("#dddcca"))
	draw_circle(Vector2(1645,312),27,Color("#584331"))
	draw_arc(Vector2(1645,312),43,-0.8,0.8,16,Color("#dddcca"),9,true)
	# Room toys outside the ribbon.
	for i in range(12):
		var p: Vector2 = Vector2(650+(i*157)%450,1000+(i*79)%280)
		var tint: Color = Color("#d26d50") if i%3==0 else (Color("#729cab") if i%3==1 else Color("#d6b867"))
		draw_rect(Rect2(p,Vector2(55,44)),tint)
		for j in range(3): draw_circle(p+Vector2(10+j*16,10),4,tint.lightened(0.25))
	draw_circle(Vector2(2380,1520),95,Color("#d0b075"))
	draw_circle(Vector2(2380,1520),73,Color("#e0c38b"))
	draw_line(Vector2(2880,430),Vector2(2880,1840),Color("#534f45"),14)
	draw_arc(Vector2(2820,1840),60,0,PI,30,Color("#534f45"),14,true)
	# Track ribbon: shadow, curb, roadway, chalk edge and lane marks.
	var shadow: PackedVector2Array = points.duplicate()
	for i in range(shadow.size()): shadow[i] += Vector2(10,22+elevation(lengths[i])*26)
	draw_polyline(shadow,Color(0.12,0.10,0.08,0.32),half_width*2.0+21.0,true)
	draw_polyline(points,Color("#efe6ce"),half_width*2.0+16.0,true)
	for i in range(0,points.size()-1,2):
		draw_line(points[i],points[min(i+2,points.size()-1)],Color("#c65c49") if i%4==0 else Color("#f1e7cf"),half_width*2.0+14.0,true)
	draw_polyline(points,Color("#48504d"),half_width*2.0,true)
	draw_polyline(points,road_color,half_width*2.0-14.0,true)
	for s in range(0,int(total_length),56):
		var p: Vector2 = sample(float(s))
		var f: Vector2 = direction(float(s))
		draw_line(p-f*8,p+f*8,Color("#dad3b7"),2,true)
		if s%224==0:
			draw_line(p+f*10,p-f*3+f.orthogonal()*7,Color("#8f9a87"),3,true)
			draw_line(p+f*10,p-f*3-f.orthogonal()*7,Color("#8f9a87"),3,true)
	# Start line and pit boxes.
	var start_forward: Vector2 = direction(0.0)
	var side: Vector2 = start_forward.orthogonal()
	var cells: int = int(half_width*2.0/12.0)
	for row in range(cells):
		for col in range(2):
			var p: Vector2 = sample(0.0)+side*(-half_width+6.0+row*12)+start_forward*(col*10)
			draw_set_transform(p,start_forward.angle(),Vector2.ONE)
			draw_rect(Rect2(-5,-6,10,12),Color("#f8efd8") if (row+col)%2==0 else Color("#242b29"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	draw_rect(Rect2(780,630,410,70),Color("#426671"))
	for x in range(795,1170,75): draw_rect(Rect2(x,640,60,50),Color("#b6c9bd"),false,2)
