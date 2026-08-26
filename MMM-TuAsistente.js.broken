#!/bin/bash

# ==============================================================================
# MMM-TuAsistente
# INSTALADOR COMPLETO
#
# Configura automáticamente:
#   - MMM-TuAsistente
#   - Idioma
#   - Voz Piper
#   - PTT / Wake Word
#   - Entrada de audio
#   - Salida de audio
#   - Teclado y tecla PTT
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

# ==============================================================================
# DIRECTORIO
# ==============================================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo
echo -e "${GREEN}"
echo "===================================================="
echo "       MMM-TuAsistente - INSTALADOR"
echo "===================================================="
echo -e "${NC}"

if [ ! -f "$BASE_DIR/node_helper.js" ]; then
    echo -e "${RED}[ERROR] No se encuentra node_helper.js${NC}"
    echo
    echo "Ejecuta:"
    echo "cd ~/MagicMirror/modules/MMM-TuAsistente"
    echo "./install.sh"
    echo
    exit 1
fi

cd "$BASE_DIR"

echo -e "${GREEN}[OK] Módulo encontrado:${NC}"
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
# PREGUNTAR SI INSTALAR MMM-TuAsistente
# ==============================================================================

confirm_install() {

    if [ "$USE_GUI" = true ]; then

        zenity --question \
            --title="$TITLE" \
            --text="¿Quieres instalar MMM-TuAsistente?" \
            --ok-label="Sí, instalar" \
            --cancel-label="No, cancelar" \
            --width=500 \
            2>/dev/null

        if [ $? -ne 0 ]; then
            echo
            echo -e "${YELLOW}Instalación cancelada.${NC}"
            echo
            exit 0
        fi

    else

        if ! whiptail \
            --title="$TITLE" \
            --yesno \
            "¿Quieres instalar MMM-TuAsistente?" \
            10 65
        then
            echo
            echo -e "${YELLOW}Instalación cancelada.${NC}"
            echo
            exit 0
        fi

    fi

}

confirm_install

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

cancel_if_empty() {

    local value="$1"

    if [ -z "$value" ]; then
        echo
        echo -e "${RED}Instalación cancelada.${NC}"
        exit 1
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
            --width=500 \
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
        es|en|fr|de|it) ;;
        *) cancel_if_empty "$LANGUAGE" ;;
    esac
}

# ==============================================================================
# VOZ
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

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Select Piper voice:" \
                    --column="ID" \
                    --column="Voice" \
                    --column="Description" \
                    "en_US-lessac-medium" "Lessac" "US English" \
                    --hide-column=1 \
                    --width=650 \
                    --height=250 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu \
                    "Select Piper voice:" \
                    15 75 1 \
                    "en_US-lessac-medium" "Lessac - US English" \
                    3>&1 1>&2 2>&3)

            fi
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

    cancel_if_empty "$VOICE"
}

# ==============================================================================
# MODO
# ==============================================================================

select_activation_mode() {

    if [ "$USE_GUI" = true ]; then

        MODE_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona modo de activación:" \
            --column="ID" \
            --column="Modo" \
            --column="Descripción" \
            "ptt" "PTT" "Mantener pulsada una tecla" \
            "wakeword" "Wake Word" "Activación por voz" \
            --hide-column=1 \
            --width=700 \
            --height=300 \
            2>/dev/null)

    else

        MODE_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona modo de activación:" \
            15 75 2 \
            "ptt" "PTT - Tecla" \
            "wakeword" "Wake Word - Voz" \
            3>&1 1>&2 2>&3)

    fi

    cancel_if_empty "$MODE_CHOICE"
}

# ==============================================================================
# DETECTAR ENTRADAS DE AUDIO
# ==============================================================================

detect_audio_inputs() {

    echo
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${CYAN} CONFIGURACIÓN DE AUDIO${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo

    if ! command -v arecord >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y alsa-utils >/dev/null 2>&1
    fi

    INPUT_NAMES=()
    INPUT_CARDS=()
    INPUT_DEVICES=()

    local card=""
    local device=""

    while IFS= read -r line; do

        if [[ "$line" =~ ^card[[:space:]]+([0-9]+):[[:space:]]*([^[]+) ]]; then

            card="${BASH_REMATCH[1]}"
            card_name="${BASH_REMATCH[2]}"

            card_name="$(echo "$card_name" | sed 's/[[:space:]]*$//')"

        elif [[ "$line" =~ ^[[:space:]]*([0-9]+):[[:space:]]*(.*)$ ]]; then

            device="${BASH_REMATCH[1]}"
            device_name="${BASH_REMATCH[2]}"

            INPUT_NAMES+=("${card_name} - ${device_name}")
            INPUT_CARDS+=("$card")
            INPUT_DEVICES+=("$device")

        fi

    done < <(arecord -l 2>/dev/null)

    # Método alternativo si el formato ALSA anterior no detectó nada
    if [ "${#INPUT_NAMES[@]}" -eq 0 ]; then

        while IFS= read -r line; do

            if [[ "$line" =~ card[[:space:]]+([0-9]+): ]]; then
                card="${BASH_REMATCH[1]}"
            fi

            if [[ "$line" =~ ^[[:space:]]*([0-9]+):[[:space:]]*(.*)$ ]]; then

                device="${BASH_REMATCH[1]}"
                device_name="${BASH_REMATCH[2]}"

                INPUT_NAMES+=("hw:${card},${device} - ${device_name}")
                INPUT_CARDS+=("$card")
                INPUT_DEVICES+=("$device")

            fi

        done < <(arecord -l 2>/dev/null)

    fi

    # Si no hay entradas
    if [ "${#INPUT_NAMES[@]}" -eq 0 ]; then

        echo -e "${YELLOW}[AVISO] No se detectaron entradas con arecord.${NC}"

        INPUT_NAMES=("Predeterminado del sistema")
        INPUT_CARDS=("-1")
        INPUT_DEVICES=("-1")

    fi

    if [ "$USE_GUI" = true ]; then

        local args=()

        for i in "${!INPUT_NAMES[@]}"; do
            args+=("${i}" "${INPUT_NAMES[$i]}")
        done

        INPUT_SELECTION=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona entrada de audio:" \
            --column="ID" \
            --column="Dispositivo" \
            "${args[@]}" \
            --hide-column=1 \
            --width=800 \
            --height=450 \
            2>/dev/null)

    else

        local args=()

        for i in "${!INPUT_NAMES[@]}"; do
            args+=("$i" "${INPUT_NAMES[$i]}")
        done

        INPUT_SELECTION=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona entrada de audio:" \
            20 90 10 \
            "${args[@]}" \
            3>&1 1>&2 2>&3)

    fi

    cancel_if_empty "$INPUT_SELECTION"

    INPUT_INDEX="$INPUT_SELECTION"

    AUDIO_INPUT_CARD="${INPUT_CARDS[$INPUT_INDEX]}"
    AUDIO_INPUT_DEVICE="${INPUT_DEVICES[$INPUT_INDEX]}"

    AUDIO_INPUT_NAME="${INPUT_NAMES[$INPUT_INDEX]}"

    echo
    echo -e "${GREEN}[OK] Entrada:${NC} $AUDIO_INPUT_NAME"
}

# ==============================================================================
# DETECTAR SALIDAS
# ==============================================================================

detect_audio_outputs() {

    OUTPUT_NAMES=()
    OUTPUT_CARDS=()
    OUTPUT_DEVICES=()

    local card=""
    local device=""

    while IFS= read -r line; do

        if [[ "$line" =~ ^card[[:space:]]+([0-9]+):[[:space:]]*([^[]+) ]]; then

            card="${BASH_REMATCH[1]}"
            card_name="${BASH_REMATCH[2]}"

            card_name="$(echo "$card_name" | sed 's/[[:space:]]*$//')"

        elif [[ "$line" =~ ^[[:space:]]*([0-9]+):[[:space:]]*(.*)$ ]]; then

            device="${BASH_REMATCH[1]}"
            device_name="${BASH_REMATCH[2]}"

            OUTPUT_NAMES+=("${card_name} - ${device_name}")
            OUTPUT_CARDS+=("$card")
            OUTPUT_DEVICES+=("$device")

        fi

    done < <(aplay -l 2>/dev/null)

    if [ "${#OUTPUT_NAMES[@]}" -eq 0 ]; then

        OUTPUT_NAMES=("Predeterminada del sistema")
        OUTPUT_CARDS=("-1")
        OUTPUT_DEVICES=("-1")

    fi

    if [ "$USE_GUI" = true ]; then

        local args=()

        for i in "${!OUTPUT_NAMES[@]}"; do
            args+=("${i}" "${OUTPUT_NAMES[$i]}")
        done

        OUTPUT_SELECTION=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona salida de audio:" \
            --column="ID" \
            --column="Dispositivo" \
            "${args[@]}" \
            --hide-column=1 \
            --width=800 \
            --height=450 \
            2>/dev/null)

    else

        local args=()

        for i in "${!OUTPUT_NAMES[@]}"; do
            args+=("$i" "${OUTPUT_NAMES[$i]}")
        done

        OUTPUT_SELECTION=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona salida de audio:" \
            20 90 10 \
            "${args[@]}" \
            3>&1 1>&2 2>&3)

    fi

    cancel_if_empty "$OUTPUT_SELECTION"

    OUTPUT_INDEX="$OUTPUT_SELECTION"

    AUDIO_OUTPUT_CARD="${OUTPUT_CARDS[$OUTPUT_INDEX]}"
    AUDIO_OUTPUT_DEVICE="${OUTPUT_DEVICES[$OUTPUT_INDEX]}"

    AUDIO_OUTPUT_NAME="${OUTPUT_NAMES[$OUTPUT_INDEX]}"

    echo
    echo -e "${GREEN}[OK] Salida:${NC} $AUDIO_OUTPUT_NAME"
}

# ==============================================================================
# DETECTAR TECLADOS
# ==============================================================================

detect_keyboard() {

    KEYBOARD_NAMES=()
    KEYBOARD_PATHS=()

    echo
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${CYAN} CONFIGURACIÓN PTT${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo

    if [ ! -d /dev/input ]; then
        echo -e "${RED}[ERROR] No existe /dev/input${NC}"
        exit 1
    fi

    while IFS= read -r event_path; do

        [ -z "$event_path" ] && continue

        name=""

        if [ -r "$event_path/device/name" ]; then
            name="$(cat "$event_path/device/name" 2>/dev/null)"
        fi

        [ -z "$name" ] && name="Dispositivo de entrada"

        if python3 - "$event_path" <<'PY' >/dev/null 2>&1
import sys
try:
    import evdev
    from evdev import ecodes
    dev = evdev.InputDevice(sys.argv[1])
    caps = dev.capabilities()
    if ecodes.EV_KEY in caps:
        keys = caps[ecodes.EV_KEY]
        if ecodes.KEY_SPACE in keys:
            sys.exit(0)
except Exception:
    pass
sys.exit(1)
PY
        then

            KEYBOARD_NAMES+=("$name")
            KEYBOARD_PATHS+=("$event_path")

        fi

    done < <(find /dev/input -maxdepth 1 -type c -name 'event*' 2>/dev/null | sort)

    if [ "${#KEYBOARD_NAMES[@]}" -eq 0 ]; then

        echo -e "${RED}[ERROR] No se encontró ningún teclado.${NC}"
        echo
        echo "Conecta un teclado y vuelve a ejecutar el instalador."
        exit 1

    fi

    if [ "$USE_GUI" = true ]; then

        local args=()

        for i in "${!KEYBOARD_NAMES[@]}"; do
            args+=("${i}" "${KEYBOARD_NAMES[$i]} (${KEYBOARD_PATHS[$i]})")
        done

        KEYBOARD_SELECTION=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el teclado para PTT:" \
            --column="ID" \
            --column="Teclado" \
            "${args[@]}" \
            --hide-column=1 \
            --width=800 \
            --height=400 \
            2>/dev/null)

    else

        local args=()

        for i in "${!KEYBOARD_NAMES[@]}"; do
            args+=("$i" "${KEYBOARD_NAMES[$i]} (${KEYBOARD_PATHS[$i]})")
        done

        KEYBOARD_SELECTION=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el teclado para PTT:" \
            20 90 10 \
            "${args[@]}" \
            3>&1 1>&2 2>&3)

    fi

    cancel_if_empty "$KEYBOARD_SELECTION"

    KEYBOARD_PATH="${KEYBOARD_PATHS[$KEYBOARD_SELECTION]}"
    KEYBOARD_NAME="${KEYBOARD_NAMES[$KEYBOARD_SELECTION]}"

    # ==========================================================================
    # SELECCIONAR TECLA
    # ==========================================================================

    if [ "$USE_GUI" = true ]; then

        KEY_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona la tecla que utilizarás para hablar:" \
            --column="Código" \
            --column="Tecla" \
            "SPACE" "Barra espaciadora" \
            "ENTER" "Enter" \
            "CTRL" "Ctrl" \
            "ALT" "Alt" \
            "SHIFT" "Shift" \
            "F1" "F1" \
            "F2" "F2" \
            "F3" "F3" \
            "F4" "F4" \
            "F5" "F5" \
            "F6" "F6" \
            "F7" "F7" \
            "F8" "F8" \
            "F9" "F9" \
            "F10" "F10" \
            "F11" "F11" \
            "F12" "F12" \
            --width=500 \
            --height=500 \
            2>/dev/null)

    else

        KEY_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona la tecla PTT:" \
            22 70 12 \
            "SPACE" "Barra espaciadora" \
            "ENTER" "Enter" \
            "CTRL" "Ctrl" \
            "ALT" "Alt" \
            "SHIFT" "Shift" \
            "F1" "F1" \
            "F2" "F2" \
            "F3" "F3" \
            "F4" "F4" \
            "F5" "F5" \
            "F6" "F6" \
            "F7" "F7" \
            "F8" "F8" \
            "F9" "F9" \
            "F10" "F10" \
            "F11" "F11" \
            "F12" "F12" \
            3>&1 1>&2 2>&3)

    fi

    cancel_if_empty "$KEY_CHOICE"

    echo
    echo -e "${GREEN}[OK] Teclado:${NC} $KEYBOARD_NAME"
    echo -e "${GREEN}[OK] Dispositivo:${NC} $KEYBOARD_PATH"
    echo -e "${GREEN}[OK] Tecla PTT:${NC} $KEY_CHOICE"
}

# ==============================================================================
# CONFIGURACIÓN DE AUDIO
# ==============================================================================

select_audio() {

    detect_audio_inputs
    detect_audio_outputs

    if [ "$MODE_CHOICE" = "ptt" ]; then
        detect_keyboard
    else
        KEYBOARD_PATH=""
        KEYBOARD_NAME=""
        KEY_CHOICE=""
    fi
}

# ==============================================================================
# EJECUTAR SELECCIONES
# ==============================================================================

select_language
select_voice
select_activation_mode
select_audio

# ==============================================================================
# RESUMEN
# ==============================================================================

echo
echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN} CONFIGURACIÓN SELECCIONADA${NC}"
echo -e "${CYAN}====================================================${NC}"
echo
echo "Idioma           : $LANGUAGE"
echo "Voz Piper        : $VOICE"
echo "Activación       : $MODE_CHOICE"
echo "Entrada audio    : $AUDIO_INPUT_NAME"
echo "ALSA entrada     : hw:${AUDIO_INPUT_CARD},${AUDIO_INPUT_DEVICE}"
echo "Salida audio     : $AUDIO_OUTPUT_NAME"
echo "ALSA salida      : hw:${AUDIO_OUTPUT_CARD},${AUDIO_OUTPUT_DEVICE}"

if [ "$MODE_CHOICE" = "ptt" ]; then
    echo "Teclado          : $KEYBOARD_NAME"
    echo "Dispositivo      : $KEYBOARD_PATH"
    echo "Tecla PTT        : $KEY_CHOICE"
fi

echo
echo -e "${CYAN}====================================================${NC}"
echo

# ==============================================================================
# DEPENDENCIAS
# ==============================================================================

echo -e "${BLUE}[1/8] Instalando dependencias del sistema...${NC}"

sudo apt-get update -qq

sudo apt-get install -y \
    python3-venv \
    python3-pip \
    python3-dev \
    portaudio19-dev \
    libasound2-dev \
    alsa-utils \
    ffmpeg \
    git \
    wget \
    curl \
    unzip \
    build-essential \
    libsndfile1 \
    >/dev/null 2>&1

# ==============================================================================
# VENV
# ==============================================================================

echo -e "${BLUE}[2/8] Creando entorno Python...${NC}"

if [ ! -d "$BASE_DIR/venv" ]; then
    python3 -m venv "$BASE_DIR/venv"
fi

PYTHON_BIN="$BASE_DIR/venv/bin/python"

source "$BASE_DIR/venv/bin/activate"

python -m pip install --upgrade pip setuptools wheel -q

# ==============================================================================
# PYTHON
# ==============================================================================

echo -e "${BLUE}[3/8] Instalando librerías Python...${NC}"

pip install \
    numpy \
    requests \
    ollama \
    sounddevice \
    faster-whisper \
    evdev \
    yt-dlp \
    -q

# ==============================================================================
# WAKE WORD
# ==============================================================================

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

# ==============================================================================
# PIPER
# ==============================================================================

echo -e "${BLUE}[5/8] Preparando Piper TTS...${NC}"

mkdir -p "$BASE_DIR/piper_tts"

PIPER_DIR="$BASE_DIR/piper_tts"

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
            echo -e "${RED}[ERROR] Arquitectura no soportada: $ARCH${NC}"
            deactivate
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
        echo -e "${RED}[ERROR] No se pudo descargar Piper.${NC}"
        deactivate
        exit 1
    fi

    rm -rf "$PIPER_DIR/piper"

    mkdir -p "$PIPER_DIR/piper"

    tar -xzf "$TEMP_PIPER" \
        -C "$PIPER_DIR/piper" \
        --strip-components=1

    rm -f "$TEMP_PIPER"

fi

chmod +x "$PIPER_DIR/piper/piper" 2>/dev/null

# ==============================================================================
# VOZ PIPER
# ==============================================================================

echo -e "${YELLOW}Descargando voz Piper: $VOICE${NC}"

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
        echo -e "${RED}[ERROR] Voz no soportada: $VOICE${NC}"
        deactivate
        exit 1
        ;;
esac

VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx"
VOICE_JSON_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx.json"

if [ ! -f "$PIPER_DIR/${VOICE}.onnx" ]; then
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
    echo -e "${RED}[ERROR] El modelo Piper no se descargó correctamente.${NC}"
    deactivate
    exit 1
fi

# ==============================================================================
# GENERAR transcribe.py
# ==============================================================================

echo -e "${BLUE}[6/8] Configurando reconocimiento de voz...${NC}"

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


print(
    f"[transcribe] Microphone ready. Device: {DEVICE_INDEX}",
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

# ==============================================================================
# GENERAR listen_key.py
# ==============================================================================

echo -e "${BLUE}Configurando PTT...${NC}"

KEY_CODE="KEY_SPACE"

case "$KEY_CHOICE" in
    SPACE) KEY_CODE="KEY_SPACE" ;;
    ENTER) KEY_CODE="KEY_ENTER" ;;
    CTRL) KEY_CODE="KEY_LEFTCTRL" ;;
    ALT) KEY_CODE="KEY_LEFTALT" ;;
    SHIFT) KEY_CODE="KEY_LEFTSHIFT" ;;
    F1) KEY_CODE="KEY_F1" ;;
    F2) KEY_CODE="KEY_F2" ;;
    F3) KEY_CODE="KEY_F3" ;;
    F4) KEY_CODE="KEY_F4" ;;
    F5) KEY_CODE="KEY_F5" ;;
    F6) KEY_CODE="KEY_F6" ;;
    F7) KEY_CODE="KEY_F7" ;;
    F8) KEY_CODE="KEY_F8" ;;
    F9) KEY_CODE="KEY_F9" ;;
    F10) KEY_CODE="KEY_F10" ;;
    F11) KEY_CODE="KEY_F11" ;;
    F12) KEY_CODE="KEY_F12" ;;
esac

cat > "$BASE_DIR/listen_key.py" <<PYTHON
# -*- coding: utf-8 -*-

import evdev
from evdev import InputDevice, ecodes
import sys
import subprocess
import os
import threading

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

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
KEY_NAME = "${KEY_CHOICE}"
KEY_CODE = ecodes.${KEY_CODE}


if not KEYBOARD_PATH:

    print(
        "ERROR: No keyboard configured.",
        flush=True
    )

    sys.exit(1)


print(
    f"[MMM-TuAsistente] Keyboard: {KEYBOARD_PATH}",
    flush=True
)

print(
    f"[MMM-TuAsistente] PTT key: {KEY_NAME}",
    flush=True
)


try:

    keyboard = InputDevice(KEYBOARD_PATH)

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
            f"ERROR: transcribe.py stopped: {transcribe_proc.returncode}",
            flush=True
        )

        return

    try:

        transcribe_proc.stdin.write(
            command + "\\n"
        )

        transcribe_proc.stdin.flush()

    except Exception as e:

        print(
            f"ERROR sending command: {e}",
            flush=True
        )


is_pressed = False


print(
    f"[MMM-TuAsistente] Pulsa {KEY_NAME} para hablar.",
    flush=True
)


try:

    for event in keyboard.read_loop():

        if event.type != ecodes.EV_KEY:
            continue

        if event.code != KEY_CODE:
            continue

        if event.value == 2:
            continue

        if event.value == 1:

            if not is_pressed:

                is_pressed = True

                print(
                    "RECORD_START",
                    flush=True
                )

                send_command("START")

        elif event.value == 0:

            if is_pressed:

                is_pressed = False

                print(
                    "RECORD_STOP",
                    flush=True
                )

                send_command("STOP")


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

# ==============================================================================
# WAKE WORD
# ==============================================================================

if [ "$MODE_CHOICE" = "wakeword" ]; then

    echo -e "${BLUE}Configurando Wake Word...${NC}"

    mkdir -p "$BASE_DIR/scripts"

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
        if len(sys.argv) > 1 and sys.argv[1] != "null"
        else "hey_mycroft"
    )

    try:

        threshold = (
            float(sys.argv[2])
            if len(sys.argv) > 2
            else 0.5
        )

    except ValueError:

        threshold = 0.5


    mic_index = None

    if len(sys.argv) > 3:

        try:

            if sys.argv[3] not in [
                "null",
                "undefined",
                "None"
            ]:

                mic_index = int(
                    sys.argv[3]
                )

        except ValueError:

            mic_index = None


    try:

        oww_model = Model(
            wakeword_models=[model_name],
            inference_framework="tflite"
        )

    except Exception:

        try:

            oww_model = Model(
                wakeword_models=[model_name],
                inference_framework="onnx"
            )

        except Exception as e:

            send_json({
                "status": "error",
                "message": str(e)
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
            "message": f"Error al abrir micrófono: {err}"
        })

        audio.terminate()

        sys.exit(1)


    send_json({
        "status": "ready",
        "model": model_name,
        "threshold": threshold,
        "mic": mic_index
    })


    while True:

        try:

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
            break

        except Exception:
            continue


    stream.stop_stream()
    stream.close()
    audio.terminate()


if __name__ == "__main__":
    main()
PYTHON

fi

# ==============================================================================
# NODE_HELPER.JS
# ==============================================================================

echo -e "${BLUE}[7/8] Configurando node_helper.js...${NC}"

python3 - "$BASE_DIR/node_helper.js" "$BASE_DIR/node_helper.js.tmp" "$VOICE" "$AUDIO_OUTPUT_CARD" "$AUDIO_OUTPUT_DEVICE" <<'PY'
import sys

path = sys.argv[1]
out = sys.argv[2]
voice = sys.argv[3]
card = sys.argv[4]
device = sys.argv[5]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Guardar una copia
backup = path + ".backup.install"
with open(backup, "w", encoding="utf-8") as f:
    f.write(content)

# Modelo Piper dinámico
old = 'es_ES-davefx-medium.onnx'
new = f'{voice}.onnx'

content = content.replace(old, new)

# Añadir configuración de salida ALSA
marker = "  speakText(text) {"

if marker in content and "configuredAudioOutput" not in content:

    replacement = f'''  configuredAudioOutput: "hw:{card},{device}",

  speakText(text) {{
'''

    content = content.replace(
        marker,
        replacement,
        1
    )

# Sustituir aplay por salida seleccionada
content = content.replace(
    'aplay -r 22050 -f S16_LE -t raw',
    f'aplay -D "hw:{card},{device}" -r 22050 -f S16_LE -t raw'
)

with open(out, "w", encoding="utf-8") as f:
    f.write(content)
PY

if [ $? -eq 0 ]; then
    mv "$BASE_DIR/node_helper.js.tmp" "$BASE_DIR/node_helper.js"
    echo -e "${GREEN}[OK] node_helper.js configurado.${NC}"
else
    echo -e "${RED}[ERROR] No se pudo configurar node_helper.js${NC}"
fi

# ==============================================================================
# CONFIG.JS
# ==============================================================================

echo -e "${BLUE}[8/8] Configurando MagicMirror...${NC}"

CONFIG_PATH="$BASE_DIR/../../config/config.js"

if [ ! -f "$CONFIG_PATH" ]; then

    echo -e "${YELLOW}[AVISO] No se encontró config.js:${NC}"
    echo "$CONFIG_PATH"

else

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


    if [ "$ADD_CONFIG" = true ]; then

        BACKUP="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"

        cp "$CONFIG_PATH" "$BACKUP"

        python3 - \
            "$CONFIG_PATH" \
            "$LANGUAGE" \
            "$VOICE" \
            "$MODE_CHOICE" \
            "$AUDIO_INPUT_CARD" \
            "$AUDIO_INPUT_DEVICE" \
            "$AUDIO_OUTPUT_CARD" \
            "$AUDIO_OUTPUT_DEVICE" \
            "$KEYBOARD_PATH" \
            "$KEY_CHOICE" \
            <<'PY'

import sys

config_path = sys.argv[1]
language = sys.argv[2]
voice = sys.argv[3]
mode = sys.argv[4]
input_card = sys.argv[5]
input_device = sys.argv[6]
output_card = sys.argv[7]
output_device = sys.argv[8]
keyboard_path = sys.argv[9]
key_choice = sys.argv[10]


with open(config_path, "r", encoding="utf-8") as f:
    content = f.read()


if "MMM-TuAsistente" in content:

    print(
        "MMM-TuAsistente ya existe en config.js."
    )

    sys.exit(0)


block = f'''
    {{
        module: "MMM-TuAsistente",
        position: "middle_center",

        config: {{
            language: "{language}",

            activationMode: "{mode}",

            voice: "{voice}",

            wakeWordModel: "hey_mycroft",

            wakeWordThreshold: 0.5,

            micDeviceIndex: {input_card},

            micDevice: "hw:{input_card},{input_device}",

            audioOutputCard: {output_card},

            audioOutputDevice: {output_device},

            audioOutput: "hw:{output_card},{output_device}",

            keyboardDevice: "{keyboard_path}",

            pttKey: "{key_choice}",

            model: "qwen2.5:1.5b",

            hideDelay: 18000
        }}
    }},
'''


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


with open(config_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Configuración añadida correctamente.")

PY

    fi

fi

# ==============================================================================
# PERMISOS
# ==============================================================================

chmod +x "$BASE_DIR/install.sh" 2>/dev/null
chmod +x "$BASE_DIR/listen_key.py" 2>/dev/null
chmod +x "$BASE_DIR/transcribe.py" 2>/dev/null

if [ -f "$BASE_DIR/scripts/wakeword_listener.py" ]; then
    chmod +x "$BASE_DIR/scripts/wakeword_listener.py"
fi

deactivate 2>/dev/null || true

# ==============================================================================
# FINAL
# ==============================================================================

echo
echo -e "${GREEN}"
echo "===================================================="
echo "       INSTALACIÓN COMPLETADA"
echo "===================================================="
echo -e "${NC}"

echo
echo "Idioma           : $LANGUAGE"
echo "Voz Piper        : $VOICE"
echo "Activación       : $MODE_CHOICE"
echo "Entrada audio    : $AUDIO_INPUT_NAME"
echo "Salida audio     : $AUDIO_OUTPUT_NAME"

if [ "$MODE_CHOICE" = "ptt" ]; then

    echo "Teclado          : $KEYBOARD_NAME"
    echo "Dispositivo      : $KEYBOARD_PATH"
    echo "Tecla PTT        : $KEY_CHOICE"

else

    echo "Wake Word        : Hey Mycroft"

fi

echo
echo -e "${GREEN}Archivos configurados automáticamente:${NC}"
echo
echo "  transcribe.py"
echo "  listen_key.py"
echo "  node_helper.js"

if [ "$MODE_CHOICE" = "wakeword" ]; then
    echo "  scripts/wakeword_listener.py"
fi

echo "  config.js"
echo

echo -e "${GREEN}Voz instalada:${NC}"
echo "$PIPER_DIR/${VOICE}.onnx"
echo

echo -e "${CYAN}Reinicia MagicMirror:${NC}"
echo
echo "pm2 restart mm"
echo

if [ "$MODE_CHOICE" = "ptt" ]; then

    echo -e "${CYAN}PTT:${NC}"
    echo "Teclado: $KEYBOARD_NAME"
    echo "Tecla: $KEY_CHOICE"
    echo "Mantén pulsada la tecla para hablar."

else

    echo -e "${CYAN}Wake Word:${NC}"
    echo "Di: Hey Mycroft"

fi

echo
echo -e "${GREEN}Listo.${NC}"
echo