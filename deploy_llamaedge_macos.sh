#!/bin/bash

# Default ports
proxy_port=10086
llama_port=12345
whisper_port=12306

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    printf "${GREEN}$1${NC}\n\n"
}

error() {
    printf "${RED}$1${NC}\n\n"
}

warning() {
    printf "${YELLOW}$1${NC}\n\n"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --proxy-port)
            proxy_port="$2"
            shift 2
            ;;
        --llama-port)
            llama_port="$2"
            shift 2
            ;;
        --whisper-port)
            whisper_port="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --proxy-port PORT    Set proxy server port (default: 10086)"
            echo "  --llama-port PORT    Set LlamaEdge server port (default: 12345)"
            echo "  --whisper-port PORT  Set LlamaEdge-Whisper server port (default: 12306)"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if ports are valid numbers
if ! [[ "$proxy_port" =~ ^[0-9]+$ ]] || ! [[ "$llama_port" =~ ^[0-9]+$ ]] || ! [[ "$whisper_port" =~ ^[0-9]+$ ]]; then
    error "Ports must be valid numbers"
    exit 1
fi

info "[+] Checking ports ..."
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
printf "\n\n"

info "[+] Create api-server directory in the current directory"
if [ -d "api-server" ]; then
    warning "    * api-server directory already exists. Remove it? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        rm -rf api-server
    else
        exit 1
    fi
fi
mkdir -p api-server

info "[+] Downloading LlamaEdge API Server and model..."
curl -LO# https://github.com/LlamaEdge/LlamaEdge/releases/download/0.14.15/llama-api-server.wasm
if [ ! -f Llama-3.2-3B-Instruct-Q5_K_M.gguf ]; then
    curl -LO https://huggingface.co/second-state/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q5_K_M.gguf
fi
printf "\n\n"

info "[+] Downloading LlamaEdge-Whisper API Server, Whisper model and plugin..."
curl -LO# https://github.com/LlamaEdge/whisper-api-server/releases/download/0.3.2/whisper-api-server.wasm
if [ ! -f ggml-large-v2-q5_0.bin ]; then
    curl -LO# https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q5_0.bin
fi
if [ -d "wasmedge-whisper/plugin" ]; then
    rm -rf wasmedge-whisper/plugin
fi
mkdir -p wasmedge-whisper/plugin
curl -LO# https://github.com/WasmEdge/WasmEdge/releases/download/0.14.1/WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz
tar -xzf WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz -C wasmedge-whisper/plugin
rm WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz
printf "\n\n"

info "[+] Downloading proxy server..."
curl -LO# https://github.com/LlamaEdge/llama-proxy-server/releases/download/0.1.0/llama-proxy-server.wasm
printf "\n\n"

info "[+] Starting servers in background..."
# Start LlamaEdge API Server
wasmedge --dir .:. --nn-preload default:GGML:AUTO:Llama-3.2-3B-Instruct-Q5_K_M.gguf \
  llama-api-server.wasm \
  --model-name llama \
  --prompt-template llama-3-chat \
  --ctx-size 32000 \
  --port $llama_port &

# Start Whisper API Server
WASMEDGE_PLUGIN_PATH=$(pwd)/wasmedge-whisper/plugin wasmedge --dir .:. whisper-api-server.wasm -m ggml-large-v2-q5_0.bin --task transcribe --port $whisper_port &

# Start Proxy Server
wasmedge llama-proxy-server.wasm --port $proxy_port &

# Wait for servers to start
sleep 5
info "    * Servers started."

info "[+] Registering servers with proxy..."
curl -X POST http://localhost:$proxy_port/admin/register/chat -d "http://localhost:$llama_port"
curl -X POST http://localhost:$proxy_port/admin/register/whisper -d "http://localhost:$whisper_port"
printf "\n\n"

info "[+] Done!"

info ">>> To stop the servers, run 'pkill -f wasmedge' command in Terminal."

exit 0
