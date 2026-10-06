@tool
extends EditorScript
# Rebuild the sky texture from the owner's supplied GLB; no downloaded assets.
func _run() -> void:
	var root: Node3D = load("res://environments/skybox_stylized_room.glb").instantiate()
	var meshes: Array[Node] = root.find_children("*","MeshInstance3D",true,false)
	assert(meshes.size()==1,"Bedroom source changed: review its UV mapping before rebuilding")
	var material: StandardMaterial3D = meshes[0].get_active_material(0)
	var image: Image = material.albedo_texture.get_image()
	if image.is_compressed(): assert(image.decompress()==OK,"Bedroom source texture decompression failed")
	# Source mesh maps V=1 to its north pole; PanoramaSkyMaterial expects V=0.
	image.flip_y()
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var error: Error = ResourceSaver.save(texture,"res://environments/bedroom/stylized_room_panorama.res")
	assert(error==OK,"Bedroom panorama save failed")
	print("Bedroom panorama saved: ",image.get_size())
	root.free()
