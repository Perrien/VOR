# VOR Navigator — Web Port

This folder is independent of the Swift/Xcode application. It is the gradual
browser version of the Myosia VOR navigation project.

## Step 4: place the aircraft

`index.html` supplies the page structure, including an empty marker layer above
the chart, an aircraft marker, and a selected-station details card.
`styles.css` supplies the page, marker, selection, keyboard-focus, and aircraft
appearance. `app.js` fetches `assets/VORStations.json`, creates one button per
station, then converts the station's normalized coordinates (0 through 1) into
screen positions. Clicking or keyboard-activating a marker updates the details
card. Clicking the map reverses that conversion: browser pixels become the
plane's normalized map position.

The map and authored JSON content are copied into `assets/` so the web project
can evolve without depending on Xcode's asset catalog.

To preview it locally, open `index.html` in a browser. A small local web server
is preferable once we begin loading JSON with JavaScript in Step 2.
