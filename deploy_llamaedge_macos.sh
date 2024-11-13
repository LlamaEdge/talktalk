#!/bin/bash

# echo "Installing WasmEdge Runtime..."
# curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s -- -v 0.14.1

echo "Downloading LlamaEdge API Server and model..."
curl -LO# https://github.com/LlamaEdge/LlamaEdge/releases/download/0.14.15/llama-api-server.wasm
if [ ! -f Qwen2.5-3B-Instruct-Q5_K_M.gguf ]; then
    curl -LO https://huggingface.co/second-state/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q5_K_M.gguf
fi

echo "Downloading LlamaEdge-Whisper API Server, Whisper model and plugin..."
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

echo "Downloading proxy server..."
curl -LO https://github.com/LlamaEdge/llama-proxy-server/releases/download/0.1.0/llama-proxy-server.wasm

echo "Starting servers in background..."
# Start LlamaEdge API Server
wasmedge --dir .:. --nn-preload default:GGML:AUTO:Qwen2.5-3B-Instruct-Q5_K_M.gguf \
  llama-api-server.wasm \
  --model-name Qwen2.5-3B-Instruct \
  --prompt-template chatml \
  --ctx-size 32000 \
  --port 12345 &

# Start Whisper API Server
WASMEDGE_PLUGIN_PATH=$(pwd)/wasmedge-whisper/plugin wasmedge --dir .:. whisper-api-server.wasm -m ggml-medium.bin --port 12306 &

# Start Proxy Server
wasmedge llama-proxy-server.wasm --port 10086 &

# Wait for servers to start
sleep 5

echo "Registering servers with proxy..."
curl -X POST http://localhost:10086/admin/register/chat -d "http://localhost:12345"
curl -X POST http://localhost:10086/admin/register/whisper -d "http://localhost:12306"
