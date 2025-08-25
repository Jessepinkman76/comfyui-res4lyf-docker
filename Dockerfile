FROM jalberty2018/run-comfyui-wan:latest

# Installer les dépendances pour le handler RunPod
RUN pip install runpod aiohttp

# Créer le répertoire pour le handler
RUN mkdir -p /app

# Copier le handler RunPod
COPY handler.py /app/handler.py

# Créer un script de démarrage personnalisé
COPY custom_start.sh /custom_start.sh
RUN chmod +x /custom_start.sh

# Point d'entrée modifié
CMD ["/custom_start.sh"]
