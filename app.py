import json
import os
import re
import tempfile
from pathlib import Path

import gradio as gr
import librosa
import openai
import requests
import soundfile as sf
from gtts import gTTS
from openai import OpenAI

# The workflow is now:
# 1. User uploads an audio file
# 2. The audio is transcribed to text using Whisper
# 3. The transcribed text is sent to ChatGPT
# 4. ChatGPT's response is converted to speech
# 5. The UI shows:
# - The AI's audio response
# - The original transcribed text
# - The AI's text response
# Note: This uses gTTS (Google Text-to-Speech) for the text-to-speech conversion. For # better quality, you might want to consider using OpenAI's TTS API or other commercial # TTS services.


# Initialize OpenAI client
client = OpenAI(api_key="GAIA")


def process_audio(audio_file, api_url, input_language):
    print(f"Processing audio file: {audio_file}")
    print(f"Using API URL: {api_url}")
    print(f"Input language: {input_language}")

    # Step 1: Transcribe audio to text using whisper-api-server transcriptions api
    print(f"Transcribing audio to text")
    whisper_url = f"{api_url.rstrip('/')}/v1/audio/transcriptions"

    # 构造请求的数据
    files = {"file": open(audio_file, "rb")}
    data = {
        "language": input_language,
        "max_len": 100,
        "split_on_word": "true",
        "max_context": 200,
    }

    # 发送 POST 请求
    response = requests.post(whisper_url, files=files, data=data).json()

    # # 使用正则表达式提取时间戳后的内容
    # user_message = re.sub(r"\[.*?\]\s*", "", response["text"])

    # 去掉时间戳
    processed_text = re.sub(r"\[.*?\]\s*", "", response["text"])

    # 去掉非空白字符之间的换行符，但处理标点符号场景
    transcribed_text = re.sub(
        r"(?<=[^\s.,!?])\n(?=[^\s.,!?])",
        "",  # 换行前后都不是标点符号或空白时去掉换行
        processed_text,
    )

    # 可选：清理首尾多余的空格或换行符
    user_message = transcribed_text.strip()

    print(f"Transcribed text: {user_message}")

    # Step 2: Generate response using llama-api-server chat completions api
    print(f"Generating chat completions")
    chat_url = f"{api_url.rstrip('/')}/v1/chat/completions"
    headers = {"Content-Type": "application/json"}

    # 构造请求的 JSON 数据
    data = {
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful AI assistant. You should answer questions as precisely and concisely as possible. The answer should be suitable for speech playback, not for reading.",
            },
            {
                "role": "user",
                "content": user_message,
            },
        ],
        "model": "llama",
        "stream": False,
    }

    # 发送 POST 请求
    chat_completion_response = requests.post(
        chat_url, headers=headers, json=data
    ).json()
    assistant_message = chat_completion_response["choices"][0]["message"]["content"]

    # 打印响应内容
    print(f"AI Response: {assistant_message}")

    # Step 3: Convert response text to speech using OpenAI TTS
    # speech_response = client.audio.speech.create(
    #     model="tts-1", voice="alloy", input=chat_completion_response.text
    # )

    # Save the audio response
    # output_file = "response_audio.wav"
    # with open(output_file, "wb") as f:
    #     f.write(assistant_message)

    # Step 3: Convert response text to speech using gTTS
    print(f"Converting response text to speech using gTTS in {input_language} language")
    tts = gTTS(text=assistant_message, lang=input_language)

    # Save the audio response to a temporary file
    print(f"Saving audio response")
    output_file = "response_audio.wav"
    tts.save(output_file)

    return (
        output_file,
        user_message,
        assistant_message,
    )


# Define Gradio interface
with gr.Blocks() as iface:
    gr.Markdown("# AI Conversation Demo")
    gr.Markdown(
        "Upload an audio file or record using your microphone to get an AI response in both audio and text format."
    )

    with gr.Row():
        api_url = gr.Textbox(
            label="LlamaEdge API Server URL",
            placeholder="http://localhost:10086",
            value="http://localhost:10086",
            info="Enter the URL of your LlamaEdge API server",
        )
        input_language = gr.Dropdown(
            choices=["en", "zh", "ja"],
            value="en",
            label="Input Audio Language",
            info="Select the language of your input audio",
        )

    with gr.Row():
        with gr.Column():
            audio_input = gr.Audio(
                sources=["microphone", "upload"],
                type="filepath",
                label="Me",
            )
        with gr.Column():
            audio_output = gr.Audio(type="filepath", label="TalkTalk AI")

    with gr.Row():
        submit_btn = gr.Button("Submit")

    with gr.Row():
        user_text = gr.Textbox(label="Me")
        ai_text = gr.Textbox(label="TalkTalk AI")

    submit_btn.click(
        fn=process_audio,
        inputs=[audio_input, api_url, input_language],
        outputs=[audio_output, user_text, ai_text],
    )

# Launch Gradio app
if __name__ == "__main__":
    iface.launch(share=True)
