FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer curl et git
RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

# Cloner RES4LYF manuellement
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installer les dépendances critiques de RES4LYF
RUN pip install PyWavelets numpy scipy

# Configuration du network volume
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
