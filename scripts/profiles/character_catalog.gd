extends RefCounted
# Portrait identity is independent of saved player names and vehicle skill builds.
const NAMES: Array[String] = ["Roxy Rocket","Finn Flywheel","Kit Spark","Bea Bolt","Nova Flux","Ravi Ember","Skye Frost","Milo Copper"]
const COLOURS: Array[Color] = [Color("ef6546"),Color("4ba5c9"),Color("f1c44f"),Color("86bb5b"),Color("a784eb"),Color("ff9833"),Color("58d9ef"),Color("c85c94")]
const COLOUR_NAMES: Array[String] = ["Rocket Red","Comet Blue","Spark Gold","Bolt Green","Flux Violet","Ember Orange","Frost Cyan","Copper Magenta"]
const BIOS: Array[String] = [
	"Turns spare toy parts into fearless racers. Every tabletop straight is another chance to chase a personal best.",
	"A miniature-engine tinkerer with a steady hand. Smooth lines and patient garage work are Finn's favourites.",
	"Dreams up cardboard-city circuits and unexpected shortcuts. Kit brings bright ideas and big cheers to every grid.",
	"Founded the tabletop racing club with a box of old toys. Bea loves a clean race and getting everyone involved.",
	"Sketches futuristic racers between laps. Nova mixes bold designs with a cool head when the corners get crowded.",
	"Restores tiny motors and shares every workshop trick. Ravi brings warm humour and a determined grin to the grid.",
	"Finds rhythm in winding circuits and winter colours. Skye stays composed, then celebrates every hard-earned finish.",
	"A lifelong toy collector with plenty of garage stories. Milo still gets a twinkle in his eye at every starting flag."
]

static func id(value: int) -> int:
	return clampi(value,0,NAMES.size()-1)

static func portrait_for_slot(selected: int, slot: int) -> int:
	return posmod(id(selected)+slot,NAMES.size())
