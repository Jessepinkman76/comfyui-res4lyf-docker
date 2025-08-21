FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer git
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Installer comfy-cli
RUN pip install comfy-cli

# Réinstaller ComfyUI avec la dernière version
RUN rm -rf /comfyui
RUN comfy --workspace /comfyui install --nvidia

# Cloner RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installer les dépendances de RES4LYF
WORKDIR /comfyui/custom_nodes/RES4LYF
RUN pip install -r requirements.txt

# Revenir à la racine
WORKDIR /

# Configuration pour le network volume
RUN echo "comfyui:" > /comfyui/extra_model_paths.yaml && \
    echo "  base_path: /runpod-volume/ComfyUI/" >> /comfyui/extra_model_paths.yaml && \
    echo "  is_default: true" >> /comfyui/extra_model_paths.yaml && \
    echo "  checkpoints: models/checkpoints/" >> /comfyui/extra_model_paths.yaml && \
    echo "  vae: models/vae/" >> /comfyui/extra_model_paths.yaml && \
    echo "  loras: models/loras/" >> /comfyui/extra_model_paths.yaml && \
    echo "  embeddings: models/embeddings/" >> /comfyui/extra_model_paths.yaml && \
    echo "  clip: models/clip/" >> /comfyui/extra_model_paths.yaml && \
    echo "  diffusion_models: models/diffusion_models/" >> /comfyui/extra_model_paths.yaml && \
    echo "  text_encoders: models/text_encoders/" >> /comfyui/extra_model_paths.yaml && \
    echo "  upscale_models: models/upscale_models/" >> /comfyui/extra_model_paths.yaml
