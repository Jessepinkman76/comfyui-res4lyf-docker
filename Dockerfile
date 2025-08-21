FROM runpod/worker-comfyui:latest

# Install curl (the only missing dependency)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install RES4LYF custom node
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    cd RES4LYF && \
    pip install -r requirements.txt

# Copy your custom models if needed
# COPY ./models /comfyui/models

# Set up extra_model_paths.yaml for network volume
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

# Copy your handler.py if you have custom logic
COPY handler.py /handler.py

ENV HANDLER_FUNCTION=handler
