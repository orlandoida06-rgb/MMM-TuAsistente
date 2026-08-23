import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write
from faster_whisper import WhisperModel
import os
import sys

SAMPLE_RATE = 16000
AUDIO_FILE = "/tmp/audio.wav"
DEVICE_INDEX = 4

# Cargar el modelo Whisper una sola vez al inicio
model = WhisperModel("tiny", device="cpu", compute_type="int8", cpu_threads=4)

audio_buffer = []
is_recording = False

def callback(indata, frames, time_info, status):
    if is_recording:
        audio_buffer.append(indata.copy())

with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype='float32', blocksize=1024, device=DEVICE_INDEX, callback=callback):
    for line in sys.stdin:
        cmd = line.strip()
        
        if cmd == "START":
            audio_buffer.clear()
            is_recording = True
            print("RECORDING_STARTED", flush=True)

        elif cmd == "STOP":
            is_recording = False
            if len(audio_buffer) == 0:
                print("TRANSCRIPTION:", flush=True)
                continue

            audio_data = np.concatenate(audio_buffer, axis=0)
            audio_int16 = (audio_data * 32767).astype(np.int16)
            write(AUDIO_FILE, SAMPLE_RATE, audio_int16)

            try:
                segments, _ = model.transcribe(AUDIO_FILE, language="es", beam_size=1, vad_filter=False)
                text = " ".join([segment.text for segment in segments]).strip()
                print(f"TRANSCRIPTION:{text}", flush=True)
            except Exception as e:
                print(f"ERROR:{e}", flush=True)
            finally:
                if os.path.exists(AUDIO_FILE):
                    os.remove(AUDIO_FILE)
