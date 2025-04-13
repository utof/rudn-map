<script lang="ts">
	import { onMount } from 'svelte';
	import { svgToGrid } from '../lib/svgToGrid';
	import pkg from 'pathfinding';
	const { Grid, AStarFinder } = pkg;

	interface POI {
		id: string;
		name: string;
		x: number;
		y: number;
	}

	let svgContent: string | null = null;
	let pois: POI[] = [];
	let grid: boolean[][] | null = null;
	let gridObj: any = null;
	let path: number[][] = [];
	let error = '';
	let isLoading = true;

	let startPoiId = '';
	let endPoiId = '';

	const SVG_URL = '/src/routes/map.svg';
	const POI_URL = '/src/routes/pois.json';
	const GRID_RES = 2; // px per cell, higher = finer grid, lower = faster

	// For drawing
	let canvasEl: HTMLCanvasElement | null = null;
	let svgWidth = 600;
	let svgHeight = 400;

	onMount(async () => {
		isLoading = true;
		try {
			// Load SVG and POIs
			const [svgResp, poisResp] = await Promise.all([fetch(SVG_URL), fetch(POI_URL)]);
			svgContent = await svgResp.text();
			pois = (await poisResp.json()).pois;

			// Parse SVG dimensions
			const parser = new DOMParser();
			const doc = parser.parseFromString(svgContent, 'image/svg+xml');
			const svgElem = doc.querySelector('svg');
			if (svgElem) {
				svgWidth = Number(svgElem.getAttribute('width')) || 600;
				svgHeight = Number(svgElem.getAttribute('height')) || 400;
			}

			// Rasterize SVG to grid
			grid = await svgToGrid(svgContent, svgWidth, svgHeight, 200);
			// Downsample grid for pathfinding
			const gridW = Math.floor(svgWidth / GRID_RES);
			const gridH = Math.floor(svgHeight / GRID_RES);
			const downGrid: boolean[][] = [];
			for (let y = 0; y < gridH; y++) {
				const row: boolean[] = [];
				for (let x = 0; x < gridW; x++) {
					// If any pixel in the cell is walkable, mark as walkable
					let walkable = false;
					for (let dy = 0; dy < GRID_RES; dy++) {
						for (let dx = 0; dx < GRID_RES; dx++) {
							if (grid[y * GRID_RES + dy] && grid[y * GRID_RES + dy][x * GRID_RES + dx]) {
								walkable = true;
								break;
							}
						}
						if (walkable) break;
					}
					row.push(walkable);
				}
				downGrid.push(row);
			}
			gridObj = new Grid(downGrid[0].length, downGrid.length);
			for (let y = 0; y < downGrid.length; y++) {
				for (let x = 0; x < downGrid[0].length; x++) {
					gridObj.setWalkableAt(x, y, downGrid[y][x]);
				}
			}
		} catch (e: any) {
			error = e.message || 'Failed to load data';
		}
		isLoading = false;
		draw();
	});

	function findPath() {
		if (!gridObj || !startPoiId || !endPoiId) return;
		const start = pois.find((p) => p.id === startPoiId);
		const end = pois.find((p) => p.id === endPoiId);
		if (!start || !end) return;
		// Convert POI coordinates to grid
		const sx = Math.floor(start.x / GRID_RES);
		const sy = Math.floor(start.y / GRID_RES);
		const ex = Math.floor(end.x / GRID_RES);
		const ey = Math.floor(end.y / GRID_RES);
		const finder = new AStarFinder();
		const gridClone = gridObj.clone();
		path = finder.findPath(sx, sy, ex, ey, gridClone);
		draw();
	}

	function draw() {
		if (!canvasEl || !svgContent) return;
		const ctx = canvasEl.getContext('2d');
		if (!ctx) return;
		// Clear
		ctx.clearRect(0, 0, svgWidth, svgHeight);
		// Draw SVG as background
		const img = new window.Image();
		img.onload = () => {
			ctx.drawImage(img, 0, 0, svgWidth, svgHeight);
			// Draw POIs
			for (const poi of pois) {
				ctx.beginPath();
				ctx.arc(poi.x, poi.y, 7, 0, 2 * Math.PI);
				ctx.fillStyle = '#ff7800';
				ctx.fill();
				ctx.strokeStyle = '#333';
				ctx.stroke();
				ctx.font = '12px sans-serif';
				ctx.fillStyle = '#222';
				ctx.fillText(poi.name, poi.x + 10, poi.y - 10);
			}
			// Draw path
			if (path.length > 1) {
				ctx.beginPath();
				ctx.moveTo(path[0][0] * GRID_RES + GRID_RES / 2, path[0][1] * GRID_RES + GRID_RES / 2);
				for (const [x, y] of path) {
					ctx.lineTo(x * GRID_RES + GRID_RES / 2, y * GRID_RES + GRID_RES / 2);
				}
				ctx.strokeStyle = '#00f';
				ctx.lineWidth = 3;
				ctx.stroke();
			}
		};
		img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgContent)));
	}
</script>

{#if isLoading}
	<p>Loading...</p>
{:else if error}
	<p style="color: red">{error}</p>
{:else}
	<div>
		<div style="margin-bottom: 1em;">
			<label
				>Start:
				<select bind:value={startPoiId}>
					<option value="">Select</option>
					{#each pois as poi}
						<option value={poi.id}>{poi.name}</option>
					{/each}
				</select>
			</label>
			<label style="margin-left: 1em;"
				>End:
				<select bind:value={endPoiId}>
					<option value="">Select</option>
					{#each pois as poi}
						<option value={poi.id}>{poi.name}</option>
					{/each}
				</select>
			</label>
			<button on:click={findPath} disabled={!startPoiId || !endPoiId}>Find Path</button>
		</div>
		<canvas
			bind:this={canvasEl}
			width={svgWidth}
			height={svgHeight}
			style="border:1px solid #ccc; background:#fff; max-width:100%;"
		></canvas>
	</div>
{/if}
