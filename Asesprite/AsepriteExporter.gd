class_name AsepriteExporter
extends Node

const HEADER_MAGIC_NUMBER := 42464 #0xA5E0
const HEADER_SIZE_IN_BYTES := 128

const FRAME_HEADER_SIZE_IN_BYTES := 16
const FRAME_MAGIC_NUMBER := 61946 #0xF1FA

const CHUNK_HEADER_SIZE := 6
const LAYER_CHUNK_MAGIC_NUMBER := 8196 #0x2004
const CEL_CHUNK_MAGIC_NUMBER := 8197 #0x2005
const COLOR_PALETTE_CHUNK_MAGIC_NUMBER := 8217 #0x2019
const COLOR_PROFILE_CHUNK_MAGIC_NUMBER := 8199 #0x2007S
const TAGS_CHUNK_MAGIC_NUMBER := 0x2018
const OLD_COLOR_PALETTE_CHUNK := 4 #0x0004

func _get_header(
		file_size_in_bytes : int, frames : int, 
		width_in_pixel : int, height_in_pixel
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	
	#DWORD       File size
	buffer.append_array(int_to_dword(file_size_in_bytes + HEADER_SIZE_IN_BYTES))
	
	#WORD        Magic number (0xA5E0)
	buffer.append_array(int_to_word(HEADER_MAGIC_NUMBER))
	
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
	buffer.append_array(int_to_word(FRAME_MAGIC_NUMBER))
	
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
		layer_level : int, layer_name : String
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	#WORD        Flags:1=visible 2=editable 4 =lock movement 8=background 16=linked cels 32=collapsed 64=reference layer
	buffer.append_array(int_to_word(3)) # editable and visible
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
	buffer.append(255)
	#BYTE[3]     For future (set to zero)
	for i in range(0, 3):
		buffer.append(0)
	
	#STRING      Layer name
	buffer.append_array(string_to_asa_string(layer_name))
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), LAYER_CHUNK_MAGIC_NUMBER)
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
	
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), TAGS_CHUNK_MAGIC_NUMBER)
	header.append_array(buffer)
	return header

func _create_cel_chunk(
		layer_index : int,
		image : Image
	) -> PoolByteArray:
	var buffer := PoolByteArray([])
	#WORD        Layer index
	buffer.append_array(int_to_word(layer_index))
	#SHORT       X position
	buffer.append_array(int_to_word(0)) #there should be a int_to_short
	#SHORT       Y position
	buffer.append_array(int_to_word(0))
	#BYTE        Opacity level
	buffer.append(255)
	#WORD        Cel type: 0=RawCel 1=linked cel 2=Compressed Image
	buffer.append_array(int_to_word(2))
	#BYTE[7]     For future (set to zero)
	for i in range(0, 7):
		buffer.append(0)
	
	#Image always Type 0 for now:
	buffer.append_array(image_to_raw_pixel_data(image))  #Raw Cel
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), CEL_CHUNK_MAGIC_NUMBER)
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
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), COLOR_PROFILE_CHUNK_MAGIC_NUMBER)
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
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), COLOR_PALETTE_CHUNK_MAGIC_NUMBER)
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
	
	var header : PoolByteArray = _create_chunk_header(buffer.size(), OLD_COLOR_PALETTE_CHUNK)
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
func image_to_raw_pixel_data(image : Image) -> PoolByteArray:
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
	var number_in_bytes := decimal_to_binary(number, 2)
	
	word.append(binary_to_decimal(number_in_bytes.substr(8, -1)))
	word.append(binary_to_decimal(number_in_bytes.substr(0, 8)))
	
	return word

#returns a poolVectorArray of 4 bytes with little-endian from a int
func int_to_dword(number :int = 0) -> PoolByteArray:
	var dword := PoolByteArray([])
	var number_in_bytes := decimal_to_binary(number, 4)
	
	dword.append(binary_to_decimal(number_in_bytes.substr(24, 8)))
	dword.append(binary_to_decimal(number_in_bytes.substr(16, 8)))
	dword.append(binary_to_decimal(number_in_bytes.substr(8, 8)))
	dword.append(binary_to_decimal(number_in_bytes.substr(0, 8)))
	
	return dword

#returns a string with with 0s and 1s representig a binary number with no signed bit
func decimal_to_binary(number : int, byte_size : int = 1) -> String:
	var binary_number := ""
	var bit_count : int = byte_size * 8 -1
	
	while(bit_count >= 0):
		var current_bit = number >> bit_count 
		if current_bit & 1:
			binary_number += "1"
		else:
			binary_number += "0"
		bit_count -= 1
	
	return binary_number

#takes a binary number(in string) and return a decimal number
func binary_to_decimal(binary_number : String) -> int:
	var decimal_number : int = 0
	var exponet = 0
	var binary_number_int := int(binary_number)
	
	while(binary_number_int != 0):
		var current_bit : int = binary_number_int % 10
		binary_number_int /= 10
		decimal_number += (current_bit * pow(2, exponet))
		exponet += 1
	
	return decimal_number
