import os
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from gs_utils import GaussianMapper
from pathlib import Path
import shutil
import uuid

app = FastAPI()

# Allow CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.post("/api/process")
async def process_images(files: List[UploadFile] = File(...)):
    # Create unique workspace
    job_id = str(uuid.uuid4())
    input_dir = Path(f"workspace/{job_id}/input")
    input_dir.mkdir(parents=True, exist_ok=True)
    
    # Save uploaded files
    for file in files:
        with open(input_dir / file.filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    
    # Process images
    mapper = GaussianMapper(f"workspace/{job_id}")
    mapper.run_colmap(input_dir)
    mapper.run_gaussian_splatting()
    density_map = mapper.project_to_2d()
    
    # Save result
    output_path = Path(f"static/{job_id}.png")
    cv2.imwrite(str(output_path), density_map * 255)
    
    return {"status": "completed", "result": f"/static/{job_id}.png"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)