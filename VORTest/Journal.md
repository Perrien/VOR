# The VORTest Journal

## The Big Picture
Ever seen a pilot twist a knob and chase a wobbling needle to stay on course?
That's VOR navigation — flying along invisible radio "spokes" that beam out from
ground stations. VORTest is a game that turns that skill into play. Right now
it's a baby: a flat map and a little plane you can drag around. But the dream is
a proper nav trainer disguised as a game.

## Architecture Deep Dive
Think of the app like a stage play. `VORTestApp` is the theater that opens the
doors (the window). `ContentView` is the stage. On that stage:

- `FlatMap` is the painted backdrop — the continent of **Myosia**, an ocean-fringed
  landmass drawn from artwork, letterboxed (aspect-fit) over an ocean-blue fill.
- `PlaneIcon` is the actor — a single SF Symbol airplane, tinted and rotated.
- `VORStationView` are the supporting cast — five fixed VOR beacons (WES, CTR, NOR,
  EST, SUD) planted on the land.
- `MapView` is the director. It remembers where the plane is and listens for
  drag gestures, moving the actor around the stage while keeping it from
  wandering off into the wings (bounds clamping).

The one rule that keeps the whole stage honest: **everything is positioned against
`FlatMap.fittedRect(in:)`**, the single rect where the map image actually lands.
Because the artwork keeps its own aspect ratio, the map area almost never matches
it — so stations and the plane are placed relative to the fitted rect, not the raw
container. Change how the map is fitted in one place and the beacons follow.

## The Codebase Map
- `VORTest/VORTestApp.swift` — app entry point.
- `VORTest/ContentView.swift` — everything visual right now: `ContentView`,
  `MapView`, `FlatMap`, `PlaneIcon`. Small enough to live in one file; we'll
  split it once VOR instruments arrive.

## Tech Stack & Why
- **SwiftUI** — declarative UI means the plane's position is just state; move the
  state, the view follows. Perfect for a game where things constantly move.
- **A rasterized map image** — the world is a hand-drawn Inkscape SVG (`Myosia_base.svg`).
  SwiftUI can't render SVG natively, so we bake it to a PNG once and ship it in the
  asset catalog (`MyosiaMap.imageset`). Vectors are lovely for authoring, pixels are
  lovely for a phone GPU.
- **SF Symbols** for the plane and beacons — free, crisp at any size, easy to recolor.

## The Journey
- **Drag that doesn't jump:** The classic SwiftUI trap is treating
  `DragGesture.translation` as an absolute position — the object teleports on the
  next drag. We snapshot the plane's position at drag start (`dragStartPosition`)
  and add the translation to *that*, so drags accumulate smoothly and pick up
  right where you left off.
- **Centering without a magic number:** The plane starts centered, but we don't
  know the window size until layout. Trick: keep `planePosition` optional and
  fall back to the map center (`imageRect.midX/midY`) until the first drag sets it.
- **Bringing a fantasy map to life:** The map arrived as a 723KB Inkscape SVG.
  First instinct — `qlmanage -t` to rasterize it — betrayed us: it squashed the
  1748×1254 map into a distorted 2400×2400 square. Second try, a headless `WKWebView`
  snapshot with the SVG referenced as an `<img>`, came back blank white (the local
  file load was blocked). The fix that stuck: **inline the SVG markup straight into
  the HTML** and snapshot that — faithful aspect, crisp at 2× (3496×2508).
- **Press-and-hold to turn:** A tap-once button can't fly a plane — you want to *hold*
  to keep turning. AppKit `Button`s don't do press-and-hold, so `HoldTurnButton` uses a
  zero-distance `DragGesture` (onChanged = pressed, onEnded = released) to drive a
  `Task` loop that ticks ~60×/s. We pass the tick's `dt` to the caller so the turn rate
  is a clean "degrees per second" (60°/s) regardless of frame timing — no Combine timer
  needed, in keeping with the project's async/await preference. Heading feeds three
  things at once: the numeric readout, the rotating compass card (`-heading`), and the
  map plane icon (rotated by `heading − 90`). Pinning down that offset took two wrong
  guesses: the `airplane` SF Symbol points **east** by default, not north or northeast,
  so `−45°` left it pointing NE and `0°` left it pointing E — only `−90°` faces it north
  at heading 0. Lesson: verify a symbol's default orientation before trusting intuition.
- **Zoom the map, not the map pins:** Scaling the whole map group made the VOR symbols
  and labels balloon as you zoomed — useless when the whole point of zooming is to
  separate crowded stations. The fix is a split: only the **artwork** gets `.scaleEffect`,
  while markers live in an unscaled overlay and are *positioned* by hand with the exact
  same transform the artwork uses (`(p − center)·zoom + center + pan`). Pixels stay
  put; positions track the terrain. The subtle part is keeping the manual formula and
  SwiftUI's `.scaleEffect(anchor: .center).offset` in lockstep — same center, offset
  applied after the scale — or the pins slide off their airports.
- **The hexagon with a missing side (`closeSubpath` won't stroke):** The VOR hexagon kept
  drawing as a lopsided 5-sided shape with the upper-left edge gone. It *looked* rotated,
  but the vertices printed perfectly symmetric and a debug midline rendered dead
  horizontal — so the geometry was fine. The real tell was in the pixels: the topmost
  black pixels clustered only on the right, and a close-up screenshot showed a clean gap
  where the left point should meet the top edge. Cause: the path drew five edges with
  `addLines` and left the sixth (the closing edge back to the start) to `closeSubpath()`
  — and **`closeSubpath()`'s segment doesn't get stroked** here. Fix: list every edge
  explicitly, including the closing one back to `topLeft`. Lesson: for a *stroked* outline,
  don't trust `closeSubpath()` to draw the closing side — spell it out. (This bit
  twice: the same omission turned the VORTAC's filled rectangular tabs into triangles,
  because the dropped closing edge collapsed each quad to three points. Fixed the same
  way — list all four corners back to the start.)
- **Real chart symbols, drawn as vectors:** Swapped the placeholder antenna glyph for the
  actual aeronautical navaid symbols, drawn in a `Canvas` from a flat-top hexagon:
  bare (VOR), boxed (VOR-DME), or with three filled TACAN tabs extruded along its outer
  edges (VORTAC), chosen by the station's `type`. Vectors mean they stay razor-sharp at
  the constant on-screen size, and a faint white shadow keeps black symbols legible over
  both pale lowlands and dark highlands.
- **A map camera without a coordinate-space headache:** Zoom + pan meant transforming
  the whole map (art, beacons, plane) as one group with `.scaleEffect(zoom).offset(pan)`.
  The trap: once you scale a view, what does a drag's `translation` even mean — screen
  points or map points? We dodged the guesswork by pinning both gestures to a *named*
  coordinate space (`"mapArea"`) declared outside the scale, so translations are always
  screen points. Panning maps 1:1 to the offset; the plane, which lives in unscaled
  map-space, just divides translation by `zoom`. Pan is clamped to half the overflow so
  you can never drag ocean-of-nothing into view (and it's pinned to zero at 1×).
- **Mouse wheel, meet SwiftUI:** SwiftUI still has no modifier to read a raw scroll
  wheel on a plain view (all the `scroll*` APIs are about `ScrollView`). An
  `NSViewRepresentable` that overrides `scrollWheel` *seems* right but fights the
  responder chain when it has to coexist with SwiftUI drag gestures — a background
  sibling never gets the event. The fix: a **local `NSEvent` monitor** for
  `.scrollWheel` that fires regardless of the responder chain, gated to only act when
  the pointer is over the map's window frame. Precise (trackpad) vs. line (wheel) deltas
  differ wildly in scale, so we normalize them before feeding the zoom.
- **Data out of code, into JSON:** The beacons started as a hardcoded Swift array —
  fine for five, painful for fifty. They now live in `VORStations.json` and decode at
  launch via `Decodable`. The trick that kept the rest of the app from noticing: the
  new model matches the JSON exactly (`identifier`, `location.{x,y}`, `type`, …), and
  the names the UI already used (`ident`, `relativePosition`) survive as thin computed
  properties over the new fields. Missing/malformed JSON is an authoring mistake, so
  the loader `assertionFailure`s loudly in debug rather than silently flying blind.
  Verified the decode with `RunCodeSnippet` — all five stations, all fields, no build/run.
- **Tuning by ident, not knobs:** The first radios tuned frequency with −/+ buttons —
  fine for a spreadsheet, tedious for a game. Now you type the beacon's identifier
  (WES, CTR, …) and the radio locks on, showing the frequency as confirmation. Two
  small wins made it feel right: the ident binding self-normalizes (uppercased, capped
  at three chars) so there's no stray state, and because the tuned station is recomputed
  from the ident every render, the needle wakes up the instant you finish typing — no
  submit button. Gotcha for future me: this is a **macOS** target, so the obvious
  `.textInputAutocapitalization(.characters)` doesn't exist here; uppercase in the
  binding instead.
- **Placing beacons on land, not by eyeball:** VORs must sit on land, never ocean.
  Rather than guessing coordinates off a thumbnail, we sampled the rendered pixels
  and classified each as ocean (near the SVG's base blue `#a9c9d4`) or land, printing
  an ASCII land grid. The five beacon positions were read straight off that grid, so
  "on land" is a measured fact, not a hope.

## Engineer's Wisdom
- Small, single-purpose views (`FlatMap`, `PlaneIcon`) read like sentences and
  preview independently.
- Keep gameplay state in one owner (`MapView`) rather than scattering it.
- Clamp user input at the source — the plane can never escape the map because we
  constrain the value the moment it's computed.

## If I Were Starting Over...
Nothing to regret yet — it's day one. The one thing to watch: screen-space
coordinates are fine for dragging, but VOR math wants real bearings. We'll likely
introduce a coordinate model soon (see `Roadmap.md`), so keep position logic
isolated to make that swap painless.
