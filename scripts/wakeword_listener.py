#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
MMM-TuAsistente - OpenWakeWord Listener Service
Escucha de palabras de activación continua para MagicMirror.
"""

import sys
import json
import os

# Configurar salida UTF-8 sin buffer para comunicación en tiempo real con Node.js
sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

try:
    import numpy as np
    import pyaudio
    from openwakeword.model import Model
except ImportError as err:
    print(json.dumps({"status": "error", "message": f"Librería no encontrada: {err}"}), flush=True)
    sys.exit(1)


def send_json(data):
    """Envía objetos JSON hacia node_helper.js por stdout."""
    print(json.dumps(data), flush=True)


def main():
    # Leer argumentos enviados por node_helper.js
    model_name = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "null" else "hey_mycroft"
    try:
        threshold = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
    except ValueError:
        threshold = 0.5

    mic_index = None
    if len(sys.argv) > 3 and sys.argv[3] not in ["null", "undefined", "None"]:
        try:
            mic_index = int(sys.argv[3])
        except ValueError:
            mic_index = None

    # Inicializar OpenWakeWord con framework TFLite
    try:
        oww_model = Model(wakeword_models=[model_name], inference_framework="tflite")
    except Exception:
        # Fallback a ONNX si TFLite falla
        try:
            oww_model = Model(wakeword_models=[model_name], inference_framework="onnx")
        except Exception as e:
            send_json({"status": "error", "message": f"Error al cargar el modelo '{model_name}': {str(e)}"})
            sys.exit(1)

    # Configuración de captura de audio (Standard 16kHz Mono int16)
    FORMAT = pyaudio.paInt16
    CHANNELS = 1
    RATE = 16000
    CHUNK = 1280  # ~80ms de audio por ventana

    audio = pyaudio.PyAudio()

    try:
        stream = audio.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=RATE,
            input=True,
            input_device_index=mic_index,
            frames_per_buffer=CHUNK
        )
    except Exception as err:
        send_json({"status": "error", "message": f"Error al abrir el micrófono (Índice: {mic_index}): {str(err)}"})
        sys.exit(1)

    send_json({"status": "ready", "model": model_name, "threshold": threshold})

    # Bucle principal de escucha continua
    while True:
        try:
            # Leer fragmento de audio
            raw_data = stream.read(CHUNK, exception_on_overflow=False)
            if not raw_data:
                continue

            # Convertir buffer raw a array NumPy
            audio_data = np.frombuffer(raw_data, dtype=np.int16)

            # Realizar predicción con OpenWakeWord
            prediction = oww_model.predict(audio_data)

            # Evaluar sensibilidad/umbral
            for wakeword_key, score in prediction.items():
                if score >= threshold:
                    # Emitir evento de detección para Node.js
                    send_json({
                        "status": "detected",
                        "wakeword": wakeword_key,
                        "score": round(float(score), 3)
                    })
                    # Reiniciar el buffer para no repetir la activación inmediatamente
                    oww_model.reset()

        except KeyboardInterrupt:
            break
        except Exception as e:
            # Evitar caída del bucle por fluctuaciones menores de lectura
            continue

    # Limpieza de recursos al cerrar
    stream.stop_stream()
    stream.close()
    audio.terminate()


if __name__ == "__main__":
    main()
