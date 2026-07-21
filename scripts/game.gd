extends Node2D
## Sheen — bubble shooter. Rendering (_draw) + input + game loop + pause + theme shop.
## Board logic lives in board.gd; theme data in themes.gd.
## Fixed 720x1280 design resolution — the project's stretch handles real windows.

const Board := preload("res://scripts/board.gd")
const Themes := preload("res://scripts/themes.gd")

var W := 720.0    # actual viewport size (set at runtime; "expand" keeps width ~720, grows height)
var H := 1280.0
const COLS := 11
const SPEED := 1100.0
const SHOTS_PER_DROP := 5   # a new row descends from the top every N shots
const HL := HORIZONTAL_ALIGNMENT_LEFT
const HEADER_H := 110.0
const SAVE_PATH := "user://sheen.cfg"
const PRICE := "$1.99"

var board
var theme_id := "sheen"
var owned := {"sheen": true}     # set of unlocked theme ids
var paused := false
var shop_open := false

var r: float
var row_h: float
var shooter_x: float
var shooter_y: float
var loss_y: float

var current_ci := 0
var next_ci := 0
var shots_since_drop := 0
var screen := "home"          # "home" | "game"
var about_open := false
var sound_on := true
var snd_shoot: AudioStreamPlayer
var snd_pop: AudioStreamPlayer
var aim := Vector2.ZERO
var has_aim := false
var aiming := false
var flying = null
var pops: Array = []

var font

func _ready() -> void:
	var base: FontFile = load("res://fonts/Nunito.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": 700}
	font = fv
	snd_shoot = AudioStreamPlayer.new()
	snd_shoot.stream = preload("res://sounds/shoot.wav")
	add_child(snd_shoot)
	snd_pop = AudioStreamPlayer.new()
	snd_pop.stream = preload("res://sounds/pop.wav")
	add_child(snd_pop)
	_layout()
	get_viewport().size_changed.connect(_on_resize)
	_load_save()
	AudioServer.set_bus_mute(0, not sound_on)
	board = Board.new()
	_new_game()

func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x >= 1.0:
		W = vp.x
		H = vp.y
	r = W / (2.0 * COLS)
	row_h = r * sqrt(3.0)
	shooter_x = W / 2.0
	shooter_y = H - r * 2.4
	loss_y = shooter_y - r * 2.4

func _on_resize() -> void:
	_layout()
	queue_redraw()

func _new_game() -> void:
	board.new_game()
	shots_since_drop = 0
	current_ci = _pick_color()
	next_ci = _pick_color()
	flying = null
	pops.clear()
	paused = false
	queue_redraw()

func _theme() -> Dictionary:
	return Themes.THEMES[theme_id]

func _pick_color() -> int:
	var c: Array = board.colors_in_grid()
	if c.is_empty():
		return randi() % 6
	return c[randi() % c.size()]

# ---------- save / ownership ----------
func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		owned = {}
		for id in cf.get_value("progress", "owned", ["sheen"]):
			owned[id] = true
		theme_id = cf.get_value("progress", "theme", "sheen")
		sound_on = cf.get_value("progress", "sound", true)
	if not owned.has("sheen"):
		owned["sheen"] = true
	if not owned.has(theme_id):
		theme_id = "sheen"

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "owned", owned.keys())
	cf.set_value("progress", "theme", theme_id)
	cf.set_value("progress", "sound", sound_on)
	cf.save(SAVE_PATH)

func _is_free(id: String) -> bool:
	return id == "sheen"

func _apply_theme(id: String) -> void:
	theme_id = id
	_save()
	queue_redraw()

func _buy_or_apply(id: String) -> void:
	# On web/desktop this mock-unlocks (no charge), mirroring the prototype.
	# On mobile this is where StoreKit / Play Billing IAP will hook in.
	if not owned.has(id):
		owned[id] = true
		_save()
	_apply_theme(id)

# ---------- geometry ----------
func cell_x(row: int, col: int) -> float:
	var po: int = board.parity_offset if board != null else 0
	return (2.0 * r if (row + po) % 2 == 1 else r) + col * 2.0 * r

func cell_y(row: int) -> float:
	return HEADER_H + r + row * row_h

func cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell_x(cell.x, cell.y), cell_y(cell.x))

func _hits_grid(x: float, y: float) -> bool:
	var thr := (2.0 * r * 0.9) * (2.0 * r * 0.9)
	var rrow: int = max(0, int(round((y - HEADER_H - r) / row_h)) - 1)
	for row in range(rrow, min(board.grid.size(), rrow + 4)):
		for col in board.grid[row].size():
			if board.grid[row][col] < 0:
				continue
			var dx := x - cell_x(row, col)
			var dy := y - cell_y(row)
			if dx * dx + dy * dy < thr:
				return true
	return false

func _nearest_cell(x: float, y: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for row in board.grid.size():
		for col in board.grid[row].size():
			if board.grid[row][col] != -1:
				continue
			if row != 0 and not board.has_filled_neighbor(row, col):
				continue
			var dx := x - cell_x(row, col)
			var dy := y - cell_y(row)
			var d := dx * dx + dy * dy
			if d < bd:
				bd = d
				best = Vector2i(row, col)
	return best

# ---------- shooting ----------
func _fire() -> void:
	if flying != null or board.over:
		return
	var ang := atan2(aim.y - shooter_y, aim.x - shooter_x)
	if ang > -0.18 and ang < 0.0:
		ang = -0.18
	if ang < -PI + 0.18 and ang > -PI:
		ang = -PI + 0.18
	if ang >= 0.0:
		return
	flying = {"pos": Vector2(shooter_x, shooter_y), "vel": Vector2(cos(ang), sin(ang)) * SPEED, "ci": current_ci}
	current_ci = next_ci
	next_ci = _pick_color()
	has_aim = false
	if sound_on:
		snd_shoot.play()

func _settle(x: float, y: float, ci: int) -> void:
	var cell := _nearest_cell(x, y)
	if cell.x < 0:
		return
	var res: Dictionary = board.place(cell.x, cell.y, ci)
	for p in res.popped:
		pops.append({"pos": cell_pos(p.cell), "ci": p.ci, "t": 0.0, "drop": false, "vel": 0.0})
	for p in res.dropped:
		pops.append({"pos": cell_pos(p.cell), "ci": p.ci, "t": 0.0, "drop": true, "vel": 120.0})
	if sound_on and not res.popped.is_empty():
		snd_pop.play()
	if board.over:
		return
	shots_since_drop += 1
	if shots_since_drop >= SHOTS_PER_DROP:
		shots_since_drop = 0
		board.add_top_row(5)
	_check_lose()

func _check_lose() -> void:
	var lr: int = board.lowest_filled_row()
	if lr >= 0 and cell_y(lr) + r >= loss_y:
		board.over = true
		board.won = false

func _process(delta: float) -> void:
	if screen == "game" and not paused and not shop_open and not about_open:
		if flying != null:
			var pos: Vector2 = flying.pos
			var vel: Vector2 = flying.vel
			var ci: int = flying.ci
			var landed := false
			for i in 6:
				pos += vel * (delta / 6.0)
				if pos.x < r:
					pos.x = r
					vel.x = -vel.x
				elif pos.x > W - r:
					pos.x = W - r
					vel.x = -vel.x
				if pos.y <= cell_y(0):
					_settle(pos.x, cell_y(0), ci)
					landed = true
					break
				if _hits_grid(pos.x, pos.y):
					_settle(pos.x, pos.y, ci)
					landed = true
					break
			if landed:
				flying = null
			else:
				flying.pos = pos
				flying.vel = vel
		for i in range(pops.size() - 1, -1, -1):
			var p = pops[i]
			p.t += delta * 1.6
			if p.drop:
				var v: float = p.vel + 1800.0 * delta
				var pp: Vector2 = p.pos
				pp.y += v * delta
				p.vel = v
				p.pos = pp
			if p.t >= 1.0 or p.pos.y > H + 40:
				pops.remove_at(i)
	queue_redraw()

# ---------- rendering helpers ----------
func _shade(c: Color, amt: float) -> Color:
	return c.lerp(Color(1, 1, 1), amt) if amt >= 0.0 else c.lerp(Color(0, 0, 0), -amt)

func _rgba(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

# rounded rect with optional border + soft drop shadow (the polish workhorse)
func _rrect(rect: Rect2, color: Color, radius: int, bw := 0, bcol := Color(0, 0, 0, 0), shadow := 0) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = bcol
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.16)
	draw_style_box(s, rect)

func _text_w(s: String, size: int) -> float:
	return font.get_string_size(s, HL, -1, size).x

func _draw_bubble(pos: Vector2, rad: float, ci: int, alpha := 1.0) -> void:
	var th := _theme()
	var base := Color(th.palette[ci])
	var style: String = th.style
	if style == "neon":
		draw_circle(pos, rad * 1.15, _rgba(base, 0.22 * alpha))
		draw_circle(pos, rad * 0.98, _rgba(base, alpha))
		draw_circle(pos, rad * 0.60, _rgba(_shade(base, -0.28), alpha))
		draw_circle(pos, rad * 0.42, _rgba(base, alpha))
		draw_circle(pos - Vector2(rad * 0.30, rad * 0.32), rad * 0.15, Color(1, 1, 1, 0.85 * alpha))
	elif style == "matte":
		draw_circle(pos + Vector2(0, rad * 0.14), rad * 0.98, Color(0, 0, 0, 0.10 * alpha))
		draw_circle(pos, rad * 0.96, _rgba(base, alpha))
		draw_arc(pos, rad * 0.88, 0, TAU, 40, _rgba(_shade(base, -0.18), alpha), rad * 0.14, true)
		draw_circle(pos - Vector2(rad * 0.28, rad * 0.30), rad * 0.28, Color(1, 1, 1, 0.20 * alpha))
	else: # gloss
		draw_circle(pos, rad * 0.98, _rgba(base, alpha))
		draw_circle(pos - Vector2(0, rad * 0.28), rad * 0.60, _rgba(_shade(base, 0.38), 0.6 * alpha))
		draw_circle(pos - Vector2(rad * 0.26, rad * 0.34), rad * 0.18, Color(1, 1, 1, 0.9 * alpha))
		draw_circle(pos + Vector2(rad * 0.22, rad * 0.26), rad * 0.08, Color(1, 1, 1, 0.35 * alpha))

func _stroke_rect(rect: Rect2, col: Color, wide: float) -> void:
	draw_rect(rect, col, false, wide)

func _draw_pill(rect: Rect2, label: String, th: Dictionary, filled: bool) -> void:
	var bg := Color(th.accent) if filled else _rgba(Color(th.fg), 0.10)
	var tc := Color(1, 1, 1) if filled else Color(th.fg)
	_rrect(rect, bg, int(rect.size.y / 2), 0, Color(0, 0, 0, 0), 3 if filled else 0)
	draw_string(font, rect.position + Vector2(rect.size.x / 2 - _text_w(label, 26) / 2, rect.size.y / 2 + 9), label, HL, -1, 26, tc)

# top-bar icon buttons
func _pause_btn() -> Rect2: return Rect2(W - 86, 44, 58, 58)
func _shop_btn() -> Rect2: return Rect2(W - 152, 44, 58, 58)

func _draw_top_buttons(th: Dictionary) -> void:
	var fg := Color(th.fg)
	var pb := _pause_btn()
	_rrect(pb, _rgba(fg, 0.09), 16)
	_rrect(Rect2(pb.position.x + 20, pb.position.y + 17, 6, 24), fg, 3)
	_rrect(Rect2(pb.position.x + 32, pb.position.y + 17, 6, 24), fg, 3)
	var sb := _shop_btn()
	_rrect(sb, _rgba(fg, 0.09), 16)
	for s in 3:
		draw_circle(Vector2(sb.position.x + 16 + s * 13, sb.position.y + 29), 6, Color(th.palette[s]))

# pause overlay buttons
func _resume_btn() -> Rect2: return Rect2(W / 2 - 170, H / 2 + 10, 340, 96)
func _prestart_btn() -> Rect2: return Rect2(W / 2 - 170, H / 2 + 126, 340, 96)

func _draw_pause(th: Dictionary) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	var t := "Paused"
	draw_string(font, Vector2(W / 2 - _text_w(t, 72) / 2, H / 2 - 60), t, HL, -1, 72, Color(1, 1, 1))
	var rb := _resume_btn()
	_rrect(rb, Color(th.accent), int(rb.size.y / 2), 0, Color(0, 0, 0, 0), 4)
	draw_string(font, rb.position + Vector2(rb.size.x / 2 - _text_w("Resume", 30) / 2, rb.size.y / 2 + 11), "Resume", HL, -1, 30, Color(1, 1, 1))
	var pr := _prestart_btn()
	_rrect(pr, Color(1, 1, 1, 0.13), int(pr.size.y / 2))
	draw_string(font, pr.position + Vector2(pr.size.x / 2 - _text_w("Restart", 30) / 2, pr.size.y / 2 + 11), "Restart", HL, -1, 30, Color(1, 1, 1, 0.92))
	var hb := _phome()
	_rrect(hb, Color(1, 1, 1, 0.13), int(hb.size.y / 2))
	draw_string(font, hb.position + Vector2(hb.size.x / 2 - _text_w("Home", 30) / 2, hb.size.y / 2 + 11), "Home", HL, -1, 30, Color(1, 1, 1, 0.92))

# shop rows
const SHEET_TOP := 140.0
func _shop_close() -> Rect2: return Rect2(W - 92, SHEET_TOP + 20, 64, 64)
func _shop_row(i: int) -> Rect2:
	var y0 := 244.0
	var rh := (H - 40.0 - y0) / 8.0
	return Rect2(30, y0 + i * rh, W - 60, rh - 16)
func _shop_action(row: Rect2) -> Rect2:
	return Rect2(row.position.x + row.size.x - 184, row.position.y + row.size.y / 2 - 32, 160, 64)

func _draw_shop(th: Dictionary) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))                                   # scrim
	_rrect(Rect2(0, SHEET_TOP, W, H - SHEET_TOP + 40), Color(th.panel), 36, 0, Color(0, 0, 0, 0), 14)  # rounded sheet
	draw_string(font, Vector2(40, SHEET_TOP + 74), "Themes", HL, -1, 50, Color(th.fg))
	var cb := _shop_close()
	_rrect(cb, _rgba(Color(th.fg), 0.10), int(cb.size.y / 2))
	draw_string(font, cb.position + Vector2(cb.size.x / 2 - _text_w("X", 32) / 2, cb.size.y / 2 + 12), "X", HL, -1, 32, Color(th.fg))
	for i in Themes.ORDER.size():
		var id: String = Themes.ORDER[i]
		var t: Dictionary = Themes.THEMES[id]
		var rect := _shop_row(i)
		var is_owned := owned.has(id)
		var active := theme_id == id
		if active:
			_rrect(rect, _rgba(Color(th.accent), 0.13), 22, 3, Color(th.accent))
		else:
			_rrect(rect, _rgba(Color(th.fg), 0.05), 22)
		var cy := rect.position.y + rect.size.y / 2
		for s in 5:
			draw_circle(Vector2(rect.position.x + 44 + s * 40, cy), 15, Color(t.palette[s]))
		draw_string(font, Vector2(rect.position.x + 262, cy - 2), t.name, HL, -1, 34, Color(th.fg))
		draw_string(font, Vector2(rect.position.x + 262, cy + 32), "Free" if _is_free(id) else "Premium theme", HL, -1, 22, _rgba(Color(th.fg), 0.6))
		var label := "Applied" if active else ("Apply" if is_owned else PRICE)
		_draw_pill(_shop_action(rect), label, th, (not is_owned) or active)

func _draw_aim() -> void:
	if flying != null or board.over or paused or shop_open:
		return
	var acc := Color(_theme().accent)
	var ap := aim if has_aim else Vector2(shooter_x, shooter_y - 100)
	var ang: float = clamp(atan2(ap.y - shooter_y, ap.x - shooter_x), -PI + 0.18, -0.18)
	var pos := Vector2(shooter_x, shooter_y)
	var dir := Vector2(cos(ang), sin(ang))
	var col := _rgba(acc, 0.5)
	var prev := pos
	for i in 240:
		pos += dir * 8.0
		if pos.x < r:
			pos.x = r
			dir.x = -dir.x
		elif pos.x > W - r:
			pos.x = W - r
			dir.x = -dir.x
		draw_line(prev, pos, col, 2.0)
		prev = pos
		if pos.y <= cell_y(0) or _hits_grid(pos.x, pos.y):
			break

# ---------- home / title screen ----------
func _home_play() -> Rect2: return Rect2(W / 2 - 190, H * 0.52 - 55, 380, 118)
func _home_themes() -> Rect2: return Rect2(W / 2 - 190, H * 0.52 + 96, 380, 100)
func _home_sound() -> Rect2: return Rect2(W - 96, 44, 68, 68)
func _home_about() -> Rect2: return Rect2(W / 2 - 160, H - 130, 320, 74)

func _draw_home(th: Dictionary) -> void:
	var accent := Color(th.accent)
	var fg := Color(th.fg)
	draw_string(font, Vector2(W / 2 - _text_w("Sheen", 120) / 2, H * 0.27), "Sheen", HL, -1, 120, accent)
	draw_string(font, Vector2(W / 2 - _text_w("bubble shooter", 30) / 2, H * 0.27 + 48), "bubble shooter", HL, -1, 30, _rgba(fg, 0.55))
	for i in 5:
		_draw_bubble(Vector2(W / 2 + (i - 2) * 78, H * 0.40), 30, i)
	_draw_pill(_home_play(), "Play", th, true)
	_draw_pill(_home_themes(), "Themes", th, false)
	_draw_sound_icon(_home_sound(), th)
	var ab := _home_about()
	draw_string(font, ab.position + Vector2(ab.size.x / 2 - _text_w("About", 26) / 2, ab.size.y / 2 + 9), "About", HL, -1, 26, _rgba(fg, 0.6))

func _draw_sound_icon(rect: Rect2, th: Dictionary) -> void:
	var fg := Color(th.fg)
	_rrect(rect, _rgba(fg, 0.09), 18)
	var c := rect.position + rect.size / 2
	draw_rect(Rect2(c.x - 14, c.y - 7, 8, 14), fg)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, c.y - 7), Vector2(c.x + 4, c.y - 16), Vector2(c.x + 4, c.y + 16), Vector2(c.x - 6, c.y + 7)]), fg)
	if sound_on:
		draw_arc(Vector2(c.x + 9, c.y), 9, -0.6, 0.6, 8, fg, 3.0)
		draw_arc(Vector2(c.x + 9, c.y), 15, -0.6, 0.6, 10, fg, 3.0)
	else:
		draw_line(rect.position + Vector2(15, 15), rect.position + rect.size - Vector2(15, 15), Color(0.9, 0.35, 0.35), 5.0)

func _about_close() -> Rect2: return Rect2(W - 92, SHEET_TOP + 20, 64, 64)

func _draw_about(th: Dictionary) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	_rrect(Rect2(0, SHEET_TOP, W, H - SHEET_TOP + 40), Color(th.panel), 36, 0, Color(0, 0, 0, 0), 14)
	var fg := Color(th.fg)
	draw_string(font, Vector2(40, SHEET_TOP + 74), "How to Play", HL, -1, 50, fg)
	var cb := _about_close()
	_rrect(cb, _rgba(fg, 0.10), int(cb.size.y / 2))
	draw_string(font, cb.position + Vector2(cb.size.x / 2 - _text_w("X", 32) / 2, cb.size.y / 2 + 12), "X", HL, -1, 32, fg)
	var lines := [
		"Drag to aim, release to fire a bubble.",
		"",
		"Match 3+ bubbles of the same colour to pop",
		"them. Bubbles cut off from the top drop for",
		"bonus points.",
		"",
		"A new row drops in every few shots. Clear",
		"them before the stack reaches the line —",
		"cross it and it's game over.",
		"",
		"Unlock new colour themes in the shop.",
	]
	var y := SHEET_TOP + 148.0
	for line in lines:
		draw_string(font, Vector2(44, y), line, HL, -1, 30, _rgba(fg, 0.85))
		y += 46

func _phome() -> Rect2: return Rect2(W / 2 - 170, H / 2 + 242, 340, 96)

func _draw() -> void:
	var th := _theme()
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([Color(th.bg2), Color(th.bg2), Color(th.bg), Color(th.bg)]))
	if screen == "game":
		for row in board.grid.size():
			for col in board.grid[row].size():
				if board.grid[row][col] >= 0:
					_draw_bubble(Vector2(cell_x(row, col), cell_y(row)), r, board.grid[row][col])
		for p in pops:
			var s: float = 1.0 if p.drop else 1.0 + p.t * 0.8
			_draw_bubble(p.pos, r * s, p.ci, 1.0 - clamp(p.t, 0.0, 1.0))
		draw_dashed_line(Vector2(0, loss_y), Vector2(W, loss_y), _rgba(Color(th.accent), 0.25), 2.0, 12.0)
		_draw_aim()
		if flying != null:
			_draw_bubble(flying.pos, r, flying.ci)
		if not board.over and not shop_open:
			_draw_bubble(Vector2(shooter_x, shooter_y), r * 1.08, current_ci)
			_draw_bubble(Vector2(W - r * 1.4, shooter_y + r * 0.2), r * 0.62, next_ci, 0.9)
		draw_rect(Rect2(0, 0, W, HEADER_H), Color(th.panel))
		draw_polygon(
			PackedVector2Array([Vector2(0, HEADER_H), Vector2(W, HEADER_H), Vector2(W, HEADER_H + 16), Vector2(0, HEADER_H + 16)]),
			PackedColorArray([Color(0, 0, 0, 0.10), Color(0, 0, 0, 0.10), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_string(font, Vector2(34, 76), "Sheen", HL, -1, 50, Color(th.accent))
		var sc := str(board.score)
		draw_string(font, Vector2(W / 2 - _text_w(sc, 50) / 2, 76), sc, HL, -1, 50, Color(th.fg))
		if not paused and not shop_open and not board.over:
			_draw_top_buttons(th)
		if board.over:
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
			var title: String = "Cleared!" if board.won else "Blocked!"
			draw_string(font, Vector2(W / 2 - _text_w(title, 72) / 2, H / 2 - 20), title, HL, -1, 72, Color(1, 1, 1))
			var sub := "Score %d   ·   tap to restart" % board.score
			draw_string(font, Vector2(W / 2 - _text_w(sub, 32) / 2, H / 2 + 40), sub, HL, -1, 32, Color(1, 1, 1, 0.9))
	else:
		_draw_home(th)
	if paused:
		_draw_pause(th)
	if shop_open:
		_draw_shop(th)
	if about_open:
		_draw_about(th)

# ---------- input ----------
func _click(pos: Vector2) -> void:
	# Priority: about > shop > home > pause > game-over > top buttons > fire
	if about_open:
		if _about_close().has_point(pos):
			about_open = false
			queue_redraw()
		return
	if shop_open:
		if _shop_close().has_point(pos):
			shop_open = false
			queue_redraw()
			return
		for i in Themes.ORDER.size():
			if _shop_row(i).has_point(pos):
				_buy_or_apply(Themes.ORDER[i])
				return
		return
	if screen == "home":
		if _home_sound().has_point(pos):
			sound_on = not sound_on
			AudioServer.set_bus_mute(0, not sound_on)
			if sound_on:
				snd_pop.play()
			_save()
		elif _home_themes().has_point(pos):
			shop_open = true
		elif _home_about().has_point(pos):
			about_open = true
		elif _home_play().has_point(pos):
			screen = "game"
			_new_game()
		queue_redraw()
		return
	if paused:
		if _resume_btn().has_point(pos):
			paused = false
		elif _prestart_btn().has_point(pos):
			_new_game()
		elif _phome().has_point(pos):
			paused = false
			screen = "home"
		queue_redraw()
		return
	if board.over:
		_new_game()
		return
	if _pause_btn().has_point(pos):
		paused = true
		queue_redraw()
		return
	if _shop_btn().has_point(pos):
		shop_open = true
		queue_redraw()
		return
	# otherwise it's a fire (handled on release via aiming)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_global_mouse_position()
		if event.pressed:
			# UI hit-tests happen on press; only start aiming if the press is in open play
			if screen != "game" or about_open or shop_open or paused or board.over or _pause_btn().has_point(mp) or _shop_btn().has_point(mp):
				_click(mp)
			else:
				aim = mp
				has_aim = true
				aiming = true
		elif aiming:
			aim = get_global_mouse_position()
			_fire()
			aiming = false
	elif event is InputEventMouseMotion and aiming:
		aim = get_global_mouse_position()
		has_aim = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_new_game()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if not shop_open:
				paused = not paused
				queue_redraw()
		else:
			# dev shortcut: number keys jump to any theme (unlocks it too)
			for i in Themes.ORDER.size():
				if event.keycode == KEY_1 + i:
					_buy_or_apply(Themes.ORDER[i])
					break
