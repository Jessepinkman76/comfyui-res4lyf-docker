# Force l’arch x86_64 (important si build sur Mac M1/M2)
FROM --platform=linux/amd64 nvidia/cuda:12.1.1-cudnn-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# Dépendances système
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git python3 python3-venv python3-pip \
      wget curl ca-certificates \
      libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root
RUN useradd -m -u 1000 -s /bin/bash comfyuser
USER comfyuser
WORKDIR /home/comfyuser

# Créer un venv utilisateur
RUN python3 -m venv .venv
ENV PATH="/home/comfyuser/.venv/bin:${PATH}" \
    PIP_NO_INPUT=1 \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1

# Mettre pip à jour
RUN pip install --upgrade pip setuptools wheel

# Installer PyTorch cu121 (versions cohérentes)
RUN pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cu121 \
    "torch==2.4.0+cu121" "torchvision==0.19.0+cu121" "torchaudio==2.4.0+cu121"

# Dépendances Python (headless pour OpenCV)
RUN pip install --no-cache-dir \
    aiohttp pillow numpy scipy opencv-python-headless pyyaml requests \
    safetensors transformers accelerate diffusers websocket-client runpod

# Cloner tes sources (jalberty2018 / custom nodes)
RUN git clone https://github.com/jalberty2018/run-comfyui-wan.git ComfyUI

# (Option) Installer les requirements.txt des custom_nodes trouvés
RUN if [ -d "ComfyUI/custom_nodes" ]; then \
      echo "Recherche des requirements.txt dans les custom_nodes..." && \
      find ComfyUI/custom_nodes/ -name "requirements.txt" -type f | while read file; do \
        echo "Installation des dépendances depuis $file" && \
        pip install --no-cache-dir -r "$file" || echo "Échec pour $file, on continue..."; \
      done; \
    fi

# Évite le doublet opencv-python et opencv-python-headless
# (Si un requirements.txt installe opencv-python, au besoin le désinstaller:)
# RUN pip uninstall -y opencv-python || true

# Copier handler/start/config
COPY --chown=comfyuser:comfyuser handler.py /home/comfyuser/handler.py
COPY --chown=comfyuser:comfyuser start.sh /home/comfyuser/start.sh
# Place extra_model_paths.yaml à la racine ComfyUI (là où ComfyUI le lit)
COPY --chown=comfyuser:comfyuser extra_model_paths.yaml /home/comfyuser/ComfyUI/extra_model_paths.yaml

RUN chmod +x /home/comfyuser/start.sh

# Variables d’environnement
ENV PYTHONPATH=/home/comfyuser/ComfyUI \
    MODEL_PATH=/runpod-volume/models \
    COMFYUI_PATH=/home/comfyuser/ComfyUI \
    COMFY_PORT=8188 \
    SERVE_API_LOCALLY=false

EXPOSE 8188

CMD ["/home/comfyuser/start.sh"]
