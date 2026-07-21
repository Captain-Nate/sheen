extends SceneTree
## Regression test for the sideways-stack bug: a bubble arriving BELOW the last
## allocated grid row must extend the grid downward and land there, not deflect
## to a sideways cell. Drives the real game.gd settle path headlessly.
## (game.gd's _ready needs a viewport, so the geometry is initialized manually.)
## Run: godot --headless --path <project> --script res://tests/test_settle.gd

func _initialize() -> void:
	var fails := 0
	var g: Node2D = load("res://scripts/game.gd").new()
	g.board = load("res://scripts/board.gd").new()
	g.r = 720.0 / 22.0
	g.row_h = g.r * sqrt(3.0)
	g.loss_y = 99999.0
	g.sound_on = false

	# Build a no-match vertical chain from the ceiling down to the LAST allocated
	# row (colors cycle 0/1/2 so nothing can pop and drop the chain).
	g.board.blank()
	var col := 5
	for row in g.board.grid.size():
		g.board.grid[row][col] = row % 3
	var before: int = g.board.grid.size()
	var last: int = before - 1

	# Settle a bubble one row-height below the chain's tip.
	var x: float = g.cell_x(last, col)
	var y: float = g.cell_y(last) + g.row_h
	g._settle(x, y, 3)

	fails += _eq("grid grew downward", g.board.grid.size(), before + 1)
	var found := -1
	for c in g.board.grid[before].size():
		if g.board.grid[before][c] == 3:
			found = c
	fails += _eq("bubble landed in the NEW row (not sideways)", found >= 0, true)
	var side_hits := 0
	for c in g.board.grid[last].size():
		if c != col and g.board.grid[last][c] == 3:
			side_hits += 1
	fails += _eq("no sideways placement in old last row", side_hits, 0)

	g.free()
	if fails == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILED: %d check(s)" % fails)
	quit(fails)

func _eq(label: String, got, want) -> int:
	if got == want:
		print("  ok  | %s = %s" % [label, str(got)])
		return 0
	print("  FAIL| %s => got %s, want %s" % [label, str(got), str(want)])
	return 1
