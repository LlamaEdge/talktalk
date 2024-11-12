import os
import tempfile
from pathlib import Path

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
    # Step 1: Transcribe audio to text using whisper-api-server transcriptions api
    url = "http://localhost:10086/v1/audio/transcriptions"

    # 构造请求的数据
    files = {"file": open(audio_file, "rb")}
    data = {"language": "zh"}

    # 发送 POST 请求
    response = requests.post(url, files=files, data=data)

    # 打印响应内容
    print(response.text)

    # # Step 2: Generate response using llama-api-server chat completions api
    # url = "http://localhost:10086/v1/chat/completions"
    # headers = {"Content-Type": "application/json"}

    # # 构造请求的 JSON 数据
    # data = {
    #     "context_window": 2,
    #     "messages": [
    #         {"role": "system", "content": "You are a helpful assistant."},
    #         {
    #             "role": "user",
    #             "content": "What is the location of Paris, France along the Seine river?",
    #         },
    #     ],
    #     "model": "Llama-3.2-3B-Instruct",
    #     "stream": False,
    # }

    # # 发送 POST 请求
    # chat_completion_response = requests.post(url, headers=headers, json=data)

    # # 打印响应内容
    # print(chat_completion_response.text)

    # # Step 3: Convert response text to speech using OpenAI TTS
    # speech_response = client.audio.speech.create(
    #     model="tts-1", voice="alloy", input=chat_completion_response.text
    # )

    # Save the audio response
    output_file = "response_audio.wav"
    # with open(output_file, "wb") as f:
    #     f.write(speech_response.content)

    # return output_file, chat_completion_response.text, response.text
    return output_file, "Not available chat completion", response.text


# Define Gradio interface
iface = gr.Interface(
    fn=process_audio,
    inputs=gr.Audio(type="filepath"),
    outputs=[
        gr.Audio(type="filepath", label="AI Response"),
        gr.Textbox(label="Transcribed Text"),
        gr.Textbox(label="AI Response Text"),
    ],
    title="AI Conversation Demo",
    description="Upload an audio file to get an AI response in both audio and text format.",
)

# Launch Gradio app
if __name__ == "__main__":
    iface.launch()
