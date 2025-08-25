#!/bin/bash

# Définir les chemins
COMFYUI_PATH="/home/comfyuser/ComfyUI"
MODEL_PATH="/runpod-volume/models"

# Configurer les paths des modèles si le volume est monté
if [ -d "$MODEL_PATH" ]; then
    echo "Volume detected. Configuring model paths..."
    export MODEL_PATH_ENV="$MODEL_PATH"
    # Copier la configuration si nécessaire
    if [ -f "extra_model_paths.yaml" ]; then
        cp extra_model_paths.yaml "$COMFYUI_PATH/extra_model_paths.yaml"
    fi
else
    echo "No volume detected. Using default model paths."
fi

# Vérifier que ComfyUI existe
if [ ! -d "$COMFYUI_PATH" ]; then
    echo "ERROR: ComfyUI directory not found at $COMFYUI_PATH"
    exit 1
fi

# Démarrer l'API ComfyUI en arrière-plan si nécessaire
if [ "$SERVE_API_LOCALLY" = "true" ]; then
    echo "Starting ComfyUI API locally..."
    cd "$COMFYUI_PATH"
    python3 main.py &
    COMFY_PID=$!
    sleep 10
fi

# Démarrer le handler RunPod
echo "Starting RunPod handler..."
cd /home/comfyuser
python3 handler.py

# Arrêter ComfyUI si nécessaire
if [ "$SERVE_API_LOCALLY" = "true" ]; then
    kill $COMFY_PID
fi
