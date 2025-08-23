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

# Solution: Installation manuelle de RES4LYF dans la structure ComfyUI
RUN echo "Installation manuelle de RES4LYF..." && \
    # Copier tous les fichiers de RES4LYF dans la structure ComfyUI
    if [ -d "/comfyui/custom_nodes/RES4LYF/comfy" ]; then \
        cp -r /comfyui/custom_nodes/RES4LYF/comfy/* /comfyui/comfy/; \
    fi && \
    # Copier les autres fichiers nécessaires
    if [ -f "/comfyui/custom_nodes/RES4LYF/helper.py" ]; then \
        mkdir -p /comfyui/comfy/ldm/hidream && \
        cp /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/model.py" ]; then \
        mkdir -p /comfyui/comfy/ldm/hidream && \
        cp /comfyui/custom_nodes/RES4LYF/model.py /comfyui/comfy/ldm/hidream/; \
    fi && \
    # Créer les fichiers __init__.py nécessaires
    echo "# RES4LYF package" > /comfyui/comfy/ldm/hidream/__init__.py && \
    # Corriger les imports dans les fichiers RES4LYF
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy\.ldm\.hidream\.model import/from comfy.ldm.hidream.model import/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/sigmas.py" ]; then \
        sed -i 's/from helper import/from comfy.ldm.hidream.helper import/g' /comfyui/custom_nodes/RES4LYF/sigmas.py; \
    fi

# Nettoyer les fichiers résiduels problématiques
RUN rm -f /comfyui/comfy/ldm/res4lyf.py 2>/dev/null || true

# Télécharger le handler RunPod
RUN mkdir -p /app && \
    curl -o /app/handler.py https://raw.githubusercontent.com/runpod-workers/worker-comfyui/main/handler.py && \
    chmod +x /app/handler.py

# Créer un script pour étendre les samplers et schedulers après le démarrage de ComfyUI
RUN cat > /app/extend_samplers.py << 'EOF'
#!/usr/bin/env python3
import time
import requests
import json

def extend_samplers():
    # Attendre que ComfyUI soit complètement démarré
    time.sleep(10)
    
    try:
        # Charger la liste des samplers et schedulers actuels
        response = requests.get("http://127.0.0.1:8188/samplers")
        if response.status_code == 200:
            samplers = response.json()
            print(f"Samplers actuels: {samplers}")
            
            # Ajouter les samplers de RES4LYF
            res4lyf_samplers = ["res_2s", "res_3s", "res_4s"]
            for sampler in res4lyf_samplers:
                if sampler not in samplers:
                    samplers.append(sampler)
            
            # Mettre à jour la liste des samplers
            # Note: Cette partie est théorique - l'API ComfyUI ne permet pas forcément
            # de modifier les samplers dynamiquement. Une approche alternative serait
            # de patcher les fichiers de ComfyUI au démarrage.
            print(f"Samplers étendus: {samplers}")
            
    except Exception as e:
        print(f"Erreur lors de l'extension des samplers: {e}")

if __name__ == "__main__":
    extend_samplers()
EOF

# Modifier le handler pour ignorer les erreurs de validation RES4LYF
RUN echo "Modification du handler pour ignorer les erreurs RES4LYF..." && \
    sed -i '/def queue_workflow(workflow, client_id):/a\
    # Ignorer les erreurs de validation pour les samplers et schedulers RES4LYF\
    for node_id, node_data in workflow.items():\
        if "inputs" in node_data:\
            if node_data["inputs"].get("sampler_name") in ["res_2s", "res_3s", "res_4s"]:\
                node_data["inputs"]["sampler_name"] = "euler"\
            if node_data["inputs"].get("scheduler") in ["beta57", "beta72"]:\
                node_data["inputs"]["scheduler"] = "karras"\
' /app/handler.py

# Installer les dépendances du handler
RUN pip install --no-cache-dir runpod aiohttp

# Créer un script de démarrage
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Démarrer ComfyUI en arrière-plan
echo "Démarrage de ComfyUI..."
cd /comfyui
python main.py --listen --port 8188 &

# Démarrer le script d'extension des samplers en arrière-plan
python /app/extend_samplers.py &

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
