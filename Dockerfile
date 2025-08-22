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

# Installer TOUTES les dépendances nécessaires
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
    safetensors \
    einops \
    kornia \
    timm \
    huggingface_hub

# Cloner RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Configuration pour pointer vers les modèles du volume réseau
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

# Créer des liens symboliques pour que ComfyUI trouve les custom nodes
RUN mkdir -p /app/custom_nodes && \
    ln -sf /comfyui/custom_nodes/RES4LYF /app/custom_nodes/RES4LYF

# Corriger la structure comfy pour RES4LYF
RUN if [ -d "/comfyui/custom_nodes/RES4LYF/comfy" ]; then \
    echo "Copie de la structure comfy de RES4LYF..."; \
    mkdir -p /comfyui/comfy/ldm && \
    cp -r /comfyui/custom_nodes/RES4LYF/comfy/ldm/hidream /comfyui/comfy/ldm/; \
else \
    echo "Création de la structure manquante..."; \
    mkdir -p /comfyui/comfy/ldm/hidream && \
    touch /comfyui/comfy/ldm/hidream/__init__.py; \
fi

# Vérification de la structure
RUN echo "=== Structure RES4LYF ===" && \
    find /comfyui/custom_nodes/RES4LYF -type f -name "*.py" | head -10 && \
    echo "=== Structure comfy ===" && \
    find /comfyui/comfy -name "hidream" -type d

# Vérifier et copier le handler depuis l'image de base
RUN if [ -f "/app/handler.py" ]; then \
    echo "Handler found in /app"; \
else \
    echo "Recherche du handler..."; \
    find / -name "handler.py" -exec echo "Handler trouvé: {}" \; 2>/dev/null | head -1; \
fi

# Point d'entrée
CMD ["bash", "-c", "python -u /app/handler.py"]
