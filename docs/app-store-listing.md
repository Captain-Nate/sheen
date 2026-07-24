# Sheen — App Store listing packet (v1.0)

Paste-ready values for App Store Connect. Decided 2026-07-23.

## Identity
| Field | Value |
|---|---|
| App Store name | `Sheen: Bubble Pop` |
| Subtitle (30 max) | `Bubble shooter — aim & match` |
| Bundle ID | `com.captainnate.sheen` |
| SKU | `sheen-001` |
| Primary category | Games → **Puzzle** |
| Secondary (sub)category | Games → **Casual** |
| Price | Free (premium theme IAPs) |
| Copyright | 2026 Nathaniel Mason |
| Device family | iPhone only (v1; iPad-native later) |

## Promotional text (170 max — editable anytime, no review)
```
Pop your way through 20 picture puzzles or go endless. Earn coins as you play, unlock 12 themes and 5 bubble finishes, and find your look. One finger. No ads.
```

## Description
```
Aim, match three, pop. Sheen is a clean, satisfying bubble shooter built for
one-handed play — no ads, no account, works completely offline.

TWO WAYS TO PLAY
• Levels — 20 handcrafted picture puzzles: pop your way through hearts, rockets,
  owls, whales, a space invader… each board is a little pixel-art painting.
  Pick your bubble color freely in levels — every puzzle is pure aim and
  planning, never deal luck. Clear with shots to spare for 3 stars.
• Endless — the classic climb. The ceiling descends, the multiplier grows,
  one bad shot ends it. How far can you get?

MAKE IT YOURS
• 12 themes — from glossy pastels to Midnight, retro Arcade, icy Glacier.
• 5 bubble finishes — gloss, neon, matte, or glass. Mix any finish with any theme.
• Earn coins just by playing and spend them on new looks — or unlock the
  premium themes instantly.

BUILT TO BE READABLE
Every palette is engineered for color-blind players (deuteranopia and
protanopia tested) — bubbles stay tellable-apart for everyone, in every theme.

No ads. No timers. No energy systems. Just popping.
```

## Keywords (100 max, no spaces; excludes name/subtitle words per ASO rule)
```
puzzle,match,arcade,casual,offline,relaxing,cozy,colorblind,levels,aim,themes,satisfying,popper
```
(95 chars)

## Age rating questionnaire
- All content descriptors (violence, sexual content, profanity, horror, etc.): **None**
- Gambling / simulated gambling: **No**
- Contests: **None**
- Unrestricted web access: **No**
- Advertising: **No** (the app shows no ads)
- → expected rating: **4+**

## App Privacy
- **Data Not Collected** (same as Ember). The game is fully offline: no analytics,
  no accounts, no network calls; saves are local (`user://sheen.cfg`). Purchases go
  through Apple StoreKit; we receive no user data.
- Tracking: **No**. ATT: not used.

## Export compliance
`ITSAppUsesNonExemptEncryption=false` is baked into the export preset — no
compliance prompt at upload.

## In-App Purchases (8 non-consumables — created 2026-07-23)
`com.captainnate.sheen.theme.{crimson,neon,matte,glacier,reef,latte,arcade}` at $1.99
+ `com.captainnate.sheen.themes.all` at $4.99. All ride with the v1.0 submission.
Each needs a review screenshot — reuse the shared shop screenshot (legacy size
1242×2208, padded).

## Screenshots (6.9" slot, 1320×2868 portrait)
1. Levels — Heart picture level mid-board (signature)
2. Levels — another picture board (variety)
3. Endless — bold theme, stack + multiplier
4. Shop — 12 themes, finishes, coin balance (doubles as IAP review shot at legacy size)
5. Home — clean title screen in a premium theme

## Open items
- Support URL + Privacy Policy URL — pages not yet hosted (Ember pattern:
  GitHub Pages). Needs a public repo or a corner of an existing site.
- Sandbox purchase verification (waiting on ASC product propagation).
- Release export + upload (deploy.sh builds debug; submission needs release archive).
