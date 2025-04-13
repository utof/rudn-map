<script lang="ts">
	import { onMount } from 'svelte';

	let map: any;
	let svgOverlay: any;

	// Placeholder function for pathfinding (not used yet)
	function findPath(roomA: number, roomB: number) {
		console.log('Finding path from room', roomA, 'to room', roomB);
	}

	// A simple SVG with four rooms and a curved corridor.
	// The rooms are given as irregular (tilted) shapes.
	const indoorSVG = `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 400">
        <!-- Curved corridor in the middle -->
        <path id="corridor" d="M 50,200 Q 300,100 550,200 Q 300,300 50,200 Z" fill="#fff" stroke="#000" stroke-width="3"/>
        <!-- Room 1: Top-left, irregular -->
        <path id="room1" d="M 60,60 L 260,40 L 240,180 L 60,160 Z" fill="#b3e5fc" stroke="#000" stroke-width="2"/>
        <!-- Room 2: Top-right, tilted -->
        <path id="room2" d="M 300,50 L 540,70 L 520,190 L 300,170 Z" fill="#ffccbc" stroke="#000" stroke-width="2"/>
        <!-- Room 3: Bottom-left, irregular -->
        <path id="room3" d="M 70,220 L 250,240 L 230,360 L 70,340 Z" fill="#c8e6c9" stroke="#000" stroke-width="2"/>
        <!-- Room 4: Bottom-right, rotated -->
        <path id="room4" d="M 280,230 L 520,250 L 500,370 L 280,350 Z" fill="#d1c4e9" stroke="#000" stroke-width="2"/>
        <!-- Labels for the rooms -->
        <text x="150" y="120" font-size="24" text-anchor="middle" fill="#000">1</text>
        <text x="420" y="120" font-size="24" text-anchor="middle" fill="#000">2</text>
        <text x="150" y="300" font-size="24" text-anchor="middle" fill="#000">3</text>
        <text x="420" y="300" font-size="24" text-anchor="middle" fill="#000">4</text>
      </svg>
    `;

	onMount(async () => {
		// Dynamically import Leaflet only on client side
		const L = await import('leaflet');
		await import('leaflet/dist/leaflet.css');

		// Initialize the Leaflet map with a simple CRS.
		map = L.map('map', {
			crs: L.CRS.Simple,
			minZoom: -1
		});

		// Define the bounds as [y, x]: here we set the SVG canvas size (height 400, width 600).
		const bounds = [
			[0, 0],
			[400, 600]
		];

		// Convert the inline SVG string into a Blob URL.
		const blob = new Blob([indoorSVG], { type: 'image/svg+xml;charset=utf-8' });
		const url = URL.createObjectURL(blob);

		// Add the SVG overlay to the map.
		svgOverlay = L.imageOverlay(url, bounds).addTo(map);
		map.fitBounds(bounds);

		// Add a click event listener to the overlay.
		// When a room (i.e. a <path> element with id "roomX") is clicked, log its room number.
		svgOverlay.getElement().addEventListener('click', (e: MouseEvent) => {
			// Use document.elementFromPoint to detect which SVG element was clicked.
			const element = document.elementFromPoint(e.clientX, e.clientY) as HTMLElement;
			if (element && element.tagName === 'path' && element.id.startsWith('room')) {
				const roomNumber = element.id.replace('room', '');
				console.log('Clicked on room:', roomNumber);
				// Future functionality: call a function to highlight the selected room, etc.
			}
		});
	});
</script>

<!-- The map container -->
<div id="map"></div>

<style>
	/* Basic styling for the map container */
	#map {
		height: 500px;
		width: 100%;
		border: 1px solid #ccc;
	}
</style>
