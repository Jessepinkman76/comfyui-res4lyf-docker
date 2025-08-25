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

# Cloner ComfyUI et les nodes custom avec vérification
RUN git clone https://github.com/jalberty2018/run-comfyui-wan.git ComfyUI && \
    echo "Contenu du répertoire ComfyUI après clone:" && \
    ls -la ComfyUI/ && \
    echo "Recherche de requirements.txt:" && \
    find ComfyUI/ -name "requirements.txt" -type f

# Vérifier que le clone a réussi et trouver requirements.txt
RUN if [ ! -d "ComfyUI" ]; then \
    echo "ERROR: ComfyUI directory not found"; \
    exit 1; \
    fi && \
    REQUIREMENTS_FILE=$(find ComfyUI/ -name "requirements.txt" -type f | head -1) && \
    if [ -z "$REQUIREMENTS_FILE" ]; then \
    echo "ERROR: requirements.txt not found in ComfyUI directory or subdirectories"; \
    echo "Contents of ComfyUI directory:"; \
    ls -la ComfyUI/; \
    exit 1; \
    else \
    echo "Found requirements.txt at: $REQUIREMENTS_FILE"; \
    fi

# Configurer l'environnement Python
ENV PATH="/home/comfyuser/.local/bin:$PATH"
RUN pip install --upgrade pip

# Afficher les versions de Python et pip pour le debug
RUN python3 --version && pip --version

# Trouver le requirements.txt et installer les dépendances
RUN REQUIREMENTS_FILE=$(find ComfyUI/ -name "requirements.txt" -type f | head -1) && \
    echo "Installing dependencies from: $REQUIREMENTS_FILE" && \
    pip install --no-cache-dir -r "$REQUIREMENTS_FILE" 2>&1 | tee pip_install.log || \
    (echo "PIP INSTALL FAILED. LOG CONTENTS:" && cat pip_install.log && exit 1)

# Installer torch avec CUDA 12.1
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Installer les dépendances des nodes custom (RES4LYF)
RUN if [ -f "ComfyUI/custom_nodes/RES4LYF/requirements.txt" ]; then \
    echo "Installing RES4LYF dependencies..." && \
    pip install --no-cache-dir -r ComfyUI/custom_nodes/RES4LYF/requirements.txt; \
    else \
    echo "RES4LYF requirements.txt not found, searching in custom nodes..."; \
    CUSTOM_REQ=$(find ComfyUI/custom_nodes/ -name "requirements.txt" -type f); \
    if [ -n "$CUSTOM_REQ" ]; then \
        echo "Found custom node requirements: $CUSTOM_REQ"; \
        for req in $CUSTOM_REQ; do \
        echo "Installing from $req"; \
        pip install --no-cache-dir -r "$req"; \
        done; \
    fi; \
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
