extends TileMapLayer

const wfc_size = Vector2i(32, 32)
var wfc: WFC
@onready var tick_timer = $TickTimer
@onready var restart_timer = $RestartTimer
@onready var stats_timer = $StatsTimer

# stats
@onready var collapse_count = 0
@onready var collapse_msec = 0

const direction_to_tile_coords = [
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(0, 0),
	Vector2i(1, 1)
]

func _ready() -> void:
	# tick_timer.timeout.connect(_on_tick_timer_timeout)
	stats_timer.timeout.connect(_on_stats_timer_timeout)
	restart_timer.timeout.connect(_on_restart_timer_timeout)

	wfc = WFC.new()
	wfc.initialize(wfc_size)
	
	#for row in range(wfc.num_rows):
		#for col in range(wfc.num_cols):
			#var direction = wfc.get_tile(row, col)
			#set_cell(Vector2i(col, row), 0, direction_to_tile_coords[direction])


func handle_fail():
	restart_timer.start()
	
	# todo: show this visually!


func _on_tick_timer_timeout():
	tick()
	
	
func tick():
	if wfc.running and restart_timer.is_stopped():
		# get [cell: Vector2i, state: TileDirection]
		var start = Time.get_ticks_msec()
		var result = wfc.collapse_one()
		var end = Time.get_ticks_msec()
		
		if result == null:
			handle_fail()
			return

		collapse_count += 1
		collapse_msec += end - start

		var cell = result[0]
		var state = result[1]
		set_cell(cell, 0, direction_to_tile_coords[state])
		# print(wfc.repr())
		
		if wfc.complete:
			restart_timer.start()
		
		
func _on_stats_timer_timeout():
	if !wfc.running:
		return

	print("tiles collapsed: ", collapse_count)
	print("total collapse processing time: ", collapse_msec / 1000.0)
	print("tiles / second: ", collapse_count * 1000.0 / collapse_msec)
	print()
	
	
func _on_restart_timer_timeout():
	clear()
	wfc.initialize(wfc_size)


func _process(_delta: float) -> void:
	tick()
