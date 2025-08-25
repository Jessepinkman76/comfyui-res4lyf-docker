# Utiliser une image de base compatible
FROM ls250824/comfyui-runtime:22082025 AS base

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

# Mettre à jour pip
RUN pip install --no-cache-dir --upgrade pip

# Définir le répertoire de travail
WORKDIR /ComfyUI

# Cloner tous les custom nodes nécessaires
RUN mkdir -p custom_nodes && cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/welltop-cn/ComfyUI-TeaCache.git && \
    git clone https://github.com/liusida/ComfyUI-Login.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone https://github.com/Flow-two/ComfyUI-WanStartEndFramesNative.git && \
    git clone https://github.com/ShmuelRonen/ComfyUI-VideoUpscale_WithModel && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    git clone https://github.com/BlenderNeko/ComfyUI_Noise.git && \
    git clone https://github.com/ChenDarYen/ComfyUI-NAG.git && \
    git clone https://github.com/vrgamegirl19/comfyui-vrgamedevgirl.git && \
    git clone https://github.com/evanspearman/ComfyMath.git && \
    git clone https://github.com/city96/ComfyUI-GGUF.git && \
    git clone https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git && \
    git clone https://github.com/Azornes/Comfyui-Resolution-Master.git && \
    git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale --recursive

# Installer les dépendances Python pour tous les custom nodes
RUN pip install --no-cache-dir \
    diffusers \
    psutil \
    -r /ComfyUI/custom_nodes/ComfyUI-Login/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-TeaCache/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt \
    -r /ComfyUI/custom_nodes/comfyui-vrgamedevgirl/requirements.txt \
    -r /ComfyUI/custom_nodes/RES4LYF/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-GGUF/requirements.txt

# Installation correcte de RES4LYF
RUN echo "Installation manuelle de RES4LYF..." && \
    # Copier les fichiers dans la structure ComfyUI
    if [ -d "/ComfyUI/custom_nodes/RES4LYF/comfy" ]; then \
        cp -r /ComfyUI/custom_nodes/RES4LYF/comfy/* /ComfyUI/comfy/; \
    fi && \
    # Créer les répertoires nécessaires
    mkdir -p /ComfyUI/comfy/ldm/hidream && \
    # Copier les fichiers spécifiques
    if [ -f "/ComfyUI/custom_nodes/RES4LYF/helper.py" ]; then \
        cp /ComfyUI/custom_nodes/RES4LYF/helper.py /ComfyUI/comfy/ldm/hidream/; \
    fi && \
    if [ -f "/ComfyUI/custom_nodes/RES4LYF/model.py" ]; then \
        cp /ComfyUI/custom_nodes/RES4LYF/model.py /ComfyUI/comfy/ldm/hidream/; \
    fi && \
    # Créer les fichiers __init__.py nécessaires
    echo "# RES4LYF package" > /ComfyUI/comfy/ldm/hidream/__init__.py && \
    # Corriger les imports dans les fichiers RES4LYF
    if [ -f "/ComfyUI/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy\.ldm\.hidream\.model import/from comfy.ldm.hidream.model import/g' /ComfyUI/custom_nodes/RES4LYF/models.py; \
    fi && \
    if [ -f "/ComfyUI/custom_nodes/RES4LYF/sigmas.py" ]; then \
        sed -i 's/from helper import/from comfy.ldm.hidream.helper import/g' /ComfyUI/custom_nodes/RES4LYF/sigmas.py; \
    fi

# Nettoyer les fichiers résiduels problématiques
RUN rm -f /ComfyUI/comfy/ldm/res4lyf.py 2>/dev/null || true

# Installer le handler RunPod
RUN mkdir -p /app && \
    pip install runpod aiohttp && \
    # Télécharger un handler adapté
    curl -o /app/handler.py https://gist.githubusercontent.com/assistant/raw/example-handler.py && \
    chmod +x /app/handler.py

# Créer un script de démarrage personnalisé
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Démarrer ComfyUI
echo "Démarrage de ComfyUI..."
cd /ComfyUI
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

# Exposer les ports
EXPOSE 8188 8000

# Point d'entrée
CMD ["/start.sh"]
