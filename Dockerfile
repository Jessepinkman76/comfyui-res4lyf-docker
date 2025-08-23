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
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Mettre à jour pip et numpy
RUN pip install --no-cache-dir --upgrade pip numpy

# Installer les dépendances nécessaires
RUN pip install --no-cache-dir \
    PyWavelets \
    scipy \
    pyyaml \
    pyOpenSSL \
    simpleeval \
    matplotlib \
    opencv-python-headless \
    rembg \
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

# Solution: Installation complète de RES4LYF selon sa méthode recommandée
RUN echo "Installation complète de RES4LYF..." && \
    # Créer la structure de répertoires requise par RES4LYF dans ComfyUI
    mkdir -p /comfyui/comfy/ldm/hidream && \
    # Copier les fichiers nécessaires aux emplacements attendus par RES4LYF
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        cp /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        cp /comfyui/custom_nodes/RES4LYF/model.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    # Créer un fichier __init__.py pour le package hidream
    echo "# RES4LYF package" > /comfyui/comfy/ldm/hidream/__init__.py && \
    # Corriger les imports dans tous les fichiers RES4LYF
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy\.ldm\.hidream\.model import/from comfy.ldm.hidream.model import/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/sigmas.py" ]; then \
        sed -i 's/from helper import/from comfy.ldm.hidream.helper import/g' /comfyui/custom_nodes/RES4LYF/sigmas.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/beta/rk_guide_func_beta.py" ]; then \
        sed -i 's/from \.\.models import/from ..models import/g' /comfyui/custom_nodes/RES4LYF/beta/rk_guide_func_beta.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/conditioning.py" ]; then \
        sed -i 's/from \.beta\.constants import/from .beta.constants import/g' /comfyui/custom_nodes/RES4LYF/conditioning.py; \
    fi

# Nettoyer les fichiers résiduels problématiques
RUN rm -f /comfyui/comfy/ldm/res4lyf.py 2>/dev/null || true

# Télécharger le handler RunPod
RUN mkdir -p /app && \
    curl -o /app/handler.py https://raw.githubusercontent.com/runpod-workers/worker-comfyui/main/handler.py && \
    chmod +x /app/handler.py

# Installer les dépendances du handler
RUN pip install --no-cache-dir runpod aiohttp

# Créer un script de démarrage
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Démarrer ComfyUI en arrière-plan
echo "Démarrage de ComfyUI..."
cd /comfyui
python main.py --listen --port 8188 &

# Attendre que ComfyUI soit prêt
echo "Attente du démarrage de ComfyUI..."
for i in {1..30}; do
    if curl -s http://127.0.0.1:8188 >/dev/null; then
        echo "ComfyUI est démarré et accessible"
        break
    fi
    echo "Tentative $i/30 - ComfyUI n'est pas encore prêt"
    sleep 2
done

# Démarrer le handler RunPod
echo "Démarrage du handler RunPod..."
exec python -u /app/handler.py
EOF

RUN chmod +x /start.sh

# Point d'entrée
CMD ["/start.sh"]
