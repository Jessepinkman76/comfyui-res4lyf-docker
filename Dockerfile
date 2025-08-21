FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Installe les dépendances système
RUN apt-get update && apt-get install -y git curl

# Installe RES4LYF
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    cd RES4LYF && \
    pip install -r requirements.txt

# Corrige les conflits de dépendances
RUN pip install 'click<=8.1.8' 'urllib3>=1.21,<2.0' --force-reinstall

# Crée le fichier de configuration
RUN echo 'comfyui:' > /comfyui/extra_model_paths.yaml && \
    echo '  base_path: /runpod-volume/ComfyUI/' >> /comfyui/extra_model_paths.yaml && \
    echo '  is_default: true' >> /comfyui/extra_model_paths.yaml && \
    echo '  text_encoders: models/text_encoders/' >> /comfyui/extra_model_paths.yaml && \
    echo '  vae: models/vae/' >> /comfyui/extra_model_paths.yaml && \
    echo '  diffusion_models: |' >> /comfyui/extra_model_paths.yaml && \
    echo '    models/diffusion_models' >> /comfyui/extra_model_paths.yaml && \
    echo '    models/unet' >> /comfyui/extra_model_paths.yaml && \
    echo '  checkpoints: models/checkpoints/' >> /comfyui/extra_model_paths.yaml && \
    echo '  clip: models/clip/' >> /comfyui/extra_model_paths.yaml && \
    echo '  loras: models/loras/' >> /comfyui/extra_model_paths.yaml && \
    echo '  embeddings: models/embeddings/' >> /comfyui/extra_model_paths.yaml && \
    echo '  upscale_models: models/upscale_models/' >> /comfyui/extra_model_paths.yaml
