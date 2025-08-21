FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Install curl (the only missing dependency)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Installe les dépendances système en une seule couche
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone et installe RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git
WORKDIR /comfyui/custom_nodes/RES4LYF
RUN pip install -r requirements.txt

# Corrige les conflits de dépendances
RUN pip install 'click<=8.1.8' 'urllib3>=1.21,<2.0' --force-reinstall

# Crée le fichier de configuration (plus lisible)
RUN cat > /comfyui/extra_model_paths.yaml << EOF
comfyui:
  base_path: /runpod-volume/ComfyUI/
  is_default: true
  text_encoders: models/text_encoders/
  vae: models/vae/
  diffusion_models: |
    models/diffusion_models
    models/unet
  checkpoints: models/checkpoints/
  clip: models/clip/
  loras: models/loras/
  embeddings: models/embeddings/
  upscale_models: models/upscale_models/
EOF
