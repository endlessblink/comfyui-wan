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

echo "🚀 Starting Lightweight Wan 2.2 ComfyUI Container..."

# Step 1: Clone and integrate Hearmeman24 repo
echo "📦 Cloning Hearmeman24 ComfyUI Wan repo..."
if [ ! -d "/app/comfyui/hearmenan-repo" ]; then
  cd /tmp
  if git clone https://github.com/Hearmeman24/comfyui-wan.git hearmenan-repo; then
    echo "✅ Successfully cloned Hearmeman24 repo"

    # Copy ALL assets from Hearmeman24
    echo "📂 Copying Hearmeman24 assets..."
    if [ -d "hearmenan-repo/src" ]; then
      cp -r hearmenan-repo/src/* /app/comfyui/src/ 2>/dev/null || echo "⚠️ Some src files could not be copied"
    fi
    if [ -d "hearmenan-repo/workflows" ]; then
      cp -r hearmenan-repo/workflows/* /app/comfyui/workflows/ 2>/dev/null || echo "⚠️ Some workflow files could not be copied"
    fi

    # Move repo to accessible location
    cp -r hearmenan-repo /app/comfyui/hearmenan-repo
    echo "✅ Hearmeman24 integration complete"
  else
    echo "❌ Failed to clone Hearmeman24 repo, continuing without it..."
  fi
else
  echo "✅ Hearmeman repo already present"
fi

# Step 2: Install custom ComfyUI nodes
echo "🔧 Installing custom ComfyUI nodes..."
cd /app/comfyui/custom_nodes

# List of custom nodes to install
CUSTOM_NODES=(
  "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
  "https://github.com/kijai/ComfyUI-KJNodes.git"
  "https://github.com/wildminder/ComfyUI-VibeVoice.git"
  "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git"
  "https://github.com/obisin/ComfyUI-FSampler.git"
  "https://github.com/cmeka/ComfyUI-WanMoEScheduler.git"
  "https://github.com/Hearmeman24/CivitAI_Downloader.git"
)

for node_url in "${CUSTOM_NODES[@]}"; do
  node_name=$(basename "$node_url" .git)
  if [ ! -d "$node_name" ]; then
    echo "Installing $node_name..."
    git clone "$node_url" || echo "⚠️ Failed to install $node_name"
  fi
done

# Step 3: Run Hearmeman24's download script
echo "⬇️ Running Hearmeman24 model downloads..."
cd /app/comfyui

if [ -f "/app/comfyui/hearmenan-repo/src/start.sh" ]; then
  echo "✅ Using Hearmeman24 download script..."
  # Extract and run just the download parts
  bash /app/comfyui/hearmenan-repo/src/start.sh --download-only || \
  echo "⚠️ Some downloads may have failed, continuing anyway..."
else
  echo "⚠️ Hearmeman24 download script not found, using fallback downloads..."

  # Fallback: Download essential models
  LORA_DIR="/app/comfyui/models/loras"
  CHECKPOINT_DIR="/app/comfyui/models/checkpoints"

  mkdir -p "$LORA_DIR" "$CHECKPOINT_DIR"

  # Download CausVid LoRA (essential)
  echo "⬇️ Downloading CausVid LoRA..."
  wget --timeout=30 --tries=3 \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" \
    -O "$LORA_DIR/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" || \
    echo "⚠️ CausVid LoRA download failed"
fi

echo "✅ Model downloads complete"

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

echo "✅ Lightweight container startup complete!"
echo "   ComfyUI: http://localhost:8188"
echo "   Jupyter: http://localhost:8888"
echo "   Hearmeman24 Workflows: /app/comfyui/workflows/"
echo "   Custom Nodes: /app/comfyui/custom_nodes/"
echo "   Logs: /tmp/comfyui.log and /tmp/jupyter.log"
echo "   Workspace: /workspace"

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