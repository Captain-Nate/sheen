extends SceneTree
## Validates every Level-mode layout in scripts/levels.gd:
##  - row lengths fit the offset grid (11 cells even rows, 10 odd)
##  - only '0'-'4' and '.' characters
##  - at least one bubble and a positive shot budget
##  - EVERY bubble is anchored (connected to row 0) — an unanchored cluster
##    would float at level start until the first pop, which reads as a bug
## Run: godot --headless --path <project> --script res://tests/test_levels.gd

const Levels := preload("res://scripts/levels.gd")
const Board := preload("res://scripts/board.gd")

func _initialize() -> void:
	var fails := 0
	for li in Levels.LEVELS.size():
		var lv: Dictionary = Levels.LEVELS[li]
		var label := "L%d" % (li + 1)
		if int(lv.shots) <= 0:
			fails += _fail(label, "non-positive shot budget")
		var rows: Array = lv.rows
		var bubbles := 0
		var ok := true
		for ri in rows.size():
			var s: String = rows[ri]
			var want := 11 if ri % 2 == 0 else 10
			if s.length() != want:
				fails += _fail(label, "row %d length %d, want %d" % [ri, s.length(), want])
				ok = false
			for ch in s:
				if ch == ".":
					continue
				if ch < "0" or ch > "4":
					fails += _fail(label, "bad char '%s' in row %d" % [ch, ri])
					ok = false
				bubbles += 1
		if bubbles == 0:
			fails += _fail(label, "no bubbles")
			ok = false
		if not ok:
			continue
		# anchoring: BFS from filled row-0 cells through filled neighbors
		var b = Board.new()
		b.load_level(rows)
		var anchored := {}
		var stack: Array = []
		for col in b.grid[0].size():
			if b.grid[0][col] >= 0:
				anchored[Vector2i(0, col)] = true
				stack.append(Vector2i(0, col))
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for n in b.neighbors(cur.x, cur.y):
				if not anchored.has(n) and b.grid[n.x][n.y] >= 0:
					anchored[n] = true
					stack.append(n)
		var loose := 0
		for ri in b.grid.size():
			for ci in b.grid[ri].size():
				if b.grid[ri][ci] >= 0 and not anchored.has(Vector2i(ri, ci)):
					loose += 1
		if loose > 0:
			fails += _fail(label, "%d unanchored bubble(s)" % loose)
			continue
		# difficulty bound: shots to pop every cluster DIRECTLY (max(1, 3-size)
		# each). Drops only reduce this; unlucky deals raise it. If the bound
		# exceeds the budget the level is likely unwinnable; near it, unfair.
		var seen := {}
		var bound := 0
		var clusters := 0
		for ri in b.grid.size():
			for ci in b.grid[ri].size():
				var v := Vector2i(ri, ci)
				if b.grid[ri][ci] < 0 or seen.has(v):
					continue
				clusters += 1
				var size := 0
				var st: Array = [v]
				seen[v] = true
				while not st.is_empty():
					var cur: Vector2i = st.pop_back()
					size += 1
					for n in b.neighbors(cur.x, cur.y):
						if not seen.has(n) and b.grid[n.x][n.y] == b.grid[cur.x][cur.y]:
							seen[n] = true
							st.append(n)
				bound += maxi(1, 3 - size)
		var budget: int = lv.shots
		if bound > budget:
			fails += _fail(label, "shot bound %d exceeds budget %d (likely unwinnable)" % [bound, budget])
		elif float(bound) > 0.65 * budget:
			print("  WARN| %s: bound %d vs budget %d — tight/luck-dependent" % [label, bound, budget])
		else:
			print("  ok  | %s: %d bubbles, %d clusters, bound %d, budget %d" % [label, bubbles, clusters, bound, budget])

	if fails == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILED: %d check(s)" % fails)
	quit(fails)

func _fail(label: String, msg: String) -> int:
	print("  FAIL| %s: %s" % [label, msg])
	return 1
