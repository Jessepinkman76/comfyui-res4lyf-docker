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

# Vérifier que le clone a réussi et que requirements.txt existe
RUN if [ ! -f "ComfyUI/requirements.txt" ]; then \
    echo "ERROR: requirements.txt not found in ComfyUI directory"; \
    echo "Contents of ComfyUI directory:"; \
    ls -la ComfyUI/; \
    exit 1; \
    fi

# Configurer l'environnement Python
ENV PATH="/home/comfyuser/.local/bin:$PATH"
RUN pip install --upgrade pip

# Afficher les versions de Python et pip pour le debug
RUN python3 --version && pip --version

# Installer torch en premier (souvent la source de problèmes)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Installer les dépendances de base ComfyUI avec logging détaillé
RUN pip install --no-cache-dir -r ComfyUI/requirements.txt 2>&1 | tee pip_install.log || \
    (echo "PIP INSTALL FAILED. LOG CONTENTS:" && cat pip_install.log && exit 1)

# Installer les dépendances des nodes custom (RES4LYF)
RUN if [ -f "ComfyUI/custom_nodes/RES4LYF/requirements.txt" ]; then \
    echo "Installing RES4LYF dependencies..." && \
    pip install --no-cache-dir -r ComfyUI/custom_nodes/RES4LYF/requirements.txt; \
    else \
    echo "RES4LYF requirements.txt not found, skipping..."; \
    fi

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
