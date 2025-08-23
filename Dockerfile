FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Utiliser le même environnement virtuel que l'image de base
ENV PATH="/opt/venv/bin:${PATH}"

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y \
    curl \
    git \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    libgl1 \
    libssl-dev \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Mettre à jour pip et numpy
RUN pip install --no-cache-dir --upgrade pip numpy

# Installer les dépendances nécessaires
RUN pip install --no-cache-dir \
    PyWavelets \
    scipy \
    pyyaml \
    pyOpenSSL \
    simpleeval \
    matplotlib \
    opencv-python-headless \
    rembg \
    requirements-parser \
    torchvision \
    pillow \
    requests \
    transformers \
    accelerate \
    safetensors \
    einops \
    kornia \
    timm \
    huggingface_hub

# Cloner RES4LYF
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Installation CORRECTE de RES4LYF selon sa documentation
RUN echo "Installation de RES4LYF avec la méthode officielle..." && \
    # Créer la structure de répertoires requise
    mkdir -p /comfyui/comfy/ldm/hidream && \
    # Copier les fichiers nécessaires aux emplacements attendus
    cp /comfyui/custom_nodes/RES4LYF/helper.py /comfyui/comfy/ldm/hidream/ && \
    cp /comfyui/custom_nodes/RES4LYF/model.py /comfyui/comfy/ldm/hidream/ && \
    # Créer le fichier __init__.py pour le package hidream
    echo "# RES4LYF package" > /comfyui/comfy/ldm/hidream/__init__.py && \
    # Corriger les imports dans les fichiers RES4LYF avec la bonne approche
    # Utiliser des séd plus précis pour éviter les erreurs
    if [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ]; then \
        sed -i 's/from comfy\.ldm\.hidream\.model import/from comfy.ldm.hidream.model import/g' /comfyui/custom_nodes/RES4LYF/models.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/sigmas.py" ]; then \
        sed -i 's/from helper import/from comfy.ldm.hidream.helper import/g' /comfyui/custom_nodes/RES4LYF/sigmas.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/beta/rk_guide_func_beta.py" ]; then \
        sed -i 's/from \.\.models import/from ..models import/g' /comfyui/custom_nodes/RES4LYF/beta/rk_guide_func_beta.py; \
    fi && \
    if [ -f "/comfyui/custom_nodes/RES4LYF/conditioning.py" ]; then \
        sed -i 's/from \.beta\.constants import/from .beta.constants import/g' /comfyui/custom_nodes/RES4LYF/conditioning.py; \
    fi && \
    # S'assurer que tous les fichiers nécessaires sont présents
    echo "Structure finale:" && \
    find /comfyui/comfy/ldm/hidream/ -type f && \
    echo "Fichiers RES4LYF:" && \
    find /comfyui/custom_nodes/RES4LYF/ -name "*.py" | head -10

# Vérifier que les fichiers critiques sont présents
RUN echo "Vérification des fichiers critiques..." && \
    [ -f "/comfyui/comfy/ldm/hidream/helper.py" ] && echo "✓ helper.py présent" || echo "✗ helper.py manquant" && \
    [ -f "/comfyui/comfy/ldm/hidream/model.py" ] && echo "✓ model.py présent" || echo "✗ model.py manquant" && \
    [ -f "/comfyui/custom_nodes/RES4LYF/models.py" ] && echo "✓ models.py présent" || echo "✗ models.py manquant"

# Télécharger le handler RunPod
RUN mkdir -p /app && \
    curl -o /app/handler.py https://raw.githubusercontent.com/runpod-workers/worker-comfyui/main/handler.py && \
    chmod +x /app/handler.py

# Installer les dépendances du handler
RUN pip install --no-cache-dir runpod aiohttp

# Créer un script de démarrage avec tests complets
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Test d'import complet de RES4LYF avant le démarrage
echo "=== TEST COMPLET RES4LYF ==="
python -c "
import sys
import os

# Ajouter les chemins nécessaires
sys.path.insert(0, '/comfyui')
sys.path.insert(0, '/comfyui/custom_nodes')
sys.path.insert(0, '/comfyui/custom_nodes/RES4LYF')

print('Chemins Python:', sys.path)
print()

# Test 1: Vérification des fichiers
def check_file(path):
    if os.path.exists(path):
        print(f'✓ {path}')
        return True
    else:
        print(f'✗ {path} - MANQUANT')
        return False

print('Vérification des fichiers:')
files_to_check = [
    '/comfyui/comfy/ldm/hidream/helper.py',
    '/comfyui/comfy/ldm/hidream/model.py', 
    '/comfyui/comfy/ldm/hidream/__init__.py',
    '/comfyui/custom_nodes/RES4LYF/models.py',
    '/comfyui/custom_nodes/RES4LYF/sigmas.py'
]

all_files_ok = all([check_file(f) for f in files_to_check])
print()

# Test 2: Test d'import
try:
    from comfy.ldm.hidream import helper, model
    print('✓ Import comfy.ldm.hidream réussi')
except Exception as e:
    print(f'✗ Erreur import comfy.ldm.hidream: {e}')
    import traceback
    traceback.print_exc()

print()

# Test 3: Test des samplers
try:
    # Essayer d'importer les samplers RES4LYF
    import RES4LYF.models
    print('✓ Import RES4LYF.models réussi')
    
    # Vérifier si res_2s est disponible
    if hasattr(RES4LYF.models, 'res_2s'):
        print('✓ Sampler res_2s disponible')
    else:
        print('✗ Sampler res_2s non trouvé')
        
except Exception as e:
    print(f'✗ Erreur import RES4LYF: {e}')
    import traceback
    traceback.print_exc()
"

echo "=== DÉMARRAGE COMFYUI ==="

# Démarrer ComfyUI en arrière-plan
cd /comfyui
python main.py --listen --port 8188 &

# Attendre que ComfyUI soit prêt
for i in {1..30}; do
    if curl -s http://127.0.0.1:8188 >/dev/null; then
        echo "ComfyUI est démarré"
        
        # Vérifier que RES4LYF est chargé dans l'API
        echo "Vérification de l'API ComfyUI..."
        API_RESPONSE=$(curl -s http://127.0.0.1:8188/object_info)
        if echo "$API_RESPONSE" | grep -i "res_2s\|beta57\|RES4LYF" >/dev/null; then
            echo "✓ RES4LYF détecté dans l'API ComfyUI"
        else
            echo "⚠ RES4LYF non visible dans l'API"
            echo "Réponse API (extrait):"
            echo "$API_RESPONSE" | head -5
        fi
        break
    fi
    echo "Attente ComfyUI ($i/30)..."
    sleep 2
done

# Démarrer le handler RunPod
echo "Démarrage du handler RunPod..."
exec python -u /app/handler.py
EOF

RUN chmod +x /start.sh

# Point d'entrée
CMD ["/start.sh"]
