# -*- coding: utf-8 -*-

import os
import sys

os.environ["OMP_NUM_THREADS"] = "2"
os.environ["OPENBLAS_NUM_THREADS"] = "2"
os.environ["MKL_NUM_THREADS"] = "2"

import sounddevice as sd
import numpy as np
from faster_whisper import WhisperModel


SAMPLE_RATE = 16000
CHANNELS = 1
BLOCKSIZE = 1024

# Índice del micrófono
DEVICE_INDEX = 4

# Estado de grabación
is_recording = False
audio_buffer = []


print("[transcribe] Loading Whisper...", flush=True)

try:
    model = WhisperModel(
        "base",
        device="cpu",
        compute_type="int8",
        cpu_threads=2,
        num_workers=1
    )

except Exception as e:
    print(
        f"ERROR loading Whisper: {e}",
        flush=True
    )
    sys.exit(1)


print("[transcribe] Whisper ready.", flush=True)


def callback(indata, frames, time_info, status):
    global is_recording

    if status:
        print(
            f"[audio] {status}",
            file=sys.stderr,
            flush=True
        )

    if is_recording:
        audio_buffer.append(indata.copy())


try:
    stream = sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=CHANNELS,
        dtype="float32",
        blocksize=BLOCKSIZE,
        device=DEVICE_INDEX,
        callback=callback
    )

    stream.start()

except Exception as e:
    print(
        f"ERROR opening microphone: {e}",
        flush=True
    )
    sys.exit(1)


print("[transcribe] Microphone ready.", flush=True)


def transcribe_audio():
    global audio_buffer

    if not audio_buffer:
        print(
            "TRANSCRIPTION:",
            flush=True
        )
        return

    audio_data = np.concatenate(
        audio_buffer,
        axis=0
    ).flatten()

    audio_buffer.clear()

    try:
        segments, info = model.transcribe(
            audio_data,
            language="es",
            beam_size=1,
            best_of=1,
            temperature=0,
            vad_filter=True
        )

        text = " ".join(
            segment.text
            for segment in segments
        ).strip()

        print(
            f"TRANSCRIPTION:{text}",
            flush=True
        )

    except Exception as e:
        print(
            f"ERROR transcription: {e}",
            flush=True
        )


try:
    for line in sys.stdin:

        command = line.strip()

        if command == "START":

            audio_buffer.clear()

            is_recording = True

            print(
                "RECORDING_STARTED",
                flush=True
            )

        elif command == "STOP":

            is_recording = False

            print(
                "RECORDING_STOPPED",
                flush=True
            )

            transcribe_audio()


except KeyboardInterrupt:
    pass

except Exception as e:
    print(
        f"ERROR main loop: {e}",
        flush=True
    )

finally:

    is_recording = False

    try:
        stream.stop()
        stream.close()

    except Exception:
        pass

    print(
        "[transcribe] Stopped.",
        flush=True
    )
