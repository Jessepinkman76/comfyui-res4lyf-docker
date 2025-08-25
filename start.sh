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

# Démarrer l'API ComfyUI en arrière-plan si nécessaire
if [ "$SERVE_API_LOCALLY" = "true" ]; then
    echo "Starting ComfyUI API locally..."
    python3 "$COMFYUI_PATH/main.py" &
    COMFY_PID=$!
    sleep 5
fi

# Démarrer le handler RunPod
echo "Starting RunPod handler..."
python3 handler.py

# Arrêter ComfyUI si nécessaire
if [ "$SERVE_API_LOCALLY" = "true" ]; then
    kill $COMFY_PID
fi
