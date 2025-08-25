# Utiliser une image de base avec CUDA 12.1
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Installer les dépendances système
RUN apt-get update && \
    apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root
RUN useradd -m -u 1000 -s /bin/bash comfyuser
USER comfyuser
WORKDIR /home/comfyuser

# Cloner ComfyUI et les nodes custom
RUN git clone https://github.com/jalberty2018/run-comfyui-wan.git ComfyUI

# Afficher la structure du repository pour debug
RUN echo "Structure du repository ComfyUI:" && \
    find ComfyUI/ -maxdepth 3 -type d -print && \
    echo "Fichiers dans ComfyUI:" && \
    ls -la ComfyUI/

# Configurer l'environnement Python
ENV PATH="/home/comfyuser/.local/bin:$PATH"
RUN pip install --upgrade pip

# Afficher les versions de Python et pip pour le debug
RUN python3 --version && pip --version

# Installer les dépendances de base pour ComfyUI (sans requirements.txt)
RUN pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    aiohttp \
    pillow \
    numpy \
    scipy \
    opencv-python \
    pyyaml \
    requests \
    safetensors \
    transformers \
    accelerate \
    diffusers

# Installer ComfyUI directement depuis le repository officiel
RUN pip install --no-cache-dir \
    git+https://github.com/comfyanonymous/ComfyUI.git

# Installer les dépendances des nodes custom (RES4LYF et autres)
RUN if [ -d "ComfyUI/custom_nodes" ]; then \
    echo "Recherche des requirements.txt dans les custom_nodes..." && \
    find ComfyUI/custom_nodes/ -name "requirements.txt" -type f | while read file; do \
        echo "Installation des dépendances depuis $file" && \
        pip install --no-cache-dir -r "$file" || echo "Échec de l'installation pour $file, continuation..."; \
    done; \
    fi

# Installer manuellement les dépendances courantes pour les nodes custom
RUN pip install --no-cache-dir \
    insightface \
    onnxruntime \
    opencv-python-headless \
    scikit-image \
    imageio \
    imageio-ffmpeg

# Installer le SDK RunPod
RUN pip install --no-cache-dir runpod

# Copier les fichiers de configuration RunPod
COPY --chown=comfyuser:comfyuser handler.py .
COPY --chown=comfyuser:comfyuser rp_handler.py .
COPY --chown=comfyuser:comfyuser start.sh .
COPY --chown=comfyuser:comfyuser extra_model_paths.yaml .

# Configurer les variables d'environnement
ENV PYTHONPATH=/home/comfyuser/ComfyUI
ENV MODEL_PATH=/runpod-volume/models
ENV COMFYUI_PATH=/home/comfyuser/ComfyUI
ENV SERVE_API_LOCALLY=false

# Exposer le port
EXPOSE 8188

# Script de démarrage
CMD ["./start.sh"]
