class_name AsepriteExporter
extends Node

const HEADER_SIZE_IN_BYTES := 128
const FRAME_HEADER_SIZE_IN_BYTES := 16
const CHUNK_HEADER_SIZE := 6

var frame_buffer := PoolByteArray([])
var layers_buffer := PoolByteArray([])
var tags_buffer := PoolByteArray([])
var final_file_buffer := PoolByteArray([])

var current_layer := 0
var frame_count := 0
var chunk_count := 0

var canvas_width = 0
var canvas_height = 0

var frame_duration_ms := 100.0

enum  Flags{
	FLAGS_VISIBLE = 1
	FLAG_EDITABLE = 2
	FLAG_LOCK_MOVEMENT = 4
	FLAG_BACKGROUND = 8
	FLAG_LINKED_CELS = 16
	FLAG_COLLAPSED = 32
	FLAG_REFERENCE_LAYER = 64
}

func set_canvas_size_px(width, height) -> void:
	canvas_width = width
	canvas_height = height

func define_tags(tags : Array) -> void:
	tags_buffer = _create_tag_chunk(tags)
	chunk_count += 1

func define_layers(layers : Array) -> void:
	for layer in layers:
		chunk_count += 1
		layers_buffer.append_array(_create_layer_chunk(0, layer))

func add_layer(layer_name : String, flags : int = Flags.FLAGS_VISIBLE | Flags.FLAG_EDITABLE, opacity : int = 255):
	chunk_count += 1
	layers_buffer.append_array(_create_layer_chunk(0, layer_name, flags, opacity))

func add_cel(image : Image, img_position := Vector2.ZERO, especific_index := -1, crop_used_rect := false) -> void:
	var layer_index : int
	
	if especific_index < 0:
		layer_index = current_layer
	else:
		layer_index = especific_index
	
	frame_buffer.append_array(_create_cel_chunk(layer_index, image, img_position,crop_used_rect))
	chunk_count += 1
	current_layer += 1

func next_frame() -> void:
	var buffer := PoolByteArray([])
	
	#first frame only things
	if frame_count == 0:
		buffer.append_array(_create_color_profile_chunk())
		buffer.append_array(_create_color_palette())
		buffer.append_array(_create_old_color_palette())
		chunk_count += 3
		
		buffer.append_array(layers_buffer)
		buffer.append_array(tags_buffer)
		layers_buffer = []
		tags_buffer = []
	
	buffer.append_array(frame_buffer)
	
	var header := _create_frame(buffer.size(), frame_duration_ms, chunk_count)
	frame_count += 1
	
	final_file_buffer.append_array(header)
	final_file_buffer.append_array(buffer)
	
	frame_buffer = []
	current_layer = 0
	chunk_count = 0

func create_file(path : String) -> void:
	var file := File.new()
	
	file.open(path, File.WRITE)
	
	file.store_buffer(_get_header(final_file_buffer.size(), frame_count, canvas_width, canvas_height))
	file.store_buffer(final_file_buffer)
	
	file.close()

func _get_header(
		file_size_in_bytes : int, frames : int, 
		width_in_pixel : int, height_in_pixel
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	#DWORD       File size
	buffer.append_array(int_to_dword(file_size_in_bytes + 0xA5E0))
	
	#WORD        Magic number (0xA5E0)
	buffer.append_array(int_to_word(0xA5E0))
	
	#WORD        Frames
	buffer.append_array(int_to_word(frames))
	
	#WORD        Width in pixels
	buffer.append_array(int_to_word(width_in_pixel))
	
	#WORD        Height in pixels
	buffer.append_array(int_to_word(height_in_pixel))
	
	#WORD        Color depth (bits per pixel)
	buffer.append_array(int_to_word(32)) #Only rgb for now
	
	#DWORD       Flags: 1 = Layer opacity has valid value
	buffer.append_array(int_to_dword(1))
	
	#WORD        Speed (milliseconds between frame, like in FLC files)
	buffer.append_array(int_to_word(100)) #Not change, each frame has to specify its owns speed
	
	#DWORD       Set be 0
	buffer.append_array(int_to_dword(0))
	
	#DWORD       Set be 0
	buffer.append_array(int_to_dword(0))
	
	#BYTE        Palette entry (index) which represent transparent color
	#BYTE[3]     Ignore these bytes
	buffer.append_array(int_to_dword(0)) #has there is no index color pallet all 4 bits are in 0 there for it is set all together
	
	#WORD        Number of colors (0 means 256 for old sprites)
	buffer.append_array(int_to_word(2))
	
	#BYTE        Pixel width (pixel ratio is "pixel width/pixel height")
	buffer.append(1) #pixels will always have a 1:1 aspect ratio.
	#BYTE        Pixel height
	buffer.append(1) 
	
	#SHORT       X position of the grid
	buffer.append_array(int_to_word(0)) #There should be a int_to_short() function
	#SHORT       Y position of the grid
	buffer.append_array(int_to_word(0))
	
	#WORD        Grid width (zero if there is no grid, grid size is 16x16 on Aseprite by default)
	buffer.append_array(int_to_word(16))
	#WORD        Grid height (zero if there is no grid)
	buffer.append_array(int_to_word(16))
	
	#BYTE[84]    For future (set to zero)
	for i in range(0, 84):
		buffer.append(0)
	
	return buffer

func _create_frame(
		size_in_bytes : int, frame_duration_in_milliseconds : int,
		number_of_chuks : int
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	#DWORD       Size of this frame
	buffer.append_array(int_to_dword(size_in_bytes + FRAME_HEADER_SIZE_IN_BYTES))
	
	#WORD        Magic number (always 0xF1FA)
	buffer.append_array(int_to_word(0xF1FA))
	
	#WORD        Old field which specifies the number of "chunks"
	buffer.append_array(int_to_word(number_of_chuks))        # TODO if number of chunks biger that 65535 store 65535 0xFFFF
	
	#WORD        Frame duration (in milliseconds)
	buffer.append_array(int_to_word(frame_duration_in_milliseconds))
	
	#BYTE[2]     For future (set to zero)
	buffer.append_array(int_to_word(0))
	
	#DWORD       New field which specifies the number of "chunks"
	#            in this frame (if this is 0, use the old field)
	buffer.append_array(int_to_dword(number_of_chuks))
	
	return buffer

func _create_chunk_header(
	chunk_size : int, chunk_type : int
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	
#	DWORD       Chunk size
	buffer.append_array(int_to_dword(chunk_size + CHUNK_HEADER_SIZE))
#	WORD        Chunk type
	buffer.append_array(int_to_word(chunk_type))
	
	return buffer

func _create_layer_chunk(
		layer_level : int, layer_name : String, flags : int = 3, opacity : int = 255
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	#WORD        Flags:1=visible 2=editable 4 =lock movement 8=background 16=linked cels 32=collapsed 64=reference layer
	buffer.append_array(int_to_word(flags)) # editable and visible
	#WORD        Layer type:0=Normal 1=Group
	buffer.append_array(int_to_word(0)) #no groups option for now
	
	#WORD        Layer child level
	buffer.append_array(int_to_word(layer_level))
	
	#WORD        Default layer width in pixels (ignored)
	#WORD        Default layer height in pixels (ignored)
	buffer.append_array(int_to_dword(0))
	
	#WORD        Blend mode (always 0 for layer set)
	buffer.append_array(int_to_word(0))
	
	#BYTE        Opacity
	buffer.append(opacity)
	#BYTE[3]     For future (set to zero)
	for i in range(0, 3):
		buffer.append(0)
	
	#STRING      Layer name
	buffer.append_array(string_to_asa_string(layer_name))
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), 0x2004)
	header.append_array(buffer)
	return header


#each tag is an array [TageName:string, form_frame:int, to_frame]
#Then ech tag should be append to an array making a 2d Array
#example of 2 tags [["idle", 0, 3], ["run", 4, 6]]
func _create_tag_chunk(
		tags : Array
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	#WORD        Number of tags
	buffer.append_array(int_to_word(tags.size()))
	
	#BYTE[8]     For future (set to zero)
	for i in range(0, 8):
		buffer.append(0)
	
	# For each tag
	for tag in tags:
		#  WORD      From frame
		buffer.append_array(int_to_word(tag[1]))
		
		#  WORD      To frame
		buffer.append_array(int_to_word(tag[2]))
		
		#  BYTE      Loop animation direction 0=Forward 1=Reverse 2=Ping-Pong
		buffer.append(0)
		
		#  BYTE[8]   For future (set to zero)
		for i in range(0, 8):
			buffer.append(0)
		
		#  BYTE[3]   RGB values of the tag color
		#  BYTE      Extra byte (zero)
		for i in range(0, 4):
			buffer.append(0)
		
		#  STRING    Tag name
		buffer.append_array(string_to_asa_string(tag[0]))
	
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), 0x2018)
	header.append_array(buffer)
	return header

func _create_cel_chunk(
		layer_index : int,
		image : Image,
		img_position : Vector2,
		crop_used_rect : bool
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	
	#WORD        Layer index
	buffer.append_array(int_to_word(layer_index))
	#SHORT       X position
	buffer.append_array(int_to_word(img_position.x)) #there should be a int_to_short
	#SHORT       Y position
	buffer.append_array(int_to_word(img_position.y))
	#BYTE        Opacity level
	buffer.append(255)
	#WORD        Cel type: 0=RawCel 1=linked cel 2=Compressed Image
	buffer.append_array(int_to_word(2))
	#BYTE[7]     For future (set to zero)
	for i in range(0, 7):
		buffer.append(0)
	
	if crop_used_rect:
		var used_rect := image.get_used_rect()
		image = image.get_rect(used_rect)
	
	buffer.append_array(image_to_data(image))
	
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), 0x2005)
	header.append_array(buffer)
	
	return header

func _create_color_profile_chunk() -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	#WORD        Type: 0=No color 1=sRGB 2= ICC profile
	buffer.append_array(int_to_word(1))
	#WORD        Flags 1 - use special fixed gamma
	buffer.append_array(int_to_word(0))
	#FIXED       Fixed gamma (1.0 = linear)
	buffer.append_array(int_to_dword(0))
	#BYTE[8]     Reserved (set to zero
	for i in range(0, 8):
		buffer.append(0)
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), 0x2007)
	header.append_array(buffer)
	return header

#hardcoded color palette with white and black
func _create_color_palette() -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	#DWORD       New palette size (total number of entries)
	buffer.append_array(int_to_dword(2))
	#DWORD       First color index to change
	buffer.append_array(int_to_dword(0))
	#DWORD       Last color index to change
	buffer.append_array(int_to_dword(1))
	#BYTE[8]     For future (set to zero)
	for i in range(0, 8):
		buffer.append(0)
	
	#  WORD      Entry flags:
	buffer.append_array(int_to_word(0))
	#  BYTE(for each) R(0-255) G(0-255) B(0-255) A(0-255)
	buffer.append(255)
	buffer.append(255)
	buffer.append(255)
	buffer.append(255)
	
		#  WORD      Entry flags:
	buffer.append_array(int_to_word(0))
	#  BYTE(for each) R(0-255) G(0-255) B(0-255) A(0-255)
	buffer.append(0)
	buffer.append(0)
	buffer.append(0)
	buffer.append(255)
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), 0x2019)
	header.append_array(buffer)
	return header

#hardcoded color palette with white and black
func _create_old_color_palette() -> PoolByteArray:
	var buffer := PoolByteArray([])
	#WORD        Number of packets
	buffer.append_array(int_to_word(1))
	
	# For each packet
	#  BYTE      Number of palette entries to skip from the last packet (start from 0)
	buffer.append(0)
	#  BYTE      Number of colors in the packet (0 means 256)
	buffer.append(2)
	#  + For each color in the packet BYTE R G B
	buffer.append(255)
	buffer.append(255)
	buffer.append(255)
	buffer.append(0)
	buffer.append(0)
	buffer.append(0)
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), 0x0004)
	header.append_array(buffer)
	return header

func string_to_asa_string(string : String) -> PoolByteArray:
	var asa_string := PoolByteArray([])
	var string_in_bytes := string.to_utf8()
	
	asa_string.append_array(int_to_word(string_in_bytes.size()))
	asa_string.append_array(string_in_bytes)
	
	return asa_string

#takes a instace of Image_clase
#makes a header with width and height
#then it appends every pixel in rgba 32
func image_to_data(image : Image) -> PoolByteArray:
	var buffer := PoolByteArray([])
	image.lock()
	
	#  WORD      Width in pixels
	buffer.append_array(int_to_word(image.get_width()))
	#  WORD      Height in pixels
	buffer.append_array(int_to_word(image.get_height()))
	
	#  BYTE[]    "Raw Cel" data compressed with ZLIB method
	var image_buffer := image.get_data().compress(File.COMPRESSION_DEFLATE)
	
	buffer.append_array(image_buffer)
	
	return buffer

#returns a poolVectorArray of 2 bytes with little-endian from a int
func int_to_word(number :int = 0) -> PoolByteArray:
	var word := PoolByteArray([])
	word.append(number)
	word.append(number >> 8)
	return word

#returns a poolVectorArray of 4 bytes with little-endian from a int
func int_to_dword(number :int = 0) -> PoolByteArray:
	var dword := PoolByteArray([])
	
	dword.append(number)
	dword.append(number >> 8)
	dword.append(number >> 16)
	dword.append(number >> 24)
	
	return dword
