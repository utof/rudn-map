<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';

	// Import specific Leaflet types directly - This is safe for SSR
	import type {
		Map as LeafletMap, // Use alias to avoid naming conflict with built-in Map
		SVGOverlay,
		Polyline,
		LayerGroup,
		LatLngBounds,
		LatLngExpression,
		CircleMarker // Import CircleMarker type if needed
	} from 'leaflet';

	// Import pathfinding classes and DiagonalMovement enum
	import pkg from 'pathfinding';
	const { Grid, AStarFinder, Util, DiagonalMovement } = pkg;

	// Declare L to hold the Leaflet module *value* when loaded
	// Use 'any' initially or a more specific type if preferred, but it will be assigned the actual module
	let L: typeof import('leaflet') | undefined;

	// --- Types ---
	interface POI {
		id: string;
		name: string;
		x: number; // SVG X coordinate
		y: number; // SVG Y coordinate
		gridX?: number; // Corresponding grid X coordinate
		gridY?: number; // Corresponding grid Y coordinate
	}

	// --- Constants ---
	const SVG_URL = 'src/routes/map.svg';
	const POI_URL = 'src/router/pois.json';
	const GRID_RESOLUTION = 10;

	// --- State ---
	// Use the imported types directly
	let map: LeafletMap | null = null;
	let svgOverlay: SVGOverlay | null = null;
	let pathPolyline: Polyline | null = null;
	let poiMarkers: LayerGroup | null = null;

	let svgContent: string | null = null;
	let svgRootElement: SVGSVGElement | null = null;
	let pois: POI[] = [];
	let navigationGrid: typeof Grid | null = null;

	let pathStartPOI: string = '';
	let pathEndPOI: string = '';
	let isLoading = true;
	let errorMessage = '';

	// --- Leaflet & SVG Setup ---
	// Make initializeMap async as it performs fetches
	async function initializeMap() {
		if (!L || !browser) {
			errorMessage = 'Leaflet library not loaded or not in browser.';
			isLoading = false;
			return; // Guard against running without L
		}
		try {
			isLoading = true; // Reset loading state
			errorMessage = '';

			// 1. Fetch Data
			const [svgResponse, poiResponse] = await Promise.all([fetch(SVG_URL), fetch(POI_URL)]);
			if (!svgResponse.ok)
				throw new Error(`Failed to load SVG (${SVG_URL}): ${svgResponse.statusText}`);
			if (!poiResponse.ok)
				throw new Error(`Failed to load POIs (${POI_URL}): ${poiResponse.statusText}`);

			svgContent = await svgResponse.text();
			const poiData = await poiResponse.json();
			pois = poiData.pois || [];

			// 2. Initialize Leaflet Map
			map = L.map('map', { crs: L.CRS.Simple, minZoom: -2 });

			// 3. Parse SVG and get bounds
			const parser = new DOMParser();
			const svgDoc = parser.parseFromString(svgContent, 'image/svg+xml');
			svgRootElement = svgDoc.querySelector('svg');
			if (!svgRootElement) throw new Error('Could not find SVG element in fetched content.');

			const viewBox = svgRootElement.viewBox.baseVal;
			if (!viewBox) throw new Error('SVG missing viewBox attribute.');
			const svgWidth = viewBox.width;
			const svgHeight = viewBox.height;
			// Use the imported LatLngBounds type if needed, but L.latLngBounds works fine
			const bounds = L.latLngBounds([
				[0, 0],
				[svgHeight, svgWidth]
			]);

			// 4. Add SVG Overlay
			svgOverlay = L.svgOverlay(svgContent, bounds, {
				interactive: false
			}).addTo(map);
			map.fitBounds(bounds);

			// 5. Build Navigation Grid
			buildNavigationGrid(svgWidth, svgHeight);
			if (!navigationGrid) throw new Error('Failed to build navigation grid.');

			// 6. Map POIs to Grid and Display Markers
			mapPoisToGrid();
			displayPoisOnMap();

			isLoading = false;
		} catch (err: any) {
			console.error('Initialization failed:', err);
			errorMessage = `Error initializing map: ${err.message}`;
			isLoading = false;
		}
	}

	// --- Grid Generation (Keep as before) ---
	function buildNavigationGrid(svgWidth: number, svgHeight: number) {
		// ... (implementation remains the same) ...
		if (!svgRootElement) {
			console.error('SVG root element not available for grid building.');
			return;
		}
		const gridWidth = Math.ceil(svgWidth / GRID_RESOLUTION);
		const gridHeight = Math.ceil(svgHeight / GRID_RESOLUTION);
		console.log(`Building grid: ${gridWidth}x${gridHeight}`);
		navigationGrid = new Grid(gridWidth, gridHeight);
		const walkablePaths = svgRootElement.querySelectorAll('path[fill="#fff"], path[fill="white"]');
		if (walkablePaths.length === 0) {
			console.warn('No walkable path elements found in SVG.');
		} else {
			console.log(`Found ${walkablePaths.length} walkable path elements.`);
		}
		for (let y = 0; y < gridHeight; y++) {
			for (let x = 0; x < gridWidth; x++) {
				const svgX = (x + 0.5) * GRID_RESOLUTION;
				const svgY = (y + 0.5) * GRID_RESOLUTION;
				let isWalkable = false;
				for (const path of walkablePaths) {
					if (isPointInWalkableArea(svgX, svgY, path as SVGPathElement)) {
						isWalkable = true;
						break;
					}
				}
				navigationGrid.setWalkableAt(x, y, isWalkable);
			}
		}
		console.log('Navigation grid built.');
	}

	// --- Point-in-Polygon Check (Keep as before) ---
	function isPointInWalkableArea(x: number, y: number, pathElement: SVGPathElement): boolean {
		// ... (implementation remains the same) ...
		if (svgRootElement && typeof pathElement.isPointInFill === 'function') {
			const svgPoint = svgRootElement.createSVGPoint();
			svgPoint.x = x;
			svgPoint.y = y;
			try {
				return pathElement.isPointInFill(svgPoint);
			} catch (e) {
				return false;
			}
		} else {
			return false;
		}
	}

	// --- POI Handling (Keep as before, including findNearestWalkableNode) ---
	function mapPoisToGrid() {
		// ... (implementation remains the same) ...
		if (!navigationGrid) {
			console.error('Cannot map POIs: Navigation grid not available.');
			return;
		}
		pois.forEach((poi) => {
			const idealGridX = Math.floor(poi.x / GRID_RESOLUTION);
			const idealGridY = Math.floor(poi.y / GRID_RESOLUTION);
			if (navigationGrid!.isWalkableAt(idealGridX, idealGridY)) {
				poi.gridX = idealGridX;
				poi.gridY = idealGridY;
			} else {
				const nearest = findNearestWalkableNode(idealGridX, idealGridY, 5);
				if (nearest) {
					poi.gridX = nearest.x;
					poi.gridY = nearest.y;
					console.warn(`POI '${poi.name}' mapped to nearest node.`);
				} else {
					console.error(`POI '${poi.name}' could not be mapped.`);
				}
			}
		});
		console.log('POIs mapped to grid.');
	}

	function findNearestWalkableNode(
		startX: number,
		startY: number,
		maxRadius: number
	): { x: number; y: number } | null {
		// ... (implementation remains the same) ...
		if (!navigationGrid) return null;
		const grid = navigationGrid;
		if (grid.isWalkableAt(startX, startY)) {
			return { x: startX, y: startY };
		}
		const queue: { x: number; y: number; dist: number }[] = [{ x: startX, y: startY, dist: 0 }];
		const visited = new Set<string>([`${startX},${startY}`]);
		while (queue.length > 0) {
			const current = queue.shift()!;
			const currentNodeObject = grid.getNodeAt(current.x, current.y);
			if (!currentNodeObject) continue;
			const neighbors = grid.getNeighbors(currentNodeObject, DiagonalMovement.Always);
			for (const neighbor of neighbors) {
				const key = `${neighbor.x},${neighbor.y}`;
				const dist = Math.abs(neighbor.x - startX) + Math.abs(neighbor.y - startY);
				if (dist <= maxRadius && !visited.has(key) && grid.isInside(neighbor.x, neighbor.y)) {
					visited.add(key);
					if (grid.isWalkableAt(neighbor.x, neighbor.y)) {
						return { x: neighbor.x, y: neighbor.y };
					}
					queue.push({ x: neighbor.x, y: neighbor.y, dist: current.dist + 1 });
				}
			}
		}
		return null;
	}

	function displayPoisOnMap() {
		// ... (implementation remains the same, uses L directly) ...
		if (!map || !L) return;
		if (poiMarkers) {
			map.removeLayer(poiMarkers);
		}
		poiMarkers = L.layerGroup().addTo(map);
		pois.forEach((poi) => {
			if (!L) {
				console.error('Leaflet not initialized');
				return;
			}
			const latLng = L.latLng(poi.y, poi.x);
			const marker = L.circleMarker(latLng, {
				fillColor: poi.gridX !== undefined ? '#ff7800' : '#888888',
				radius: 8
			}).addTo(poiMarkers!);
			marker.bindTooltip(poi.name, {
				/* ... options ... */
			});
			marker.on('click', () => {
				/* ... click logic ... */
			});
		});
	}

	// --- Pathfinding ---
	function findAndDrawPath() {
		// ... (implementation remains the same, uses L directly) ...
		clearPath();
		if (!navigationGrid || !map || !L) {
			errorMessage = 'Map or navigation grid not ready.';
			return;
		}
		if (!pathStartPOI || !pathEndPOI) {
			errorMessage = 'Please select both points.';
			return;
		}
		if (pathStartPOI === pathEndPOI) {
			errorMessage = 'Points cannot be the same.';
			return;
		}
		const startPoi = pois.find((p) => p.id === pathStartPOI);
		const endPoi = pois.find((p) => p.id === pathEndPOI);
		if (!startPoi || startPoi.gridX === undefined) {
			errorMessage = `Start POI '${pathStartPOI}' error.`;
			return;
		}
		if (!endPoi || endPoi.gridX === undefined) {
			errorMessage = `End POI '${pathEndPOI}' error.`;
			return;
		}
		console.log(`Finding path from ${startPoi.name} to ${endPoi.name}`);
		errorMessage = '';
		try {
			const gridClone = navigationGrid.clone();
			const finder = new AStarFinder({ diagonalMovement: DiagonalMovement.IfAtMostOneObstacle });
			const pathGridCoords = finder.findPath(
				startPoi.gridX!,
				startPoi.gridY!,
				endPoi.gridX!,
				endPoi.gridY!,
				gridClone
			);
			if (pathGridCoords && pathGridCoords.length > 0) {
				const smoothedPathGridCoords = Util.smoothenPath(gridClone, pathGridCoords);
				// Use imported LatLngExpression type
				const latLngPoints: LatLngExpression[] = smoothedPathGridCoords.map((gridCoord) => {
					const svgX = (gridCoord[0] + 0.5) * GRID_RESOLUTION;
					const svgY = (gridCoord[1] + 0.5) * GRID_RESOLUTION;
					if (!L) {
						throw new Error('Leaflet not initialized');
					}
					return L.latLng(svgY, svgX);
				});
				pathPolyline = L.polyline(latLngPoints, {
					/* ... styles ... */
				}).addTo(map);
			} else {
				errorMessage = 'No path found.';
			}
		} catch (error: any) {
			errorMessage = `Pathfinding error: ${error.message}`;
		}
	}

	function clearPath() {
		// ... (implementation remains the same) ...
		if (pathPolyline && map) {
			map.removeLayer(pathPolyline);
			pathPolyline = null;
		}
	}

	function clearAll() {
		// ... (implementation remains the same) ...
		pathStartPOI = '';
		pathEndPOI = '';
		clearPath();
		errorMessage = '';
		pathStartPOI = pathStartPOI;
		pathEndPOI = pathEndPOI; // Force reactivity
	}

	// --- Lifecycle ---
	onMount(() => {
		// Use an IIAFE (Immediately Invoked Async Function Expression)
		// The onMount callback itself remains synchronous
		(async () => {
			if (browser) {
				try {
					// Dynamically import Leaflet and assign to L
					L = await import('leaflet');
					await import('leaflet/dist/leaflet.css');
					console.log('Leaflet loaded dynamically.');

					// Now call the async initialization function
					await initializeMap();
				} catch (error) {
					console.error('Failed to load Leaflet or initialize map:', error);
					errorMessage = 'Failed to load map library.';
					isLoading = false;
				}
			} else {
				console.log('Skipping Leaflet initialization on server.');
				// Set loading false here if you want the UI to show non-loading state during SSR
				// isLoading = false;
			}
		})(); // Invoke the async function immediately

		// The synchronous onMount function returns the cleanup function
		return () => {
			console.log('Cleaning up IndoorMap component');
			// Cleanup logic remains the same
			clearPath();
			if (map) {
				if (poiMarkers) {
					try {
						map.removeLayer(poiMarkers);
					} catch (e) {
						console.warn('Error removing POI markers:', e);
					}
				}
				if (pathPolyline) {
					try {
						map.removeLayer(pathPolyline);
					} catch (e) {
						console.warn('Error removing path polyline:', e);
					}
				}
				try {
					map.remove();
				} catch (e) {
					console.warn('Error removing map:', e);
				}
			}
			map = null;
			svgOverlay = null;
			svgRootElement = null;
			navigationGrid = null;
			pois = [];
			poiMarkers = null;
			pathPolyline = null;
			L = undefined; // Clear L
		};
	}); // onMount remains synchronous
</script>

<!-- UI Elements (Keep as before) -->
{#if isLoading}
	<p>Loading map data...</p>
{:else if errorMessage}
	<p class="error-message">Error: {errorMessage}</p>
{/if}

<div class="controls-container" style:opacity={isLoading ? 0.5 : 1}>
	<!-- ... controls ... -->
	<div class="pathfinding-container control-group">
		<label for="startPoi">Find Path:</label>
		<select
			id="startPoi"
			bind:value={pathStartPOI}
			on:change={() => {
				clearPath();
				errorMessage = '';
			}}
			disabled={isLoading}
		>
			<option value="">-- Select Start --</option>
			{#each pois as poi (poi.id)}
				<option value={poi.id} disabled={poi.gridX === undefined}
					>{poi.name}{poi.gridX === undefined ? ' (unreachable)' : ''}</option
				>
			{/each}
		</select>
		<span>→</span>
		<select
			id="endPoi"
			bind:value={pathEndPOI}
			on:change={() => {
				clearPath();
				errorMessage = '';
			}}
			disabled={isLoading}
		>
			<option value="">-- Select End --</option>
			{#each pois as poi (poi.id)}
				<option value={poi.id} disabled={poi.gridX === undefined}
					>{poi.name}{poi.gridX === undefined ? ' (unreachable)' : ''}</option
				>
			{/each}
		</select>
		<button on:click={findAndDrawPath} disabled={!pathStartPOI || !pathEndPOI || isLoading}
			>Find Path</button
		>
		<button on:click={clearAll} disabled={isLoading}>Clear</button>
	</div>
	<p class="hint">Hint: Click markers on map to select start/end points, or use the dropdowns.</p>
</div>

<!-- The map container -->
<div id="map"></div>

<!-- Styles (Keep as before) -->
<style>
	/* ... styles ... */
	#map {
		height: 600px;
		width: 100%;
		border: 1px solid #ccc;
		margin-top: 10px;
		background-color: #f0f0f0;
		position: relative;
	}
	.controls-container {
		display: flex;
		flex-direction: column;
		gap: 10px;
		margin-bottom: 10px;
		padding: 10px;
		background-color: #eee;
		border-radius: 5px;
		transition: opacity 0.3s ease-in-out;
	}
	.control-group {
		display: flex;
		gap: 8px;
		align-items: center;
		flex-wrap: wrap;
	}
	.control-group label {
		font-weight: bold;
		margin-right: 5px;
	}
	.control-group select {
		padding: 8px;
		border-radius: 4px;
		border: 1px solid #ccc;
		flex-grow: 1;
		min-width: 150px;
	}
	.control-group span {
		font-weight: bold;
	}
	.control-group button {
		padding: 8px 12px;
		border: none;
		background-color: #007bff;
		color: white;
		border-radius: 4px;
		cursor: pointer;
		white-space: nowrap;
		transition: background-color 0.2s ease;
	}
	.control-group button:hover:not(:disabled) {
		background-color: #0056b3;
	}
	.control-group button:disabled {
		background-color: #ccc;
		cursor: not-allowed;
		opacity: 0.7;
	}
	.control-group button:last-of-type {
		background-color: #6c757d;
	}
	.control-group button:last-of-type:hover:not(:disabled) {
		background-color: #5a6268;
	}
	.error-message {
		color: #d8000c;
		font-weight: bold;
		padding: 8px 12px;
		background-color: #ffd2d2;
		border: 1px solid #d8000c;
		border-radius: 4px;
		margin: 5px 0;
	}
	.hint {
		font-size: 0.9em;
		color: #555;
		margin-top: 0px;
	}
	:global(.leaflet-tooltip) {
		background-color: rgba(255, 255, 255, 0.9);
		border: 1px solid #aaa;
		border-radius: 3px;
		padding: 4px 8px;
		white-space: nowrap;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
		color: #333;
		font-size: 11px;
	}
	:global(.leaflet-tooltip-permanent) {
		font-weight: bold;
	}
	:global(.leaflet-pane path.leaflet-interactive[stroke='blue']) {
		stroke-linecap: round;
		stroke-linejoin: round;
	}
	select option:disabled {
		color: #999;
		background-color: #f0f0f0;
	}
</style>
