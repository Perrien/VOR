# VOR Navigator — Web Port

This folder is independent of the Swift/Xcode application. It is the gradual
browser version of the Myosia VOR navigation project.

## Step 1: static layout

`index.html` supplies the page structure, `styles.css` supplies its appearance,
and `app.js` is reserved for behavior in the next step. The map and authored
JSON content are copied into `assets/` so the web project can evolve without
depending on Xcode's asset catalog.

To preview it locally, open `index.html` in a browser. A small local web server
is preferable once we begin loading JSON with JavaScript in Step 2.
