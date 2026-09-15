const chartPanel = document.querySelector(".chart-panel");
const chartImage = document.querySelector("#chart-image");
const stationLayer = document.querySelector("#station-layer");
const selectedStationName = document.querySelector("#selected-station-name");
const selectedStationIdent = document.querySelector("#selected-station-ident");
const selectedStationFrequency = document.querySelector("#selected-station-frequency");
const selectedStationType = document.querySelector("#selected-station-type");
const selectedStationService = document.querySelector("#selected-station-service");

let selectedStationId = null;

async function loadStations() {
  const response = await fetch("assets/VORStations.json");

  if (!response.ok) {
    throw new Error(`Could not load VOR stations: ${response.status}`);
  }

  return response.json();
}

function addStationMarkers(stations) {
  for (const station of stations) {
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
    marker.addEventListener("click", () => selectStation(station));
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

async function start() {
  try {
    const stations = await loadStations();
    addStationMarkers(stations);
    positionStationMarkers();
    window.addEventListener("resize", positionStationMarkers);
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
