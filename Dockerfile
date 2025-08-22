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

# Solution: Organiser correctement les fichiers RES4LYF
RUN echo "Organisation des fichiers RES4LYF..." && \
    # Vérifier la structure de RES4LYF
    echo "=== Structure avant organisation ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/ && \
    # Déplacer les fichiers si nécessaire
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        mkdir -p /comfyui/custom_nodes/RES4LYF/hidream && \
        mv /comfyui/custom_nodes/RES4LYF/model.py /comfyui/custom_nodes/RES4LYF/hidream/; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        mkdir -p /comfyui/custom_nodes/RES4LYF/hidream && \
        mv /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/custom_nodes/RES4LYF/hidream/; \
    fi && \
    # Créer les __init__.py nécessaires
    touch /comfyui/custom_nodes/RES4LYF/hidream/__init__.py && \
    # Corriger les imports
    if [ -f "/comfyui/custom_nodes/RES4LYF/hidream/model.py" ]; then \
        sed -i 's/from ..helper/from .helper/g' /comfyui/custom_nodes/RES4LYF/hidream/model.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy.ldm.hidream.model/from hidream.model/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi

# Créer un script de démarrage simplifié
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "Démarrage du conteneur..."' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Nettoyer les fichiers résiduels problématiques' >> /start.sh && \
    echo 'rm -f /comfyui/comfy/ldm/res4lyf.py 2>/dev/null || true' >> /start.sh && \
    echo 'rm -rf /comfyui/comfy/ldm/hidream 2>/dev/null || true' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Attendre le volume réseau avec timeout' >> /start.sh && \
    echo 'echo "Attente du volume réseau..."' >> /start.sh && \
    echo 'timeout=60' >> /start.sh && \
    echo 'while [ ! -d /runpod-volume/ComfyUI ] && [ $timeout -gt 0 ]; do' >> /start.sh && \
    echo '    sleep 2' >> /start.sh && \
    echo '    timeout=$((timeout-2))' >> /start.sh && \
    echo 'done' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'if [ ! -d /runpod-volume/ComfyUI ]; then' >> /start.sh && \
    echo '    echo "Avertissement: Volume réseau non trouvé après 60 secondes"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '    echo "Volume réseau trouvé"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Configurer le PYTHONPATH' >> /start.sh && \
    echo 'export PYTHONPATH="/comfyui:/comfyui/custom_nodes/RES4LYF:/comfyui/custom_nodes/RES4LYF/hidream:$PYTHONPATH"' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Démarrer ComfyUI' >> /start.sh && \
    echo 'cd /comfyui' >> /start.sh && \
    echo 'python main.py --fast --listen --port 8188 &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Attendre que le serveur soit prêt' >> /start.sh && \
    echo 'echo "Attente du démarrage de ComfyUI..."' >> /start.sh && \
    echo 'timeout=30' >> /start.sh && \
    echo 'while ! curl -s http://127.0.0.1:8188 >/dev/null && [ $timeout -gt 0 ]; do' >> /start.sh && \
    echo '    sleep 1' >> /start.sh && \
    echo '    timeout=$((timeout-1))' >> /start.sh && \
    echo 'done' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'if [ $timeout -eq 0 ]; then' >> /start.sh && \
    echo '    echo "Avertissement: Timeout lors de l\'attente de ComfyUI"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '    echo "ComfyUI est démarré"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Trouver et exécuter le handler' >> /start.sh && \
    echo 'HANDLER_PATH=$(find / -name "handler.py" -type f 2>/dev/null | head -1)' >> /start.sh && \
    echo 'if [ -z "$HANDLER_PATH" ]; then' >> /start.sh && \
    echo '    echo "Utilisation du handler par défaut: /app/handler.py"' >> /start.sh && \
    echo '    HANDLER_PATH="/app/handler.py"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '    echo "Handler trouvé: $HANDLER_PATH"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'exec python -u "$HANDLER_PATH"' >> /start.sh && \
    chmod +x /start.sh

# Vérification de la structure
RUN echo "=== Structure RES4LYF ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/ && \
    echo "=== Contenu du dossier hidream ===" && \
    ls -la /comfyui/custom_nodes/RES4LYF/hidream/ && \
    echo "=== Vérification des corrections ===" && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        grep -n "from.*hidream" /comfyui/custom_nodes/RES4LYF/models.py || echo "Aucun import hidream trouvé"; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/hidream/model.py" ]; then \
        grep -n "from.*helper" /comfyui/custom_nodes/RES4LYF/hidream/model.py || echo "Aucun import helper trouvé"; \
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
CMD ["/start.sh"]
