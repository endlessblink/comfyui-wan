#!/bin/bash
set -e

echo "🚀 Starting Wan 2.2 ComfyUI Container..."

# Step 1: Clone Hearmeman24 repo for custom nodes
echo "📦 Cloning Hearmeman24 ComfyUI repo..."
if [ ! -d "/app/comfyui/hearmeman-repo" ]; then
  cd /tmp
  git clone https://github.com/Hearmeman24/comfyui-wan.git hearmeman-repo
  cp -r hearmeman-repo/src/* /app/comfyui/src/ 2>/dev/null || true
else
  echo "✅ Hearmeman repo already cloned"
fi

# Step 2: Download 2 LoRAs if not present
echo "⬇️ Checking LoRA models..."
LORA_DIR="/app/comfyui/models/loras"

if [ ! -f "$LORA_DIR/wan2.2-fun-a14b-inp-low-noise-hps2.1.safetensors" ]; then
  echo "Downloading low-noise LoRA..."
  wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors?download=true" -O "$LORA_DIR/wan2.2-fun-a14b-inp-low-noise-hps2.1.safetensors"
fi

if [ ! -f "$LORA_DIR/wan2.2-fun-a14b-inp-high-noise-hps2.1.safetensors" ]; then
  echo "Downloading high-noise LoRA..."
  wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-high-noise-HPS2.1.safetensors?download=true" -O "$LORA_DIR/wan2.2-fun-a14b-inp-high-noise-hps2.1.safetensors"
fi

echo "✅ Models ready"

# Step 3: Start ComfyUI and Jupyter in background
cd /app/comfyui

echo "🎨 Starting ComfyUI on port 8188..."
python main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &
COMFYUI_PID=$!

echo "📓 Starting Jupyter Lab on port 8888..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root > /tmp/jupyter.log 2>&1 &
JUPYTER_PID=$!

echo "✅ Container startup complete!"
echo "   ComfyUI: http://localhost:8188"
echo "   Jupyter: http://localhost:8888"

# Keep container alive
wait $COMFYUI_PID $JUPYTER_PID
