cd D:\APPSNospaces\dokcer-containers\comfyui-wan

# Delete the corrupted file
Remove-Item Dockerfile

# Create fresh with correct content
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$dockerfile = @'
FROM nvidia/cuda:12.5.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV NVIDIA_VISIBLE_DEVICES=all

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends python3.10 python3-pip python3.10-venv git curl wget ca-certificates libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev build-essential && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3.10 -m pip install --no-cache-dir --upgrade pip setuptools wheel

WORKDIR /app/comfyui

RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && git config --global http.postBuffer 524288000

RUN pip install --no-cache-dir -r requirements.txt

RUN pip install --no-cache-dir diffusers transformers safetensors pillow numpy opencv-python peft accelerate

WORKDIR /app/comfyui/models/checkpoints

RUN wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP/resolve/main/low_noise_model/diffusion_pytorch_model.safetensors?download=true" -O wan2.2-fun-a14b-inp-low-noise.safetensors

RUN wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP/resolve/main/high_noise_model/diffusion_pytorch_model.safetensors?download=true" -O wan2.2-fun-a14b-inp-high-noise.safetensors

WORKDIR /app/comfyui/models/loras

RUN wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors?download=true" -O wan2.2-fun-a14b-inp-low-noise-hps2.1.safetensors

RUN wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-high-noise-HPS2.1.safetensors?download=true" -O wan2.2-fun-a14b-inp-high-noise-hps2.1.safetensors

WORKDIR /app/comfyui

EXPOSE 8188 8888

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]
'@

[System.IO.File]::WriteAllText("$PWD/Dockerfile", $dockerfile, $utf8NoBom)