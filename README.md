# piximp
Pixel Exporter &amp; Importer for Godot


## Example
```gdscript
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
```
