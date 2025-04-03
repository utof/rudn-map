# Run in ADMINISTRATIVE PowerShell

# 1. Clean environment
conda deactivate
conda env remove -n gsplat -y 2>$null
Remove-Item -Recurse -Force gaussian-splatting -ErrorAction SilentlyContinue

# 2. Create fresh Conda environment
conda create -n gsplat python=3.10 -y
conda activate gsplat

# 3. Install PyTorch with compatible CUDA
conda install -c pytorch -c conda-forge -y `
    pytorch=2.3.0 `
    torchvision=0.18.0 `
    pytorch-cuda=12.1 `
    cudatoolkit=12.1.1 `
    opencv=4.9.0 `
    colmap=3.9.1

# 4. Install core Python packages
pip install `
    fastapi==0.109.1 `
    uvicorn==0.27.0 `
    matplotlib==3.8.2 `
    tqdm==4.66.2 `
    imageio==2.34.0 `
    configargparse==1.7 `
    plyfile==1.0.1

# 5. Install Gaussian Splatting with Windows fixes
git clone https://github.com/graphdeco-inria/gaussian-splatting
cd gaussian-splatting
git submodule update --init --recursive

# Build extensions using Conda Python
$CONDA_PYTHON = (conda info --base) + "\python.exe"
cd submodules/diff-gaussian-rasterization
& $CONDA_PYTHON setup.py install
cd ../simple-knn
& $CONDA_PYTHON setup.py install
cd ../../..

# 6. Verify installation
python -c "import torch; print(f'PyTorch {torch.__version__} with CUDA {torch.version.cuda}')"
python -c "import fastapi; print(f'FastAPI {fastapi.__version__} installed')"

Write-Host "`nSETUP COMPLETE!`n"
Write-Host "Start backend: conda activate gsplat && python backend/process_images.py"
Write-Host "Start frontend: cd frontend && bun run dev"