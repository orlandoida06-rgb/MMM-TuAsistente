# -*- coding: utf-8 -*-

import os
import sys
import queue
import threading

os.environ["OMP_NUM_THREADS"] = "2"
os.environ["OPENBLAS_NUM_THREADS"] = "2"
os.environ["MKL_NUM_THREADS"] = "2"

import sounddevice as sd
import numpy as np
from faster_whisper import WhisperModel


# ============================================================
# CONFIGURACIÓN
# ============================================================

SAMPLE_RATE = 16000
CHANNELS = 4
BLOCKSIZE = 2048

# No usar un índice fijo: PipeWire puede cambiarlo después de reiniciar.
# El micrófono USB se identifica por su nombre.
DEVICE_INDEX = None

# Whisper trabajará con MONO
WHISPER_CHANNELS = 1


# ============================================================
# ESTADO
# ============================================================

is_recording = False
audio_buffer = []

buffer_lock = threading.Lock()


# ============================================================
# WHISPER
# ============================================================

print("[transcribe] Cargando Whisper...", flush=True)

try:
    model = WhisperModel(
        "small",
        device="cpu",
        compute_type="int8",
        cpu_threads=2,
        num_workers=1
    )
except Exception as e:
    print(
        f"[transcribe] ERROR cargando Whisper: {e}",
        flush=True
    )
    sys.exit(1)

print("[transcribe] Whisper ready.", flush=True)


# ============================================================
# COMPROBAR DISPOSITIVO
# ============================================================

try:
    devices = sd.query_devices()

    print("[audio] Dispositivos disponibles:", flush=True)

    for i, device in enumerate(devices):
        inputs = int(device.get("max_input_channels", 0))

        if inputs > 0:
            print(
                f"[audio] INPUT {i}: "
                f"{device['name']} "
                f"({inputs} canales)",
                flush=True
            )

    # PipeWire puede ocultar temporalmente el dispositivo USB
    # como dispositivo independiente. En ese caso usamos
    # el dispositivo "pipewire", que recibe el micrófono USB.
    usb_keywords = (
        "usb camera",
        "omnivision",
        "b3.04.06.1",
        "usb audio"
    )

    DEVICE_INDEX = None
    device = None

    # 1. Buscar directamente el micrófono USB.
    for i, candidate in enumerate(devices):

        name = candidate["name"].lower()
        inputs = int(candidate.get("max_input_channels", 0))

        if inputs > 0 and any(
            keyword in name for keyword in usb_keywords
        ):
            DEVICE_INDEX = i
            device = candidate

            print(
                f"[audio] Micrófono USB encontrado directamente: "
                f"{DEVICE_INDEX} - {device['name']}",
                flush=True
            )

            break

    # 2. Si PipeWire todavía no muestra el USB directamente,
    # utilizar su entrada virtual.
    if DEVICE_INDEX is None:

        for i, candidate in enumerate(devices):

            name = candidate["name"].lower()
            inputs = int(candidate.get("max_input_channels", 0))

            if inputs > 0 and name == "pipewire":
                DEVICE_INDEX = i
                device = candidate

                print(
                    f"[audio] USB no expuesto directamente; "
                    f"usando PipeWire: {DEVICE_INDEX} - {device['name']}",
                    flush=True
                )

                break

    if DEVICE_INDEX is None:

        print(
            "[audio] ERROR: no se encontró ninguna entrada de audio.",
            flush=True
        )

        sys.exit(1)

except Exception as e:

    print(
        f"[audio] ERROR seleccionando dispositivo: {e}",
        flush=True
    )

    sys.exit(1)


# ============================================================
# CALLBACK
# ============================================================

def callback(indata, frames, time_info, status):

    if status:

        print(
            f"[audio] {status}",
            file=sys.stderr,
            flush=True
        )

    if not is_recording:
        return

    try:

        with buffer_lock:

            audio_buffer.append(
                indata.copy()
            )

    except Exception as e:

        print(
            f"[audio] ERROR callback: {e}",
            file=sys.stderr,
            flush=True
        )


# ============================================================
# ABRIR MICRÓFONO
# ============================================================

try:

    stream = sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=CHANNELS,
        dtype="float32",
        blocksize=BLOCKSIZE,
        device=DEVICE_INDEX,
        callback=callback,
        latency="high"
    )

    stream.start()

except Exception as e:

    print(
        f"ERROR opening microphone: {e}",
        flush=True
    )

    sys.exit(1)


print(
    f"[transcribe] Microphone ready. "
    f"PipeWire device: {DEVICE_INDEX}",
    flush=True
)


# ============================================================
# TRANSCRIPCIÓN
# ============================================================

def transcribe_audio():

    global audio_buffer

    with buffer_lock:

        if not audio_buffer:

            print(
                "TRANSCRIPTION:",
                flush=True
            )

            return

        chunks = audio_buffer
        audio_buffer = []

    try:

        audio_data = np.concatenate(
            chunks,
            axis=0
        )

        # ----------------------------------------------------
        # 4 CANALES → MONO
        # ----------------------------------------------------

        if audio_data.ndim == 2:

            audio_data = np.mean(
                audio_data,
                axis=1
            )

        audio_data = audio_data.astype(
            np.float32
        )

    except Exception as e:

        print(
            f"ERROR preparando audio: {e}",
            flush=True
        )

        return

    # --------------------------------------------------------
    # Comprobar que realmente hay señal
    # --------------------------------------------------------

    rms = float(
        np.sqrt(
            np.mean(
                audio_data * audio_data
            )
        )
    )

    print(
        f"[audio] RMS: {rms:.6f}",
        flush=True
    )

    if rms < 0.001:

        print(
            "TRANSCRIPTION:",
            flush=True
        )

        return

    try:

        segments, info = model.transcribe(

            audio_data,

            language="es",

            beam_size=3,

            best_of=3,

            temperature=0,

            vad_filter=True,

            vad_parameters={
                "min_silence_duration_ms": 300,
                "speech_pad_ms": 200
            }

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


# ============================================================
# BUCLE PRINCIPAL
# ============================================================

try:

    for line in sys.stdin:

        command = line.strip()

        # ----------------------------------------------------
        # START
        # ----------------------------------------------------

        if command == "START":

            with buffer_lock:
                audio_buffer = []

            is_recording = True

            print(
                "RECORDING_STARTED",
                flush=True
            )

        # ----------------------------------------------------
        # STOP
        # ----------------------------------------------------

        elif command == "STOP":

            is_recording = False

            print(
                "RECORDING_STOPPED",
                flush=True
            )

            transcribe_audio()

        # ----------------------------------------------------
        # EXIT
        # ----------------------------------------------------

        elif command == "EXIT":

            is_recording = False

            break

except KeyboardInterrupt:

    pass

finally:

    try:
        stream.stop()
        stream.close()
    except Exception:
        pass

    print(
        "[transcribe] Cerrado.",
        flush=True
    )
