FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer git seulement si nécessaire
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Cloner RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installer ses dépendances de manière sécurisée
WORKDIR /comfyui/custom_nodes/RES4LYF
RUN if [ -f requirements.txt ]; then pip install --no-deps -r requirements.txt; fi

# Revenir à la racine
WORKDIR /

# S'assurer que le fichier de configuration existe
RUN echo "comfyui:" > /comfyui/extra_model_paths.yaml && \
    echo "  base_path: /runpod-volume/ComfyUI/" >> /comfyui/extra_model_paths.yaml && \
    echo "  is_default: true" >> /comfyui/extra_model_paths.yaml && \
    echo "  checkpoints: models/checkpoints/" >> /comfyui/extra_model_paths.yaml && \
    echo "  vae: models/vae/" >> /comfyui/extra_model_paths.yaml && \
    echo "  loras: models/loras/" >> /comfyui/extra_model_paths.yaml
