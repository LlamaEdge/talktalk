import json
import os
import re
import tempfile
from pathlib import Path

import librosa
import openai
import requests
import soundfile as sf
from gtts import gTTS
from openai import OpenAI

import gradio as gr

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
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def process_audio(audio_file):
    print(f"Processing audio file: {audio_file}")

    # Check and resample if needed
    TARGET_SAMPLE_RATE = 16000

    # Load audio with librosa (automatically handles different formats)
    data, current_sample_rate = librosa.load(
        audio_file, sr=None
    )  # sr=None preserves original sample rate
    print(f"Original sample rate: {current_sample_rate} Hz")

    if current_sample_rate != TARGET_SAMPLE_RATE:
        print(f"Resampling from {current_sample_rate} Hz to {TARGET_SAMPLE_RATE} Hz")
        # High-quality resampling using librosa
        data = librosa.resample(
            y=data,
            orig_sr=current_sample_rate,
            target_sr=TARGET_SAMPLE_RATE,
            res_type="kaiser_best",  # Highest quality resampling
        )

        # Normalize audio to prevent clipping
        data = librosa.util.normalize(data)

        # Save as 32-bit float WAV for better quality
        temp_wav = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
        sf.write(
            temp_wav.name,
            data,
            TARGET_SAMPLE_RATE,
        )
        audio_file = temp_wav.name

    # Step 1: Transcribe audio to text using whisper-api-server transcriptions api
    url = "http://localhost:10086/v1/audio/transcriptions"

    # 构造请求的数据
    files = {"file": open(audio_file, "rb")}
    data = {"language": "zh"}

    # 发送 POST 请求
    response = requests.post(url, files=files, data=data).json()

    # 使用正则表达式提取时间戳后的内容
    user_message = re.sub(r"\[.*?\]\s*", "", response["text"])

    print(f"Transcribed text: {user_message}")

    if "temp_wav" in locals():
        os.unlink(temp_wav.name)

    # Step 2: Generate response using llama-api-server chat completions api
    url = "http://localhost:10086/v1/chat/completions"
    headers = {"Content-Type": "application/json"}

    # 构造请求的 JSON 数据
    data = {
        "context_window": 2,
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {
                "role": "user",
                "content": user_message,
            },
        ],
        "model": "Qwen2.5-3B-Instruct",
        "stream": False,
    }

    # 发送 POST 请求
    chat_completion_response = requests.post(url, headers=headers, json=data).json()
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
    tts = gTTS(
        text=assistant_message, lang="zh"
    )  # 'zh' for Chinese, use 'en' for English

    # Save the audio response to a temporary file
    output_file = "response_audio.wav"
    tts.save(output_file)

    return (
        output_file,
        user_message,
        assistant_message,
    )


# Define Gradio interface
iface = gr.Interface(
    fn=process_audio,
    inputs=gr.Audio(type="filepath", format="wav"),
    outputs=[
        gr.Audio(type="filepath", label="AI Response"),
        gr.Textbox(label="Me"),
        gr.Textbox(label="TalkTalk AI"),
    ],
    title="AI Conversation Demo",
    description="Upload an audio file to get an AI response in both audio and text format.",
)

# Launch Gradio app
if __name__ == "__main__":
    iface.launch()
