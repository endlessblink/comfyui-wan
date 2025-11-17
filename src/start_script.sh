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

echo "🚀 Starting Wan 2.2 ComfyUI Container with Hearmeman24 Integration..."

# Step 1: Clone and integrate Hearmeman24 repo
echo "📦 Cloning Hearmeman24 ComfyUI Wan repo..."
if [ ! -d "/app/comfyui/hearmeman-repo" ]; then
  cd /tmp
  if git clone https://github.com/Hearmeman24/comfyui-wan.git hearmeman-repo; then
    echo "✅ Successfully cloned Hearmeman24 repo"

    # Copy ALL assets from Hearmeman24
    echo "📂 Copying Hearmeman24 assets..."
    if [ -d "hearmeman-repo/src" ]; then
      cp -r hearmeman-repo/src/* /app/comfyui/src/ 2>/dev/null || echo "⚠️ Some src files could not be copied"
    fi
    if [ -d "hearmeman-repo/workflows" ]; then
      cp -r hearmeman-repo/workflows/* /app/comfyui/workflows/ 2>/dev/null || echo "⚠️ Some workflow files could not be copied"
    fi

    # Move repo to accessible location
    cp -r hearmeman-repo /app/comfyui/hearmeman-repo
    echo "✅ Hearmeman24 integration complete"
  else
    echo "❌ Failed to clone Hearmeman24 repo, continuing without it..."
  fi
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
python main.py --listen 0.0.0.0 --port 8188 --output-directory /workspace > /tmp/comfyui.log 2>&1 &
COMFYUI_PID=$!

# Wait a moment for ComfyUI to start
sleep 5

echo "📓 Starting Jupyter Lab on port 8888..."
# Use --NotebookApp.token='' for no token, or generate a secure token
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --notebook-dir=/workspace > /tmp/jupyter.log 2>&1 &
JUPYTER_PID=$!

# Wait a moment for Jupyter to start
sleep 3

echo "✅ Container startup complete!"
echo "   ComfyUI: http://localhost:8188"
echo "   Jupyter: http://localhost:8888"
echo "   Hearmeman24 Workflows: /app/comfyui/workflows/"
echo "   Custom Nodes: /app/comfyui/src/"
echo "   Logs: /tmp/comfyui.log and /tmp/jupyter.log"

# Function to check if services are running
check_services() {
    if ! kill -0 $COMFYUI_PID 2>/dev/null; then
        echo "❌ ComfyUI process died! Check /tmp/comfyui.log"
        return 1
    fi
    if ! kill -0 $JUPYTER_PID 2>/dev/null; then
        echo "❌ Jupyter Lab process died! Check /tmp/jupyter.log"
        return 1
    fi
    return 0
}

# Keep container alive and monitor services
while true; do
    if ! check_services; then
        echo "🔴 One or more services failed, shutting down..."
        cleanup
    fi
    sleep 30
done