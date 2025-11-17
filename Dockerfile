FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV NVIDIA_VISIBLE_DEVICES=all

WORKDIR /app

# Install basic system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    python3.10-venv \
    git \
    curl \
    wget \
    ca-certificates \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    build-essential \
    ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python3.10 -m pip install --no-cache-dir --upgrade pip setuptools wheel

WORKDIR /app/comfyui

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    git config --global http.postBuffer 524288000

# Install ComfyUI requirements
RUN pip install --no-cache-dir -r requirements.txt

# Install additional essential packages
RUN pip install --no-cache-dir jupyter jupyterlab

# Create workspace and model directories
RUN mkdir -p /workspace /app/comfyui/models/{diffusion_models,loras,clip_vision,upscale_models,vae}

# Add environment variables for network access
ENV HF_ENDPOINT=https://hf-mirror.com
ENV TRANSFORMERS_CACHE=/tmp/huggingface_cache

# Expose ports
EXPOSE 8188 8888

# Add health check for RunPod monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
  CMD curl -f http://localhost:8188/ || exit 1

# Copy our simple startup script
COPY src/start_v4_simple.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]