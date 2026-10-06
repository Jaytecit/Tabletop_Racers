extends RefCounted
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const PAINTS: Array[String] = ["stock","mint","violet","chrome"]
const NAMES: Array[String] = ["STOCK","MINT POP","VIOLET FLASH","CHROME"]
const COSTS: Array[int] = [0,100,200,300]
const COLORS: Array[Color] = [Color.WHITE,Color("36e6ae"),Color("b36eff"),Color("d6e5ef")]

static func fresh() -> Dictionary:
	return {"stats":STATS.starting(),"points":0,"bling":0,"owned":["stock"],"paint":"stock"}

static func rewards(mode: String, laps: int, rows: Array) -> Dictionary:
	for row: Dictionary in rows:
		if row.player!=1 or not row.finished: continue
		var bonus: int = 0
		if mode!="trial" and rows.size()>1:
			bonus = 2 if row.rank==1 else (1 if row.rank==2 else 0)
		# Three laps is the standard race; longer races pay per three-lap block.
		var points: int = (1+bonus)*maxi(1,ceili(float(laps)/3.0))
		return {"points":points,"bling":points*10}
	return {"points":0,"bling":0}

static func purchase(build: Dictionary, index: int, wallet: Dictionary = {}) -> bool:
	if index<0 or index>=PAINTS.size(): return false
	var balance: Dictionary = build if wallet.is_empty() else wallet
	var paint: String = PAINTS[index]
	if paint not in build.owned:
		if balance.bling<COSTS[index]: return false
		balance.bling -= COSTS[index]
		build.owned.append(paint)
	build.paint = paint
	return true
