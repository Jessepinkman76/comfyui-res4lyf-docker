FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Installe les dépendances système
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Installe torch et les dépendances essentielles dans l'environnement Python global
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip install huggingface_hub transformers accelerate && \
    pip install safetensors aiohttp

# Clone RES4LYF et vérifie la structure
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    cd RES4LYF && \
    ls -la && \
    # Vérifie si le dossier beta existe
    if [ ! -d "beta" ]; then echo "WARNING: beta directory missing, creating it"; mkdir -p beta; fi && \
    # Crée constants.py si il n'existe pas
    if [ ! -f "beta/constants.py" ]; then \
        echo "WARNING: beta/constants.py missing, creating default"; \
        echo "MAX_STEPS = 100" > beta/constants.py; \
        echo "__init__.py created for beta module"; \
        touch beta/__init__.py; \
    fi && \
    # Vérifie les permissions
    chmod -R 755 . && \
    # Installe les dépendances du projet RES4LYF si requirements.txt existe
    if [ -f "requirements.txt" ]; then \
        pip install -r requirements.txt; \
    else \
        echo "No requirements.txt found for RES4LYF"; \
    fi

# Installe les dépendances supplémentaires potentiellement nécessaires
RUN pip install opencv-python pillow numpy requests click

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
