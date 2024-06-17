extends TileMap

### Signals
signal sig_world_spawn_laser_grenade_launcher(pos : Vector2, dir : Vector2)

var used_cells : Array[Vector2i]
var default_layer : int = 0

const atlas_id_default_tiles : int = 1
const atlas_id_lasergrenadelauncher_tiles : int = 3

func _ready() -> void:
	## Subscribe to signals
	var _World : Node2D = get_tree().get_first_node_in_group("World")
	_World.connect("sig_world_readied", _on_received_world_readied)

func prepare_tilemap() -> void:
	"""
	Prepare the TileMap. Since tiles have no functionality, replace some specific tiles with Nodes,
	for example: LaserGrenadeLauncher, which looks like a tile with the additional functionality of
	launching LaserGrenades
	"""
	used_cells = get_used_cells(default_layer)
	for coord in used_cells:
		var _source_id = get_cell_source_id(default_layer, coord)
		var _atlas_coords = get_cell_atlas_coords(default_layer, coord)
		var _global_coords = to_global(map_to_local(coord))
		
		# If the cell is NOT a default tileset cell, then it should be replaced with a Node
		if _source_id != atlas_id_default_tiles:
			set_cell(default_layer, coord, -1) # Erase cell
			replace_cell_with_node(_source_id, _atlas_coords, _global_coords) # Replace cell with Node

func replace_cell_with_node(source_id : int, source_coords : Vector2i, global_pos : Vector2) -> void:
	"""
	Given a source id (atlas id), replace the TileSet cell with a Node
	
	source_id : int -- id of the source of the tile to be replaced
	source_coords : Vector2i -- (atlas) coordinates of the tile in regards to its source
	pos : Vector2 -- global_position to place the node
	"""
	match source_id:
		atlas_id_lasergrenadelauncher_tiles:
			match source_coords:
				Vector2i(2, 1):
					sig_world_spawn_laser_grenade_launcher.emit(global_pos, Vector2.UP)
				Vector2i(3, 2):
					sig_world_spawn_laser_grenade_launcher.emit(global_pos, Vector2.RIGHT)
				Vector2i(2, 3):
					sig_world_spawn_laser_grenade_launcher.emit(global_pos, Vector2.DOWN)
				Vector2i(1, 2):
					sig_world_spawn_laser_grenade_launcher.emit(global_pos, Vector2.LEFT)

######################
## Received Signals
######################
func _on_received_world_readied() -> void:
	"""
	Once the World is ready (subscribed to all signals), then signal World to replace tiles
	"""
	prepare_tilemap()
