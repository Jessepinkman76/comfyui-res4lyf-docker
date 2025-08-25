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
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root
RUN useradd -m -u 1000 -s /bin/bash comfyuser
USER comfyuser
WORKDIR /home/comfyuser

# Configurer l'environnement Python
ENV PATH="/home/comfyuser/.local/bin:$PATH"
RUN pip install --upgrade pip setuptools wheel

# Afficher les versions de Python et pip pour le debug
RUN python3 --version && pip --version

# Installer torch avec CUDA 12.1 en premier (version compatible)
RUN pip install --no-cache-dir \
    torch==2.0.1+cu118 \
    torchvision==0.15.2+cu118 \
    torchaudio==2.0.2+cu118 \
    --extra-index-url https://download.pytorch.org/whl/cu118

# Installer les dépendances de base une par une avec gestion d'erreurs
RUN pip install --no-cache-dir aiohttp && \
    pip install --no-cache-dir pillow && \
    pip install --no-cache-dir numpy && \
    pip install --no-cache-dir scipy && \
    pip install --no-cache-dir pyyaml && \
    pip install --no-cache-dir requests && \
    pip install --no-cache-dir safetensors && \
    pip install --no-cache-dir transformers && \
    pip install --no-cache-dir accelerate && \
    pip install --no-cache-dir diffusers

# Installer opencv-python-headless au lieu de opencv-python (moins de dépendances)
RUN pip install --no-cache-dir opencv-python-headless

# Cloner ComfyUI et les nodes custom APRÈS l'installation des dépendances
RUN git clone https://github.com/jalberty2018/run-comfyui-wan.git ComfyUI

# Afficher la structure du repository pour debug
RUN echo "Structure du repository ComfyUI:" && \
    find ComfyUI/ -maxdepth 3 -type d -print

# Installer ComfyUI depuis le repository officiel
RUN pip install --no-cache-dir \
    git+https://github.com/comfyanonymous/ComfyUI.git

# Installer les dépendances des nodes custom
RUN if [ -d "ComfyUI/custom_nodes" ]; then \
    echo "Installation des dépendances pour les nodes custom..." && \
    find ComfyUI/custom_nodes/ -name "requirements.txt" -type f | while read file; do \
        echo "Installation depuis $file" && \
        pip install --no-cache-dir -r "$file" || echo "Échec de l'installation pour $file, continuation..."; \
    done; \
    fi

# Installer manuellement les dépendances courantes pour les nodes custom
RUN pip install --no-cache-dir \
    insightface \
    onnxruntime \
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
