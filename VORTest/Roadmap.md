# VORTest Roadmap

## Vision
A playable game that teaches VOR navigation: pilot a plane across a map using
simulated VOR beacons, radials, and course deviation indicators — the way real
pilots learn to fly airways.

## Decisions needed (blocking)
- Coordinate model — screen-space points vs. a real lat/long + heading model.
  Blocks: VOR bearing math, realistic movement.
- Movement model — free drag (current) vs. heading + airspeed simulation.
  Blocks: gameplay loop, CDI/needle behavior.

## Now (in progress)
- [x] Flat map with a draggable plane icon.

## Next (committed, not started — priority-ordered)
### P1 — Must have soon
- [x] Place VOR stations on the map (5, random, frequency-labelled).
- [ ] Compute and display the radial from the plane to a tuned VOR.
### P2 — Important but can wait
- [ ] Course Deviation Indicator (CDI) instrument.
- [ ] OBS (Omni Bearing Selector) control.
### P3 — Nice to have
- [ ] Multiple VOR stations / airways.
- [ ] Plane heading rotation based on movement direction.

## Later (ideas, not yet committed)
- [ ] Wind drift simulation.
- [ ] Navigation challenges / scoring.
- [ ] DME (distance measuring equipment) readout.

## Shipped
- [x] Flat map + draggable plane prototype (2026-09-08).
- [x] 5 randomly placed, frequency-labelled VOR stations (2026-09-08).
- [x] Real map — the continent of Myosia (rasterized from `Myosia_base.svg`),
      aspect-fit over an ocean fill (2026-09-09).
- [x] 5 fixed VOR beacons (WES/CTR/NOR/EST/SUD) hand-placed on land (2026-09-09).
- [x] Station data moved out of code into bundled `VORStations.json` (2026-09-09).
- [x] Tune NAV radios by typing a station identifier (2026-09-09).
- [x] Map control panel: zoom (scroll wheel + slider), drag-to-pan when zoomed,
      and a VOR layer show/hide checkbox (2026-09-09).
- [x] Plane control: heading indicator + press-and-hold turn buttons; plane icon
      on the map rotates to match the heading (2026-09-09).
- [x] Proper aeronautical VOR/VOR-DME/VORTAC chart symbols, drawn as vectors (2026-09-09).
- [x] Markers and labels stay constant screen size while zooming (2026-09-09).

## Open questions
- ~~What visual style for the map — sectional-chart look, or clean/abstract?~~
  Resolved: hand-drawn fantasy continent (Myosia).
- Should ocean be off-limits for the plane, or free to fly over (currently free)?
