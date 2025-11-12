# Download Wan 2.2 models from Hugging Face
RUN mkdir -p /ComfyUI/models/diffusion_models /ComfyUI/models/loras && \
    cd /ComfyUI/models/diffusion_models && \
    wget -O Wan2.2-Fun-A14B-InP-low-noise.safetensors "https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP/resolve/main/low_noise_model/diffusion_pytorch_model.safetensors?download=true" && \
    wget -O Wan2.2-Fun-A14B-InP-high-noise.safetensors "https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP/resolve/main/high_noise_model/diffusion_pytorch_model.safetensors?download=true" && \
    cd /ComfyUI/models/loras && \
    wget -O Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors?download=true" && \
    wget -O Wan2.2-Fun-A14B-InP-high-noise-HPS2.1.safetensors "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-high-noise-HPS2.1.safetensors?download=true"

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh
COPY 4xLSDIR.pth /4xLSDIR.pth

CMD ["/start_script.sh"]