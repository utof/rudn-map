# Setup.ps1 - Complete environment setup for Windows 10

# Check if conda is installed
if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Host "Miniconda not found. Installing..."
    Invoke-WebRequest -Uri "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" -OutFile "Miniconda3-latest-Windows-x86_64.exe"
    Start-Process -FilePath ".\Miniconda3-latest-Windows-x86_64.exe" -ArgumentList "/S /AddToPath=1 /RegisterPython=1" -Wait
    Remove-Item "Miniconda3-latest-Windows-x86_64.exe"
}

# Create conda environment
conda create -n gsplat python=3.10 -y
conda activate gsplat

# Install core dependencies
conda install -c conda-forge -y `
    cudatoolkit=12.2 `
    pytorch=2.3.0 `
    torchvision=0.18.0 `
    pytorch-cuda=12.2 `
    opencv=4.9.0 `
    colmap=3.9.1

# Install Python requirements
pip install `
    plyfile==0.9.1 `
    matplotlib==3.8.2 `
    tqdm==4.66.2 `
    imageio==2.34.0 `
    imageio-ffmpeg==0.4.9 `
    configargparse==1.7 `
    fastapi `
    uvicorn `
    python-multipart

# Clone and setup Gaussian Splatting
git clone --recursive https://github.com/graphdeco-inria/gaussian-splatting
cd gaussian-splatting
pip install ./submodules/diff-gaussian-rasterization
pip install ./submodules/simple-knn
cd ..

# Setup frontend
cd frontend
bun install
cd ..

Write-Host "Setup complete! Run the following commands to start:"
Write-Host "1. Start backend: conda activate gsplat && python backend/server.py"
Write-Host "2. Start frontend: cd frontend && bun run dev"