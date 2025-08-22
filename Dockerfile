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

# Nettoyer les fichiers problématiques qui pourraient avoir été copiés précédemment
RUN rm -rf /comfyui/comfy/ldm/res4lyf.py /comfyui/comfy/ldm/hidream 2>/dev/null || true

# Solution complète: Organiser correctement les fichiers RES4LYF
RUN echo "Organisation des fichiers RES4LYF..." && \
    # Créer le dossier hidream s'il n'existe pas
    mkdir -p /comfyui/custom_nodes/RES4LYF/hidream && \
    # Déplacer model.py dans hidream s'il est à la racine
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        mv /comfyui/custom_nodes/RES4LYF/model.py /comfyui/custom_nodes/RES4LYF/hidream/; \
    fi && \
    # Déplacer helper.py dans hidream s'il est à la racine
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        mv /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/custom_nodes/RES4LYF/hidream/; \
    fi && \
    # Créer les __init__.py nécessaires
    touch /comfyui/custom_nodes/RES4LYF/hidream/__init__.py && \
    # Corriger les imports dans model.py
    if [ -f "/comfyui/custom_nodes/RES4LYF/hidream/model.py" ]; then \
        sed -i 's/from ..helper/from .helper/g' /comfyui/custom_nodes/RES4LYF/hidream/model.py; \
    fi && \
    # Corriger les imports dans models.py
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy.ldm.hidream.model/from hidream.model/g' /comfyui/custom_nodes/RES4LYF/models.py; \
        sed -i 's/from hidream.model/from .hidream.model/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi

# Vérification de la structure et des corrections
RUN echo "=== Structure RES4LYF ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/ && \
    echo "=== Contenu du dossier hidream ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/hidream/ && \
    echo "=== Vérification des corrections ===" && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        grep -n "from.*hidream" /comfyui/custom_nodes/RES4LYF/models.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/hidream/model.py" ]; then \
        grep -n "from.*helper" /comfyui/custom_nodes/RES4LYF/hidream/model.py; \
    fi

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
