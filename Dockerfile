FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python de base pour ComfyUI et les custom nodes
RUN pip install --upgrade pip setuptools wheel

# Installer torch explicitement avec la bonne version CUDA
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Installer huggingface_hub et autres dépendances communes
RUN pip install huggingface-hub requests

# Cloner et installer RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git
WORKDIR /comfyui/custom_nodes/RES4LYF

# Installer les dépendances de RES4LYF
RUN pip install -r requirements.txt

# Revenir au répertoire de base
WORKDIR /comfyui

# Script pour installer les dépendances de tous les custom nodes au démarrage
RUN cat > /install_custom_node_deps.py << 'EOF'
import os
import subprocess
import sys

def install_custom_node_dependencies():
    custom_nodes_dir = "/comfyui/custom_nodes"
    
    for node_name in os.listdir(custom_nodes_dir):
        node_path = os.path.join(custom_nodes_dir, node_name)
        requirements_file = os.path.join(node_path, "requirements.txt")
        
        if os.path.isdir(node_path) and os.path.exists(requirements_file):
            print(f"Installing dependencies for {node_name}...")
            try:
                # Exclure les packages qui pourraient entrer en conflit avec ComfyUI
                with open(requirements_file, 'r') as f:
                    requirements = f.read().splitlines()
                
                filtered_requirements = []
                for req in requirements:
                    req = req.strip()
                    if req and not req.startswith('#'):
                        # Exclure les packages qui pourraient causer des conflits
                        if not any(pkg in req.lower() for pkg in ['torch', 'torchvision', 'torchaudio', 'transformers', 'safetensors']):
                            filtered_requirements.append(req)
                
                if filtered_requirements:
                    subprocess.check_call([sys.executable, "-m", "pip", "install"] + filtered_requirements)
                    print(f"Successfully installed dependencies for {node_name}")
                else:
                    print(f"No additional dependencies needed for {node_name}")
            except subprocess.CalledProcessError as e:
                print(f"Failed to install dependencies for {node_name}: {e}")

if __name__ == "__main__":
    install_custom_node_dependencies()
EOF

# Créer le fichier de configuration
RUN cat > /comfyui/extra_model_paths.yaml << EOF
comfyui:
  base_path: /runpod-volume/ComfyUI/
  is_default: true
  text_encoders: models/text_encoders/
  vae: models/vae/
  diffusion_models: |
    models/diffusion_models
    models/unet
  checkpoints: models/checkpoints/
  clip: models/clip/
  loras: models/loras/
  embeddings: models/embeddings/
  upscale_models: models/upscale_models/
EOF
