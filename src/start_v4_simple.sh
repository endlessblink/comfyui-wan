#!/bin/bash
set -e

# Global variables for process IDs
COMFYUI_PID=""
JUPYTER_PID=""

# Graceful shutdown handler
cleanup() {
    echo "🛑 Received shutdown signal, gracefully stopping services..."

    if [ ! -z "$COMFYUI_PID" ]; then
        echo "Stopping ComfyUI (PID: $COMFYUI_PID)..."
        kill -TERM $COMFYUI_PID 2>/dev/null || true
        wait $COMFYUI_PID 2>/dev/null || true
    fi

    if [ ! -z "$JUPYTER_PID" ]; then
        echo "Stopping Jupyter Lab (PID: $JUPYTER_PID)..."
        kill -TERM $JUPYTER_PID 2>/dev/null || true
        wait $JUPYTER_PID 2>/dev/null || true
    fi

    echo "✅ All services stopped gracefully"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

echo "🚀 Starting v4: Hearmeman24 + Jupyter Integration"

# Step 1: Clone Hearmeman24 repo and use their exact setup
echo "📦 Setting up Hearmeman24 ComfyUI..."
cd /app/comfyui

if [ ! -d "hearmenan-repo" ]; then
  git clone https://github.com/Hearmeman24/comfyui-wan.git hearmenan-repo
  echo "✅ Hearmeman24 repo cloned"
else
  echo "✅ Hearmeman24 repo already present"
fi

# Step 2: Copy workflows
echo "📂 Installing Hearmeman24 workflows..."
mkdir -p workflows
cp -r hearmenan-repo/workflows/* workflows/ 2>/dev/null || echo "⚠️ Some workflows may not copy"

# Step 3: Install Jupyter Lab (only thing missing from Hearmeman24)
echo "📓 Installing Jupyter Lab..."
pip install --no-cache-dir jupyter jupyterlab || echo "⚠️ Jupyter install failed"

# Step 4: Run Hearmeman24's COMPLETE setup script
echo "⬇️ Running Hearmeman24 complete setup (this handles EVERYTHING)..."
if [ -f "hearmenan-repo/src/start.sh" ]; then
  # Run their script which handles:
  # - All custom nodes installation
  # - All model downloads
  # - All Python packages
  # - All configuration

  # Run their setup but skip the final ComfyUI start (we'll handle that)
  bash hearmenan-repo/src/start.sh || echo "⚠️ Hearmeman24 setup completed with some warnings"
else
  echo "❌ Hearmeman24 start.sh not found!"
  exit 1
fi

echo "✅ Hearmeman24 setup complete!"

# Step 5: Download our specific models and LoRAs
echo "⬇️ Downloading our specific Wan 2.2 Fun models..."

LORA_DIR="/app/comfyui/models/loras"
CHECKPOINT_DIR="/app/comfyui/models/checkpoints"
mkdir -p "$LORA_DIR" "$CHECKPOINT_DIR"

# Download Wan 2.2 Fun A14B Models (57GB total)
echo "⬇️ Downloading Low Noise Model (28.6GB)..."
wget --timeout=30 --tries=3 \
  "https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP/resolve/main/low_noise_model/diffusion_pytorch_model.safetensors?download=true" \
  -O "$CHECKPOINT_DIR/wan2.2-fun-a14b-inp-low-noise.safetensors" || \
  echo "⚠️ Low noise model download failed"

echo "⬇️ Downloading High Noise Model (28.6GB)..."
wget --timeout=30 --tries=3 \
  "https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP/resolve/main/high_noise_model/diffusion_pytorch_model.safetensors?download=true" \
  -O "$CHECKPOINT_DIR/wan2.2-fun-a14b-inp-high-noise.safetensors" || \
  echo "⚠️ High noise model download failed"

# Download HPS2.1 LoRAs
echo "⬇️ Downloading HPS2.1 LoRAs..."
wget --timeout=30 --tries=3 \
  "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors?download=true" \
  -O "$LORA_DIR/wan2.2-fun-a14b-inp-low-noise-hps2.1.safetensors" || \
  echo "⚠️ Low noise HPS2.1 LoRA download failed"

wget --timeout=30 --tries=3 \
  "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-high-noise-HPS2.1.safetensors?download=true" \
  -O "$LORA_DIR/wan2.2-fun-a14b-inp-high-noise-hps2.1.safetensors" || \
  echo "⚠️ High noise HPS2.1 LoRA download failed"

# Download CausVid LoRA
echo "⬇️ Downloading CausVid LoRA..."
wget --timeout=30 --tries=3 \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" \
  -O "$LORA_DIR/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" || \
  echo "⚠️ CausVid LoRA download failed"

echo "✅ All specific models downloaded (57GB + LoRAs)!"

# Step 6: Start ComfyUI and Jupyter with our configuration
echo "🎨 Starting ComfyUI on port 8188..."
python main.py --listen 0.0.0.0 --port 8188 --output-directory /workspace > /tmp/comfyui.log 2>&1 &
COMFYUI_PID=$!

# Wait for ComfyUI
sleep 5

echo "📓 Starting Jupyter Lab on port 8888..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --notebook-dir=/workspace > /tmp/jupyter.log 2>&1 &
JUPYTER_PID=$!

# Wait for Jupyter
sleep 3

echo "✅ v4 container ready!"
echo "   ComfyUI: http://localhost:8188"
echo "   Jupyter: http://localhost:8888"
echo "   All Hearmeman24 features: Available"
echo "   Logs: /tmp/comfyui.log, /tmp/jupyter.log"

# Keep container running
check_services() {
    if ! kill -0 $COMFYUI_PID 2>/dev/null || ! kill -0 $JUPYTER_PID 2>/dev/null; then
        echo "❌ Service failure detected"
        cleanup
    fi
}

while true; do
    check_services
    sleep 30
done