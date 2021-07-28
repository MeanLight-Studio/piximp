extends Node2D

export var file_name : String = "test1"
export var frames_amount := 7
export var texture : Texture

var ase_ex := AsepriteExporter.new()
var file : File

func _ready() -> void:
	_create_file_test()
	print("done")

func _create_file_test() -> void:
	var image : Image = texture.get_data()
	
	ase_ex.set_canvas_size_px(texture.get_width(), texture.get_height())
	
	ase_ex.define_layers(get_layers())
	ase_ex.define_tags(get_tags())
	
	
	for f in range(0, frames_amount):
		for l in range(0, get_layers().size()):
			ase_ex.add_cel(image)
		ase_ex.next_frame()
	
	ase_ex.create_file("res://FileTest/new_test.aseprite")

func get_tags() -> Array:
	var tags = [
		["test1", 0, 3],
		["test2", 4, 5]
	]
	return tags

func get_layers() -> Array:
	var layers = ["layer1", "layer2", "layer3"]
	return layers
