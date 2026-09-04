#!/usr/bin/env python3
from pathlib import Path
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

    # ------------------------------------------------------------
    # Selección dinámica del micrófono
    # ------------------------------------------------------------
    # No depender de un índice numérico guardado en config.js.
    # Los índices de PyAudio pueden cambiar después de reiniciar.
    #
    # Preferencia:
    #   1. Micrófono USB detectado directamente por nombre.
    #   2. PipeWire como entrada virtual.
    #
    # En esta Raspberry Pi el USB no aparece directamente en PyAudio,
    # pero sí está disponible a través de PipeWire.

    mic_index = None
    mic_name = None

    # Solo usar un índice recibido explícitamente si realmente existe.
    if len(sys.argv) > 3 and sys.argv[3] not in ["null", "undefined", "None"]:
        try:
            mic_index = int(sys.argv[3])
        except ValueError:
            mic_index = None

    audio_probe = None

    try:
        audio_probe = pyaudio.PyAudio()

        usb_keywords = (
            "usb camera",
            "omnivision",
            "b3.04.06.1",
            "usb audio",
        )

        # --------------------------------------------------------
        # 1. Buscar directamente el micrófono USB
        # --------------------------------------------------------
        for i in range(audio_probe.get_device_count()):
            try:
                device_info = audio_probe.get_device_info_by_index(i)
                name = str(device_info.get("name", ""))
                name_lower = name.lower()
                inputs = int(device_info.get("maxInputChannels", 0))

                if inputs > 0 and any(
                    keyword in name_lower for keyword in usb_keywords
                ):
                    mic_index = i
                    mic_name = name
                    print(
                        f"[audio] Micrófono USB encontrado directamente "
                        f"en PyAudio: [{i}] {name}",
                        flush=True
                    )
                    break

            except Exception:
                continue

        # --------------------------------------------------------
        # 2. Si el USB no aparece directamente, usar PipeWire
        # --------------------------------------------------------
        if mic_index is None:
            for i in range(audio_probe.get_device_count()):
                try:
                    device_info = audio_probe.get_device_info_by_index(i)
                    name = str(device_info.get("name", ""))
                    inputs = int(device_info.get("maxInputChannels", 0))

                    if inputs > 0 and name.strip().lower() == "pipewire":
                        mic_index = i
                        mic_name = name
                        print(
                            f"[audio] USB no expuesto directamente por PyAudio; "
                            f"usando PipeWire: [{i}] {name}",
                            flush=True
                        )
                        break

                except Exception:
                    continue

    except Exception as err:
        print(
            f"[audio] No se pudo consultar PyAudio dinámicamente: {err}",
            flush=True
        )

    finally:
        if audio_probe is not None:
            try:
                audio_probe.terminate()
            except Exception:
                pass

    # ------------------------------------------------------------
    # 3. Si no encontramos ningún dispositivo, dejar None
    # ------------------------------------------------------------
    if mic_index is None:
        print(
            "[audio] No se encontró un dispositivo de entrada específico; "
            "PyAudio utilizará su entrada predeterminada.",
            flush=True
        )
    else:
        print(
            f"[audio] Dispositivo final seleccionado: "
            f"[{mic_index}] {mic_name}",
            flush=True
        )

    # ------------------------------------------------------------
    # Resolver el modelo OpenWakeWord
    # ------------------------------------------------------------
    # El usuario/config.js utiliza el nombre lógico, por ejemplo:
    #
    #     hey_mycroft
    #
    # OpenWakeWord 0.4.0 necesita la ruta real del modelo ONNX:
    #
    #     hey_mycroft_v0.1.onnx
    #
    # Buscamos el modelo dentro del propio paquete instalado para
    # no depender de una ruta absoluta ni de una versión de Python.
    try:
        import openwakeword

        models_dir = (
            Path(openwakeword.__file__).resolve().parent
            / "resources"
            / "models"
        )

        # Buscar primero una coincidencia exacta del nombre lógico.
        model_candidates = sorted(
            models_dir.glob(f"{model_name}_v*.onnx")
        )

        # Si no existe con ese patrón, permitir que se haya
        # configurado directamente un archivo .onnx.
        if not model_candidates:
            direct_model = Path(model_name).expanduser()

            if direct_model.is_file():
                model_candidates = [direct_model]

        if not model_candidates:
            raise FileNotFoundError(
                f"No se encontró el modelo '{model_name}' en "
                f"{models_dir}"
            )

        model_path = model_candidates[0]

        print(
            f"[wakeword] Modelo seleccionado: {model_path}",
            flush=True
        )

        oww_model = Model(
            wakeword_model_paths=[str(model_path)]
        )

    except Exception as e:
        send_json({
            "status": "error",
            "message": (
                f"Error al cargar el modelo '{model_name}': "
                f"{str(e)}"
            )
        })
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
