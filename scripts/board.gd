extends RefCounted
## Pure bubble-shooter board logic — no rendering, no nodes, so it's unit-testable
## headless. Cells are color indices 0..5 or -1 (empty).
##
## Rows form an offset/hex grid. A row's "odd-ness" is (row + parity_offset) % 2 rather
## than row % 2, so a new row can be PREPENDED (descending ceiling) without restructuring
## the existing rows: prepending flips parity_offset, which keeps every existing row's
## effective parity (and therefore its length + horizontal offset) exactly the same.

const COLS := 11
const ROWS := 14          # initial row count; the grid grows past this as rows descend
const NUM_COLORS := 6

var grid: Array = []
var parity_offset := 0
var score := 0
var over := false
var won := false

func _odd(row: int) -> bool:
	return (row + parity_offset) % 2 == 1

func row_len(row: int) -> int:
	return COLS - 1 if _odd(row) else COLS

func blank() -> void:
	grid = []
	parity_offset = 0
	for row in ROWS:
		var arr: Array = []
		for col in row_len(row):
			arr.append(-1)
		grid.append(arr)
	score = 0
	over = false
	won = false

func new_game(start_colors := 5, start_rows := 5) -> void:
	blank()
	for row in start_rows:
		for col in grid[row].size():
			grid[row][col] = randi() % start_colors

func in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < grid.size() and col >= 0 and col < grid[row].size()

func neighbors(row: int, col: int) -> Array:
	var list: Array
	if _odd(row):
		list = [Vector2i(row, col - 1), Vector2i(row, col + 1),
			Vector2i(row - 1, col), Vector2i(row - 1, col + 1),
			Vector2i(row + 1, col), Vector2i(row + 1, col + 1)]
	else:
		list = [Vector2i(row, col - 1), Vector2i(row, col + 1),
			Vector2i(row - 1, col - 1), Vector2i(row - 1, col),
			Vector2i(row + 1, col - 1), Vector2i(row + 1, col)]
	var out: Array = []
	for c in list:
		if in_bounds(c.x, c.y):
			out.append(c)
	return out

func has_filled_neighbor(row: int, col: int) -> bool:
	for c in neighbors(row, col):
		if grid[c.x][c.y] >= 0:
			return true
	return false

func colors_in_grid() -> Array:
	var s := {}
	for row in grid.size():
		for col in grid[row].size():
			var v: int = grid[row][col]
			if v >= 0:
				s[v] = true
	return s.keys()

## Prepend a fresh row of bubbles at the top (the descending ceiling). Existing rows
## shift down one; flipping parity_offset keeps their length + offset unchanged.
func add_top_row(num_colors := 5) -> void:
	parity_offset = (parity_offset + 1) % 2
	var new_row: Array = []
	for i in row_len(0):
		new_row.append(randi() % num_colors)
	grid.insert(0, new_row)

## Grow the grid DOWNWARD with blank rows so `row` exists. Landing a bubble just
## below the last allocated row must extend the grid, not deflect sideways.
func ensure_row(row: int) -> void:
	while grid.size() <= row:
		var arr: Array = []
		for col in row_len(grid.size()):
			arr.append(-1)
		grid.append(arr)

## Deepest row index still holding a bubble (for the loss check). -1 if the board is empty.
func lowest_filled_row() -> int:
	for row in range(grid.size() - 1, -1, -1):
		for col in grid[row].size():
			if grid[row][col] >= 0:
				return row
	return -1

## Place color `ci` at (row,col), resolve matches + drops, update score.
func place(row: int, col: int, ci: int) -> Dictionary:
	grid[row][col] = ci
	var cluster := _flood_same(row, col, ci)
	var result := {"popped": [], "dropped": []}
	if cluster.size() >= 3:
		for cell in cluster:
			grid[cell.x][cell.y] = -1
			result.popped.append({"cell": cell, "ci": ci})
		score += cluster.size() * 10
		var dropped := _drop_floating()
		result.dropped = dropped
		score += dropped.size() * 20
	if colors_in_grid().is_empty():
		won = true
		over = true
	return result

func _flood_same(row: int, col: int, ci: int) -> Array:
	var seen := {}
	var stack := [Vector2i(row, col)]
	var cluster: Array = []
	seen[Vector2i(row, col)] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		cluster.append(cur)
		for n in neighbors(cur.x, cur.y):
			if not seen.has(n) and grid[n.x][n.y] == ci:
				seen[n] = true
				stack.append(n)
	return cluster

func _drop_floating() -> Array:
	var anchored := {}
	var stack: Array = []
	for col in grid[0].size():
		if grid[0][col] >= 0:
			var v := Vector2i(0, col)
			anchored[v] = true
			stack.append(v)
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for n in neighbors(cur.x, cur.y):
			if not anchored.has(n) and grid[n.x][n.y] >= 0:
				anchored[n] = true
				stack.append(n)
	var dropped: Array = []
	for row in grid.size():
		for col in grid[row].size():
			if grid[row][col] >= 0 and not anchored.has(Vector2i(row, col)):
				dropped.append({"cell": Vector2i(row, col), "ci": grid[row][col]})
				grid[row][col] = -1
	return dropped
