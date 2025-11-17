#!/bin/bash
set -e

echo "🚀 Starting Wan 2.2 ComfyUI Container with Hearmeman24 Integration..."

# Step 1: Clone and integrate Hearmeman24 repo
echo "📦 Cloning Hearmeman24 ComfyUI Wan repo..."
if [ ! -d "/app/comfyui/hearmeman-repo" ]; then
  cd /tmp
  git clone https://github.com/Hearmeman24/comfyui-wan.git hearmeman-repo

  # Copy ALL assets from Hearmeman24
  echo "📂 Copying Hearmeman24 assets..."
  cp -r hearmeman-repo/src/* /app/comfyui/src/ 2>/dev/null || true
  cp -r hearmeman-repo/workflows/* /app/comfyui/workflows/ 2>/dev/null || true

  # Move repo to accessible location
  cp -r hearmeman-repo /app/comfyui/hearmeman-repo
else
  echo "✅ Hearmeman repo already present"
fi

# Step 2: Download models via Hearmeman24's download script if it exists
echo "⬇️ Running model downloads..."
if [ -f "/app/comfyui/hearmeman-repo/src/download.py" ]; then
  cd /app/comfyui
  python hearmeman-repo/src/download.py 2>/dev/null || true
fi

# Step 3: Ensure LoRA models are present
echo "⬇️ Verifying LoRA models..."
LORA_DIR="/app/comfyui/models/loras"
mkdir -p "$LORA_DIR"

if [ ! -f "$LORA_DIR/wan2.2-fun-a14b-inp-low-noise-hps2.1.safetensors" ]; then
  echo "Downloading low-noise LoRA..."
  wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors?download=true" -O "$LORA_DIR/wan2.2-fun-a14b-inp-low-noise-hps2.1.safetensors" 2>/dev/null || true
fi

if [ ! -f "$LORA_DIR/wan2.2-fun-a14b-inp-high-noise-hps2.1.safetensors" ]; then
  echo "Downloading high-noise LoRA..."
  wget --timeout=30 --tries=3 "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-high-noise-HPS2.1.safetensors?download=true" -O "$LORA_DIR/wan2.2-fun-a14b-inp-high-noise-hps2.1.safetensors" 2>/dev/null || true
fi

echo "✅ All assets ready"

# Step 4: Start ComfyUI and Jupyter in background
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
echo "   Hearmeman24 Workflows: /app/comfyui/workflows/"
echo "   Custom Nodes: /app/comfyui/src/"

# Keep container alive
wait $COMFYUI_PID $JUPYTER_PID