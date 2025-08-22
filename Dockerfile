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

# Installer le handler ComfyUI pour RunPod
RUN echo "Téléchargement du handler ComfyUI pour RunPod..." && \
    curl -o /app/handler.py https://raw.githubusercontent.com/runpod/runpod-worker-comfy/main/comfyui/handler.py && \
    chmod +x /app/handler.py && \
    # Installer les dépendances du handler
    pip install --no-cache-dir runpod

# Vérification de la structure et des corrections
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

# Créer un script de démarrage simplifié avec heredoc pour éviter les problèmes d'échappement
RUN cat > /start.sh << 'EOF'
#!/bin/bash
echo "Démarrage du conteneur..."

# Nettoyer les fichiers résiduels problématiques
rm -f /comfyui/comfy/ldm/res4lyf.py 2>/dev/null || true
rm -rf /comfyui/comfy/ldm/hidream 2>/dev/null || true

# Attendre le volume réseau avec timeout
echo "Attente du volume réseau..."
timeout=60
while [ ! -d /runpod-volume/ComfyUI ] && [ $timeout -gt 0 ]; do
    sleep 2
    timeout=$((timeout-2))
done

if [ ! -d /runpod-volume/ComfyUI ]; then
    echo "Avertissement: Volume réseau non trouvé après 60 secondes"
else
    echo "Volume réseau trouvé"
fi

# Configurer le PYTHONPATH
export PYTHONPATH="/comfyui:/comfyui/custom_nodes/RES4LYF:/comfyui/custom_nodes/RES4LYF/hidream:$PYTHONPATH"

# Démarrer ComfyUI
cd /comfyui
python main.py --fast --listen --port 8188 &

# Attendre que le serveur soit prêt
echo "Attente du démarrage de ComfyUI..."
timeout=30
while ! curl -s http://127.0.0.1:8188 >/dev/null && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

if [ $timeout -eq 0 ]; then
    echo "Avertissement: Timeout lors de l'attente de ComfyUI"
else
    echo "ComfyUI est démarré"
fi

# Démarrer le handler RunPod
echo "Démarrage du handler RunPod..."
exec python -u /app/handler.py
EOF

RUN chmod +x /start.sh

# Point d'entrée
CMD ["/start.sh"]
