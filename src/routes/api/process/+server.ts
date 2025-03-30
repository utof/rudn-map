import { json } from '@sveltejs/kit';

export async function POST({ request }) {
	// Forward to backend
	const backendResponse = await fetch('http://localhost:8000/api/process', {
		method: 'POST',
		body: await request.formData()
	});

	return json(await backendResponse.json());
}
