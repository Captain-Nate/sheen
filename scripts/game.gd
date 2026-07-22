extends Node2D
## Sheen — bubble shooter. Rendering (_draw) + input + game loop + pause + theme shop.
## Board logic lives in board.gd; theme data in themes.gd.
## Fixed 720x1280 design resolution — the project's stretch handles real windows.

const Board := preload("res://scripts/board.gd")
const Themes := preload("res://scripts/themes.gd")
const Levels := preload("res://scripts/levels.gd")

var W := 720.0    # actual viewport size (set at runtime; "expand" keeps width ~720, grows height)
var H := 1280.0
const COLS := 11
const SPEED := 1100.0
const SHOTS_PER_DROP := 5   # a new row descends from the top every N shots
const HL := HORIZONTAL_ALIGNMENT_LEFT
const HEADER_H := 110.0
const SAVE_PATH := "user://sheen.cfg"
const PRICE := "$1.99"
const PRICE_ALL := "$4.99"
const FINISHES := ["auto", "gloss", "neon", "matte", "clear"]   # bubble finish override; "auto" follows the theme
const FINISH_COSTS := {"neon": 100, "matte": 200, "clear": 350}  # coin prices; auto+gloss start unlocked
const COIN_RATE := 10                                            # 10 score = 1 coin

var board
var theme_id := "sheen"
var owned := {"sheen": true}     # set of unlocked theme ids
var paused := false
var shop_open := false
var bubble_style := "auto"       # one of FINISHES; free customization, not an IAP
var shop_scroll := 0.0
var shop_pressing := false       # a press started inside the shop sheet
var shop_moved := false          # that press dragged far enough to count as a scroll
var shop_start := Vector2.ZERO
var shop_last := Vector2.ZERO

var r: float
var row_h: float
var shooter_x: float
var shooter_y: float
var loss_y: float

var current_ci := 0
var next_ci := 0
var shots_since_drop := 0
var mode := "endless"            # "endless" | "levels"
var level_i := 0                 # current level index (levels mode)
var shots_left := 0              # remaining shot budget (levels mode)
var last_stars := 0              # stars earned on the just-cleared level (overlay)
var level_stars := {}            # int level index -> best stars earned; persisted
var best_score := 0              # best single-game score (home-screen bragging line)
var coins := 0                   # spendable currency: earned from score, spent in the shop
var run_coins := 0               # coins earned during the current run (game-over line)
var owned_finishes := {}         # bought bubble finishes; auto + gloss need no entry
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
	if mode == "levels":
		var lv: Dictionary = Levels.LEVELS[level_i]
		board.load_level(lv.rows)
		shots_left = lv.shots
	else:
		board.new_game()
	shots_since_drop = 0
	run_coins = 0
	last_stars = 0
	if mode == "levels":
		current_ci = _picker_colors()[0]   # levels: player picks; start on the first live color
	else:
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
		return randi() % 5   # only palette[0..4] are in play
	return c[randi() % c.size()]

# ---------- level-mode color picker (no deal luck: the player chooses) ----------
func _picker_colors() -> Array:
	var c: Array = board.colors_in_grid()
	if c.is_empty():
		return [0]
	c.sort()
	return c

func _picker_center(k: int) -> Vector2:
	return Vector2(W / 2 + 70 + k * 62, shooter_y)

## Color at a tap position, or -1. Levels mode only.
func _picker_hit(pos: Vector2) -> int:
	if mode != "levels" or board.over:
		return -1
	var live := _picker_colors()
	for k in live.size():
		if pos.distance_to(_picker_center(k)) <= 34.0:
			return live[k]
	return -1

# ---------- save / ownership ----------
func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		owned = {}
		for id in cf.get_value("progress", "owned", ["sheen"]):
			owned[id] = true
		theme_id = cf.get_value("progress", "theme", "sheen")
		sound_on = cf.get_value("progress", "sound", true)
		bubble_style = cf.get_value("progress", "bubble", "auto")
		best_score = cf.get_value("progress", "best", 0)
		# Older saves earned by score threshold; seed the wallet from best score.
		coins = cf.get_value("progress", "coins", int(best_score / float(COIN_RATE)))
		owned_finishes = {}
		for f in cf.get_value("progress", "finishes", []):
			owned_finishes[f] = true
		level_stars = cf.get_value("progress", "levels", {})
	if not owned.has("sheen"):
		owned["sheen"] = true
	if not owned.has(theme_id):
		theme_id = "sheen"
	if not FINISHES.has(bubble_style) or not _finish_owned(bubble_style):
		bubble_style = "auto"

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "owned", owned.keys())
	cf.set_value("progress", "theme", theme_id)
	cf.set_value("progress", "sound", sound_on)
	cf.set_value("progress", "bubble", bubble_style)
	cf.set_value("progress", "best", best_score)
	cf.set_value("progress", "coins", coins)
	cf.set_value("progress", "finishes", owned_finishes.keys())
	cf.set_value("progress", "levels", level_stars)
	cf.save(SAVE_PATH)

func _apply_theme(id: String) -> void:
	theme_id = id
	_save()
	queue_redraw()

func _tier(id: String) -> String:
	if id == "sheen":
		return "free"
	return "coins" if Themes.THEMES[id].has("coins") else "premium"

func _finish_owned(f: String) -> bool:
	return not FINISH_COSTS.has(f) or owned_finishes.has(f)

func _buy_or_apply(id: String) -> void:
	if not owned.has(id):
		if _tier(id) == "coins":
			var price: int = Themes.THEMES[id].coins
			if coins < price:
				return
			coins -= price
		# else premium: mock-unlock on web/desktop; StoreKit / Play Billing hooks in here.
		owned[id] = true
		_save()
	_apply_theme(id)

func _buy_finish(f: String) -> void:
	if not _finish_owned(f):
		var price: int = FINISH_COSTS[f]
		if coins < price:
			return
		coins -= price
		owned_finishes[f] = true
	bubble_style = f
	_save()
	queue_redraw()

## Score earned this settle becomes coins (10 score = 1 coin) + best tracking.
func _earn(delta: int) -> void:
	if delta <= 0:
		return
	var c := int(delta / float(COIN_RATE))
	coins += c
	run_coins += c
	if mode == "endless":   # level scores are capped by design; Best = endless runs
		best_score = maxi(best_score, board.score)
	_save()

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
	var nrows: int = board.grid.size()
	for row in nrows + 1:   # +1: the stack may grow one row past the allocated grid
		var rl: int = board.grid[row].size() if row < nrows else board.row_len(row)
		for col in rl:
			if row < nrows and board.grid[row][col] != -1:
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
	if mode == "levels" and shots_left <= 0:
		return
	var ang := atan2(aim.y - shooter_y, aim.x - shooter_x)
	if ang > -0.18 and ang < 0.0:
		ang = -0.18
	if ang < -PI + 0.18 and ang > -PI:
		ang = -PI + 0.18
	if ang >= 0.0:
		return
	flying = {"pos": Vector2(shooter_x, shooter_y), "vel": Vector2(cos(ang), sin(ang)) * SPEED, "ci": current_ci}
	if mode == "levels":
		shots_left -= 1        # picked color stays selected shot to shot
	else:
		current_ci = next_ci
		next_ci = _pick_color()
	has_aim = false
	if sound_on:
		snd_shoot.play()

func _settle(x: float, y: float, ci: int) -> void:
	var cell := _nearest_cell(x, y)
	if cell.x < 0:
		return
	board.ensure_row(cell.x)
	var score_before: int = board.score
	var res: Dictionary = board.place(cell.x, cell.y, ci)
	for p in res.popped:
		pops.append({"pos": cell_pos(p.cell), "ci": p.ci, "t": 0.0, "drop": false, "vel": 0.0})
	for p in res.dropped:
		pops.append({"pos": cell_pos(p.cell), "ci": p.ci, "t": 0.0, "drop": true, "vel": 120.0})
	if sound_on and not res.popped.is_empty():
		snd_pop.play()
	_earn(board.score - score_before)
	# When a color is wiped from the board, drop it from the queue/selection —
	# otherwise the player is forced to waste shots on dead colors.
	var live: Array = board.colors_in_grid()
	if not live.is_empty():
		if mode == "levels":
			if not live.has(current_ci):
				current_ci = _picker_colors()[0]
		else:
			if not live.has(current_ci):
				current_ci = _pick_color()
			if not live.has(next_ci):
				next_ci = _pick_color()
	if board.over:
		if mode == "levels" and board.won:
			_complete_level()
		return
	if mode == "endless":
		shots_since_drop += 1
		if shots_since_drop >= SHOTS_PER_DROP:
			shots_since_drop = 0
			board.add_top_row(5)
	_check_lose()
	if mode == "levels" and not board.over and shots_left <= 0:
		board.over = true
		board.won = false

func _complete_level() -> void:
	var lv: Dictionary = Levels.LEVELS[level_i]
	var frac := float(shots_left) / float(lv.shots)
	last_stars = 3 if frac >= 0.35 else (2 if frac >= 0.12 else 1)
	if int(level_stars.get(level_i, 0)) == 0:   # first clear pays a coin bonus
		coins += 30
		run_coins += 30
	level_stars[level_i] = maxi(last_stars, int(level_stars.get(level_i, 0)))
	_save()

func _check_lose() -> void:
	var lr: int = board.lowest_filled_row()
	if lr >= 0 and cell_y(lr) + r >= loss_y:
		board.over = true
		board.won = false

func _process(delta: float) -> void:
	if screen == "game" and not paused and not shop_open and not about_open:
		var animating := flying != null or not pops.is_empty()
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
		if animating:   # only animation needs per-frame redraws; UI changes queue their own
			queue_redraw()

# ---------- rendering helpers ----------
func _shade(c: Color, amt: float) -> Color:
	return c.lerp(Color(1, 1, 1), amt) if amt >= 0.0 else c.lerp(Color(0, 0, 0), -amt)

func _rgba(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

# WCAG relative luminance / contrast — used to keep button text readable on any accent
func _lin_ch(u: float) -> float:
	return u / 12.92 if u <= 0.04045 else pow((u + 0.055) / 1.055, 2.4)

func _lum(c: Color) -> float:
	return 0.2126 * _lin_ch(c.r) + 0.7152 * _lin_ch(c.g) + 0.0722 * _lin_ch(c.b)

func _contrast(a: Color, b: Color) -> float:
	var x := _lum(a)
	var y := _lum(b)
	return (max(x, y) + 0.05) / (min(x, y) + 0.05)

# Text color for accent-filled buttons: white, unless the theme's dark tone reads better
# (e.g. Neon's cyan pills would leave white text illegible).
func _on_accent(th: Dictionary) -> Color:
	var acc := Color(th.accent)
	var dark := Color(th.fg) if _lum(Color(th.fg)) < _lum(Color(th.bg)) else Color(th.bg)
	return Color(1, 1, 1) if _contrast(Color(1, 1, 1), acc) >= _contrast(dark, acc) else dark

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

func _draw_bubble(pos: Vector2, rad: float, ci: int, alpha := 1.0, force_style := "") -> void:
	var th := _theme()
	var base := Color(th.palette[ci])
	var style: String = force_style
	if style == "":
		style = String(th.style) if bubble_style == "auto" else bubble_style
	if style == "neon":
		draw_circle(pos, rad * 1.34, _rgba(base, 0.10 * alpha))
		draw_circle(pos, rad * 1.15, _rgba(base, 0.22 * alpha))
		draw_circle(pos, rad * 0.98, _rgba(base, alpha))
		draw_circle(pos, rad * 0.60, _rgba(_shade(base, -0.42), alpha))
		draw_circle(pos, rad * 0.42, _rgba(base, alpha))
		draw_circle(pos - Vector2(rad * 0.30, rad * 0.32), rad * 0.15, Color(1, 1, 1, 0.85 * alpha))
	elif style == "matte":
		draw_circle(pos + Vector2(0, rad * 0.14), rad * 0.98, Color(0, 0, 0, 0.10 * alpha))
		draw_circle(pos, rad * 0.96, _rgba(base, alpha))
		draw_arc(pos, rad * 0.88, 0, TAU, 40, _rgba(_shade(base, -0.18), alpha), rad * 0.14, true)
		draw_circle(pos - Vector2(rad * 0.28, rad * 0.30), rad * 0.28, Color(1, 1, 1, 0.20 * alpha))
	elif style == "clear": # glass: tinted body, strong colored rim, sheen band
		draw_circle(pos, rad * 0.94, _rgba(base, 0.28 * alpha))
		draw_arc(pos, rad * 0.86, 0, TAU, 48, _rgba(base, 0.95 * alpha), rad * 0.11, true)
		draw_arc(pos, rad * 0.62, -2.6, -0.9, 14, Color(1, 1, 1, 0.5 * alpha), rad * 0.09, true)
		draw_circle(pos - Vector2(rad * 0.24, rad * 0.32), rad * 0.15, Color(1, 1, 1, 0.9 * alpha))
		draw_circle(pos + Vector2(rad * 0.28, rad * 0.30), rad * 0.11, _rgba(base, 0.55 * alpha))
	else: # gloss
		draw_circle(pos, rad * 0.98, _rgba(base, alpha))
		draw_arc(pos, rad * 0.80, 0.5, PI - 0.5, 22, _rgba(_shade(base, -0.30), 0.45 * alpha), rad * 0.22, true)
		draw_circle(pos - Vector2(0, rad * 0.28), rad * 0.60, _rgba(_shade(base, 0.38), 0.6 * alpha))
		draw_circle(pos - Vector2(rad * 0.26, rad * 0.34), rad * 0.18, Color(1, 1, 1, 0.9 * alpha))
		draw_circle(pos + Vector2(rad * 0.22, rad * 0.26), rad * 0.08, Color(1, 1, 1, 0.35 * alpha))
		draw_arc(pos, rad * 0.93, 0, TAU, 48, _rgba(_shade(base, -0.32), 0.35 * alpha), rad * 0.06, true)

func _stroke_rect(rect: Rect2, col: Color, wide: float) -> void:
	draw_rect(rect, col, false, wide)

# small gold coin glyph, used wherever a coin amount is shown
func _draw_coin(pos: Vector2, rad: float) -> void:
	draw_circle(pos, rad, Color("#e8a815"))
	draw_circle(pos, rad * 0.72, Color("#f7cf4a"))
	draw_circle(pos - Vector2(rad * 0.25, rad * 0.3), rad * 0.2, Color(1, 1, 1, 0.75))

# coin amount with leading glyph, horizontally centered on `center_x`
func _draw_coin_amount(center_x: float, baseline_y: float, amount: int, size: int, col: Color) -> void:
	var txt := str(amount)
	var crad := size * 0.34
	var total := crad * 2.0 + 8.0 + _text_w(txt, size)
	var x := center_x - total / 2.0
	_draw_coin(Vector2(x + crad, baseline_y - size * 0.36), crad)
	draw_string(font, Vector2(x + crad * 2.0 + 8.0, baseline_y), txt, HL, -1, size, col)

func _draw_pill(rect: Rect2, label: String, th: Dictionary, filled: bool) -> void:
	var bg := Color(th.accent) if filled else _rgba(Color(th.fg), 0.10)
	var tc := _on_accent(th) if filled else Color(th.fg)
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
	draw_string(font, rb.position + Vector2(rb.size.x / 2 - _text_w("Resume", 30) / 2, rb.size.y / 2 + 11), "Resume", HL, -1, 30, _on_accent(th))
	var pr := _prestart_btn()
	_rrect(pr, Color(1, 1, 1, 0.13), int(pr.size.y / 2))
	draw_string(font, pr.position + Vector2(pr.size.x / 2 - _text_w("Restart", 30) / 2, pr.size.y / 2 + 11), "Restart", HL, -1, 30, Color(1, 1, 1, 0.92))
	var hb := _phome()
	_rrect(hb, Color(1, 1, 1, 0.13), int(hb.size.y / 2))
	draw_string(font, hb.position + Vector2(hb.size.x / 2 - _text_w("Home", 30) / 2, hb.size.y / 2 + 11), "Home", HL, -1, 30, Color(1, 1, 1, 0.92))

# shop — scrollable sheet: Bubbles (finish chips) + Themes (rows)
const SHEET_TOP := 140.0
const SHEET_HEAD := 112.0      # fixed band with the "Shop" title + close button
func _shop_close() -> Rect2: return Rect2(W - 92, SHEET_TOP + 24, 64, 64)
func _content_y(y: float) -> float: return SHEET_TOP + SHEET_HEAD + y - shop_scroll
func _finish_chip(i: int) -> Rect2:
	var cw := (W - 60.0 - 48.0) / 5.0
	return Rect2(30.0 + i * (cw + 12.0), _content_y(58.0), cw, 108.0)
func _unlock_all_visible() -> bool: return owned.size() < Themes.ORDER.size()
func _unlock_row() -> Rect2: return Rect2(30.0, _content_y(238.0), W - 60.0, 78.0)
func _rows_base() -> float: return 238.0 + (94.0 if _unlock_all_visible() else 0.0)
func _shop_row(i: int) -> Rect2: return Rect2(30.0, _content_y(_rows_base() + i * 118.0), W - 60.0, 104.0)
func _shop_max_scroll() -> float:
	var content_h := _rows_base() + Themes.ORDER.size() * 118.0 + 20.0
	return maxf(0.0, content_h - (H - SHEET_TOP - SHEET_HEAD - 10.0))
func _shop_action(row: Rect2) -> Rect2:
	return Rect2(row.position.x + row.size.x - 184, row.position.y + row.size.y / 2 - 32, 160, 64)

func _draw_shop(th: Dictionary) -> void:
	var fg := Color(th.fg)
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))                                   # scrim
	_rrect(Rect2(0, SHEET_TOP, W, H - SHEET_TOP + 40), Color(th.panel), 36, 0, Color(0, 0, 0, 0), 14)  # rounded sheet
	# --- scrolled content ---
	draw_string(font, Vector2(40, _content_y(38)), "Bubbles", HL, -1, 26, _rgba(fg, 0.55))
	for i in FINISHES.size():
		var f: String = FINISHES[i]
		var chip := _finish_chip(i)
		var locked := not _finish_owned(f)
		if bubble_style == f:
			_rrect(chip, _rgba(Color(th.accent), 0.13), 20, 3, Color(th.accent))
		else:
			_rrect(chip, _rgba(fg, 0.05), 20)
		var pstyle: String = String(th.style) if i == 0 else f
		_draw_bubble(Vector2(chip.position.x + chip.size.x / 2, chip.position.y + 38), 21, i, 0.35 if locked else 1.0, pstyle)
		var lb: String = f.capitalize()
		draw_string(font, Vector2(chip.position.x + chip.size.x / 2 - _text_w(lb, 21) / 2, chip.position.y + 84), lb, HL, -1, 21, _rgba(fg, 0.45 if locked else 1.0))
		if locked:
			var price: int = FINISH_COSTS[f]
			var pc := Color(th.accent) if coins >= price else _rgba(fg, 0.5)
			_draw_coin_amount(chip.position.x + chip.size.x / 2, chip.position.y + 104, price, 16, pc)
	draw_string(font, Vector2(40, _content_y(222)), "Themes", HL, -1, 26, _rgba(fg, 0.55))
	if _unlock_all_visible():
		var ur := _unlock_row()
		_rrect(ur, _rgba(Color(th.accent), 0.08), 22, 2, _rgba(Color(th.accent), 0.55))
		draw_string(font, Vector2(ur.position.x + 28, ur.position.y + ur.size.y / 2 + 11), "Unlock everything", HL, -1, 30, fg)
		_draw_pill(Rect2(ur.position.x + ur.size.x - 184, ur.position.y + ur.size.y / 2 - 28, 160, 56), PRICE_ALL, th, true)
	for i in Themes.ORDER.size():
		var id: String = Themes.ORDER[i]
		var t: Dictionary = Themes.THEMES[id]
		var rect := _shop_row(i)
		if rect.position.y + rect.size.y < SHEET_TOP + SHEET_HEAD or rect.position.y > H:
			continue   # off-screen row
		var is_owned := owned.has(id)
		var active := theme_id == id
		if active:
			_rrect(rect, _rgba(Color(th.accent), 0.13), 22, 3, Color(th.accent))
		else:
			_rrect(rect, _rgba(fg, 0.05), 22)
		var cy := rect.position.y + rect.size.y / 2
		for s in 5:
			var dc := Vector2(rect.position.x + 44 + s * 40, cy)
			draw_circle(dc, 15, Color(t.palette[s]))
			draw_arc(dc, 15, 0, TAU, 24, _rgba(fg, 0.18), 1.5, true)   # keeps white swatches visible on the sheet
		draw_string(font, Vector2(rect.position.x + 262, cy - 2), t.name, HL, -1, 34, fg)
		var tier := _tier(id)
		var sub := "Free"
		if tier == "coins":
			sub = "Coin unlock"
		elif tier == "premium":
			sub = "Premium theme"
		draw_string(font, Vector2(rect.position.x + 262, cy + 32), sub, HL, -1, 22, _rgba(fg, 0.6))
		var ar := _shop_action(rect)
		if is_owned:
			_draw_pill(ar, "Applied" if active else "Apply", th, active)
		elif tier == "coins":
			var price: int = t.coins
			var afford := coins >= price
			_rrect(ar, Color(th.accent) if afford else _rgba(fg, 0.08), int(ar.size.y / 2), 0, Color(0, 0, 0, 0), 3 if afford else 0)
			_draw_coin_amount(ar.position.x + ar.size.x / 2, ar.position.y + ar.size.y / 2 + 9, price, 26, _on_accent(th) if afford else _rgba(fg, 0.5))
		else:
			_draw_pill(ar, PRICE, th, true)
	# --- fixed header, drawn over the scrolled content ---
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(th.panel)
	hs.corner_radius_top_left = 36
	hs.corner_radius_top_right = 36
	draw_style_box(hs, Rect2(0, SHEET_TOP, W, SHEET_HEAD))
	draw_string(font, Vector2(40, SHEET_TOP + 74), "Shop", HL, -1, 50, fg)
	var ct := str(coins)
	var cx := W - 116 - _text_w(ct, 30) / 2.0 - 11.0
	_draw_coin_amount(cx, SHEET_TOP + 67, coins, 30, fg)
	var cb := _shop_close()
	_rrect(cb, _rgba(fg, 0.10), int(cb.size.y / 2))
	draw_string(font, cb.position + Vector2(cb.size.x / 2 - _text_w("X", 32) / 2, cb.size.y / 2 + 12), "X", HL, -1, 32, fg)

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
func _home_levels() -> Rect2: return Rect2(W / 2 - 190, H * 0.52 - 70, 380, 108)
func _home_endless() -> Rect2: return Rect2(W / 2 - 190, H * 0.52 + 54, 380, 108)
func _home_themes() -> Rect2: return Rect2(W / 2 - 190, H * 0.52 + 178, 380, 92)
func _home_sound() -> Rect2: return Rect2(W - 96, 44, 68, 68)
func _home_about() -> Rect2: return Rect2(W / 2 - 160, H - 130, 320, 74)

func _draw_home(th: Dictionary) -> void:
	var accent := Color(th.accent)
	var fg := Color(th.fg)
	draw_string(font, Vector2(W / 2 - _text_w("Sheen", 120) / 2, H * 0.27), "Sheen", HL, -1, 120, accent)
	draw_string(font, Vector2(W / 2 - _text_w("bubble shooter", 30) / 2, H * 0.27 + 48), "bubble shooter", HL, -1, 30, _rgba(fg, 0.55))
	if best_score > 0:
		var bt := "Best %d" % best_score
		draw_string(font, Vector2(W / 2 - _text_w(bt, 26) / 2, H * 0.27 + 92), bt, HL, -1, 26, _rgba(fg, 0.45))
	for i in 5:
		_draw_bubble(Vector2(W / 2 + (i - 2) * 78, H * 0.40), 30, i)
	_draw_pill(_home_levels(), "Levels", th, true)
	_draw_pill(_home_endless(), "Endless", th, false)
	_draw_pill(_home_themes(), "Shop", th, false)
	_draw_sound_icon(_home_sound(), th)
	var ab := _home_about()
	draw_string(font, ab.position + Vector2(ab.size.x / 2 - _text_w("About", 26) / 2, ab.size.y / 2 + 9), "About", HL, -1, 26, _rgba(fg, 0.6))

# ---------- level select ----------
func _sel_back() -> Rect2: return Rect2(28, 44, 128, 64)
func _sel_cell(i: int) -> Rect2:
	var cw := 136.0
	var gap := 16.0
	var x0 := (W - (4 * cw + 3 * gap)) / 2
	var y0 := H * 0.19
	return Rect2(x0 + (i % 4) * (cw + gap), y0 + (i / 4) * (cw + gap), cw, cw)

var dev_all_levels := false   # KEY_L toggle (keyboard-only, not saved): preview any level

func _level_unlocked(i: int) -> bool:
	return dev_all_levels or i == 0 or int(level_stars.get(i - 1, 0)) > 0

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		var ang := -PI / 2 + k * PI / 5
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)

func _draw_select(th: Dictionary) -> void:
	var fg := Color(th.fg)
	draw_string(font, Vector2(W / 2 - _text_w("Levels", 64) / 2, H * 0.12), "Levels", HL, -1, 64, Color(th.accent))
	var bb := _sel_back()
	_rrect(bb, _rgba(fg, 0.09), 18)
	draw_string(font, bb.position + Vector2(bb.size.x / 2 - _text_w("Back", 26) / 2, bb.size.y / 2 + 9), "Back", HL, -1, 26, fg)
	for i in Levels.LEVELS.size():
		var cell := _sel_cell(i)
		var stars: int = level_stars.get(i, 0)
		var unlocked := _level_unlocked(i)
		var frontier := unlocked and stars == 0
		if frontier:
			_rrect(cell, _rgba(Color(th.accent), 0.13), 24, 3, Color(th.accent))
		else:
			_rrect(cell, _rgba(fg, 0.09 if unlocked else 0.04), 24)
		var cx := cell.position.x + cell.size.x / 2
		if not unlocked:
			var lc := _rgba(fg, 0.3)
			var ly := cell.position.y + cell.size.y / 2
			_rrect(Rect2(cx - 13, ly - 2, 26, 20), lc, 5)
			draw_arc(Vector2(cx, ly - 2), 9, PI, TAU, 12, lc, 4.0)
			continue
		var num := str(i + 1)
		draw_string(font, Vector2(cx - _text_w(num, 44) / 2, cell.position.y + 62), num, HL, -1, 44, fg)
		for s in 3:
			var col := Color(th.accent) if s < stars else _rgba(fg, 0.15)
			_draw_star(Vector2(cx + (s - 1) * 30, cell.position.y + 94), 12, col)

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
		"Levels: pick your bubble colour, then",
		"clear every bubble before shots run out.",
		"Spare shots earn up to three stars.",
		"Endless: new rows keep coming — survive",
		"the line as long as you can.",
		"",
		"Popping earns coins. Spend them in the",
		"shop on new colour themes and bubble",
		"styles — gloss, neon, matte or clear.",
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
		draw_dashed_line(Vector2(0, loss_y), Vector2(W, loss_y), _rgba(Color(th.accent), 0.55), 3.5, 14.0)
		_draw_aim()
		if flying != null:
			_draw_bubble(flying.pos, r, flying.ci)
		if not board.over and not shop_open:
			_draw_bubble(Vector2(shooter_x, shooter_y), r * 1.08, current_ci)
			if mode == "levels":
				var live := _picker_colors()
				for k in live.size():
					var pc := _picker_center(k)
					if live[k] == current_ci:
						draw_arc(pc, r * 0.62 + 7, 0, TAU, 32, Color(th.accent), 4.0, true)
					_draw_bubble(pc, r * 0.62, live[k])
			else:
				_draw_bubble(Vector2(W - r * 1.4, shooter_y + r * 0.2), r * 0.62, next_ci, 0.9)
		draw_rect(Rect2(0, 0, W, HEADER_H), Color(th.panel))
		draw_polygon(
			PackedVector2Array([Vector2(0, HEADER_H), Vector2(W, HEADER_H), Vector2(W, HEADER_H + 16), Vector2(0, HEADER_H + 16)]),
			PackedColorArray([Color(0, 0, 0, 0.10), Color(0, 0, 0, 0.10), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		var hud_title := "Lv %d" % (level_i + 1) if mode == "levels" else "Sheen"
		draw_string(font, Vector2(34, 76), hud_title, HL, -1, 50, Color(th.accent))
		var sc := str(board.score)
		draw_string(font, Vector2(W / 2 - _text_w(sc, 50) / 2, 76), sc, HL, -1, 50, Color(th.fg))
		if mode == "levels" and not board.over:
			var st := "Shots  %d" % shots_left
			draw_string(font, Vector2(28, shooter_y + 12), st, HL, -1, 34, _rgba(Color(th.fg), 0.75) if shots_left > 3 else Color(th.accent))
		if not paused and not shop_open and not board.over:
			_draw_top_buttons(th)
		if board.over:
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
			var title := "Cleared!" if board.won else "Blocked!"
			var sub := "Score %d   ·   tap to restart" % board.score
			if mode == "levels":
				if board.won:
					title = "Level %d Clear!" % (level_i + 1)
					sub = "tap to continue" if level_i + 1 < Levels.LEVELS.size() else "all levels cleared!"
				else:
					title = "Out of Shots!" if shots_left <= 0 else "Blocked!"
					sub = "tap to retry"
			draw_string(font, Vector2(W / 2 - _text_w(title, 66) / 2, H / 2 - 40), title, HL, -1, 66, Color(1, 1, 1))
			if mode == "levels" and board.won:
				for s in 3:
					var col := Color("#f7cf4a") if s < last_stars else Color(1, 1, 1, 0.25)
					_draw_star(Vector2(W / 2 + (s - 1) * 64, H / 2 + 30), 26, col)
			var sub_y := H / 2 + (96 if mode == "levels" and board.won else 20)
			draw_string(font, Vector2(W / 2 - _text_w(sub, 32) / 2, sub_y), sub, HL, -1, 32, Color(1, 1, 1, 0.9))
			if run_coins > 0:
				var ut := "+%d coins" % run_coins
				var cw := 28 * 0.34 * 2.0 + 8.0 + _text_w(ut, 28)
				_draw_coin(Vector2(W / 2 - cw / 2 + 9, sub_y + 46), 9.5)
				draw_string(font, Vector2(W / 2 - cw / 2 + 27, sub_y + 56), ut, HL, -1, 28, Color(1, 1, 1, 0.95))
	elif screen == "select":
		_draw_select(th)
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
		if _shop_close().has_point(pos) or pos.y < SHEET_TOP:   # X, or tap on the scrim
			shop_open = false
			queue_redraw()
			return
		if pos.y < SHEET_TOP + SHEET_HEAD:
			return   # dead zone: fixed header band
		for i in FINISHES.size():
			if _finish_chip(i).has_point(pos):
				_buy_finish(FINISHES[i])   # no-op if unaffordable; applies if owned
				return
		if _unlock_all_visible() and _unlock_row().has_point(pos):
			# Mock-unlock like single themes; StoreKit "unlock all" bundle hooks in here.
			for id in Themes.ORDER:
				owned[id] = true
			for f in FINISH_COSTS:
				owned_finishes[f] = true
			_save()
			shop_scroll = clampf(shop_scroll, 0.0, _shop_max_scroll())
			queue_redraw()
			return
		for i in Themes.ORDER.size():
			if _shop_row(i).has_point(pos):
				_buy_or_apply(Themes.ORDER[i])
				return
		return
	if screen == "select":
		if _sel_back().has_point(pos):
			screen = "home"
		else:
			for i in Levels.LEVELS.size():
				if _sel_cell(i).has_point(pos) and _level_unlocked(i):
					mode = "levels"
					level_i = i
					screen = "game"
					_new_game()
					break
		queue_redraw()
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
			shop_scroll = 0.0
		elif _home_about().has_point(pos):
			about_open = true
		elif _home_levels().has_point(pos):
			screen = "select"
		elif _home_endless().has_point(pos):
			mode = "endless"
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
		if mode == "levels" and board.won:
			if level_i + 1 < Levels.LEVELS.size():
				level_i += 1     # straight into the next level
				_new_game()
			else:
				screen = "select"
				queue_redraw()
		else:
			_new_game()          # retry (levels) / new run (endless)
		return
	if _pause_btn().has_point(pos):
		paused = true
		queue_redraw()
		return
	if _shop_btn().has_point(pos):
		shop_open = true
		shop_scroll = 0.0
		queue_redraw()
		return
	var pick := _picker_hit(pos)
	if pick != -1:
		current_ci = pick
		queue_redraw()
		return
	# otherwise it's a fire (handled on release via aiming)

func _input(event: InputEvent) -> void:
	if shop_open and not about_open and event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		shop_scroll = clampf(shop_scroll + (60.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -60.0), 0.0, _shop_max_scroll())
		queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_global_mouse_position()
		if event.pressed:
			if shop_open and not about_open:
				# defer to release: a still press is a tap, a moving press scrolls the sheet
				shop_pressing = true
				shop_moved = false
				shop_start = mp
				shop_last = mp
				return
			# UI hit-tests happen on press; only start aiming if the press is in open play
			if screen != "game" or about_open or paused or board.over or _pause_btn().has_point(mp) or _shop_btn().has_point(mp) or _picker_hit(mp) != -1:
				_click(mp)
			else:
				aim = mp
				has_aim = true
				aiming = true
				queue_redraw()
		else:
			if shop_pressing:
				shop_pressing = false
				if not shop_moved:
					_click(mp)
				return
			if aiming:
				aim = mp
				_fire()
				aiming = false
				queue_redraw()
	elif event is InputEventMouseMotion:
		if shop_pressing:
			var mp := get_global_mouse_position()
			shop_scroll = clampf(shop_scroll - (mp.y - shop_last.y), 0.0, _shop_max_scroll())
			shop_last = mp
			if absf(mp.y - shop_start.y) > 12.0:
				shop_moved = true
			queue_redraw()
		elif aiming:
			aim = get_global_mouse_position()
			has_aim = true
			queue_redraw()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_new_game()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if not shop_open and screen == "game" and not board.over:
				paused = not paused
				queue_redraw()
		elif event.keycode == KEY_L:
			# dev shortcut: unlock every level for this session (not saved)
			if screen == "select":
				dev_all_levels = not dev_all_levels
				queue_redraw()
		elif event.keycode == KEY_0:
			# dev shortcut: +500 score (and its coins) to exercise the shop economy
			if screen == "game" and not board.over:
				board.score += 500
				_earn(500)
				queue_redraw()
		else:
			# dev shortcut: number keys jump to any theme (unlocks it too)
			for i in Themes.ORDER.size():
				if event.keycode == KEY_1 + i:
					_buy_or_apply(Themes.ORDER[i])
					break
