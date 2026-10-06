extends RefCounted
const CREDIT: String = """“table top racing - toys r you” by amogusstrikesback2
https://sketchfab.com/amogusstrikesback2
Source: https://sketchfab.com/3d-models/table-top-racing-toys-r-you-deff0be0d0284820ab6d94493b33e4e0
Creative Commons Attribution 4.0 International
https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, materials adjusted, collision and race route added.
No endorsement by the original creator is implied."""
const TABLETOP_CREDITS: String = """Toys R Asleep — “table top racing - toys r asleep”
Source: https://sketchfab.com/3d-models/table-top-racing-toys-r-asleep-5e6fca61cc5e4d85a20675fd141b97b1
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.

Rusty Nuts Workshop — “table top racing - rusty nuts workshop”
Source: https://sketchfab.com/3d-models/table-top-racing-rusty-nuts-workshop-8ac8eef11e404195985dee59dabd5eb7
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.

Moonlight Junk Heap — “table top racing - moonlight junk heap”
Source: https://sketchfab.com/3d-models/table-top-racing-moonlight-junk-heap-70903adf67624d2e90c2dae0d5cee467
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.

Firefly BBQ — “table top racing - firefly bbq”
Source: https://sketchfab.com/3d-models/table-top-racing-firefly-bbq-2fc12d167b8848ce8f1c8a02ee13b6d7
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.

Nighttime Noodles — “table top racing - nighttime noodles”
Source: https://sketchfab.com/3d-models/table-top-racing-nighttime-noodles-1f8a8a8856cd4f2a95ef29cac4c9f9b7
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.

Mount Rainier — “gt racing 2 - mount rainier”
Source: https://sketchfab.com/3d-models/gt-racing-2-mount-rainier-c4efa86f4b7b4cd5b897fd6c67645a32
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, source materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.

Bazaar — “bazaar track”
Source: https://sketchfab.com/3d-models/bazaar-track-ce96ebef18d54982836ff7a86b1a6d85
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision transforms baked, independent road boundaries, timing plane and checkpoint cues added.
No endorsement by the original creator is implied.

Town Square — town square track
Source: https://sketchfab.com/3d-models/town-square-track-410edb9f4ce0433981e91c05e7a225dd
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, baked materials preserved, collision transforms baked, independent road boundaries, measured timing plane and checkpoint cues added.
No endorsement by the original creator is implied.

Topspeed Oval - gt racing 2 - topspeed oval
Source: https://sketchfab.com/3d-models/gt-racing-2-topspeed-oval-b16b90a16110462599bf61e34568e954
By amogusstrikesback2, https://sketchfab.com/amogusstrikesback2
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted for (not) THE REAL THING: scaled, source materials preserved, collision, measured route and checkpoint cues added.
No endorsement by the original creator is implied.
"""
const BEDROOM_CREDIT: String = """Skybox Stylized Room — Van_Twinkle
https://sketchfab.com/Van_Twinkle
Source: https://sketchfab.com/3d-models/skybox-stylized-room-41f386740dbb4de7af2724734f98151f
CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Adapted: extracted embedded panorama, flipped vertically to match sky mapping, added mipmaps and used as a bedroom backdrop.
No endorsement by the original creator is implied."""
static func setup(race: Node3D) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Third-party asset credits"
	dialog.theme = race.menu.theme
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000,340)
	dialog.add_child(scroll)
	var text: RichTextLabel = RichTextLabel.new()
	text.custom_minimum_size.x = 960
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.fit_content = true
	text.selection_enabled = true
	text.text = CREDIT+"\n\n"+TABLETOP_CREDITS+"\n\n"+BEDROOM_CREDIT+"\n\nParticle textures: Kenney Particle Pack (CC0)\nhttps://kenney.nl/assets/particle-pack\nSmoke, spark and light textures; licence retained in assets/effects/kenney/License.txt."
	scroll.add_child(text)
	race.add_child(dialog)
	var button: Button = Button.new()
	button.name = "AssetCredits"
	button.text = "ASSET CREDITS"
	button.position = Vector2(958,20)
	button.size = Vector2(164,32)
	button.add_theme_font_size_override("font_size",12)
	race.menu.add_child(button)
	button.pressed.connect(func() -> void: dialog.popup_centered(Vector2i(1040,420)))
