<script lang="ts">
	import { onMount } from 'svelte';
	import L from 'leaflet'; // Import Leaflet directly
	import 'leaflet/dist/leaflet.css'; // Import Leaflet CSS

	// Define the SVG content outside the component logic
	const indoorSVG = `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 400" style="pointer-events: all;"> <!-- Added pointer-events: all -->
        <!-- Curved corridor in the middle -->
        <path id="corridor" d="M 50,200 Q 300,100 550,200 Q 300,300 50,200 Z" fill="#fff" stroke="#000" stroke-width="3" style="pointer-events: none;"/> <!-- Corridor shouldn't block clicks -->
        <!-- Room 1: Top-left, irregular -->
        <path id="room1" data-room-number="1" d="M 60,60 L 260,40 L 240,180 L 60,160 Z" fill="#b3e5fc" stroke="#000" stroke-width="2"/>
        <!-- Room 2: Top-right, tilted -->
        <path id="room2" data-room-number="2" d="M 300,50 L 540,70 L 520,190 L 300,170 Z" fill="#ffccbc" stroke="#000" stroke-width="2"/>
        <!-- Room 3: Bottom-left, irregular -->
        <path id="room3" data-room-number="3" d="M 70,220 L 250,240 L 230,360 L 70,340 Z" fill="#c8e6c9" stroke="#000" stroke-width="2"/>
        <!-- Room 4: Bottom-right, rotated -->
        <path id="room4" data-room-number="4" d="M 280,230 L 520,250 L 500,370 L 280,350 Z" fill="#d1c4e9" stroke="#000" stroke-width="2"/>
        <!-- Labels for the rooms (make them non-interactive) -->
        <text x="150" y="120" font-size="24" text-anchor="middle" fill="#000" style="pointer-events: none;">1</text>
        <text x="420" y="120" font-size="24" text-anchor="middle" fill="#000" style="pointer-events: none;">2</text>
        <text x="150" y="300" font-size="24" text-anchor="middle" fill="#000" style="pointer-events: none;">3</text>
        <text x="420" y="300" font-size="24" text-anchor="middle" fill="#000" style="pointer-events: none;">4</text>
      </svg>
    `;

	let map: L.Map | null = null;
	let svgOverlay: L.SVGOverlay | null = null;
	let searchTerm: string = '';
	let highlightedElement: SVGElement | null = null; // Type hint for SVG element

	// Placeholder function for pathfinding
	function findPath(roomA: number, roomB: number) {
		console.log('Finding path from room', roomA, 'to room', roomB);
		// Pathfinding logic would go here
	}

	// Function to highlight a room based on its number
	function highlightRoom(roomNumber: string) {
		// Remove previous highlight if any
		if (highlightedElement) {
			highlightedElement.classList.remove('highlighted');
			highlightedElement = null;
		}

		if (!roomNumber || !svgOverlay) return; // Do nothing if search term is empty or overlay not ready

		const interactiveSvgElement = svgOverlay.getElement(); // This is the <svg> element managed by Leaflet
		if (!interactiveSvgElement) return;

		// Find the room element by ID within the SVG element
		const roomElement = interactiveSvgElement.querySelector(`#room${roomNumber}`) as SVGElement; // Cast to SVGElement

		if (roomElement) {
			// Apply highlight style
			roomElement.classList.add('highlighted');
			highlightedElement = roomElement;
			console.log('Highlighting room:', roomNumber);
		} else {
			console.log('Room not found:', roomNumber);
		}
	}

	function handleSearch() {
		highlightRoom(searchTerm.trim());
	}

	function clearSearch() {
		searchTerm = '';
		highlightRoom('');
	}

	onMount(() => {
		// Removed async as direct import is used
		try {
			// Add try...catch for better error handling during init
			// Initialize the Leaflet map
			map = L.map('map', {
				crs: L.CRS.Simple,
				minZoom: -1
			});

			// Define the bounds
			const bounds = L.latLngBounds([
				[0, 0],
				[400, 600]
			]);

			// --- Create SVG element from the string ---
			const tempDiv = document.createElement('div');
			tempDiv.innerHTML = indoorSVG.trim(); // Trim whitespace
			const svgElementSource = tempDiv.firstChild as SVGElement; // Get the actual <svg> node

			if (!svgElementSource || !(svgElementSource instanceof SVGElement)) {
				console.error('Failed to create SVG element from string.');
				// Handle error appropriately, maybe show a message to the user
				return;
			}
			// --- End SVG element creation ---

			// Use L.svgOverlay with the created SVG *element*
			svgOverlay = L.svgOverlay(svgElementSource, bounds, {
				// Pass the element, not the string
				interactive: true
			}).addTo(map);

			map.fitBounds(bounds); // Fit map view to the SVG bounds

			// Get the SVG element *added by Leaflet* to attach listener
			const interactiveSvgElement = svgOverlay.getElement();
			if (interactiveSvgElement) {
				interactiveSvgElement.addEventListener('click', (e: MouseEvent) => {
					const target = e.target as SVGElement;
					if (target && target.tagName === 'path' && target.dataset.roomNumber) {
						const roomNumber = target.dataset.roomNumber;
						console.log('Clicked on room:', roomNumber);
						searchTerm = roomNumber; // Update search term input
						highlightRoom(roomNumber);
					}
				});
			} else {
				console.error('Could not get SVG element from overlay after adding to map.');
			}
		} catch (error) {
			console.error('Error initializing Leaflet map or SVG overlay:', error);
			// Optionally display an error message to the user
		}

		// Cleanup function
		return () => {
			if (map) {
				map.remove();
				map = null;
				svgOverlay = null; // Clear overlay reference too
				highlightedElement = null; // Clear highlight reference
			}
		};
	}); // End onMount
</script>

<!-- Search Bar -->
<div class="search-container">
	<input
		type="text"
		bind:value={searchTerm}
		placeholder="Enter room number (1-4)"
		on:input={handleSearch}
	/>
	<button on:click={handleSearch}>Search</button>
	<button on:click={clearSearch}>Clear</button>
</div>

<!-- The map container -->
<div id="map"></div>

<style>
	/* Basic styling for the map container */
	#map {
		height: 500px; /* Or adjust as needed */
		width: 100%;
		border: 1px solid #ccc;
		margin-top: 10px; /* Add some space below the search bar */
		background-color: #f0f0f0; /* Optional: background for map area */
	}

	.search-container {
		margin-bottom: 10px;
		display: flex;
		gap: 5px;
		align-items: center;
	}

	.search-container input {
		padding: 8px;
		border: 1px solid #ccc;
		border-radius: 4px;
	}

	.search-container button {
		padding: 8px 12px;
		border: none;
		background-color: #007bff;
		color: white;
		border-radius: 4px;
		cursor: pointer;
	}
	.search-container button:hover {
		background-color: #0056b3;
	}
	.search-container button:last-child {
		/* Style clear button differently */
		background-color: #6c757d;
	}
	.search-container button:last-child:hover {
		background-color: #5a6268;
	}

	/* Style for highlighted room */
	:global(.leaflet-pane .highlighted) {
		/* Target .highlighted specifically within leaflet panes */
		fill: yellow !important; /* Use !important to override inline fill */
		stroke: red !important;
		stroke-width: 4px !important;
		transition:
			fill 0.2s ease-in-out,
			stroke 0.2s ease-in-out; /* Smooth transition */
	}

	/* Ensure SVG elements receive pointer events correctly */
	:global(.leaflet-svg-overlay) {
		pointer-events: auto; /* Allow events on the overlay container */
	}
</style>
