#!/usr/bin/env python3
"""Sheen level designer: rasterizes geometric shape compositions onto the
hex bubble lattice at TRUE rendered cell centers (odd rows shift +r), so
pictures don't shear. Validates anchoring, computes shot bounds, rejects
keystones (one-shot clears), and emits GDScript rows + an SVG proof sheet.
Run:  python3 tools/levelgen.py   (from the repo root)
Then: eyeball build/web/levels.svg, paste build/levels_out.txt into
scripts/levels.gd."""
import math

R = 1.0                    # bubble radius (design unit)
ROWH = math.sqrt(3.0)      # row height in r-units
COLS = 11
MAXROWS = 11

def centers(rows=MAXROWS):
    out = []
    for row in range(rows):
        odd = row % 2 == 1
        n = COLS - 1 if odd else COLS
        for col in range(n):
            x = (2.0 if odd else 1.0) + col * 2.0
            y = 1.0 + row * ROWH
            out.append((row, col, x, y))
    return out

# ---- shape primitives (return True if point inside) ----
def circle(cx, cy, r):
    return lambda x, y: (x-cx)**2 + (y-cy)**2 <= r*r
def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1.0
def ring(cx, cy, r1, r2):
    return lambda x, y: r1*r1 <= (x-cx)**2 + (y-cy)**2 <= r2*r2
def rect(x0, y0, x1, y1):
    return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1
def tri(p1, p2, p3):
    def sign(a, b, p):
        return (p[0]-b[0])*(a[1]-b[1]) - (a[0]-b[0])*(p[1]-b[1])
    def inside(x, y):
        p = (x, y)
        d1, d2, d3 = sign(p1,p2,p), sign(p2,p3,p), sign(p3,p1,p)
        neg = d1 < 0 or d2 < 0 or d3 < 0
        pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (neg and pos)
    return inside
def heart(cx, cy, s):
    def inside(x, y):
        u = (x-cx)/s; v = -(y-cy)/s
        return (u*u + v*v - 1)**3 - u*u * v**3 <= 0
    return inside
def halfup(cy):  return lambda x, y: y <= cy
def halfdown(cy): return lambda x, y: y >= cy
def AND(a, b): return lambda x, y: a(x, y) and b(x, y)
def NOT(a): return lambda x, y: not a(x, y)
def sector_stripes(cx, cy, n, ca, cb):
    """alternating angular sectors -> returns color chooser used specially"""
    def which(x, y):
        ang = math.atan2(y-cy, x-cx)
        k = int(((ang + math.pi) / (2*math.pi)) * n) % 2
        return ca if k == 0 else cb
    return which
def by_x(x0, ca, cb):
    return lambda x, y: ca if x < x0 else cb
def by_y(y0, ca, cb):
    return lambda x, y: ca if y < y0 else cb

# A level = list of (shape, color) painted in order (later on top),
# or (shape, chooser_fn) where chooser returns a color per point.
LEVELS = [
 ("Target", [   # rings split into left/right arcs — no keystone ring
    (circle(11, 5.9, 6.4), by_x(11, 1, 2)),
    (circle(11, 5.9, 4.3), by_x(11, 3, 4)),
    (circle(11, 5.9, 2.1), 0)]),
 ("Heart", [    # two-tone shell halves + split core
    (circle(7.4, 4.4, 3.7), 0), (circle(14.6, 4.4, 3.7), 4),
    (tri((3.8, 6.0), (11, 14.4), (18.2, 6.0)), by_x(11, 0, 4)),
    (circle(9.2, 5.4, 1.9), 3), (circle(12.8, 5.4, 1.9), 2),
    (tri((7.6, 6.2), (11, 10.6), (14.4, 6.2)), by_x(11, 3, 2))]),
 ("Smiley", [   # two-tone face + eyes + grin + blush dots
    (circle(11, 6.2, 6.1), by_x(11, 3, 1)),
    (circle(8.3, 5.3, 1.2), 4),
    (circle(13.7, 5.3, 1.2), 4),
    (circle(5.9, 8.0, 1.0), 2), (circle(16.1, 8.0, 1.0), 2),
    (AND(ring(11, 6.9, 3.1, 4.7), halfdown(8.6)), 0)]),
 ("Balloon", [  # two-tone balloon; wide crown so both halves anchor
    (circle(11, 5.0, 4.9), by_x(11, 0, 4)),
    (circle(9.2, 4.2, 1.2), 3),
    (rect(10.2, 10.2, 11.8, 11.4), 2),
    (rect(10.4, 11.4, 12.2, 16.4), 2)]),
 ("Flower", [   # alternating petal colors around a split core
    (circle(8.3, 2.6, 2.5), 0), (circle(13.7, 2.6, 2.5), 4),
    (circle(6.9, 6.6, 2.4), 4), (circle(15.1, 6.6, 2.4), 0), (circle(11, 9.6, 2.5), 4),
    (circle(11, 5.8, 2.4), 3),
    (rect(10.4, 11.4, 12.2, 16.0), 2),
    (circle(9.4, 13.6, 1.2), 2), (circle(13.6, 14.4, 1.2), 2)]),
 ("Mushroom", [ # two-tone toadstool cap + gills + stem + grass
    (AND(circle(11, 7.6, 6.5), halfup(7.9)), by_x(11, 0, 4)),
    (circle(7.7, 4.9, 1.1), 1), (circle(14.3, 4.9, 1.1), 1), (circle(11, 2.7, 1.1), 1),
    (rect(6.0, 7.9, 16.0, 8.9), 3),
    (rect(9.2, 8.9, 12.8, 14.6), 3),
    (rect(6.8, 14.6, 15.2, 15.6), 2)]),
 ("Gem", [      # faceted: light/dark halves, banded core, sparkle
    (lambda x, y: abs(x-11)/6.6 + abs(y-4.9)/5.9 <= 1.0, by_x(11, 4, 1)),
    (lambda x, y: abs(x-11)/3.7 + abs(y-4.9)/3.3 <= 1.0, by_y(4.9, 3, 2)),
    (circle(11, 4.9, 1.05), 0)]),
 ("Moon", [     # crescent split along its arc + two different stars
    (AND(circle(10, 6.6, 6.2), NOT(circle(14.2, 5.4, 5.4))), by_y(6.6, 3, 1)),
    (circle(16.8, 1.6, 1.15), 0),
    (circle(18.8, 1.8, 1.1), 2)]),
 ("Butterfly", [
    (ellipse(7.8, 4.9, 3.4, 2.9), 0), (ellipse(14.2, 4.9, 3.4, 2.9), 0),
    (ellipse(8.4, 9.4, 2.8, 2.4), 4), (ellipse(13.6, 9.4, 2.8, 2.4), 4),
    (rect(10.4, 2.2, 12.2, 11.6), 2),
    (circle(7.8, 4.9, 1.05), 3), (circle(14.2, 4.9, 1.05), 3)]),
 ("Rainbow", [
    (AND(circle(11, 12.6, 11.4), halfup(12.4)), by_x(11, 0, 4)),
    (AND(circle(11, 12.6, 9.1), halfup(12.4)), 1),
    (AND(circle(11, 12.6, 6.8), halfup(12.4)), 2),
    (AND(circle(11, 12.6, 4.5), halfup(12.4)), 3),
    (AND(circle(11, 12.6, 2.2), halfup(12.4)), 4)]),
 ("Donut", [    # icing halves over dough halves + sprinkles
    (ring(11, 7.2, 2.4, 6.0), by_x(11, 3, 2)),
    (AND(ring(11, 7.2, 2.4, 6.0), halfup(7.2)), by_x(11, 0, 1)),
    (circle(8.2, 4.6, 0.9), 2), (circle(11.2, 3.2, 0.9), 4), (circle(13.9, 4.9, 0.9), 3)]),
 ("Fish", [     # striped tropical fish
    (tri((14.5, 4.2), (19.2, 0.8), (19.2, 7.6)), 4),
    (ellipse(10, 4.2, 5.1, 3.6), lambda x, y: [1, 2, 1, 2][min(3, max(0, int((x-5.4)/2.6)))]),
    (tri((9.5, 1.6), (11.2, -0.8), (13.2, 1.8)), 4),
    (circle(7.3, 3.4, 1.0), 0)]),
 ("Umbrella", [
    (AND(circle(11, 6.2, 6.6), halfup(6.2)), sector_stripes(11, 6.2, 10, 0, 3)),
    (rect(10.4, 6.2, 12.2, 14.4), 4),
    (circle(13.2, 14.2, 1.05), 4)]),
 ("House", [    # two-tone roof + two-tone walls + door + windows
    (tri((3.2, 6.4), (11, -1.6), (18.8, 6.4)), by_x(11, 0, 2)),
    (rect(4.8, 6.4, 17.2, 13.4), by_x(11, 3, 1)),
    (rect(9.7, 9.6, 12.3, 13.4), 4),
    (circle(7.3, 8.8, 1.05), 1), (circle(14.7, 8.8, 1.05), 3)]),
 ("Tree", [     # tiered pine: tinsel bands split the canopy
    (tri((11, -6.0), (4.4, 11.4), (17.6, 11.4)), by_x(11, 2, 4)),
    (AND(tri((11, -6.0), (4.4, 11.4), (17.6, 11.4)), rect(0, 4.0, 22, 5.0)), 0),
    (AND(tri((11, -6.0), (4.4, 11.4), (17.6, 11.4)), rect(0, 7.5, 22, 8.5)), 3),
    (rect(9.8, 11.4, 12.2, 15.8), 3)]),
 ("Cat", [      # two-tone: golden top, pink muzzle
    (tri((4.6, 6.4), (5.4, 0.9), (9.8, 4.8)), 3), (tri((12.2, 4.8), (16.6, 0.9), (17.4, 6.4)), 1),
    (circle(11, 8.8, 5.5), by_x(11, 3, 1)),
    (AND(circle(11, 8.8, 5.5), halfdown(9.6)), 0),
    (circle(8.5, 7.8, 1.05), 2), (circle(13.5, 7.8, 1.05), 2),
    (circle(11, 10.4, 0.95), 4)]),
 ("Snowman", [  # scarf separates head from body; buttons + hat
    (circle(11, 10.6, 4.8), 1),
    (circle(11, 4.0, 3.3), 1),
    (rect(7.4, 5.7, 14.6, 6.7), 0),
    (rect(5.8, 0.8, 10.6, 2.4), 4),
    (circle(9.8, 4.2, 0.85), 4), (circle(12.2, 4.2, 0.85), 4),
    (circle(12, 9.7, 0.9), 3), (circle(11, 11.4, 0.9), 3)]),
 ("Invader", None),   # hand bitmap: banded variant below
 ("Sun", [      # alternating ray wedges around a banded disc
    (circle(11, 6.2, 6.5), sector_stripes(11, 6.2, 8, 0, 3)),
    (circle(11, 6.2, 4.4), by_y(6.2, 3, 0)),
    (circle(8.9, 5.2, 1.0), 4), (circle(13.1, 5.2, 1.0), 4),
    (AND(ring(11, 5.8, 2.0, 3.2), halfdown(7.2)), 4)]),
 ("Bubble", [   # the finale: quadrant rim, split fill, inner swirl, twin glints
    (circle(11, 6.2, 6.3), by_x(11, 4, 2)),
    (circle(11, 6.2, 4.9), by_x(11, 1, 0)),
    (ring(11, 6.2, 1.6, 2.8), 3),
    (circle(8.4, 3.8, 1.6), 3)]),
]

INVADER_ROWS = [
    "..2.....4..",
    "..2....4..",
    "..2222222..",
    ".22022022.",
    "44444444444",
    "4.4....4.4",
    "4.........4"]

def _sample(shapes, dy):
    grid = {}
    for row, col, x, y in centers():
        color = None
        for shape, c in shapes:
            if shape(x, y + dy):
                color = c(x, y + dy) if callable(c) and not isinstance(c, int) else c
        if color is not None:
            grid[(row, col)] = color
    return grid

def rasterize(shapes):
    # translate the whole composition up until its topmost bubble is in row 0
    dy = 0.0
    for _ in range(12):
        grid = _sample(shapes, dy)
        if not grid:
            return []
        top = min(r for r, _ in grid)
        if top == 0:
            break
        dy += top * ROWH
    maxr = max(r for r, _ in grid)
    rows = []
    for r in range(0, maxr + 1):
        n = COLS - 1 if r % 2 == 1 else COLS
        rows.append("".join(str(grid[(r, c)]) if (r, c) in grid else "." for c in range(n)))
    return rows

def neighbors(r, c, rows):
    odd = r % 2 == 1
    if odd:
        cand = [(r,c-1),(r,c+1),(r-1,c),(r-1,c+1),(r+1,c),(r+1,c+1)]
    else:
        cand = [(r,c-1),(r,c+1),(r-1,c-1),(r-1,c),(r+1,c-1),(r+1,c)]
    out = []
    for rr, cc in cand:
        if 0 <= rr < len(rows) and 0 <= cc < len(rows[rr]):
            out.append((rr, cc))
    return out

def analyze(rows):
    """anchoring floaters + cluster shot bound"""
    filled = {(r, c) for r in range(len(rows)) for c in range(len(rows[r])) if rows[r][c] != "."}
    anchored = set()
    stack = [(0, c) for c in range(len(rows[0])) if rows[0][c] != "."]
    anchored.update(stack)
    while stack:
        cur = stack.pop()
        for n in neighbors(cur[0], cur[1], rows):
            if n in filled and n not in anchored:
                anchored.add(n)
                stack.append(n)
    floaters = filled - anchored
    seen, bound = set(), 0
    clusters = []
    for cell in filled:
        if cell in seen:
            continue
        col = rows[cell[0]][cell[1]]
        stack, members = [cell], []
        seen.add(cell)
        while stack:
            cur = stack.pop()
            members.append(cur)
            for n in neighbors(cur[0], cur[1], rows):
                if n in filled and n not in seen and rows[n[0]][n[1]] == col:
                    seen.add(n)
                    stack.append(n)
        clusters.append(members)
        bound += max(1, 3 - len(members))
    # keystone check: does popping ONE cluster (plus resulting drops) clear the board?
    keystones = 0
    for members in clusters:
        remaining = filled - set(members)
        if not remaining:
            keystones += 1   # only cluster left = trivially final, ignore below
            continue
        anch = set(c for c in remaining if c[0] == 0)
        stack = list(anch)
        while stack:
            cur = stack.pop()
            for n in neighbors(cur[0], cur[1], rows):
                if n in remaining and n not in anch:
                    anch.add(n)
                    stack.append(n)
        if not anch:   # everything else drops -> one-shot clear
            keystones += 1
    keystones = max(0, keystones - (1 if len(clusters) == 1 else 0))
    return floaters, bound, len(filled), keystones

PAL = {0: "#f0439a", 1: "#2ac5ee", 2: "#239a4c", 3: "#f0a80e", 4: "#5661f4"}

def svg_board(rows, ox, oy, scale):
    parts = []
    for r in range(len(rows)):
        for c in range(len(rows[r])):
            ch = rows[r][c]
            if ch == ".":
                continue
            x = ((2.0 if r % 2 else 1.0) + c * 2.0) * scale + ox
            y = (1.0 + r * ROWH) * scale + oy
            parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{scale*0.95:.1f}" fill="{PAL[int(ch)]}"/>')
    return "".join(parts)

def main():
    cell = 7.0
    bw, bh = 24 * cell, 21 * cell
    cols = 4
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols*bw}" height="{5*bh}" style="background:#eaf1fb">']
    gd = []
    ok = True
    for i, (name, shapes) in enumerate(LEVELS):
        rows = INVADER_ROWS if shapes is None else rasterize(shapes)
        floaters, bound, bubbles, keystones = analyze(rows)
        budget = max(bound + 4, int(round(bound * 1.6)), 8)
        status = f"{name}: {bubbles} bubbles, bound {bound}, budget {budget}, rows {len(rows)}"
        if floaters:
            status += f"  FLOATERS: {sorted(floaters)}"
            ok = False
        if keystones:
            status += f"  KEYSTONES: {keystones} (one-shot clear possible)"
            ok = False
        print(status)
        ox, oy = (i % cols) * bw, (i // cols) * bh
        svg.append(f'<rect x="{ox}" y="{oy}" width="{bw}" height="{bh}" fill="none" stroke="#ccd" />')
        svg.append(f'<text x="{ox+6}" y="{oy+14}" font-family="sans-serif" font-size="12" fill="#345">{i+1}. {name}</text>')
        svg.append(svg_board(rows, ox + cell, oy + 16, cell))
        gd.append((name, budget, rows))
    svg.append("</svg>")
    import os
    base = os.path.join(os.path.dirname(__file__), "..", "build")
    os.makedirs(os.path.join(base, "web"), exist_ok=True)
    with open(os.path.join(base, "web", "levels.svg"), "w") as f:
        f.write("".join(svg))
    with open(os.path.join(base, "levels_out.txt"), "w") as f:
        for name, budget, rows in gd:
            f.write(f'\t# {name}\n\t{{"shots": {budget}, "rows": [\n')
            f.write(",\n".join(f'\t\t"{r}"' for r in rows))
            f.write("]},\n")
    print("ANCHOR OK" if ok else ">>> FLOATERS PRESENT")

main()
