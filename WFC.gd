class_name WFC

extends Resource

var states: Array
var is_collapsed: Array

var size: Vector2i

var num_rows: int:
	get:
		return size.y

var num_cols: int:
	get:
		return size.x

# Array[Array[float]]
var entropies: Array[Array]

# coordinate pairs of cells left to collapse
var uncollapsed_cells: Array[Vector2i]

# wfc state
var failed: bool
var complete: bool:
	get:
		return uncollapsed_cells.size() == 0
var running: bool:
	get:
		return !complete && !failed

var collapse_cell_hist: Array
var collapse_entropy_hist: Array
var collapse_choice_hist: Array

# in which direction is the other half of the brick in this tile?
enum TileDirection { NORTH, EAST, SOUTH, WEST }

const ALL_DIRECTIONS = {
	TileDirection.NORTH: .25,
	TileDirection.EAST: .25,
	TileDirection.SOUTH: .25,
	TileDirection.WEST: .25
}

const DIRECTION_OFFSET = {
	TileDirection.NORTH: Vector2i(0, -1),
	TileDirection.EAST: Vector2i(1, 0),
	TileDirection.SOUTH: Vector2i(0, 1),
	TileDirection.WEST: Vector2i(-1, 0)
}

func initialize(_size: Vector2i):
	size = _size
	
	# at first, all locations can point all directions
	states = []
	is_collapsed = []
	entropies = []
	for row_index in range(num_rows):
		var states_row = []
		var is_collapsed_row = []
		var entropies_row = []
		for col_index in range(num_cols):
			states_row.append(ALL_DIRECTIONS.duplicate())
			is_collapsed_row.append(false)
			entropies_row.append(0.0)
			
		states.append(states_row)
		is_collapsed.append(is_collapsed_row)
		entropies.append(entropies_row)

	# remove states so that bricks fit within the edges?
	# top/bottom
	for col in range(num_cols):
		states[0][col].erase(TileDirection.NORTH)
		states[num_rows - 1][col].erase(TileDirection.SOUTH)
		
	# right/left
	for row in range(num_rows):
		states[row][0].erase(TileDirection.WEST)
		states[row][num_cols - 1].erase(TileDirection.EAST)

	uncollapsed_cells = []
	for row in range(num_rows):
		for col in range(num_cols):
			uncollapsed_cells.append(Vector2i(col, row))

	failed = false

	collapse_cell_hist = []
	collapse_entropy_hist = []
	collapse_choice_hist = []
	
	# calculate initial entropies
	for row in range(num_rows):
		for col in range(num_cols):
			get_entropy_at(Vector2i(col, row))


func print_entropy() -> void:
	for row in states:
		print(row)


func sum(list: Array):
	return list.reduce(func add(x, y): return x + y, 0.0)


func get_entropy_at(coords: Vector2i):
	# def get_entropy_at(self, row, col):
	#     total_weight = sum(self.states[row][col].values())
	#     return sum(w / total_weight * log(total_weight / w, 2) for w in self.states[row][col].values())
	var row = coords.y
	var col = coords.x
	var total_weight = sum(states[row][col].values())
	var entropy = 0.0
	for weight in self.states[row][col].values():
		entropy += weight / total_weight * log(total_weight / weight) / log(2)
		
	entropies[row][col] = entropy

	return entropy


func entropy_lt(cell1: Vector2i, cell2: Vector2i):
	return entropies[cell1.y][cell1.x] < entropies[cell2.y][cell2.x]
	# return get_entropy_at(cell1) < get_entropy_at(cell2)

	
# return TileDirection OR null if none possible
func choose_state(coords: Vector2i):
	var row = coords.y
	var col = coords.x
	var available_states = states[row][col].keys()
	var weights = states[row][col].values()

	# are there any states left to choose?
	if available_states.size() == 0 or sum(weights) == 0:
		return null

	var point = randf() * sum(weights)
	var index = 0
	var cumulative_sum = weights[0]
	while point > cumulative_sum:
		index += 1
		cumulative_sum += weights[index]

	return available_states[index]
	

func propagate_rules(coords: Vector2i, collapsed_state: TileDirection):
	# wherever this faces, that square has to face back
	var other_cell = coords + DIRECTION_OFFSET[collapsed_state]
	var other_direction = (collapsed_state + 2) % 4 as TileDirection
	if states[other_cell.y][other_cell.x].get(other_direction, 0) <= 0:
		print("removed last possible state while propagating rules")
		fail()
		return false

	states[other_cell.y][other_cell.x] = {other_direction: 1.0}
	get_entropy_at(other_cell)
	
	# also tiles in the other three directions can't face this tile
	for direction_index in range(4):
		var direction = direction_index as TileDirection
		# if this is the direction of the other half of the brick, nevermind
		if direction == collapsed_state:
			continue
		
		var outside_cell = coords + DIRECTION_OFFSET[direction]

		# is this other cell even on the grid?
		if outside_cell.x < 0 or outside_cell.y < 0:
			continue
		
		if outside_cell.y >= num_rows or outside_cell.x >= num_cols:
			continue
		
		# this one cannot point back at the collapsed half-brick
		var back_direction = (direction + 2) % 4 as TileDirection
		states[outside_cell.y][outside_cell.x].erase(back_direction)
		get_entropy_at(outside_cell)
		
		
func pop_random_with_least_entropy(cells: Array[Vector2i]):
	var selected_index = 0
	var least_entropy = entropies[cells[0].y][cells[0].x]
	var count_with_least_entropy = 1
	for index in range(1, cells.size()):
		var cell = cells[index]
		var entropy = entropies[cell.y][cell.x]
		if entropy > least_entropy:
			# at this point we're only looking at spots with less entropy than this one
			continue
		elif entropy == least_entropy:
			# should we switch to randomly selecting this cell?
			count_with_least_entropy += 1
			if randf() < 1.0 / count_with_least_entropy:
				selected_index = index
		else:
			# this is the first cell we've seen with entropy this low
			selected_index = index
			least_entropy = entropy
			count_with_least_entropy = 1
	
	return cells.pop_at(selected_index)


# return [Vector2i(col, row), state] OR null if impossible
func collapse_one():
	# alternatively, assert(running)?
	if !running:
		return null

	# uncollapsed_cells.shuffle()
	# uncollapsed_cells.sort_custom(entropy_lt)
	# var cell = uncollapsed_cells.pop_front()
	var cell = pop_random_with_least_entropy(uncollapsed_cells)
	var row = cell.y
	var col = cell.x
	var entropy = states[row][col].duplicate()
	
	var chosen_state = choose_state(cell)
	# "Collapsing cell ", cell, " with weights ", states[row][col], " to state ", chosen_state)

	# did we fail?
	if chosen_state == null:
		fail()
		return null

	states[row][col] = {chosen_state: 1.0}
	is_collapsed[row][col] = true
	
	# now propagate results to nearby uncollapsed cells
	# wherever this one is facing, that one has to face back at it
	if propagate_rules(cell, chosen_state) == false:
		return null

	if complete:
		print("Complete!")
	
	collapse_cell_hist.append(cell)
	collapse_entropy_hist.append(entropy)
	collapse_choice_hist.append(chosen_state)
	return [cell, chosen_state]


func collapse_all():
	while uncollapsed_cells.size() > 0 && !failed:
		collapse_one()


func repr():
	var result = ""
	for row in range(num_rows):
		var row_string = ""
		for col in range(num_cols):
			if !is_collapsed[row][col]:
				row_string += "?"
				continue

			# is this spot out of states? (so total weight is 0)
			if sum(states[row][col].values()) == 0:
				row_string += "X"
				continue

			var chars = {
				TileDirection.NORTH: "N",
				TileDirection.EAST: "E",
				TileDirection.SOUTH: "S",
				TileDirection.WEST: "W"
			}
			row_string += chars[states[row][col].keys()[0]]

		result += row_string + "\n"
		
	return result


func print_stats():
	print("state: ")
	print(repr())
	print()
	print("entropy:")
	print_entropy()
	print()
	#print("history: ")
	#print_hist()
	#print()
	#print()

func fail() -> void:
	failed = true
	print("failed!")
	# print_stats()
	print(repr())
	
	
func print_hist() -> void:
	# this way results in output overflow
	# for n in range(collapse_cell_hist.size()):
		# print(collapse_cell_hist[n], " ", collapse_entropy_hist[n], " -> ", collapse_choice_hist)
		
	print(collapse_cell_hist)
	print(collapse_entropy_hist)
	print(collapse_choice_hist)


# func get_tile(row: int, col: int):
# 	return states[row][col].keys()[0]
