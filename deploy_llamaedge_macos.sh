#!/bin/bash

proxy_port=10086
llama_port=12345
whisper_port=12306


info() {
    printf "${GREEN}$1${NC}\n\n"
}

error() {
    printf "${RED}$1${NC}\n\n"
}


printf "[+] Checking ports ...\n"
if lsof -Pi :$proxy_port -sTCP:LISTEN -t >/dev/null; then
    error "    * Port $proxy_port is already in use. Please choose another port."
    exit 1
fi
if lsof -Pi :$llama_port -sTCP:LISTEN -t >/dev/null; then
    error "    * Port $llama_port is already in use. Please choose another port."
    exit 1
fi
if lsof -Pi :$whisper_port -sTCP:LISTEN -t >/dev/null; then
    error "    * Port $whisper_port is already in use. Please choose another port."
    exit 1
fi
info "    * All ports are available."

info "[+] Installing WasmEdge Runtime..."
curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s -- -v 0.14.1
printf "\n"

info "[+] Downloading LlamaEdge API Server and model..."
curl -LO# https://github.com/LlamaEdge/LlamaEdge/releases/download/0.14.15/llama-api-server.wasm
if [ ! -f Qwen2.5-3B-Instruct-Q5_K_M.gguf ]; then
    curl -LO https://huggingface.co/second-state/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q5_K_M.gguf
fi
printf "\n"

info "[+] Downloading LlamaEdge-Whisper API Server, Whisper model and plugin..."
curl -LO# https://github.com/LlamaEdge/whisper-api-server/releases/download/0.3.2/whisper-api-server.wasm
if [ ! -f ggml-medium.bin ]; then
    curl -LO# https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin
fi
if [ -d "wasmedge-whisper/plugin" ]; then
    rm -rf wasmedge-whisper/plugin
fi
mkdir -p wasmedge-whisper/plugin
curl -LO# https://github.com/WasmEdge/WasmEdge/releases/download/0.14.1/WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz
tar -xzf WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz -C wasmedge-whisper/plugin
rm WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz
printf "\n"

info "[+] Downloading proxy server..."
curl -LO# https://github.com/LlamaEdge/llama-proxy-server/releases/download/0.1.0/llama-proxy-server.wasm
printf "\n"

info "[+] Starting servers in background..."
# Start LlamaEdge API Server
wasmedge --dir .:. --nn-preload default:GGML:AUTO:Qwen2.5-3B-Instruct-Q5_K_M.gguf \
  llama-api-server.wasm \
  --model-name Qwen2.5-3B-Instruct \
  --prompt-template chatml \
  --ctx-size 32000 \
  --port $llama_port &

# Start Whisper API Server
WASMEDGE_PLUGIN_PATH=$(pwd)/wasmedge-whisper/plugin wasmedge --dir .:. whisper-api-server.wasm -m ggml-medium.bin --port $whisper_port &

# Start Proxy Server
wasmedge llama-proxy-server.wasm --port $proxy_port &

# Wait for servers to start
sleep 5
info "    * Servers started."

info "[+] Registering servers with proxy..."
curl -X POST http://localhost:$proxy_port/admin/register/chat -d "http://localhost:$llama_port"
curl -X POST http://localhost:$proxy_port/admin/register/whisper -d "http://localhost:$whisper_port"
printf "\n"

info "[+] Done!"
