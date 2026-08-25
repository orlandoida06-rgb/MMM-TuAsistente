#!/bin/bash

# ==============================================================================
# MMM-TuAsistente
# INSTALADOR COMPLETO
#
# Configura automáticamente:
#   - Idioma
#   - Voz Piper
#   - PTT / Wake Word
#   - Teclado y tecla PTT
#   - Entrada de audio
#   - Salida de audio
#   - Whisper
#   - OpenWakeWord
#   - Piper
#   - transcribe.py
#   - listen_key.py
#   - wakeword_listener.py
#   - node_helper.js
#   - config.js
# ==============================================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TITLE="MMM-TuAsistente - Instalación"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==============================================================================
# COMPROBAR MÓDULO
# ==============================================================================

if [ ! -f "$BASE_DIR/node_helper.js" ]; then

    echo -e "${RED}"
    echo "ERROR: No se encuentra node_helper.js"
    echo
    echo "Ejecuta:"
    echo
    echo "cd ~/MagicMirror/modules/MMM-TuAsistente"
    echo "./install.sh"
    echo -e "${NC}"

    exit 1
fi

cd "$BASE_DIR"

echo
echo -e "${GREEN}"
echo "===================================================="
echo "       MMM-TuAsistente - INSTALADOR"
echo "===================================================="
echo -e "${NC}"

echo "Directorio:"
echo "$BASE_DIR"
echo

# ==============================================================================
# GUI / TUI
# ==============================================================================

USE_GUI=false

if [ "${1:-}" = "--gui" ]; then

    USE_GUI=true

elif [ "${1:-}" = "--tui" ]; then

    USE_GUI=false

elif [ -n "${DISPLAY:-}" ]; then

    USE_GUI=true

fi

# ==============================================================================
# INSTALAR INTERFAZ
# ==============================================================================

if [ "$USE_GUI" = true ]; then

    if ! command -v zenity >/dev/null 2>&1; then

        echo -e "${YELLOW}Instalando Zenity...${NC}"

        sudo apt-get update -qq
        sudo apt-get install -y zenity >/dev/null 2>&1

    fi

else

    if ! command -v whiptail >/dev/null 2>&1; then

        echo -e "${YELLOW}Instalando Whiptail...${NC}"

        sudo apt-get update -qq
        sudo apt-get install -y whiptail >/dev/null 2>&1

    fi

fi

# ==============================================================================
# FUNCIONES
# ==============================================================================

cancel_install() {

    echo
    echo -e "${RED}Instalación cancelada.${NC}"
    echo

    exit 0
}


# ==============================================================================
# PREGUNTA INSTALAR
# ==============================================================================

confirm_install() {

    if [ "$USE_GUI" = true ]; then

        zenity --question \
            --title="$TITLE" \
            --text="¿Quieres instalar MMM-TuAsistente?" \
            --ok-label="Sí, instalar" \
            --cancel-label="No, cancelar" \
            --width=450 \
            2>/dev/null

        if [ $? -ne 0 ]; then
            cancel_install
        fi

    else

        if ! whiptail \
            --title="$TITLE" \
            --yesno \
            "¿Quieres instalar MMM-TuAsistente?" \
            10 65
        then

            cancel_install

        fi

    fi
}


# ==============================================================================
# IDIOMA
# ==============================================================================

select_language() {

    if [ "$USE_GUI" = true ]; then

        LANGUAGE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el idioma del asistente:" \
            --column="ID" \
            --column="Idioma" \
            --column="Código" \
            "1" "Español" "es" \
            "2" "English" "en" \
            "3" "Français" "fr" \
            "4" "Deutsch" "de" \
            "5" "Italiano" "it" \
            --hide-column=1 \
            --width=550 \
            --height=350 \
            2>/dev/null)

    else

        LANGUAGE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el idioma del asistente:" \
            16 70 5 \
            "es" "Español" \
            "en" "English" \
            "fr" "Français" \
            "de" "Deutsch" \
            "it" "Italiano" \
            3>&1 1>&2 2>&3)

    fi

    case "$LANGUAGE" in

        "Español") LANGUAGE="es" ;;
        "English") LANGUAGE="en" ;;
        "Français") LANGUAGE="fr" ;;
        "Deutsch") LANGUAGE="de" ;;
        "Italiano") LANGUAGE="it" ;;

        es|en|fr|de|it)
            ;;

        *)
            cancel_install
            ;;

    esac
}


# ==============================================================================
# VOZ PIPER
# ==============================================================================

select_voice() {

    case "$LANGUAGE" in

        es)

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Selecciona la voz Piper:" \
                    --column="ID" \
                    --column="Voz" \
                    --column="Descripción" \
                    "es_ES-davefx-medium" "DaveFX" "Voz española masculina" \
                    "es_ES-sharvard-medium" "Sharvard" "Voz española" \
                    --hide-column=1 \
                    --width=650 \
                    --height=300 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu \
                    "Selecciona la voz Piper:" \
                    15 75 2 \
                    "es_ES-davefx-medium" "DaveFX - Voz española masculina" \
                    "es_ES-sharvard-medium" "Sharvard - Voz española" \
                    3>&1 1>&2 2>&3)

            fi
            ;;

        en)

            VOICE="en_US-lessac-medium"
            ;;

        fr)

            VOICE="fr_FR-upmc-medium"
            ;;

        de)

            VOICE="de_DE-thorsten-medium"
            ;;

        it)

            VOICE="it_IT-riccardo-x_low"
            ;;

    esac

    if [ -z "${VOICE:-}" ]; then
        cancel_install
    fi
}


# ==============================================================================
# MODO ACTIVACIÓN
# ==============================================================================

select_activation_mode() {

    if [ "$USE_GUI" = true ]; then

        MODE_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el método de activación:" \
            --column="ID" \
            --column="Método" \
            --column="Descripción" \
            "ptt" "PTT" "Mantener pulsada una tecla" \
            "wakeword" "Wake Word" "Activación mediante Hey Mycroft" \
            --hide-column=1 \
            --width=700 \
            --height=300 \
            2>/dev/null)

    else

        MODE_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el método de activación:" \
            15 75 2 \
            "ptt" "PTT - Tecla" \
            "wakeword" "Wake Word - Hey Mycroft" \
            3>&1 1>&2 2>&3)

    fi

    if [ -z "${MODE_CHOICE:-}" ]; then
        cancel_install
    fi
}


# ==============================================================================
# DETECTAR TECLADOS
# ==============================================================================

detect_keyboards() {

    KEYBOARD_PATHS=()
    KEYBOARD_NAMES=()

    for device in /dev/input/event*; do

        [ -e "$device" ] || continue

        name=$(udevadm info --query=property --name="$device" 2>/dev/null |
            sed -n 's/^NAME=//p' |
            tr -d '"')

        if [ -z "$name" ]; then
            name=$(cat "/sys/class/input/$(basename "$device")/device/name" 2>/dev/null || true)
        fi

        if [ -z "$name" ]; then
            name="Dispositivo de entrada"
        fi

        if evtest "$device" 2>/dev/null | grep -q "KEY_SPACE"; then

            KEYBOARD_PATHS+=("$device")
            KEYBOARD_NAMES+=("$name")

        fi

    done
}


# ==============================================================================
# SELECCIONAR TECLADO
# ==============================================================================

select_keyboard() {

    echo -e "${BLUE}Detectando teclados...${NC}"

    if ! command -v evtest >/dev/null 2>&1; then

        sudo apt-get install -y evtest >/dev/null 2>&1

    fi

    detect_keyboards

    if [ "${#KEYBOARD_PATHS[@]}" -eq 0 ]; then

        echo -e "${RED}No se encontraron teclados.${NC}"
        echo
        echo "Se utilizará búsqueda automática."
        echo

        KEYBOARD_PATH="auto"

    else

        MENU_ARGS=()

        for ((i=0; i<${#KEYBOARD_PATHS[@]}; i++)); do

            MENU_ARGS+=(
                "$((i+1))"
                "${KEYBOARD_NAMES[$i]} - ${KEYBOARD_PATHS[$i]}"
            )

        done

        if [ "$USE_GUI" = true ]; then

            DATA=""

            for ((i=0; i<${#KEYBOARD_PATHS[@]}; i++)); do

                DATA+="\"$((i+1))\" \"${KEYBOARD_NAMES[$i]}\" \"${KEYBOARD_PATHS[$i]}\" "

            done

            KEYBOARD_CHOICE=$(eval "zenity --list \
                --title=\"$TITLE\" \
                --text=\"Selecciona el teclado PTT:\" \
                --column=\"ID\" \
                --column=\"Teclado\" \
                --column=\"Dispositivo\" \
                $DATA \
                --hide-column=1 \
                --width=750 \
                --height=400 \
                2>/dev/null")

        else

            KEYBOARD_CHOICE=$(whiptail \
                --title="$TITLE" \
                --menu \
                "Selecciona el teclado PTT:" \
                20 90 \
                "${#KEYBOARD_PATHS[@]}" \
                "${MENU_ARGS[@]}" \
                3>&1 1>&2 2>&3)

        fi

        if [ -z "${KEYBOARD_CHOICE:-}" ]; then
            cancel_install
        fi

        if [[ "$KEYBOARD_CHOICE" =~ ^[0-9]+$ ]]; then

            INDEX=$((KEYBOARD_CHOICE - 1))

            KEYBOARD_PATH="${KEYBOARD_PATHS[$INDEX]}"

        else

            KEYBOARD_PATH="$KEYBOARD_CHOICE"

        fi

    fi

    echo
    echo -e "${GREEN}Teclado seleccionado:${NC}"
    echo "$KEYBOARD_PATH"
    echo
}


# ==============================================================================
# SELECCIONAR TECLA
# ==============================================================================

select_key() {

    KEY_OPTIONS=(
        "57" "ESPACIO"
        "28" "ENTER"
        "29" "CTRL"
        "56" "ALT"
        "59" "F1"
        "60" "F2"
        "61" "F3"
        "62" "F4"
        "63" "F5"
        "64" "F6"
        "65" "F7"
        "66" "F8"
        "67" "F9"
        "68" "F10"
        "87" "F11"
        "88" "F12"
    )

    if [ "$USE_GUI" = true ]; then

        KEY_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona la tecla que utilizarás para hablar:" \
            --column="Código" \
            --column="Tecla" \
            "${KEY_OPTIONS[@]}" \
            --width=500 \
            --height=500 \
            2>/dev/null)

    else

        KEY_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona la tecla que utilizarás para hablar:" \
            20 60 16 \
            "${KEY_OPTIONS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    if [ -z "${KEY_CHOICE:-}" ]; then
        cancel_install
    fi

    KEYBOARD_KEY="$KEY_CHOICE"

    case "$KEYBOARD_KEY" in

        57) KEYBOARD_KEY_NAME="ESPACIO" ;;
        28) KEYBOARD_KEY_NAME="ENTER" ;;
        29) KEYBOARD_KEY_NAME="CTRL" ;;
        56) KEYBOARD_KEY_NAME="ALT" ;;
        59) KEYBOARD_KEY_NAME="F1" ;;
        60) KEYBOARD_KEY_NAME="F2" ;;
        61) KEYBOARD_KEY_NAME="F3" ;;
        62) KEYBOARD_KEY_NAME="F4" ;;
        63) KEYBOARD_KEY_NAME="F5" ;;
        64) KEYBOARD_KEY_NAME="F6" ;;
        65) KEYBOARD_KEY_NAME="F7" ;;
        66) KEYBOARD_KEY_NAME="F8" ;;
        67) KEYBOARD_KEY_NAME="F9" ;;
        68) KEYBOARD_KEY_NAME="F10" ;;
        87) KEYBOARD_KEY_NAME="F11" ;;
        88) KEYBOARD_KEY_NAME="F12" ;;

        *) KEYBOARD_KEY_NAME="KEY_$KEYBOARD_KEY" ;;

    esac
}


# ==============================================================================
# AUDIO - ENTRADA
# ==============================================================================

select_audio_input() {

    echo -e "${BLUE}Detectando entradas de audio...${NC}"

    INPUT_IDS=()
    INPUT_NAMES=()

    while IFS= read -r line; do

        if [[ "$line" =~ ^card[[:space:]]+([0-9]+): ]]; then

            CARD="${BASH_REMATCH[1]}"

            NAME=$(echo "$line" |
                sed -E 's/^card [0-9]+: ([^[]+).*/\1/' |
                xargs)

            INPUT_IDS+=("$CARD")
            INPUT_NAMES+=("$NAME")

        fi

    done < <(arecord -l 2>/dev/null)

    if [ "${#INPUT_IDS[@]}" -eq 0 ]; then

        echo -e "${RED}No se encontraron entradas de audio.${NC}"
        exit 1

    fi

    MENU_ARGS=()

    for ((i=0; i<${#INPUT_IDS[@]}; i++)); do

        MENU_ARGS+=(
            "${INPUT_IDS[$i]}"
            "${INPUT_NAMES[$i]}"
        )

    done

    if [ "$USE_GUI" = true ]; then

        INPUT_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona la entrada de audio:" \
            --column="ID" \
            --column="Dispositivo" \
            "${MENU_ARGS[@]}" \
            --width=700 \
            --height=400 \
            2>/dev/null)

    else

        INPUT_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona la entrada de audio:" \
            20 80 \
            "${#INPUT_IDS[@]}" \
            "${MENU_ARGS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    if [ -z "${INPUT_CHOICE:-}" ]; then
        cancel_install
    fi

    AUDIO_INPUT_CARD="$INPUT_CHOICE"

    for ((i=0; i<${#INPUT_IDS[@]}; i++)); do

        if [ "${INPUT_IDS[$i]}" = "$INPUT_CHOICE" ]; then

            AUDIO_INPUT_NAME="${INPUT_NAMES[$i]}"

        fi

    done
}


# ==============================================================================
# AUDIO - SALIDA
# ==============================================================================

select_audio_output() {

    echo -e "${BLUE}Detectando salidas de audio...${NC}"

    OUTPUT_IDS=()
    OUTPUT_NAMES=()

    while IFS= read -r line; do

        if [[ "$line" =~ ^card[[:space:]]+([0-9]+): ]]; then

            CARD="${BASH_REMATCH[1]}"

            NAME=$(echo "$line" |
                sed -E 's/^card [0-9]+: ([^[]+).*/\1/' |
                xargs)

            OUTPUT_IDS+=("$CARD")
            OUTPUT_NAMES+=("$NAME")

        fi

    done < <(aplay -l 2>/dev/null)

    if [ "${#OUTPUT_IDS[@]}" -eq 0 ]; then

        echo -e "${RED}No se encontraron salidas de audio.${NC}"
        exit 1

    fi

    MENU_ARGS=()

    for ((i=0; i<${#OUTPUT_IDS[@]}; i++)); do

        MENU_ARGS+=(
            "${OUTPUT_IDS[$i]}"
            "${OUTPUT_NAMES[$i]}"
        )

    done

    if [ "$USE_GUI" = true ]; then

        OUTPUT_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona la salida de audio:" \
            --column="ID" \
            --column="Dispositivo" \
            "${MENU_ARGS[@]}" \
            --width=700 \
            --height=400 \
            2>/dev/null)

    else

        OUTPUT_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona la salida de audio:" \
            20 80 \
            "${#OUTPUT_IDS[@]}" \
            "${MENU_ARGS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    if [ -z "${OUTPUT_CHOICE:-}" ]; then
        cancel_install
    fi

    AUDIO_OUTPUT_CARD="$OUTPUT_CHOICE"

    for ((i=0; i<${#OUTPUT_IDS[@]}; i++)); do

        if [ "${OUTPUT_IDS[$i]}" = "$OUTPUT_CHOICE" ]; then

            AUDIO_OUTPUT_NAME="${OUTPUT_NAMES[$i]}"

        fi

    done
}


# ==============================================================================
# RESUMEN DE SELECCIÓN
# ==============================================================================

show_selection() {

    echo
    echo -e "${CYAN}"
    echo "===================================================="
    echo " CONFIGURACIÓN SELECCIONADA"
    echo "===================================================="
    echo -e "${NC}"

    echo "Idioma       : $LANGUAGE"
    echo "Voz          : $VOICE"
    echo "Activación   : $MODE_CHOICE"

    if [ "$MODE_CHOICE" = "ptt" ]; then

        echo "Teclado      : $KEYBOARD_PATH"
        echo "Tecla        : $KEYBOARD_KEY_NAME ($KEYBOARD_KEY)"

    fi

    echo "Entrada      : [$AUDIO_INPUT_CARD] $AUDIO_INPUT_NAME"
    echo "Salida       : [$AUDIO_OUTPUT_CARD] $AUDIO_OUTPUT_NAME"

    echo
}


# ==============================================================================
# BACKUPS
# ==============================================================================

backup_file() {

    FILE="$1"

    if [ -f "$FILE" ]; then

        cp "$FILE" \
            "$FILE.backup.$(date +%Y%m%d_%H%M%S)"

    fi
}


# ==============================================================================
# INSTALAR DEPENDENCIAS
# ==============================================================================

install_dependencies() {

    echo -e "${BLUE}[1/8] Instalando dependencias del sistema...${NC}"

    sudo apt-get update -qq

    sudo apt-get install -y \
        python3-venv \
        python3-pip \
        python3-dev \
        portaudio19-dev \
        libasound2-dev \
        alsa-utils \
        evtest \
        ffmpeg \
        git \
        wget \
        curl \
        unzip \
        build-essential \
        libsndfile1 \
        libffi-dev \
        >/dev/null 2>&1

}


# ==============================================================================
# VENV
# ==============================================================================

install_venv() {

    echo -e "${BLUE}[2/8] Creando entorno Python...${NC}"

    if [ ! -d "$BASE_DIR/venv" ]; then

        python3 -m venv "$BASE_DIR/venv"

    fi

    source "$BASE_DIR/venv/bin/activate"

    python -m pip install --upgrade \
        pip \
        setuptools \
        wheel \
        -q

}


# ==============================================================================
# PYTHON
# ==============================================================================

install_python() {

    echo -e "${BLUE}[3/8] Instalando librerías Python...${NC}"

    pip install \
        numpy \
        requests \
        ollama \
        sounddevice \
        faster-whisper \
        evdev \
        -q

}


# ==============================================================================
# OPENWAKEWORD
# ==============================================================================

install_wakeword() {

    if [ "$MODE_CHOICE" = "wakeword" ]; then

        echo -e "${BLUE}[4/8] Instalando OpenWakeWord...${NC}"

        pip install \
            openwakeword \
            pyaudio \
            tflite-runtime \
            -q

    else

        echo -e "${BLUE}[4/8] Modo PTT: OpenWakeWord no necesario.${NC}"

    fi
}


# ==============================================================================
# PIPER
# ==============================================================================

install_piper() {

    echo -e "${BLUE}[5/8] Preparando Piper TTS...${NC}"

    PIPER_DIR="$BASE_DIR/piper_tts"

    mkdir -p "$PIPER_DIR"

    if [ ! -x "$PIPER_DIR/piper/piper" ]; then

        echo -e "${YELLOW}Descargando Piper...${NC}"

        ARCH="$(uname -m)"

        case "$ARCH" in

            x86_64)
                PIPER_ARCH="amd64"
                ;;

            aarch64|arm64)
                PIPER_ARCH="arm64"
                ;;

            armv7l|armv7)
                PIPER_ARCH="armv7"
                ;;

            *)
                echo -e "${RED}Arquitectura no soportada: $ARCH${NC}"
                exit 1
                ;;

        esac

        PIPER_VERSION="2023.11.14-2"

        PIPER_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_linux_${PIPER_ARCH}.tar.gz"

        TEMP_PIPER="/tmp/piper_mmm.tar.gz"

        wget -q --show-progress \
            "$PIPER_URL" \
            -O "$TEMP_PIPER"

        if [ $? -ne 0 ]; then

            echo -e "${RED}No se pudo descargar Piper.${NC}"
            exit 1

        fi

        rm -rf "$PIPER_DIR/piper"

        mkdir -p "$PIPER_DIR/piper"

        tar -xzf "$TEMP_PIPER" \
            -C "$PIPER_DIR/piper" \
            --strip-components=1

        rm -f "$TEMP_PIPER"

    fi

    chmod +x "$PIPER_DIR/piper/piper"


    case "$VOICE" in

        es_ES-davefx-medium)
            VOICE_PATH="es/es_ES/davefx/medium"
            ;;

        es_ES-sharvard-medium)
            VOICE_PATH="es/es_ES/sharvard/medium"
            ;;

        en_US-lessac-medium)
            VOICE_PATH="en/en_US/lessac/medium"
            ;;

        fr_FR-upmc-medium)
            VOICE_PATH="fr/fr_FR/upmc/medium"
            ;;

        de_DE-thorsten-medium)
            VOICE_PATH="de/de_DE/thorsten/medium"
            ;;

        it_IT-riccardo-x_low)
            VOICE_PATH="it/it_IT/riccardo/x_low"
            ;;

        *)
            echo -e "${RED}Voz no soportada: $VOICE${NC}"
            exit 1
            ;;

    esac


    VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx"

    VOICE_JSON_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx.json"


    if [ ! -f "$PIPER_DIR/${VOICE}.onnx" ]; then

        echo -e "${YELLOW}Descargando voz Piper: $VOICE${NC}"

        wget -q --show-progress \
            "$VOICE_URL" \
            -O "$PIPER_DIR/${VOICE}.onnx"

    fi


    if [ ! -f "$PIPER_DIR/${VOICE}.onnx.json" ]; then

        wget -q --show-progress \
            "$VOICE_JSON_URL" \
            -O "$PIPER_DIR/${VOICE}.onnx.json"

    fi


    if [ ! -s "$PIPER_DIR/${VOICE}.onnx" ]; then

        echo -e "${RED}El modelo Piper no se descargó correctamente.${NC}"
        exit 1

    fi
}


# ==============================================================================
# GENERAR TRANSCRIBE.PY
# ==============================================================================

write_transcribe() {

    echo -e "${BLUE}[6/8] Configurando transcripción y micrófono...${NC}"

    backup_file "$BASE_DIR/transcribe.py"

    cat > "$BASE_DIR/transcribe.py" <<PYTHON
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

# Configurado automáticamente por install.sh
DEVICE_INDEX = ${AUDIO_INPUT_CARD}

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


print(
    "[transcribe] Microphone ready.",
    flush=True
)


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
            language="${LANGUAGE}",
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
PYTHON

    chmod +x "$BASE_DIR/transcribe.py"
}


# ==============================================================================
# GENERAR LISTEN_KEY.PY
# ==============================================================================

write_listener() {

    echo -e "${BLUE}Configurando PTT...${NC}"

    backup_file "$BASE_DIR/listen_key.py"

    cat > "$BASE_DIR/listen_key.py" <<PYTHON
# -*- coding: utf-8 -*-

import evdev
from evdev import InputDevice, ecodes
import sys
import subprocess
import os
import threading


BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)

python_bin = os.path.join(
    BASE_DIR,
    "venv",
    "bin",
    "python"
)

transcribe_script = os.path.join(
    BASE_DIR,
    "transcribe.py"
)


KEYBOARD_PATH = "${KEYBOARD_PATH}"
KEYBOARD_KEY = ${KEYBOARD_KEY}


if KEYBOARD_PATH == "auto":

    for device_path in evdev.list_devices():

        try:

            dev = InputDevice(device_path)

            capabilities = dev.capabilities()

            if ecodes.EV_KEY not in capabilities:
                continue

            keys = capabilities[ecodes.EV_KEY]

            if KEYBOARD_KEY in keys:

                KEYBOARD_PATH = dev.path
                break

        except Exception:

            continue


if not KEYBOARD_PATH or KEYBOARD_PATH == "auto":

    print(
        "ERROR: No se encontró el teclado configurado.",
        flush=True
    )

    sys.exit(1)


print(
    f"[MMM-TuAsistente] Keyboard: {KEYBOARD_PATH}",
    flush=True
)

print(
    f"[MMM-TuAsistente] Key: {KEYBOARD_KEY}",
    flush=True
)


try:

    keyboard = InputDevice(
        KEYBOARD_PATH
    )

except Exception as e:

    print(
        f"ERROR opening keyboard: {e}",
        flush=True
    )

    sys.exit(1)


if not os.path.exists(python_bin):

    print(
        f"ERROR: Python not found: {python_bin}",
        flush=True
    )

    sys.exit(1)


if not os.path.exists(transcribe_script):

    print(
        f"ERROR: transcribe.py not found: {transcribe_script}",
        flush=True
    )

    sys.exit(1)


try:

    transcribe_proc = subprocess.Popen(
        [
            python_bin,
            transcribe_script
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )

except Exception as e:

    print(
        f"ERROR starting transcribe.py: {e}",
        flush=True
    )

    sys.exit(1)


def read_output():

    try:

        for line in transcribe_proc.stdout:

            print(
                line,
                end="",
                flush=True
            )

    except Exception as e:

        print(
            f"ERROR reading transcribe.py: {e}",
            flush=True
        )


def read_errors():

    try:

        for line in transcribe_proc.stderr:

            print(
                f"[transcribe ERROR] {line}",
                end="",
                flush=True
            )

    except Exception as e:

        print(
            f"ERROR reading stderr: {e}",
            flush=True
        )


threading.Thread(
    target=read_output,
    daemon=True
).start()


threading.Thread(
    target=read_errors,
    daemon=True
).start()


def send_command(command):

    if transcribe_proc.poll() is not None:

        print(
            f"ERROR: transcribe.py stopped: "
            f"{transcribe_proc.returncode}",
            flush=True
        )

        return


    try:

        transcribe_proc.stdin.write(
            command + "\n"
        )

        transcribe_proc.stdin.flush()

    except Exception as e:

        print(
            f"ERROR sending command: {e}",
            flush=True
        )


is_pressed = False


print(
    "[MMM-TuAsistente] PTT listo.",
    flush=True
)


try:

    for event in keyboard.read_loop():

        if event.type != ecodes.EV_KEY:
            continue


        if event.value == 2:
            continue


        if event.code != KEYBOARD_KEY:
            continue


        if event.value == 1:

            if not is_pressed:

                is_pressed = True

                print(
                    "RECORD_START",
                    flush=True
                )

                send_command(
                    "START"
                )


        elif event.value == 0:

            if is_pressed:

                is_pressed = False

                print(
                    "RECORD_STOP",
                    flush=True
                )

                send_command(
                    "STOP"
                )


except KeyboardInterrupt:

    pass


except Exception as e:

    print(
        f"ERROR keyboard loop: {e}",
        flush=True
    )


finally:

    try:

        if transcribe_proc.poll() is None:

            transcribe_proc.terminate()

            try:

                transcribe_proc.wait(
                    timeout=2
                )

            except subprocess.TimeoutExpired:

                transcribe_proc.kill()

    except Exception:

        pass
PYTHON

    chmod +x "$BASE_DIR/listen_key.py"
}


# ==============================================================================
# GENERAR WAKEWORD LISTENER
# ==============================================================================

write_wakeword() {

    echo -e "${BLUE}Configurando Wake Word...${NC}"

    mkdir -p "$BASE_DIR/scripts"

    backup_file "$BASE_DIR/scripts/wakeword_listener.py"

    cat > "$BASE_DIR/scripts/wakeword_listener.py" <<PYTHON
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import json

sys.stdout.reconfigure(
    encoding="utf-8",
    line_buffering=True
)

try:

    import numpy as np
    import pyaudio

    from openwakeword.model import Model

except ImportError as err:

    print(
        json.dumps({
            "status": "error",
            "message": f"Librería no encontrada: {err}"
        }),
        flush=True
    )

    sys.exit(1)


def send_json(data):

    print(
        json.dumps(data),
        flush=True
    )


def main():

    model_name = (
        sys.argv[1]
        if len(sys.argv) > 1
        and sys.argv[1] != "null"
        else "hey_mycroft"
    )


    try:

        threshold = float(
            sys.argv[2]
        ) if len(sys.argv) > 2 else 0.5

    except ValueError:

        threshold = 0.5


    mic_index = None


    if len(sys.argv) > 3:

        if sys.argv[3] not in [
            "null",
            "undefined",
            "None"
        ]:

            try:

                mic_index = int(
                    sys.argv[3]
                )

            except ValueError:

                mic_index = None


    try:

        oww_model = Model(
            wakeword_models=[
                model_name
            ],
            inference_framework="tflite"
        )

    except Exception:

        try:

            oww_model = Model(
                wakeword_models=[
                    model_name
                ],
                inference_framework="onnx"
            )

        except Exception as e:

            send_json({
                "status": "error",
                "message":
                    f"Error al cargar el modelo "
                    f"'{model_name}': {str(e)}"
            })

            sys.exit(1)


    FORMAT = pyaudio.paInt16
    CHANNELS = 1
    RATE = 16000
    CHUNK = 1280


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

        send_json({
            "status": "error",
            "message":
                f"Error al abrir el micrófono "
                f"(Índice: {mic_index}): {str(err)}"
        })

        audio.terminate()

        sys.exit(1)


    send_json({
        "status": "ready",
        "model": model_name,
        "threshold": threshold,
        "mic": mic_index
    })


    try:

        while True:

            raw_data = stream.read(
                CHUNK,
                exception_on_overflow=False
            )


            if not raw_data:
                continue


            audio_data = np.frombuffer(
                raw_data,
                dtype=np.int16
            )


            prediction = oww_model.predict(
                audio_data
            )


            for wakeword_key, score in prediction.items():

                if score >= threshold:

                    send_json({
                        "status": "detected",
                        "wakeword": wakeword_key,
                        "score": round(
                            float(score),
                            3
                        )
                    })

                    oww_model.reset()


    except KeyboardInterrupt:

        pass


    finally:

        try:
            stream.stop_stream()
            stream.close()
        except Exception:
            pass

        audio.terminate()


if __name__ == "__main__":

    main()
PYTHON

    chmod +x "$BASE_DIR/scripts/wakeword_listener.py"
}


# ==============================================================================
# MODIFICAR NODE_HELPER.JS
# ==============================================================================

write_node_helper() {

    echo -e "${BLUE}Configurando Node Helper y salida de audio...${NC}"

    backup_file "$BASE_DIR/node_helper.js"

    python3 - "$BASE_DIR/node_helper.js" "$VOICE" "$AUDIO_OUTPUT_CARD" <<'PY'
import sys
import re

path = sys.argv[1]
voice = sys.argv[2]
output_card = sys.argv[3]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Guardar voz/salida en defaults internos solamente como referencia.
# La función speakText leerá this.config dinámicamente.

old = """const modelPath = path.join(__dirname, 'piper_tts', 'es_ES-davefx-medium.onnx');"""

new = """const selectedVoice = (this.config && this.config.voice)
      ? this.config.voice
      : 'es_ES-davefx-medium';

    const modelPath = path.join(
      __dirname,
      'piper_tts',
      selectedVoice + '.onnx'
    );"""

if old in content:
    content = content.replace(old, new, 1)

# Sustituir la línea aplay actual.
old_aplay = """`aplay -r 22050 -f S16_LE -t raw`;"""

new_aplay = """`aplay -D "plughw:${this.config && this.config.audioOutputCard !== undefined ? this.config.audioOutputCard : 0}" -r 22050 -f S16_LE -t raw`;"""

if old_aplay in content:
    content = content.replace(old_aplay, new_aplay, 1)

# Si no encuentra exactamente la línea anterior, cambiar el fragmento.
content = content.replace(
    "`aplay -r 22050 -f S16_LE -t raw`",
    "`aplay -D \\"plughw:${this.config && this.config.audioOutputCard !== undefined ? this.config.audioOutputCard : 0}\\" -r 22050 -f S16_LE -t raw`"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
}


# ==============================================================================
# CONFIGURAR CONFIG.JS
# ==============================================================================

configure_magicmirror() {

    echo -e "${BLUE}[8/8] Configurando MagicMirror...${NC}"

    CONFIG_PATH="$BASE_DIR/../../config/config.js"

    if [ ! -f "$CONFIG_PATH" ]; then

        echo
        echo -e "${YELLOW}No se encontró automáticamente:${NC}"
        echo "$CONFIG_PATH"
        echo

        return

    fi


    ADD_CONFIG=false


    if [ "$USE_GUI" = true ]; then

        zenity --question \
            --title="$TITLE" \
            --text="¿Quieres añadir MMM-TuAsistente automáticamente a config.js?" \
            --ok-label="Sí" \
            --cancel-label="No" \
            --width=500 \
            2>/dev/null

        if [ $? -eq 0 ]; then
            ADD_CONFIG=true
        fi

    else

        if whiptail \
            --title="$TITLE" \
            --yesno \
            "¿Quieres añadir MMM-TuAsistente automáticamente a config.js?" \
            10 65
        then

            ADD_CONFIG=true

        fi

    fi


    if [ "$ADD_CONFIG" != true ]; then
        return
    fi


    backup_file "$CONFIG_PATH"


    TEMP_CONFIG="/tmp/config_mmm_tuasistente.js"


    python3 \
        "$CONFIG_PATH" \
        "$TEMP_CONFIG" \
        "$LANGUAGE" \
        "$VOICE" \
        "$MODE_CHOICE" \
        "$AUDIO_INPUT_CARD" \
        "$AUDIO_INPUT_NAME" \
        "$AUDIO_OUTPUT_CARD" \
        "$AUDIO_OUTPUT_NAME" \
        "$KEYBOARD_PATH" \
        "$KEYBOARD_KEY" \
        "$KEYBOARD_KEY_NAME" <<'PY'
import sys

config_path = sys.argv[1]
output_path = sys.argv[2]

language = sys.argv[3]
voice = sys.argv[4]
mode = sys.argv[5]

input_card = sys.argv[6]
input_name = sys.argv[7]

output_card = sys.argv[8]
output_name = sys.argv[9]

keyboard_path = sys.argv[10]
keyboard_key = sys.argv[11]
keyboard_key_name = sys.argv[12]


with open(
    config_path,
    "r",
    encoding="utf-8"
) as f:

    content = f.read()


if "MMM-TuAsistente" in content:

    print(
        "MMM-TuAsistente ya existe en config.js"
    )

    sys.exit(2)


keyboard_config = ""

if mode == "ptt":

    keyboard_config = f"""
            keyboardDevice: "{keyboard_path}",
            keyboardKey: {keyboard_key},
            keyboardKeyName: "{keyboard_key_name}",
"""


block = f"""
    {{
        module: "MMM-TuAsistente",

        position: "middle_center",

        config: {{

            language: "{language}",

            activationMode: "{mode}",

            voice: "{voice}",

            micDeviceIndex: {input_card},

            micDeviceName: "{input_name}",

            audioOutputCard: {output_card},

            audioOutputName: "{output_name}",

{keyboard_config}

            wakeWordModel: "hey_mycroft",

            wakeWordThreshold: 0.5,

            model: "qwen2.5:1.5b",

            hideDelay: 18000
        }}
    }},
"""


marker = "modules: ["

if marker not in content:

    print(
        "ERROR: No se encontró 'modules: ['"
    )

    sys.exit(1)


content = content.replace(
    marker,
    marker + "\n" + block,
    1
)


with open(
    output_path,
    "w",
    encoding="utf-8"
) as f:

    f.write(content)
PY


    RESULT=$?


    if [ "$RESULT" -eq 0 ]; then

        mv "$TEMP_CONFIG" "$CONFIG_PATH"

        echo -e "${GREEN}[OK] MMM-TuAsistente añadido a config.js${NC}"

    elif [ "$RESULT" -eq 2 ]; then

        rm -f "$TEMP_CONFIG"

        echo -e "${YELLOW}[AVISO] MMM-TuAsistente ya estaba en config.js${NC}"

    else

        rm -f "$TEMP_CONFIG"

        echo -e "${RED}[ERROR] No se pudo modificar config.js${NC}"

    fi
}


# ==============================================================================
# PERMISOS
# ==============================================================================

set_permissions() {

    chmod +x "$BASE_DIR/install.sh"
    chmod +x "$BASE_DIR/listen_key.py"
    chmod +x "$BASE_DIR/transcribe.py"
    chmod +x "$BASE_DIR/scripts/wakeword_listener.py"

}


# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

final_message() {

    echo

    echo -e "${GREEN}"
    echo "===================================================="
    echo "       INSTALACIÓN COMPLETADA"
    echo "===================================================="
    echo -e "${NC}"

    echo "Idioma        : $LANGUAGE"
    echo "Voz Piper     : $VOICE"
    echo "Activación    : $MODE_CHOICE"

    if [ "$MODE_CHOICE" = "ptt" ]; then

        echo "Teclado       : $KEYBOARD_PATH"
        echo "Tecla         : $KEYBOARD_KEY_NAME ($KEYBOARD_KEY)"

    fi

    echo "Entrada audio : [$AUDIO_INPUT_CARD] $AUDIO_INPUT_NAME"
    echo "Salida audio  : [$AUDIO_OUTPUT_CARD] $AUDIO_OUTPUT_NAME"

    echo

    echo -e "${GREEN}Piper:${NC}"
    echo "$BASE_DIR/piper_tts/${VOICE}.onnx"

    echo

    if [ "$MODE_CHOICE" = "ptt" ]; then

        echo -e "${CYAN}PTT:${NC}"
        echo "Mantén pulsada la tecla $KEYBOARD_KEY_NAME para hablar."

    else

        echo -e "${CYAN}Wake Word:${NC}"
        echo "Di: Hey Mycroft"

    fi

    echo

    echo -e "${GREEN}Reinicia MagicMirror:${NC}"
    echo
    echo "pm2 restart mm"
    echo

}


# ==============================================================================
# EJECUCIÓN
# ==============================================================================

confirm_install

select_language

select_voice

select_activation_mode


# Teclado solamente para PTT
if [ "$MODE_CHOICE" = "ptt" ]; then

    select_keyboard
    select_key

else

    KEYBOARD_PATH=""
    KEYBOARD_KEY=""
    KEYBOARD_KEY_NAME=""

fi


# Audio SIEMPRE
select_audio_input
select_audio_output


show_selection


# Instalación
install_dependencies

install_venv

install_python

install_wakeword

install_piper

write_transcribe

write_listener

write_wakeword

write_node_helper

configure_magicmirror

set_permissions


deactivate 2>/dev/null || true


final_message