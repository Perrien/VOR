# VOR Navigator — Web Port

This folder is independent of the Swift/Xcode application. It is the gradual
browser version of the Myosia VOR navigation project.

## Step 8: NAV 1 CDI

`index.html` supplies the page structure, including an empty marker layer above
the chart, an aircraft marker, aircraft heading and speed controls, a
selected-station details card, and a NAV 1 instrument. `styles.css` supplies the
page, marker, selection, keyboard-focus, aircraft, and control appearance.
`app.js` fetches `assets/VORStations.json`, creates one button per station, then
converts the station's normalized coordinates (0 through 1) into screen
positions. Clicking or keyboard-activating a marker updates the details card;
the Tune NAV 1 button stores that station as the radio's tuned station and
updates the NAV 1 instrument. NAV 1 now includes an OBS course control and a
simple CDI needle, TO/FROM flag, and station radial. The instrument updates when
the plane moves, the OBS changes, or the tuned station changes. Clicking the map
reverses that conversion: browser pixels become the plane's normalized map
position. The Start flight button runs a browser animation loop that moves the
plane by its speed and heading. Training time is 60×, so one real second equals
one simulated minute.

The map and authored JSON content are copied into `assets/` so the web project
can evolve without depending on Xcode's asset catalog.

To preview it locally, open `index.html` in a browser. A small local web server
is preferable once we begin loading JSON with JavaScript in Step 2.
