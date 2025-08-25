#!/bin/bash

# Définir les chemins
COMFYUI_PATH="/home/comfyuser/ComfyUI"

# Vérifier que ComfyUI existe
if [ ! -d "$COMFYUI_PATH" ]; then
    echo "ERROR: ComfyUI directory not found at $COMFYUI_PATH"
    exit 1
fi

# Démarrer le handler RunPod
echo "Starting RunPod handler..."
cd /home/comfyuser
python3 handler.py
