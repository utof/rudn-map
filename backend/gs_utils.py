import os
import subprocess
import numpy as np
import cv2
from PIL import Image
from pathlib import Path
from typing import List, Tuple

class GaussianMapper:
    def __init__(self, workspace: str = "workspace"):
        self.workspace = Path(workspace)
        self.workspace.mkdir(exist_ok=True)
        
    def run_colmap(self, image_dir: Path):
        colmap_dir = self.workspace / "colmap"
        colmap_dir.mkdir(exist_ok=True)
        
        cmd = f"colmap automatic_reconstructor \
            --image_path {image_dir} \
            --workspace_path {colmap_dir} \
            --use_gpu 1"
        subprocess.run(cmd, shell=True, check=True)
        
    def run_gaussian_splatting(self):
        gs_dir = self.workspace / "gaussian"
        gs_dir.mkdir(exist_ok=True)
        
        cmd = f"python gaussian-splatting/train.py \
            -s {self.workspace/'colmap/sparse'} \
            -m {gs_dir} \
            --iterations 7000"
        subprocess.run(cmd, shell=True, check=True)
        
    def project_to_2d(self, height_threshold: float = 0.2) -> np.ndarray:
        from submodules.diff_gaussian_rasterization import GaussianRasterizer
        import torch
        
        # Load the trained Gaussian model
        ply_path = self.workspace / "gaussian/point_cloud.ply"
        
        # Simplified 2D projection - in practice you'd use the full renderer
        points = self._load_ply(ply_path)
        
        # Filter by height (assuming Y is up)
        points = points[points[:,1] < height_threshold]
        
        # Create density map
        xz = points[:,[0,2]]
        heatmap, xedges, zedges = np.histogram2d(
            xz[:,0], xz[:,1], bins=100)
        
        return heatmap.T
    
    def _load_ply(self, path: Path) -> np.ndarray:
        from plyfile import PlyData
        plydata = PlyData.read(path)
        vertices = plydata['vertex']
        return np.vstack([vertices['x'], vertices['y'], vertices['z']]).T