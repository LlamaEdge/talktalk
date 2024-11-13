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
