# VORTest

## Overview
A game based on VOR (VHF Omnidirectional Range) navigation. The player pilots a
plane and navigates using simulated VOR radio beacons over the continent of
**Myosia**. Early prototype: a real map, a draggable plane, and two NAV radios
with working OBS/CDI instruments.

## Architecture
- SwiftUI app, standard `App` + `WindowGroup` entry point (`VORTestApp.swift`).
- `ContentView` hosts a `MapView`.
- `MapView` owns the plane position, the map camera (`zoom`/`pan`), layer
  visibility, drag handling, and the NAV radios.
- `MapControlPanel` is the right-hand sidebar: a zoom slider and layer checkboxes.
- `PlaneControlView` is the leftmost bottom-row instrument: a `HeadingIndicator`
  (rotating compass card + fixed plane silhouette) flanked by `HoldTurnButton`s that
  turn the plane while held. `heading` drives both the readout and the map plane icon.
- `ScrollWheelReader` (NSViewRepresentable) bridges mouse scroll-wheel events into
  SwiftUI for zoom — there's no first-party modifier for this on a plain view.
- `FlatMap` draws the Myosia map image over an ocean fill, aspect-fit. Its static
  `fittedRect(in:)` is the single source of truth for where the map lands.
- `VORStation` / `VORStationView` — the VOR beacons, decoded at launch from
  `VORStations.json` into `VORStation.myosia`. `VORSymbol` draws the standard
  aeronautical chart symbol per `type` from SwiftUI `Shape`s (`VORHexagon`,
  `DMESquare`, `TacanTabs`) sharing `VORGeometry` — a regular flat-top hexagon
  (points left/right, ~1.15× wider than tall), matching `Icons_of_VOR's.svg`.
- `NavRadioView` — a NAV radio tuned by typing a station identifier (e.g. "CTR");
  it resolves via `station(forIdent:)` and shows the matched frequency + CDI.
- `PlaneIcon` is the player's plane sprite.

## Station data
- VOR beacons live in `VORTest/VORStations.json` (bundled resource), decoded into
  `[VORStation]` (`Decodable`) at launch. Add/edit stations there, not in code.
- Per-station fields: `id` (internal unique ID), `name`, `identifier` (3-letter,
  shown to the user), `frequency` (MHz), `location.{x,y}` (0...1 relative to the
  map image), `type` (VOR / VOR_DME / VORTAC), `serviceVolume` (T/L/H, mapping
  to 25/40/100 NM), `elevationFT`, `dme` (bool). `identifier` must stay unique
  (tuning keys off it); positions must stay on land.

## Map asset
- The world is authored as an Inkscape SVG (`Myosia_base.svg`, at the repo root,
  outside the Xcode project). SwiftUI can't render SVG, so it's rasterized to
  `VORTest/Assets.xcassets/MyosiaMap.imageset/MyosiaMap.png` (3496×2508, 2× native).
- To re-bake after editing the SVG: render it faithfully (inline the SVG markup in
  an HTML page and snapshot via `WKWebView` — `qlmanage` distorts the aspect ratio),
  then replace the PNG in the imageset. See Journal.md for the gotchas.

## Conventions
- Modern SwiftUI, Swift Concurrency (async/await) over Combine.
- 4-space indentation, PascalCase types, camelCase members.
- `@State private var` for view-local state.

## Build/Run
Build with the Xcode `BuildProject` tool (or ⌘B in Xcode). Target: VORTest.

## Notes / Gotchas
- Plane position is tracked in the map's `GeometryReader` coordinate space and
  clamped to the map bounds during drag.
- Station `relativePosition` is 0...1 **relative to the map image rect** (not the
  full container). Positions in `VORStation.myosia` are hand-placed on land; if you
  move/rescale the map, re-verify they don't land in ocean or the lake.
- This is a **macOS app** (SDKROOT `macosx`). iOS-only SwiftUI modifiers such as
  `.textInputAutocapitalization` won't compile — the ident field uppercases inside
  its binding instead. Station idents must stay unique for tuning to be unambiguous.
- Map camera: only the map **artwork** scales via `.scaleEffect(zoom).offset(pan)`.
  Markers and the plane are kept at constant screen size and positioned by applying
  the same transform manually to their map coordinates via `MapView.screenPoint(_:mapSize:)`
  (`(p - center) * zoom + center + pan`). Keep that formula in sync with the artwork's
  `.scaleEffect`/`.offset` or markers will drift from the map.
- Gestures use the named `"mapArea"` coordinate space (outer/screen): plane-drag
  translations are divided by `zoom` to convert to map-space; `pan` is clamped so the
  scaled map always covers the area (zero pan at zoom 1).

Roadmap and feature backlog live in `Roadmap.md` — read it when planning
features or answering "what's next?".
