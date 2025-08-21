FROM timpietruskyblibla/runpod-worker-comfy:3.6.0-base

# Install système dependencies including curl
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create RES4LYF installation directory
WORKDIR /comfyui/custom_nodes

# Clone RES4LYF repository
RUN git clone https://github.com/willwong123/RES4LYF

# Install RES4LYF dependencies
WORKDIR /comfyui/custom_nodes/RES4LYF
RUN /opt/venv/bin/pip install -r requirements.txt

# Create configuration file for RES4LYF
RUN echo "COMFYUI_IGNORE_UPCAST_ATTENTION=true" > /comfyui/custom_nodes/RES4LYF/.env

# Return to working directory
WORKDIR /comfyui

# Ensure all permissions are correct
RUN chown -R root:root /comfyui/custom_nodes/RES4LYF
