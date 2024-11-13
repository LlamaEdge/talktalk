# :speaking_head: TalkTalk (唠嗑)

> [!NOTE]
> This project is for experimental purposes. If you like it, please give it a star :wink:

## Setup

```bash
git clone https://github.com/LlamaEdge/talktalk.git
cd talktalk
```

- Deploy LlamaEdge API Servers on MacOS (Apple Silicon)

  ```bash
  ./deploy_llamaedge_macos.sh

  # or, specify the ports
  ./deploy_llamaedge_macos.sh --proxy-port 10086 --llama-port 12345 --whisper-port 12306
  ```

  The default ports for `llama-proxy-server`, `llama-api-server` and `whisper-api-server` are `10086`, `12345` and `12306`, respectively. You can change them by using the `--proxy-port`, `--llama-port` and `--whisper-port` options.

  <details>
  <summary>For those who want to deploy servers step by step:</summary>

  - Install WasmEdge Runtime

    ```bash
    # Install WasmEdge Runtime
    curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s -- -v 0.14.1
    ```

  - LlamaEdge API Server

    ```bash
    # Download LlamaEdge API Server
    curl -LO https://github.com/LlamaEdge/LlamaEdge/releases/download/0.14.15/llama-api-server.wasm

    # Download chat model
    curl -LO https://huggingface.co/second-state/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q5_K_M.gguf

    # Start LlamaEdge API Server
    wasmedge --dir .:. --nn-preload default:GGML:AUTO:Qwen2.5-3B-Instruct-Q5_K_M.gguf \
      llama-api-server.wasm \
      --model-name Qwen2.5-3B-Instruct \
      --prompt-template chatml \
      --ctx-size 32000 \
      --port 12345
    ```

  - LlamaEdge-Whisper API Server

    ```bash
    # Download whisper model
    curl -LO https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin

    # Download wasmedge-whisper plugin
    mkdir -p wasmedge-whisper/plugin
    curl -LO https://github.com/WasmEdge/WasmEdge/releases/download/0.14.1/WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz
    tar -xzf WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz -C wasmedge-whisper/plugin
    rm WasmEdge-plugin-wasi_nn-whisper-0.14.1-darwin_arm64.tar.gz

    # Start LlamaEdge-Whisper API Server
    WASMEDGE_PLUGIN_PATH=$(pwd)/wasmedge-whisper/plugin wasmedge --dir .:. whisper-api-server.wasm -m ggml-medium.bin --port 12306
    ```

  - Proxy Server

    ```bash
    curl -LO https://github.com/LlamaEdge/llama-proxy-server/releases/download/0.1.0/llama-proxy-server.wasm
    wasmedge llama-proxy-server.wasm --port 10086

    # register chat server
    curl -X POST http://localhost:10086/admin/register/chat -d "http://localhost:12345"

    # register whisper server
    curl -X POST http://localhost:10086/admin/register/whisper -d "http://localhost:12306"
    ```

  </details>

- Install dependencies and start TalkTalk App

  ```bash
  # Optional: create a new virtual environment with conda or other tools
  conda create -n talktalk python=3.11
  conda activate talktalk

  # Install dependencies
  pip install -r requirements.txt

  # Start TalkTalk App
  python app.py
  ```

  If the app is running, you can visit http://127.0.0.1:7860 to use the app.

## Talk with TalkTalk

  [![TalkTalk Demo](https://img.youtube.com/vi/NFpLShcT7NM/0.jpg)](https://youtu.be/NFpLShcT7NM)

## Future Plan

*TalkTalk* is using `gtts` for text-to-speech conversion. In the next step, it will be replaced by [LlamaEdge-TTS API Server](https://github.com/LlamaEdge/tts-api-server).
