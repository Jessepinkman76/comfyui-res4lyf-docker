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

# Mettre à jour numpy pour résoudre les conflits de version
RUN pip install --no-cache-dir --upgrade numpy

# Installer les dépendances nécessaires
RUN pip install --no-cache-dir \
    PyWavelets \
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

# Solution propre: Modifier les imports de RES4LYF au lieu de déplacer les fichiers
# Créer un patch pour corriger les imports problématiques
RUN echo "Correction des imports dans RES4LYF..." && \
    # Créer un fichier __init__.py dans le dossier hidream de RES4LYF
    touch /comfyui/custom_nodes/RES4LYF/hidream/__init__.py && \
    # Modifier les imports dans les fichiers RES4LYF pour qu'ils pointent vers le custom node
    sed -i 's/from comfy.ldm.hidream.model/from hidream.model/g' /comfyui/custom_nodes/RES4LYF/models.py && \
    sed -i 's/from ..helper/from hidream.helper/g' /comfyui/custom_nodes/RES4LYF/hidream/model.py

# Vérification de la structure
RUN echo "=== Structure RES4LYF ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/ && \
    echo "=== Contenu du dossier hidream ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/hidream/

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
