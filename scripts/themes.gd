extends RefCounted
## Theme catalog. `sheen` (glossy) is the free default; the rest are unlocks.
## A theme = background/accent mood + a 6-color bubble palette. Gameplay uses
## palette[0..4]; palette[5] is a spare (decorative only). All 5 in-play colors
## are tuned to stay distinguishable under deuteranopia/protanopia (min Lab
## dE >= 26 simulated, >= 38 normal) and to hold >= 1.5 contrast against `bg`
## on light themes. style: "gloss" | "neon" | "matte" | "clear" — the default
## bubble finish; the player can override it from the shop's Bubbles chips.
## `panel` is the surface color for the header bar + shop sheet + buttons.
## Tiers: sheen is free; a theme with a `coins` key is bought with coins earned
## in play (10 score = 1 coin); everything else is a premium IAP.

## Shop order: free + score-unlock themes first, then the premium tier.
const ORDER := ["sheen", "cotton", "meadow", "midnight", "sunset", "crimson", "neon", "matte", "glacier", "reef", "latte", "arcade"]

const THEMES := {
	"sheen": {"name": "Sheen", "style": "gloss", "bg": "#eaf1fb", "bg2": "#dbe7f6", "fg": "#1f2a37", "accent": "#3d7edb", "panel": "#ffffff",
		"palette": ["#f0439a", "#2ac5ee", "#239a4c", "#f0a80e", "#5661f4", "#ff8a4d"]},
	"cotton": {"name": "Cotton Candy", "style": "gloss", "coins": 50, "bg": "#ffe9f4", "bg2": "#ffd8ec", "fg": "#5a3a4d", "accent": "#ef4d92", "panel": "#fff6fb",
		"palette": ["#f675ac", "#4199fb", "#29ad56", "#ecac13", "#7b2ff0", "#ffb38a"]},
	"meadow": {"name": "Meadow", "style": "gloss", "coins": 150, "bg": "#e8f6ea", "bg2": "#d2ecd6", "fg": "#26402c", "accent": "#2e8b47", "panel": "#f6fdf7",
		"palette": ["#2e7953", "#f16f36", "#52a1df", "#ffba02", "#9e4ff1", "#ff5d9e"]},
	"midnight": {"name": "Midnight", "style": "gloss", "coins": 300, "bg": "#060a18", "bg2": "#0e1a3a", "fg": "#dce7ff", "accent": "#4d9fff", "panel": "#101b38",
		"palette": ["#3c8fff", "#60defb", "#1ae680", "#f54799", "#fde443", "#8f7bff"]},
	"crimson": {"name": "Crimson", "style": "neon", "bg": "#100407", "bg2": "#2a0a12", "fg": "#ffe6ea", "accent": "#ff3b5c", "panel": "#1e0a10",
		"palette": ["#fa121e", "#f8d83b", "#ff99e0", "#c831fd", "#2c9681", "#ff8a3d"]},
	"sunset": {"name": "Sunset", "style": "gloss", "coins": 500, "bg": "#3a1836", "bg2": "#7a2f4a", "fg": "#ffe9de", "accent": "#ff8a4d", "panel": "#2e1530",
		"palette": ["#f95b10", "#ff3363", "#ffe433", "#49cfad", "#56a5f7", "#c06bff"]},
	"neon": {"name": "Neon", "style": "neon", "bg": "#0a0b16", "bg2": "#141634", "fg": "#eaf0ff", "accent": "#00f0ff", "panel": "#171a33",
		"palette": ["#28e0fe", "#ff0095", "#b2ff1a", "#a96cf9", "#fa6142", "#ffe14d"]},
	"matte": {"name": "Matte", "style": "matte", "bg": "#f4eee2", "bg2": "#efe7d6", "fg": "#2c2a26", "accent": "#cf5a3d", "panel": "#fffdf8",
		"palette": ["#de4a41", "#34bdaa", "#3d63f2", "#eca009", "#b26ecf", "#5fbd6b"]},
	"glacier": {"name": "Glacier", "style": "clear", "bg": "#e6f3fa", "bg2": "#d3ecf7", "fg": "#14303c", "accent": "#1487c8", "panel": "#f3fafd",
		"palette": ["#4ba6f1", "#16c5c4", "#f91f61", "#ee9c0a", "#8341f1", "#9adcf5"]},
	"reef": {"name": "Reef", "style": "gloss", "bg": "#d9f6ef", "bg2": "#c2efe6", "fg": "#113c33", "accent": "#f4593b", "panel": "#f0fdf9",
		"palette": ["#ee562b", "#2051e7", "#ffb300", "#d677e9", "#2c8464", "#ff9d76"]},
	"latte": {"name": "Latte", "style": "matte", "bg": "#f3e9dc", "bg2": "#eaddcb", "fg": "#38291f", "accent": "#a0603a", "panel": "#fdf8f1",
		"palette": ["#d05542", "#3abbaa", "#3050d8", "#e29c08", "#a049ab", "#c9a227"]},
	"arcade": {"name": "Arcade", "style": "neon", "bg": "#0d0221", "bg2": "#1c0b45", "fg": "#eae6ff", "accent": "#ff2079", "panel": "#1b0f3e",
		"palette": ["#fa1b8c", "#1ac2ff", "#49f034", "#f5f4f4", "#4464fc", "#ffd23d"]},
}
