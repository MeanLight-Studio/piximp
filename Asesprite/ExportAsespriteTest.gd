extends Node2D

export var file_name : String = "test1"
export var layer_name : String = "layer 1"
export var texture : Texture

var ase_ex := AsepriteExporter.new()
var file : File

func _ready() -> void:
	_create_file_test()
	print("done")

func _create_file_test() -> void:
	var image : Image = texture.get_data()
	var file = File.new()
	var buffer := PoolByteArray([])
	
	buffer.append_array(ase_ex._create_color_profile_chunk())
	buffer.append_array(ase_ex._create_color_palette())
	buffer.append_array(ase_ex._create_old_color_palette())
	buffer.append_array(ase_ex._create_layer_chunk(0, layer_name))
	buffer.append_array(ase_ex._creat_tag_chunk([["tag", 0, 0]]))
	buffer.append_array(ase_ex._create_cel_chunk(0, image))
	
	var frame1 := ase_ex._create_frame(buffer.size(), 100, 5)
	
	frame1.append_array(buffer)
	
	var header := ase_ex._get_header(frame1.size(), 1, image.get_height(), image.get_width())
	
	file.open("res://FileTest/" + file_name + ".aseprite", File.WRITE)
	file.store_buffer(header)
	file.store_buffer(frame1)
	file.close()
