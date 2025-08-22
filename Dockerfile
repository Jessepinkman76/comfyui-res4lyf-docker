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
    huggingface_hub \
    opencv-python

# Cloner RES4LYF avec la branche correcte
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    cd RES4LYF && \
    git checkout main

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

# Solution complète pour RES4LYF - copier tous les fichiers nécessaires
RUN mkdir -p /comfyui/comfy/ldm/hidream && \
    mkdir -p /comfyui/comfy/ldm

# Copier tous les fichiers nécessaires depuis RES4LYF
RUN echo "Copie de tous les fichiers nécessaires depuis RES4LYF..." && \
    # Copier model.py
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        cp /comfyui/custom_nodes/RES4LYF/model.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    # Copier helper.py
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        cp /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/comfy/ldm/; \
    fi && \
    # Copier tous les autres fichiers Python de la racine
    find /comfyui/custom_nodes/RES4LYF -maxdepth 1 -name "*.py" -exec cp {} /comfyui/comfy/ldm/ \; 2>/dev/null || true

# Créer les fichiers __init__.py nécessaires
RUN touch /comfyui/comfy/ldm/__init__.py && \
    touch /comfyui/comfy/ldm/hidream/__init__.py

# Vérification de la structure
RUN echo "=== Structure RES4LYF ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/ && \
    echo "=== Structure comfy/ldm ===" && \
    ls -la /comfyui/comfy/ldm/ && \
    echo "=== Structure comfy/ldm/hidream ===" && \
    ls -la /comfyui/comfy/ldm/hidream/

# Vérifier et copier le handler depuis l'image de base
RUN if [ -f "/app/handler.py" ]; then \
    echo "Handler found in /app"; \
else \
    echo "Recherche du handler..."; \
    HANDLER_PATH=$(find / -name "handler.py" -type f 2>/dev/null | head -1) && \
    if [ -n "$HANDLER_PATH" ]; then \
        echo "Handler trouvé à: $HANDLER_PATH"; \
        mkdir -p /app && \
        cp "$HANDLER_PATH" /app/; \
    else \
        echo "Avertissement: Handler non trouvé"; \
    fi; \
fi

# Point d'entrée
CMD ["bash", "-c", "python -u /app/handler.py"]
