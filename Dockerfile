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

# Solution: Transformer RES4LYF en vrai custom node
RUN echo "Transformation de RES4LYF en custom node propre..." && \
    # Créer la structure de package appropriée
    mkdir -p /comfyui/custom_nodes/RES4LYF/hidream && \
    # Déplacer les fichiers dans la structure de package
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        mv /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/custom_nodes/RES4LYF/hidream/; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        mv /comfyui/custom_nodes/RES4LYF/model.py /comfyui/custom_nodes/RES4LYF/hidream/; \
    fi && \
    # Créer les fichiers __init__.py nécessaires
    touch /comfyui/custom_nodes/RES4LYF/hidream/__init__.py && \
    touch /comfyui/custom_nodes/RES4LYF/__init__.py && \
    # Corriger TOUS les imports problématiques
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy\.ldm\.hidream\.model import/from .hidream.model import/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/sigmas.py" ]; then \
        sed -i 's/from helper import/from .hidream.helper import/g' /comfyui/custom_nodes/RES4LYF/sigmas.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/__init__.py" ]; then \
        sed -i 's/from \. import/from . import/g' /comfyui/custom_nodes/RES4LYF/__init__.py; \
    fi

# Nettoyer les fichiers résiduels problématiques
RUN rm -f /comfyui/comfy/ldm/res4lyf.py 2>/dev/null || true
RUN rm -rf /comfyui/comfy/ldm/hidream 2>/dev/null || true

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
