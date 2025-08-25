# Base image avec CUDA 12.1
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root
RUN useradd -m -u 1000 -s /bin/bash comfyuser
USER comfyuser
WORKDIR /home/comfyuser

# Cloner ComfyUI et les nodes custom
RUN git clone https://github.com/jalberty2018/run-comfyui-wan.git ComfyUI

# Configurer l'environnement Python
ENV PATH="/home/comfyuser/.local/bin:$PATH"
RUN pip install --upgrade pip

# Installer les dépendances de base ComfyUI
RUN pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
RUN pip install -r ComfyUI/requirements.txt

# Installer les dépendances des nodes custom (ex: RES4LYF)
# NOTE: Adapter selon les fichiers requirements.txt des nodes
RUN if [ -f "ComfyUI/custom_nodes/RES4LYF/requirements.txt" ]; then \
    pip install -r ComfyUI/custom_nodes/RES4LYF/requirements.txt; \
    fi

# Installer le SDK RunPod
RUN pip install runpod

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

# Exposer le port (si nécessaire)
EXPOSE 8188

# Script de démarrage
CMD ["./start.sh"]
