FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser l'environnement virtuel existant
ENV PATH="/opt/venv/bin:${PATH}"

# Installer git
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Mettre à jour ComfyUI vers la dernière version
WORKDIR /comfyui
RUN git pull

# Cloner RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installer les dépendances de RES4LYF
WORKDIR /comfyui/custom_nodes/RES4LYF
RUN pip install -r requirements.txt

# Revenir à la racine
WORKDIR /
