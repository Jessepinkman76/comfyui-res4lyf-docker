FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Installe les dépendances système
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Crée et configure l'environnement virtuel
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Clone et installe RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    cd RES4LYF && \
    /opt/venv/bin/pip install -r requirements.txt

# Installe les dépendances avec résolution des conflits
RUN /opt/venv/bin/pip install \
    'click<=8.1.8' \
    'urllib3>=1.21,<2.0' \
    runpod \
    --force-reinstall

# Crée le fichier de configuration
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

WORKDIR /comfyui
