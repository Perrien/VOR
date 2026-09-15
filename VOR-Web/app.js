const chartPanel = document.querySelector(".chart-panel");
const chartImage = document.querySelector("#chart-image");
const stationLayer = document.querySelector("#station-layer");
const planeMarker = document.querySelector("#plane-marker");
const planePositionReadout = document.querySelector("#plane-position");
const headingControl = document.querySelector("#heading-control");
const headingReadout = document.querySelector("#heading-readout");
const speedControl = document.querySelector("#speed-control");
const flightToggle = document.querySelector("#flight-toggle");
const flightStatus = document.querySelector("#flight-status");
const selectedStationName = document.querySelector("#selected-station-name");
const selectedStationIdent = document.querySelector("#selected-station-ident");
const selectedStationFrequency = document.querySelector("#selected-station-frequency");
const selectedStationType = document.querySelector("#selected-station-type");
const selectedStationService = document.querySelector("#selected-station-service");
const tuneNav1Button = document.querySelector("#tune-nav1");
const nav1Frequency = document.querySelector("#nav1-frequency");
const nav1Status = document.querySelector("#nav1-status");
const nav1ObsControl = document.querySelector("#nav1-obs-control");
const nav1ObsReadout = document.querySelector("#nav1-obs-readout");
const nav1CdiNeedle = document.querySelector("#nav1-cdi-needle");
const nav1Flag = document.querySelector("#nav1-flag");
const nav1Radial = document.querySelector("#nav1-radial");

let selectedStationId = null;
let nav1StationId = null;
let nav1Obs = 0;
let planePosition = { x: 0.5, y: 0.5 };
let heading = 0;
let speedKnots = 120;
let isFlying = false;
let lastFrameTime = null;

// The chart is 500 NM across. Its north-south distance follows the artwork's
// aspect ratio so one NM has the same on-screen scale in either direction.
const MAP_WIDTH_NM = 500;
const MAP_HEIGHT_NM = MAP_WIDTH_NM / (1748 / 1254);
const TRAINING_TIME_RATE = 60;
const stationsById = new Map();

async function loadStations() {
  const response = await fetch("assets/VORStations.json");

  if (!response.ok) {
    throw new Error(`Could not load VOR stations: ${response.status}`);
  }

  return response.json();
}

function addStationMarkers(stations) {
  for (const station of stations) {
    stationsById.set(station.id, station);
    const marker = document.createElement("button");
    marker.type = "button";
    marker.className = "station-marker";
    marker.dataset.stationId = station.id;
    marker.dataset.x = station.location.x;
    marker.dataset.y = station.location.y;
    marker.setAttribute(
      "aria-label",
      `${station.name} VOR, ${station.identifier}, ${station.frequency.toFixed(2)} megahertz`,
    );

    const symbol = document.createElement("span");
    symbol.className = "station-symbol";
    symbol.setAttribute("aria-hidden", "true");

    const label = document.createElement("span");
    label.textContent = station.identifier;

    marker.append(symbol, label);
    marker.addEventListener("click", (event) => {
      event.stopPropagation();
      selectStation(station);
    });
    stationLayer.append(marker);
  }
}

function selectStation(station) {
  selectedStationId = station.id;

  for (const marker of stationLayer.children) {
    marker.classList.toggle("is-selected", marker.dataset.stationId === selectedStationId);
  }

  selectedStationName.textContent = station.name;
  selectedStationIdent.textContent = station.identifier;
  selectedStationFrequency.textContent = `${station.frequency.toFixed(2)} MHz`;
  selectedStationType.textContent = station.type.replace("_", "-");
  selectedStationService.textContent = `${station.serviceVolume} volume`;
  tuneNav1Button.disabled = false;
}

function tuneNav1() {
  const station = stationsById.get(selectedStationId);
  if (!station) return;

  nav1StationId = station.id;
  nav1Frequency.textContent = station.frequency.toFixed(2);
  nav1Status.textContent = `${station.identifier} · ${station.name}`;
  nav1ObsControl.disabled = false;
  updateNav1Instrument();
}

function normalize180(angle) {
  let result = angle % 360;
  if (result > 180) result -= 360;
  if (result < -180) result += 360;
  return result;
}

function calculateNav1Reading(station) {
  const eastNM = (planePosition.x - station.location.x) * MAP_WIDTH_NM;
  const southNM = (planePosition.y - station.location.y) * MAP_HEIGHT_NM;
  const distanceNM = Math.hypot(eastNM, southNM);
  const rangeNM = station.serviceVolume === "H" ? 100 : station.serviceVolume === "L" ? 40 : 25;

  if (distanceNM < 0.1 || distanceNM > rangeNM) return null;

  let radial = Math.atan2(eastNM, -southNM) * 180 / Math.PI;
  if (radial < 0) radial += 360;

  const difference = normalize180(radial - nav1Obs);
  const flag = Math.abs(difference) <= 90 ? "FROM" : "TO";
  const deviationDegrees = flag === "FROM" ? Math.abs(difference) : 180 - Math.abs(difference);
  const planeIsRightOfCourse = eastNM * Math.cos(nav1Obs * Math.PI / 180)
    + southNM * Math.sin(nav1Obs * Math.PI / 180) > 0;
  const deflection = (planeIsRightOfCourse ? -1 : 1) * Math.min(deviationDegrees, 10) / 10;

  return { radial, flag, deflection };
}

function updateNav1Instrument() {
  const displayedObs = nav1Obs === 0 ? 360 : nav1Obs;
  nav1ObsReadout.textContent = `${String(displayedObs).padStart(3, "0")}°`;

  const station = stationsById.get(nav1StationId);
  const reading = station && calculateNav1Reading(station);

  if (!reading) {
    nav1Flag.textContent = "OFF";
    nav1Radial.textContent = station ? "No usable VOR signal" : "Radial —";
    nav1CdiNeedle.style.left = "50%";
    return;
  }

  nav1Flag.textContent = reading.flag;
  nav1Radial.textContent = `Radial ${String(Math.round(reading.radial)).padStart(3, "0")}°`;
  nav1CdiNeedle.style.left = `${50 + reading.deflection * 45}%`;
}

function updateNav1Obs() {
  nav1Obs = Number(nav1ObsControl.value);
  updateNav1Instrument();
}

function fittedMapRect() {
  const panelRect = chartPanel.getBoundingClientRect();
  const imageRatio = chartImage.naturalWidth / chartImage.naturalHeight;
  const panelRatio = panelRect.width / panelRect.height;

  if (panelRatio > imageRatio) {
    const width = panelRect.height * imageRatio;
    return { left: (panelRect.width - width) / 2, top: 0, width, height: panelRect.height };
  }

  const height = panelRect.width / imageRatio;
  return { left: 0, top: (panelRect.height - height) / 2, width: panelRect.width, height };
}

function positionStationMarkers() {
  const mapRect = fittedMapRect();

  for (const marker of stationLayer.children) {
    marker.style.left = `${mapRect.left + Number(marker.dataset.x) * mapRect.width}px`;
    marker.style.top = `${mapRect.top + Number(marker.dataset.y) * mapRect.height}px`;
  }
}

function positionPlane() {
  const mapRect = fittedMapRect();
  planeMarker.style.left = `${mapRect.left + planePosition.x * mapRect.width}px`;
  planeMarker.style.top = `${mapRect.top + planePosition.y * mapRect.height}px`;
}

function updatePlanePositionReadout() {
  planePositionReadout.textContent = `MAP ${(planePosition.x * 100).toFixed(1)}% east · ${(planePosition.y * 100).toFixed(1)}% south`;
  updateNav1Instrument();
}

function updateHeading() {
  heading = Number(headingControl.value);
  const displayedHeading = heading === 0 ? 360 : heading;

  headingReadout.textContent = `HDG ${String(displayedHeading).padStart(3, "0")}°`;
  planeMarker.style.transform = `translate(-50%, -50%) rotate(${heading}deg)`;
}

function updateSpeed() {
  speedKnots = Math.max(0, Number(speedControl.value) || 0);
  speedControl.value = speedKnots;
}

function updateFlightControls(statusMessage) {
  flightToggle.textContent = isFlying ? "Pause flight" : "Start flight";
  flightStatus.textContent = statusMessage ?? (isFlying
    ? "Flying · training time 60×"
    : "Paused · training time 60×");
}

function advanceFlight(realSeconds) {
  const simulatedHours = (realSeconds * TRAINING_TIME_RATE) / 3600;
  const distanceNM = speedKnots * simulatedHours;
  const radians = heading * Math.PI / 180;
  const proposedPosition = {
    x: planePosition.x + (Math.sin(radians) * distanceNM) / MAP_WIDTH_NM,
    y: planePosition.y - (Math.cos(radians) * distanceNM) / MAP_HEIGHT_NM,
  };
  const clampedPosition = {
    x: Math.min(1, Math.max(0, proposedPosition.x)),
    y: Math.min(1, Math.max(0, proposedPosition.y)),
  };
  const reachedMapEdge = clampedPosition.x !== proposedPosition.x
    || clampedPosition.y !== proposedPosition.y;

  planePosition = clampedPosition;
  positionPlane();
  updatePlanePositionReadout();

  if (reachedMapEdge) {
    isFlying = false;
    updateFlightControls("Paused at map edge · training time 60×");
  }
}

function animateFlight(timestamp) {
  if (!isFlying) return;

  if (lastFrameTime !== null) {
    advanceFlight((timestamp - lastFrameTime) / 1000);
  }

  lastFrameTime = timestamp;
  if (isFlying) requestAnimationFrame(animateFlight);
}

function toggleFlight() {
  isFlying = !isFlying;
  lastFrameTime = null;
  updateFlightControls();

  if (isFlying) requestAnimationFrame(animateFlight);
}

function movePlaneToClick(event) {
  const panelRect = chartPanel.getBoundingClientRect();
  const mapRect = fittedMapRect();
  const clickX = event.clientX - panelRect.left;
  const clickY = event.clientY - panelRect.top;

  const isInsideMap = clickX >= mapRect.left
    && clickX <= mapRect.left + mapRect.width
    && clickY >= mapRect.top
    && clickY <= mapRect.top + mapRect.height;

  if (!isInsideMap) return;

  planePosition = {
    x: (clickX - mapRect.left) / mapRect.width,
    y: (clickY - mapRect.top) / mapRect.height,
  };

  positionPlane();
  updatePlanePositionReadout();
}

async function start() {
  try {
    const stations = await loadStations();
    addStationMarkers(stations);
    positionStationMarkers();
    positionPlane();
    updateHeading();
    updateSpeed();
    updateFlightControls();
    chartPanel.addEventListener("click", movePlaneToClick);
    headingControl.addEventListener("input", updateHeading);
    speedControl.addEventListener("change", updateSpeed);
    flightToggle.addEventListener("click", toggleFlight);
    tuneNav1Button.addEventListener("click", tuneNav1);
    nav1ObsControl.addEventListener("input", updateNav1Obs);
    window.addEventListener("resize", () => {
      positionStationMarkers();
      positionPlane();
    });
  } catch (error) {
    console.error(error);
    stationLayer.textContent = "Unable to load VOR stations.";
  }
}

if (chartImage.complete) {
  start();
} else {
  chartImage.addEventListener("load", start, { once: true });
}
