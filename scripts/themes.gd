extends RefCounted
## Theme catalog. `sheen` (glossy) is the free default; the rest are unlocks.
## A theme = background/accent mood + a 6-color bubble palette (kept
## distinguishable so bubbles stay matchable). style: "gloss" | "neon" | "matte".
## `panel` is the surface color for the header bar + shop sheet + buttons.

const ORDER := ["sheen", "cotton", "meadow", "midnight", "crimson", "sunset", "neon", "matte"]

const THEMES := {
	"sheen": {"name": "Sheen", "style": "gloss", "bg": "#eaf1fb", "bg2": "#dbe7f6", "fg": "#1f2a37", "accent": "#3d7edb", "panel": "#ffffff",
		"palette": ["#ff5d8f", "#3ec6e0", "#6ad15b", "#ffcf3f", "#7d7bff", "#ff8a4d"]},
	"cotton": {"name": "Cotton Candy", "style": "gloss", "bg": "#ffe9f4", "bg2": "#ffd8ec", "fg": "#5a3a4d", "accent": "#ff7ab0", "panel": "#fff6fb",
		"palette": ["#ff9ec4", "#8fd0ff", "#a9e5a0", "#ffe08a", "#c9a9ff", "#ffb38a"]},
	"meadow": {"name": "Meadow", "style": "gloss", "bg": "#e8f6ea", "bg2": "#d2ecd6", "fg": "#26402c", "accent": "#3fae5a", "panel": "#f6fdf7",
		"palette": ["#3fae5a", "#ff7a59", "#4d9fe0", "#ffcf3f", "#b06bff", "#ff5d9e"]},
	"midnight": {"name": "Midnight", "style": "gloss", "bg": "#060a18", "bg2": "#0e1a3a", "fg": "#dce7ff", "accent": "#4d9fff", "panel": "#101b38",
		"palette": ["#4d9fff", "#3ad0e0", "#8f7bff", "#ff6ba0", "#ffd24d", "#4be0a0"]},
	"crimson": {"name": "Crimson", "style": "neon", "bg": "#100407", "bg2": "#2a0a12", "fg": "#ffe6ea", "accent": "#ff3b5c", "panel": "#1e0a10",
		"palette": ["#ff3b5c", "#ff8a3d", "#ffd23d", "#ff5da8", "#c04bff", "#3dd6c0"]},
	"sunset": {"name": "Sunset", "style": "gloss", "bg": "#3a1836", "bg2": "#7a2f4a", "fg": "#ffe9de", "accent": "#ff8a4d", "panel": "#2e1530",
		"palette": ["#ff8a4d", "#ff5d7a", "#ffd24d", "#c06bff", "#5db8ff", "#4be0a0"]},
	"neon": {"name": "Neon", "style": "neon", "bg": "#0a0b16", "bg2": "#141634", "fg": "#eaf0ff", "accent": "#00f0ff", "panel": "#171a33",
		"palette": ["#00f0ff", "#ff3ec8", "#b6ff3c", "#ffe14d", "#ff6a3d", "#9b7bff"]},
	"matte": {"name": "Matte", "style": "matte", "bg": "#f4eee2", "bg2": "#efe7d6", "fg": "#2c2a26", "accent": "#e07a5f", "panel": "#fffdf8",
		"palette": ["#ef6f6c", "#2ec4b6", "#4d8bff", "#f4c95d", "#9d6bd8", "#5fbd6b"]},
}
