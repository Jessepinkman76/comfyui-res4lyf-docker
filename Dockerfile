FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y \
    curl \
    git \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    libgl1 \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer toutes les dépendances Python manquantes identifiées dans les logs
RUN pip install --no-cache-dir \
    PyWavelets \
    numpy \
    scipy \
    pyyaml \
    pyOpenSSL \
    simpleeval \
    matplotlib \
    opencv-python-headless \
    rembg[gpu] \
    requirements-parser \
    torchvision \
    pillow \
    requests \
    transformers \
    accelerate \
    safetensors

# Cloner RES4LYF manuellement
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installer les dépendances spécifiques de RES4LYF
RUN if [ -f /comfyui/custom_nodes/RES4LYF/requirements.txt ]; then \
    pip install --no-cache-dir -r /comfyui/custom_nodes/RES4LYF/requirements.txt; \
fi

# Configuration du network volume
RUN mkdir -p /comfyui && cat > /comfyui/extra_model_paths.yaml << EOF
comfyui:
  base_path: /runpod-volume/ComfyUI/
  checkpoints: models/checkpoints/
  configs: models/configs/
  vae: models/vae/
  loras: models/loras/
  upscale_models: models/upscale_models/
  embeddings: models/embeddings/
  controlnet: models/controlnet/
  clip: models/clip/
EOF

# Créer un lien symbolique par défaut
RUN mkdir -p /workspace && ln -sf /runpod-volume /workspace/runpod-volume
