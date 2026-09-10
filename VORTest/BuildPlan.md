# VOR Navigator — Build Outline

## Product boundary

Build a native SwiftUI application for macOS and iPadOS that teaches and tests
VOR navigation in a persistent, fictional aviation region. Instrument behavior
and geometry should be credible; places, stations, airports, and terrain are
authored for learning and interesting route-planning problems.

The first shipped experience should be a small, complete training flight:

1. Read a sectional-style chart and a short briefing.
2. Select an aircraft and depart from a named airport.
3. Tune, identify, and use two VORs to fly a planned route.
4. Review a clear debrief, including the actual flight track and constructive scoring.

Do not begin with procedural maps, real-world data, weather, or a full flight
simulator. They depend on the common simulation and content foundations below.

## Decisions to lock before feature work

| Decision | Recommendation | Why it comes first |
| --- | --- | --- |
| World | One fixed fictional region, initially 500 × 500 NM | Makes places memorable and missions deliberately designed. |
| Coordinates | Map positions in nautical miles, with north/east axes and an explicit magnetic-variation setting | Bearings, range, movement, terrain, and rendering share one meaningful coordinate system. |
| Map art | Use the supplied SVGs as base-map candidates; keep stations, airports, labels, terrain constraints, and missions separate game data | Art can change without corrupting navigation geometry. |
| Flight model | 2D top-down, real-time heading + groundspeed simulation; no pitch/roll/3D cockpit | Provides genuine navigation decisions without becoming a flight-simulator project. |
| Instruments | Two NAV receivers with VOR first; DME only after the core VOR loop is proven | Keeps the learning game focused and supports the NAV2 sampling mechanic. |
| Platforms | Mac first, but share all simulation/content code with iPad from day one | The present Xcode project is macOS-only; iPad needs adaptive UI, not separate game logic. |
| Data | Bundled authored content for the fictional world | Deterministic, testable, and easy to evolve. Real FAA data remains a distinct later mode. |

## App shape

Keep the game separate from the views. SwiftUI renders state and receives input;
a platform-independent simulation core calculates all world truth.

```text
App / navigation shell
    ├── World content: region, map calibration, stations, airports, terrain, aircraft
    ├── Simulation: movement, NAV reception, VOR/CDI, time, validation
    ├── Mission system: briefing, phases, requirements, scoring, debrief
    ├── Presentation: chart, flight view, instruments, overlays
    └── Persistence: settings, progress, saved/replayable flights
```

The current proof of concept puts views and simulation together in
`ContentView.swift`. Before the next major feature, split it into focused
areas such as `Domain`, `Simulation`, `Content`, `Features/Flight`,
`Features/Missions`, and `UI/Shared`. This is reorganization, not an
attempt to build every screen at once.

## Build sequence

### 0. Define the first lesson and cross-platform shell

**Goal:** decide what the first playable flight is, and make the app capable of
sharing its core between Mac and iPad.

- Add an iPadOS target/destination strategy while preserving one shared core.
- Define the screens: welcome/continue, regional chart, briefing, flight, pause, and debrief.
- Establish input expectations: keyboard shortcuts and pointer/trackpad controls on Mac; touch-friendly controls and adaptive panels on iPad.
- Write a one-page vertical-slice brief: aircraft, departure, destination, available VORs, required action, success criteria, and a 10–15 minute intended duration.
- Decide simulation-time behavior. Recommended: 1×, 2×, 4×, and pause.

**Exit criterion:** one concrete mission exists on paper and both platforms can
reach a placeholder flight screen without separate game logic.

### 1. Build the navigation simulation core

**Goal:** replace screen pixels and drag movement with a deterministic world.
This is the highest-leverage work in the project.

- Define world positions in NM, headings/bearings, time, and unit conversion.
- Create authored models for VOR stations, airports, aircraft profiles, and terrain areas: identifier, frequency, location, service class/range, elevation where applicable, and display metadata.
- Implement aircraft state: position, magnetic/true heading, selected airspeed, groundspeed, and a simple wind-free movement tick.
- Replace direct plane dragging with a temporary testing control that sets heading and speed; retain a developer-only reposition tool.
- Move VOR calculations out of views: station radial, selected course, TO/FROM, CDI deflection, off flag, reception, and station identification.
- Define exact instrument conventions and test known geometry: cardinal directions, course reversal, station passage, and full-scale CDI deflection.
- Add a replayable event log: position/time samples, tuning/OBS changes, heading changes, and mission events.

**Exit criterion:** identical starting state and inputs always give the same flight
and instrument readings. Geometry tests protect the educational value of the app.

### 2. Turn one supplied SVG into a calibrated chart

**Goal:** make one map asset an aviation world rather than a background image.

The folder contains a 1748 × 1254 SVG declaring a 500-NM scale
(`Myosia_base_map_green_brown.svg`) plus the Orbeilecy map. Choose one after a
visual/design review; do not merge both into the first release.

- Preserve original SVGs as source art and make a separately exported, performance-tested app asset if necessary.
- Define chart calibration: image bounds to world-NM bounds, north direction, scale, and one source of truth for conversions.
- Overlay content at world positions rather than baking it into the SVG: VOR/VORTAC symbols, frequencies, identifiers, airports, cities, labels, airspace, and later route/track lines.
- Author broad terrain/elevation zones and mountain-pass corridors as data. Version one does not need a detailed elevation raster.
- Implement a zoomable, pannable regional chart with orientation indicator, scale bar, selectable symbols, and legible labels.
- Add layers only when useful: chart labels, terrain/elevation, station coverage, planned route, and post-flight track. Do not reveal a live aircraft location in normal instrument-challenge mode.

**Exit criterion:** a station or airport at a given NM coordinate appears in the
correct place at any zoom, and its chart location exactly agrees with simulation.

### 3. Make a usable flight station

**Goal:** a player can fly and operate instruments comfortably before a mission
system is required.

- Create a flight-session store that owns simulation state and starts, pauses, resets, and advances time.
- Build flight controls: heading selector/basic autopilot-like control, speed control, rate/time control, pause, and unambiguous status.
- Promote the existing NAV1/NAV2 instruments into reusable responsive panels. Keep tuning, OBS, CDI, TO/FROM, and NAV flag; add station identifier and signal status before adding new instruments.
- Lay out the Mac version with a chart/flight area and stable instrument panel; on iPad use a compact panel or bottom sheet that leaves dials large enough to use.
- Add an optional training overlay explaining radial, selected course, CDI side, TO/FROM, and what NAV2 receives.
- Show range rules only in training/debug modes. Normal flight should communicate reception through the instrument, not glowing coverage circles.

**Exit criterion:** a new person can tune a named station, set a course, steer
the aircraft, and understand why the CDI changes.

### 4. Deliver one vertical-slice mission

**Goal:** prove the full gameplay loop before creating a large world or mission
generator.

Build one hand-authored beginner mission with no terrain restriction:

- Briefing: departure, destination, available stations, aircraft, task, and learning objective.
- Preflight: review chart and select/tune the intended first station.
- Flight phases: depart, intercept a radial, track it, use NAV2 to anticipate a transition, then reach destination area.
- Mission rules: sensible start/end envelopes, wrong-station feedback, tolerance windows, and recovery guidance rather than instant failure.
- Debrief: actual track, planned reference geometry, NAV-action timeline, and scores for radial tracking, transition prediction, turn timing, course establishment, and station management.
- Save progress and enable exact-scenario replay.

**Exit criterion:** a player can complete an understandable 10–15 minute lesson
and learn one genuine VOR skill from its debrief.

### 5. Author the training-world content system

**Goal:** make content creation repeatable instead of a code change per mission.

- Establish simple schemas for region, stations, airports, aircraft, terrain constraints, missions, objective triggers, help, and scoring thresholds.
- Create validation: duplicate identifiers/frequencies, out-of-bounds locations, impossible route legs, absent reception, terrain conflicts, and bad mission references must be caught before a build.
- Author a station hierarchy: a few high-power regional hubs, medium regional VORs, and short-range local/airport VORs. Use realistic-feeling classes around 40/80/120 NM while choosing good game geometry.
- Add 8–12 hand-authored early missions: radial recognition, FROM/TO, intercept, tracking, two-radial position fix, NAV2 radial sampling, station change, and simple multi-leg flight.
- Add DME only if it serves a specific lesson; preserve VOR-only variants so players learn radial reasoning.

**Exit criterion:** a designer can add a station or mission through content, receive
reliable validation, and avoid touching flight UI code.

### 6. Add planning, geography, and aircraft constraints

**Goal:** grow from instrument exercises into the navigation sandbox described
in the concept discussion.

- Add a preflight planning workspace: chart, aircraft limitations, destination, relevant VOR information, and player route/notes layer.
- Implement altitude as a planning constraint, not detailed vertical-flight simulation: cruising altitude, aircraft ceiling, terrain-clearance threshold, and named pass corridors.
- Add airport capabilities/location metadata, range/endurance, and a small first aircraft roster.
- Add mountain-crossing, range-choice, alternate-VOR-route, and required-station-change missions.
- Let the player plan a route but assess the actual flown track separately; never silently force the planned route.

**Exit criterion:** a route can be valid for one aircraft and invalid for another
for understandable chart-based reasons.

### 7. Generate constrained missions on the fixed world

**Goal:** gain replayability without random, poor navigation puzzles.

- Treat the authored world as a graph of airports, stations, route corridors, terrain gateways, and reception relationships.
- Define constraints by difficulty: leg length, intercept angle, station transitions, required NAV2 observation, coverage overlap, terrain restrictions, and recovery paths.
- Generate candidate routes, validate them with the real simulator, score educational quality, and reject weak/impossible results.
- Seed every generated mission so it is replayable, shareable, and debuggable.
- Start with variants of known-good templates, not a free-form “make any flight” generator.

**Exit criterion:** generated missions are consistently solvable, varied, and
explainable in debrief.

### 8. Add advanced realism and product layers

Add these only after the core loop is stable and tested.

- Wind/drift, then weather restrictions only where they make distinct navigation decisions.
- Airspace/special-use areas and richer airport procedures.
- More nuanced VOR service volume, signal reliability, Morse identification, and optional DME.
- Free navigation and custom scenario selection in the fictional world.
- Accessibility refinement, localization, achievements/progression, and optional cloud sync.
- A separate **Real World** mode backed by versioned aeronautical-data imports. Display data cycle/version and treat updates as content releases; never let it destabilize Training World.

## Explicitly defer

- 3D cockpit, realistic aerodynamics, ATC, multiplayer, and live real-world data.
- Full procedural terrain or random VOR placement.
- Many maps before one chart supports a polished vertical slice.
- Detailed weather/density altitude before altitude, terrain, and aircraft ceilings are enjoyable by themselves.
- A user-facing mission editor before the internal content format and validation workflow are settled.

## Milestone order at a glance

```text
0  First lesson definition + cross-platform shell
1  Deterministic NM-based simulation + verified VOR math
2  Calibrated chart based on one supplied SVG
3  Usable real-time flight + two-NAV instrument station
4  One complete hand-authored lesson + debrief
5  Data-driven world + authored lesson catalogue
6  Planning, terrain passes, aircraft constraints
7  Constrained procedural missions on the same world
8  Advanced realism + optional Real World mode
```

The primary rule: every stage leaves a playable, testable experience. The map,
simulation, and first lesson are the foundation; visual detail and a huge feature
list become valuable only once that loop is fun.

