/**
 * Converts an SVG element to a walkable grid using a canvas.
 * White pixels are walkable, black are not.
 *
 * @param svgString The SVG as a string.
 * @param width The width of the grid/canvas.
 * @param height The height of the grid/canvas.
 * @param threshold Optional. 0-255, default 200. Above = walkable.
 * @returns Promise<boolean[][]> where true = walkable.
 */
export async function svgToGrid(
	svgString: string,
	width: number,
	height: number,
	threshold = 200
): Promise<boolean[][]> {
	// Create an offscreen canvas
	const canvas = document.createElement('canvas');
	canvas.width = width;
	canvas.height = height;
	const ctx = canvas.getContext('2d');
	if (!ctx) throw new Error('No 2D context');

	// Create an image from SVG
	const img = new Image();
	// Inline SVG as data URL
	img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgString)));

	await new Promise((resolve, reject) => {
		img.onload = resolve;
		img.onerror = reject;
	});

	ctx.drawImage(img, 0, 0, width, height);

	// Get pixel data
	const imageData = ctx.getImageData(0, 0, width, height);
	const data = imageData.data;

	// Build grid
	const grid: boolean[][] = [];
	for (let y = 0; y < height; y++) {
		const row: boolean[] = [];
		for (let x = 0; x < width; x++) {
			const idx = (y * width + x) * 4;
			// Simple threshold: if R,G,B all above threshold, it's white (walkable)
			const r = data[idx],
				g = data[idx + 1],
				b = data[idx + 2];
			row.push(r > threshold && g > threshold && b > threshold);
		}
		grid.push(row);
	}
	return grid;
}
