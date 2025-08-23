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
    net-tools && \  # Pour netstat
    rm -rf /var/lib/apt/lists/*

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

# Solution: Laisser RES4LYF s'installer correctement dans la structure ComfyUI
RUN echo "Installation de RES4LYF dans la structure ComfyUI..." && \
    # Copier les fichiers nécessaires dans la structure ComfyUI
    if [ -d "/comfyui/custom_nodes/RES4LYF/comfy" ]; then \
        cp -r /comfyui/custom_nodes/RES4LYF/comfy/* /comfyui/comfy/; \
    fi && \
    # Créer les liens symboliques nécessaires
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        mkdir -p /comfyui/comfy/ldm/hidream && \
        cp /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        mkdir -p /comfyui/comfy/ldm/hidream && \
        cp /comfyui/custom_nodes/RES4LYF/model.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    # Corriger les imports dans les fichiers RES4LYF
    if [ -f "/comfyui/custom_nodes/RES4LYF/sigmas.py" ]; then \
        sed -i 's/from helper import/from comfy.ldm.hidream.helper import/g' /comfyui/custom_nodes/RES4LYF/sigmas.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy.ldm.hidream.model import/from comfy.ldm.hidream.model import/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi

# Nettoyer les fichiers résiduels problématiques
RUN rm -f /comfyui/comfy/ldm/res4lyf.py 2>/dev/null || true

# Télécharger le handler officiel de RunPod depuis la bonne URL
RUN echo "Téléchargement du handler RunPod..." && \
    mkdir -p /app && \
    curl -o /app/handler.py https://raw.githubusercontent.com/runpod-workers/worker-comfyui/main/handler.py && \
    chmod +x /app/handler.py

# Installer les dépendances du handler
RUN pip install --no-cache-dir runpod aiohttp

# Créer un script de démarrage qui lance ComfyUI en premier
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Démarrer ComfyUI en arrière-plan
echo "Démarrage de ComfyUI..."
cd /comfyui
python main.py --listen --port 8188 &
COMFY_PID=$!

# Fonction pour vérifier si ComfyUI est toujours en cours d'exécution
is_comfy_running() {
    kill -0 $COMFY_PID 2>/dev/null
}

# Attendre que ComfyUI soit prêt
echo "Attente du démarrage de ComfyUI..."
MAX_RETRIES=120  # Augmenter à 120 tentatives (4 minutes)
RETRY_DELAY=2

for i in $(seq 1 $MAX_RETRIES); do
    if ! is_comfy_running; then
        echo "Erreur: Le processus ComfyUI a été interrompu"
        exit 1
    fi

    # Vérifier si le port 8188 est en écoute
    if netstat -tln | grep :8188 > /dev/null; then
        echo "Port 8188 est en écoute, vérification de la réponse HTTP..."
        if curl -s http://127.0.0.1:8188 >/dev/null; then
            echo "ComfyUI est démarré et accessible"
            break
        fi
    fi
    
    echo "Tentative $i/$MAX_RETRIES - ComfyUI n'est pas encore prêt"
    sleep $RETRY_DELAY
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo "Erreur: ComfyUI n'a pas démarré après $MAX_RETRIES tentatives"
        echo "Affichage des processus..."
        ps aux
        echo "Affichage de l'écoute des ports..."
        netstat -tln
        kill $COMFY_PID 2>/dev/null
        exit 1
    fi
done

# Démarrer le handler RunPod
echo "Démarrage du handler RunPod..."
exec python -u /app/handler.py
EOF

RUN chmod +x /start.sh

# Point d'entrée
CMD ["/start.sh"]
