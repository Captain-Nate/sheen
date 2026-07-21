extends SceneTree
## Headless logic test — mirrors the JS engine tests.
## Run: godot --headless --path <project> --script res://tests/test_board.gd

const Board := preload("res://scripts/board.gd")

func _initialize() -> void:
	var fails := 0

	# Test 1 — a 3-in-a-row match pops, scores +30, and clearing the board wins.
	var b = Board.new()
	b.blank()
	b.grid[0][0] = 0
	b.grid[0][1] = 0
	var r1 = b.place(0, 2, 0)
	fails += _eq("3-match popped", r1.popped.size(), 3)
	fails += _eq("3-match score", b.score, 30)
	fails += _eq("3-match won", b.won, true)

	# Test 2 — popping a color-3 trio severs a lone color-4 -> it drops (+20).
	var b2 = Board.new()
	b2.blank()
	b2.grid[0][5] = 3          # anchored to ceiling
	b2.grid[1][4] = 3
	b2.grid[1][5] = 3
	b2.grid[2][4] = 4          # hangs, held only via (1,4)
	var r2 = b2.place(1, 3, 3) # 4th color-3 -> pop 4, sever the 4
	fails += _eq("drop: popped", r2.popped.size(), 4)
	fails += _eq("drop: dropped", r2.dropped.size(), 1)
	fails += _eq("drop: score", b2.score, 60)

	# Test 3 — a cluster of 2 does NOT pop.
	var b3 = Board.new()
	b3.blank()
	b3.grid[0][0] = 1
	var r3 = b3.place(0, 1, 1)
	fails += _eq("no-pop popped", r3.popped.size(), 0)
	fails += _eq("no-pop score", b3.score, 0)

	# Test 4 — descending ceiling grows the grid + pushes filled bubbles down.
	var b4 = Board.new()
	b4.new_game(5, 5)
	var before_low: int = b4.lowest_filled_row()
	var before_size: int = b4.grid.size()
	b4.add_top_row(5)
	b4.add_top_row(5)
	fails += _eq("descend: grid grew by 2", b4.grid.size(), before_size + 2)
	fails += _eq("descend: bubbles pushed down 2", b4.lowest_filled_row(), before_low + 2)

	# Test 5 — matching still works after a descend (parity stays consistent).
	var b5 = Board.new()
	b5.blank()
	b5.add_top_row(5)
	for col in b5.grid[0].size():
		b5.grid[0][col] = -1
	b5.grid[0][0] = 3
	b5.grid[0][1] = 3
	var r5 = b5.place(0, 2, 3)
	fails += _eq("match after descend", r5.popped.size(), 3)

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
