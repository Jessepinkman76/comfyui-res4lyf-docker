FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Cloner RES4LYF
RUN cd /comfyui/custom_nodes && git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installer SEULEMENT les dépendances critiques de RES4LYF
RUN pip install numpy scipy

# Configuration minimale
RUN echo "comfyui:" > /comfyui/extra_model_paths.yaml && \
    echo "  base_path: /runpod-volume/ComfyUI/" >> /comfyui/extra_model_paths.yaml && \
    echo "  is_default: true" >> /comfyui/extra_model_paths.yaml
