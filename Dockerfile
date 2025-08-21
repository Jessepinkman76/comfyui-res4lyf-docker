FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer curl et git (nécessaires pour les commandes suivantes)
RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

# Installer RES4LYF en utilisant comfy-node-install
RUN comfy-node-install https://github.com/ClownsharkBatwing/RES4LYF.git

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
