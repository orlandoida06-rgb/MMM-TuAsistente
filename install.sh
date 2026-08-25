#!/usr/bin/env bash

# ==============================================================================
# MMM-TuAsistente - INSTALADOR COMPLETO
# Ubuntu 24.04 / Raspberry Pi / Orange Pi / ARM64 / x86_64
# ==============================================================================

set -u
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TITLE="MMM-TuAsistente - Instalación"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}          MMM-TuAsistente - INSTALADOR${NC}"
echo -e "${GREEN}====================================================${NC}"
echo

if [ ! -f "$BASE_DIR/node_helper.js" ]; then
    echo -e "${RED}[ERROR] No se encontró node_helper.js${NC}"
    echo
    echo "Ejecuta:"
    echo "cd ~/MagicMirror/modules/MMM-TuAsistente"
    echo "./install.sh"
    exit 1
fi

echo -e "${GREEN}[OK] Módulo encontrado:${NC}"
echo "$BASE_DIR"
echo

# ==============================================================================
# INTERFAZ
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
# INTERFAZ
# ==============================================================================

if [ "$USE_GUI" = true ]; then

    if ! command -v zenity >/dev/null 2>&1; then
        echo "[INFO] Instalando zenity..."
        sudo apt-get update -qq
        sudo apt-get install -y zenity
    fi

else

    if ! command -v whiptail >/dev/null 2>&1; then
        echo "[INFO] Instalando whiptail..."
        sudo apt-get update -qq
        sudo apt-get install -y whiptail
    fi

fi

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

abort_install()
{
    echo
    echo -e "${RED}[ERROR] Instalación cancelada.${NC}"
    deactivate 2>/dev/null || true
    exit 1
}

# ==============================================================================
# CONFIRMACIÓN
# ==============================================================================

if [ "$USE_GUI" = true ]; then

    zenity --question \
        --title="$TITLE" \
        --text="¿Quieres instalar MMM-TuAsistente?" \
        --width=500 \
        2>/dev/null

    if [ $? -ne 0 ]; then
        exit 0
    fi

else

    if ! whiptail \
        --title="$TITLE" \
        --yesno \
        "¿Quieres instalar MMM-TuAsistente?" \
        10 60
    then
        exit 0
    fi

fi

# ==============================================================================
# IDIOMA
# ==============================================================================

select_language()
{
    LANGUAGE="es"

    if [ "$USE_GUI" = true ]; then

        LANGUAGE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el idioma:" \
            --column="ID" \
            --column="Idioma" \
            "es" "Español" \
            "en" "English" \
            "fr" "Français" \
            "de" "Deutsch" \
            "it" "Italiano" \
            --hide-column=1 \
            --width=500 \
            --height=350 \
            2>/dev/null)

    else

        LANGUAGE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el idioma:" \
            16 70 5 \
            "es" "Español" \
            "en" "English" \
            "fr" "Français" \
            "de" "Deutsch" \
            "it" "Italiano" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${LANGUAGE:-}" ] || exit 1
}

# ==============================================================================
# VOZ
# ==============================================================================

select_voice()
{
    VOICE=""

    case "$LANGUAGE" in

        es)

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Selecciona la voz Piper:" \
                    --column="ID" \
                    --column="Voz" \
                    "es_ES-davefx-medium" "DaveFX - Español" \
                    "es_ES-sharvard-medium" "Sharvard - Español" \
                    --hide-column=1 \
                    --width=600 \
                    --height=300 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu \
                    "Selecciona la voz Piper:" \
                    15 75 2 \
                    "es_ES-davefx-medium" "DaveFX - Español" \
                    "es_ES-sharvard-medium" "Sharvard - Español" \
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

        *)
            echo -e "${RED}[ERROR] Idioma no soportado: $LANGUAGE${NC}"
            exit 1
            ;;

    esac

    if [ -z "${VOICE:-}" ]; then
        echo -e "${RED}[ERROR] No se seleccionó ninguna voz.${NC}"
        exit 1
    fi

    export VOICE

    echo -e "${GREEN}[OK] Voz seleccionada: $VOICE${NC}"
}

# ==============================================================================
# MODO
# ==============================================================================

select_mode()
{
    MODE_CHOICE=""

    if [ "$USE_GUI" = true ]; then

        MODE_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el modo de activación:" \
            --column="ID" \
            --column="Modo" \
            --column="Descripción" \
            "ptt" "PTT" "Pulsar una tecla" \
            "wakeword" "Wake Word" "Hey Mycroft" \
            --hide-column=1 \
            --width=700 \
            --height=300 \
            2>/dev/null)

    else

        MODE_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el modo de activación:" \
            15 75 2 \
            "ptt" "PTT - Pulsar una tecla" \
            "wakeword" "Wake Word - Hey Mycroft" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${MODE_CHOICE:-}" ] || exit 1
}

# ==============================================================================
# TECLADO
# ==============================================================================

detect_keyboards()
{
    KEYBOARD_PATHS=()
    KEYBOARD_NAMES=()

    if [ ! -d /dev/input/by-id ]; then
        return
    fi

    while IFS= read -r link; do

        [ -L "$link" ] || continue
        [ -e "$link" ] || continue

        target="$(readlink -f "$link")"

        name="$(udevadm info \
            --query=property \
            --name="$target" 2>/dev/null |
            sed -n 's/^ID_MODEL_FROM_DATABASE=//p' |
            head -n1)"

        if [ -z "$name" ]; then
            name="$(basename "$link")"
            name="${name%-event-kbd}"
            name="${name#usb-}"
            name="$(echo "$name" | tr '_' ' ')"
        fi

        KEYBOARD_PATHS+=("$link")
        KEYBOARD_NAMES+=("$name")

    done < <(
        find /dev/input/by-id \
            -maxdepth 1 \
            -type l \
            -name '*-event-kbd' \
            2>/dev/null |
        sort
    )
}

select_keyboard()
{
    detect_keyboards

    COUNT=${#KEYBOARD_PATHS[@]}

    if [ "$COUNT" -eq 0 ]; then

        echo
        echo -e "${RED}[ERROR] No se encontró ningún teclado físico.${NC}"
        echo
        echo "Comprueba:"
        echo
        ls -l /dev/input/by-id/ 2>/dev/null || true
        echo
        exit 1

    fi

    if [ "$COUNT" -eq 1 ]; then

        KEYBOARD_PATH="${KEYBOARD_PATHS[0]}"
        KEYBOARD_NAME="${KEYBOARD_NAMES[0]}"

        echo -e "${GREEN}[OK] Teclado detectado:${NC}"
        echo "$KEYBOARD_NAME"
        echo "$KEYBOARD_PATH"
        echo

        return
    fi

    MENU_ARGS=()

    for ((i=0; i<COUNT; i++)); do
        MENU_ARGS+=(
            "$((i+1))"
            "${KEYBOARD_NAMES[$i]}"
        )
    done

    if [ "$USE_GUI" = true ]; then

        KEYBOARD_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el teclado:" \
            --column="ID" \
            --column="Teclado" \
            "${MENU_ARGS[@]}" \
            --hide-column=1 \
            --width=700 \
            --height=400 \
            2>/dev/null)

    else

        KEYBOARD_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el teclado:" \
            18 80 "$COUNT" \
            "${MENU_ARGS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${KEYBOARD_CHOICE:-}" ] || exit 1

    INDEX=$((KEYBOARD_CHOICE - 1))

    KEYBOARD_PATH="${KEYBOARD_PATHS[$INDEX]}"
    KEYBOARD_NAME="${KEYBOARD_NAMES[$INDEX]}"
}

# ==============================================================================
# TECLA PTT
# ==============================================================================

select_ptt_key()
{
    KEY_CODES=(
        KEY_SPACE
        KEY_ENTER
        KEY_F1
        KEY_F2
        KEY_F3
        KEY_F4
        KEY_F5
        KEY_F6
        KEY_F7
        KEY_F8
        KEY_F9
        KEY_F10
        KEY_F11
        KEY_F12
        KEY_ESC
        KEY_TAB
    )

    KEY_NAMES=(
        "SPACE"
        "ENTER"
        "F1"
        "F2"
        "F3"
        "F4"
        "F5"
        "F6"
        "F7"
        "F8"
        "F9"
        "F10"
        "F11"
        "F12"
        "ESC"
        "TAB"
    )

    MENU_ARGS=()

    for ((i=0; i<${#KEY_CODES[@]}; i++)); do
        MENU_ARGS+=(
            "${KEY_CODES[$i]}"
            "${KEY_NAMES[$i]}"
        )
    done

    if [ "$USE_GUI" = true ]; then

        PTT_KEY=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona la tecla PTT:" \
            --column="Código" \
            --column="Tecla" \
            "${MENU_ARGS[@]}" \
            --width=500 \
            --height=500 \
            2>/dev/null)

    else

        PTT_KEY=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona la tecla PTT:" \
            20 65 10 \
            "${MENU_ARGS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${PTT_KEY:-}" ] || exit 1
}

# ==============================================================================
# AUDIO
# ==============================================================================

select_audio_devices()
{
    MIC_INDEX="null"
    MIC_NAME="Sistema"
    OUTPUT_DEVICE="default"
    OUTPUT_NAME="Sistema"

    echo
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${CYAN} CONFIGURACIÓN DE AUDIO${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo

    # --------------------------------------------------------------------------
    # MICRÓFONOS
    # --------------------------------------------------------------------------

    mapfile -t CAPTURE_LINES < <(
        arecord -l 2>/dev/null |
        sed -nE 's/^card ([0-9]+): .*device ([0-9]+):.*/\1|\2/p'
    )

    if [ "${#CAPTURE_LINES[@]}" -eq 0 ]; then

        echo -e "${YELLOW}[AVISO] No se detectaron micrófonos ALSA.${NC}"

    else

        MENU_ARGS=()

        for line in "${CAPTURE_LINES[@]}"; do

            IFS='|' read -r card device <<< "$line"

            description="$(arecord -l 2>/dev/null |
                grep "^card $card:" |
                grep "device $device:" |
                head -n1 |
                sed -E 's/^card [0-9]+: (.*)$/\1/')"

            [ -n "$description" ] || description="ALSA hw:${card},${device}"

            MENU_ARGS+=(
                "${card},${device}"
                "$description"
            )

        done

        if [ "$USE_GUI" = true ]; then

            MIC_CHOICE=$(zenity --list \
                --title="$TITLE" \
                --text="Selecciona entrada de audio:" \
                --column="ID" \
                --column="Micrófono" \
                "${MENU_ARGS[@]}" \
                --hide-column=1 \
                --width=800 \
                --height=400 \
                2>/dev/null)

        else

            MIC_CHOICE=$(whiptail \
                --title="$TITLE" \
                --menu \
                "Selecciona entrada de audio:" \
                20 90 8 \
                "${MENU_ARGS[@]}" \
                3>&1 1>&2 2>&3)

        fi

        [ -n "${MIC_CHOICE:-}" ] || exit 1

        MIC_CARD="${MIC_CHOICE%,*}"
        MIC_DEVICE="${MIC_CHOICE#*,}"

        MIC_NAME="ALSA hw:${MIC_CARD},${MIC_DEVICE}"

        # ----------------------------------------------------------------------
        # Encontrar índice sounddevice
        # ----------------------------------------------------------------------

        MIC_INDEX="$(
            "$BASE_DIR/venv/bin/python" - "$MIC_CARD" "$MIC_DEVICE" <<'PY'
import sys

card = sys.argv[1]
dev = sys.argv[2]

try:
    import sounddevice as sd

    devices = sd.query_devices()

    wanted = [
        f"hw:{card},{dev}",
        f"plughw:{card},{dev}",
    ]

    for index, info in enumerate(devices):

        name = str(info.get("name", ""))

        if int(info.get("max_input_channels", 0)) <= 0:
            continue

        if any(x in name for x in wanted):
            print(index)
            sys.exit(0)

    # Segundo intento: buscar por card/device
    for index, info in enumerate(devices):

        name = str(info.get("name", ""))

        if int(info.get("max_input_channels", 0)) <= 0:
            continue

        if f"{card},{dev}" in name:
            print(index)
            sys.exit(0)

    print("null")

except Exception as e:
    print("null")
PY
)"

        [ -n "$MIC_INDEX" ] || MIC_INDEX="null"

    fi

    # --------------------------------------------------------------------------
    # SALIDAS
    # --------------------------------------------------------------------------

    mapfile -t PLAYBACK_LINES < <(
        aplay -l 2>/dev/null |
        sed -nE 's/^card ([0-9]+): .*device ([0-9]+):.*/\1|\2/p'
    )

    if [ "${#PLAYBACK_LINES[@]}" -eq 0 ]; then

        echo -e "${YELLOW}[AVISO] No se detectaron salidas ALSA.${NC}"

    else

        MENU_ARGS=()

        for line in "${PLAYBACK_LINES[@]}"; do

            IFS='|' read -r card device <<< "$line"

            description="$(aplay -l 2>/dev/null |
                grep "^card $card:" |
                grep "device $device:" |
                head -n1 |
                sed -E 's/^card [0-9]+: (.*)$/\1/')"

            [ -n "$description" ] || description="ALSA hw:${card},${device}"

            MENU_ARGS+=(
                "${card},${device}"
                "$description"
            )

        done

        if [ "$USE_GUI" = true ]; then

            OUTPUT_CHOICE=$(zenity --list \
                --title="$TITLE" \
                --text="Selecciona salida de audio:" \
                --column="ID" \
                --column="Salida" \
                "${MENU_ARGS[@]}" \
                --hide-column=1 \
                --width=800 \
                --height=400 \
                2>/dev/null)

        else

            OUTPUT_CHOICE=$(whiptail \
                --title="$TITLE" \
                --menu \
                "Selecciona salida de audio:" \
                20 90 8 \
                "${MENU_ARGS[@]}" \
                3>&1 1>&2 2>&3)

        fi

        [ -n "${OUTPUT_CHOICE:-}" ] || exit 1

        OUTPUT_CARD="${OUTPUT_CHOICE%,*}"
        OUTPUT_DEVICE_NUM="${OUTPUT_CHOICE#*,}"

        OUTPUT_DEVICE="plughw:${OUTPUT_CARD},${OUTPUT_DEVICE_NUM}"
        OUTPUT_NAME="ALSA hw:${OUTPUT_CARD},${OUTPUT_DEVICE_NUM}"

    fi
}

# ==============================================================================
# SELECCIONES
# ==============================================================================

select_language
select_voice
select_mode

if [ "$MODE_CHOICE" = "ptt" ]; then
    select_keyboard
    select_ptt_key
else
    KEYBOARD_PATH="null"
    KEYBOARD_NAME="No utilizado"
    PTT_KEY="KEY_SPACE"
fi

# ==============================================================================
# DEPENDENCIAS
# ==============================================================================

echo
echo -e "${BLUE}[1/8] Instalando dependencias del sistema...${NC}"

if ! sudo apt-get update; then
    abort_install
fi

if ! sudo apt-get install -y \
    python3-full \
    python3-venv \
    python3-pip \
    python3-dev \
    portaudio19-dev \
    libasound2-dev \
    ffmpeg \
    git \
    wget \
    curl \
    unzip \
    build-essential \
    libsndfile1 \
    alsa-utils \
    udev
then
    abort_install
fi

echo -e "${GREEN}[OK] Dependencias del sistema.${NC}"

# ==============================================================================
# NODE
# ==============================================================================

echo
echo -e "${BLUE}[2/8] Comprobando Node.js y npm...${NC}"

if ! command -v node >/dev/null 2>&1; then

    echo -e "${YELLOW}[INFO] Node.js no está instalado.${NC}"

    if ! curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -; then
        abort_install
    fi

    if ! sudo apt-get install -y nodejs; then
        abort_install
    fi

fi

if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Node.js no disponible.${NC}"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] npm no disponible.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Node: $(node --version)${NC}"
echo -e "${GREEN}[OK] npm : $(npm --version)${NC}"

# ==============================================================================
# NODE DEPENDENCIES
# ==============================================================================

echo
echo -e "${BLUE}[3/8] Instalando dependencias Node...${NC}"

if ! npm install axios; then
    echo -e "${RED}[ERROR] npm install axios falló.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Axios instalado.${NC}"

# ==============================================================================
# VENV
# ==============================================================================

echo
echo -e "${BLUE}[4/8] Creando entorno Python...${NC}"

if [ ! -d "$BASE_DIR/venv" ]; then

    if ! python3 -m venv "$BASE_DIR/venv"; then
        abort_install
    fi

fi

source "$BASE_DIR/venv/bin/activate"

python -m pip install --upgrade pip setuptools wheel -q

echo -e "${GREEN}[OK] Entorno Python preparado.${NC}"

# ==============================================================================
# PYTHON
# ==============================================================================

echo
echo -e "${BLUE}[5/8] Instalando librerías Python...${NC}"

if ! python -m pip install \
    numpy \
    requests \
    ollama \
    sounddevice \
    faster-whisper \
    evdev \
    scipy \
    -q
then
    abort_install
fi

echo -e "${GREEN}[OK] Librerías Python instaladas.${NC}"

# ==============================================================================
# OPENWAKEWORD
# ==============================================================================

echo
echo -e "${BLUE}[6/8] Configuración de activación...${NC}"

if [ "$MODE_CHOICE" = "wakeword" ]; then

    echo "[INFO] Instalando OpenWakeWord..."

    if ! python -m pip install \
        openwakeword \
        pyaudio \
        tflite-runtime \
        -q
    then
        echo -e "${RED}[ERROR] OpenWakeWord no se pudo instalar.${NC}"
        deactivate 2>/dev/null || true
        exit 1
    fi

    echo -e "${GREEN}[OK] OpenWakeWord instalado.${NC}"

else

    echo -e "${GREEN}[OK] PTT seleccionado.${NC}"

fi

# ==============================================================================
# PIPER
# ==============================================================================

echo
echo -e "${BLUE}[7/8] Preparando Piper TTS...${NC}"

# Seguridad: comprobar VOICE antes de usarla
if [ -z "${VOICE:-}" ]; then
    echo -e "${RED}[ERROR] VOICE está vacía.${NC}"
    echo "LANGUAGE=$LANGUAGE"
    exit 1
fi

echo -e "${CYAN}[INFO] Voz seleccionada: $VOICE${NC}"

PIPER_DIR="$BASE_DIR/piper_tts"

mkdir -p "$PIPER_DIR"

if [ ! -x "$PIPER_DIR/piper/piper" ]; then

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

    TEMP_PIPER="/tmp/piper_mmm_tuasistente.tar.gz"

    echo "[INFO] Descargando Piper..."

    if ! wget -q --show-progress "$PIPER_URL" -O "$TEMP_PIPER"; then
        echo -e "${RED}[ERROR] No se pudo descargar Piper.${NC}"
        deactivate
        exit 1
    fi

    rm -rf "$PIPER_DIR/piper"
    mkdir -p "$PIPER_DIR/piper"

    if ! tar -xzf "$TEMP_PIPER" \
        -C "$PIPER_DIR/piper" \
        --strip-components=1
    then
        echo -e "${RED}[ERROR] No se pudo extraer Piper.${NC}"
        rm -f "$TEMP_PIPER"
        deactivate
        exit 1
    fi

    rm -f "$TEMP_PIPER"

fi

chmod +x "$PIPER_DIR/piper/piper" 2>/dev/null || true

# ==============================================================================
# MODELO PIPER
# ==============================================================================

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
        echo -e "${RED}[ERROR] Voz no soportada: '$VOICE'${NC}"
        deactivate
        exit 1
        ;;

esac

VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx"
VOICE_JSON_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx.json"

if [ ! -s "$PIPER_DIR/${VOICE}.onnx" ]; then

    echo "[INFO] Descargando modelo $VOICE..."

    if ! wget -q --show-progress \
        "$VOICE_URL" \
        -O "$PIPER_DIR/${VOICE}.onnx"
    then
        echo -e "${RED}[ERROR] No se pudo descargar el modelo Piper.${NC}"
        deactivate
        exit 1
    fi

fi

if [ ! -s "$PIPER_DIR/${VOICE}.onnx.json" ]; then

    echo "[INFO] Descargando configuración de voz..."

    if ! wget -q --show-progress \
        "$VOICE_JSON_URL" \
        -O "$PIPER_DIR/${VOICE}.onnx.json"
    then
        echo -e "${RED}[ERROR] No se pudo descargar la configuración Piper.${NC}"
        deactivate
        exit 1
    fi

fi

echo -e "${GREEN}[OK] Voz Piper preparada: $VOICE${NC}"

# ==============================================================================
# AHORA SELECCIONAMOS AUDIO
# IMPORTANTE: SE HACE DESPUÉS DE CREAR EL VENV
# ==============================================================================

select_audio_devices

# ==============================================================================
# CONFIGURAR LISTEN_KEY.PY
# ==============================================================================

echo
echo -e "${BLUE}[8/8] Configurando archivos del asistente...${NC}"

if [ "$MODE_CHOICE" = "ptt" ] && [ -f "$BASE_DIR/listen_key.py" ]; then

    cp "$BASE_DIR/listen_key.py" \
       "$BASE_DIR/listen_key.py.backup.$(date +%Y%m%d_%H%M%S)" \
       2>/dev/null || true

    "$BASE_DIR/venv/bin/python" - \
        "$BASE_DIR/listen_key.py" \
        "$KEYBOARD_PATH" \
        "$PTT_KEY" <<'PY'

import sys
import re

path = sys.argv[1]
keyboard = sys.argv[2]
key = sys.argv[3]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

replacement = f'''
def find_keyboard():
    configured = {keyboard!r}

    if configured != "null":
        import os
        if os.path.exists(configured):
            return configured

    try:
        for device_path in evdev.list_devices():
            try:
                dev = evdev.InputDevice(device_path)
                if "keyboard" in dev.name.lower():
                    return dev.path
            except Exception:
                continue
    except Exception:
        pass

    return None

'''

pattern = r"def find_keyboard\(\):.*?(?=\n(?:def |if __name__|KEYBOARD_PATH))"

new_content, count = re.sub(
    pattern,
    replacement,
    content,
    count=1,
    flags=re.S
)

if count:
    content = new_content

content = re.sub(
    r"ecodes\.KEY_[A-Z0-9_]+",
    f"ecodes.{key}",
    content,
    count=1
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("[OK] listen_key.py configurado")

PY

fi

# ==============================================================================
# CONFIGURAR TRANSCRIBE.PY
# ==============================================================================

if [ -f "$BASE_DIR/transcribe.py" ]; then

    cp "$BASE_DIR/transcribe.py" \
       "$BASE_DIR/transcribe.py.backup.$(date +%Y%m%d_%H%M%S)" \
       2>/dev/null || true

    "$BASE_DIR/venv/bin/python" - \
        "$BASE_DIR/transcribe.py" \
        "$MIC_INDEX" \
        "$MIC_CARD" \
        "$MIC_DEVICE" <<'PY'

import sys
import re

path = sys.argv[1]
device = sys.argv[2]
card = sys.argv[3]
dev = sys.argv[4]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Preferir índice sounddevice si existe.
# Si no existe, usar None y permitir que ALSA use el dispositivo por defecto.

if device == "null":
    replacement = "DEVICE_INDEX = None"
else:
    replacement = f"DEVICE_INDEX = {device}"

content = re.sub(
    r"DEVICE_INDEX\s*=\s*.*",
    replacement,
    content,
    count=1
)

# Añadir información ALSA sin romper el archivo
if "ALSA_DEVICE =" not in content:
    content = content.replace(
        "DEVICE_INDEX =",
        f'ALSA_DEVICE = "hw:{card},{dev}"\nDEVICE_INDEX =',
        1
    )

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(
    f"[OK] transcribe.py configurado: "
    f"DEVICE_INDEX={device}, ALSA=hw:{card},{dev}"
)

PY

fi

# ==============================================================================
# CONFIGURACIÓN WAKEWORD
# ==============================================================================

if [ "$MODE_CHOICE" = "wakeword" ]; then

    if [ -f "$BASE_DIR/scripts/wakeword_listener.py" ]; then

        cp "$BASE_DIR/scripts/wakeword_listener.py" \
           "$BASE_DIR/scripts/wakeword_listener.py.backup.$(date +%Y%m%d_%H%M%S)" \
           2>/dev/null || true

    fi

fi

# ==============================================================================
# CONFIG.JS
# ==============================================================================

CONFIG_PATH="$BASE_DIR/../../config/config.js"

echo
echo -e "${CYAN}Configurando MagicMirror...${NC}"

if [ -f "$CONFIG_PATH" ]; then

    ADD_CONFIG=false

    if [ "$USE_GUI" = true ]; then

        zenity --question \
            --title="$TITLE" \
            --text="¿Añadir MMM-TuAsistente automáticamente a config.js?" \
            --width=550 \
            2>/dev/null

        [ $? -eq 0 ] && ADD_CONFIG=true

    else

        if whiptail \
            --title="$TITLE" \
            --yesno \
            "¿Añadir MMM-TuAsistente automáticamente a config.js?" \
            10 70
        then
            ADD_CONFIG=true
        fi

    fi

    if [ "$ADD_CONFIG" = true ]; then

        if grep -q 'module: "MMM-TuAsistente"' "$CONFIG_PATH"; then

            echo -e "${YELLOW}[AVISO] MMM-TuAsistente ya está en config.js.${NC}"

        else

            BACKUP="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$CONFIG_PATH" "$BACKUP"

            TEMP_CONFIG="/tmp/config_mmm_tuasistente.js"

            "$BASE_DIR/venv/bin/python" \
                "$CONFIG_PATH" \
                "$TEMP_CONFIG" \
                "$LANGUAGE" \
                "$VOICE" \
                "$MODE_CHOICE" \
                "$MIC_INDEX" \
                "$KEYBOARD_PATH" \
                "$PTT_KEY" \
                "$OUTPUT_DEVICE" <<'PY'

import sys

config_path = sys.argv[1]
output_path = sys.argv[2]
language = sys.argv[3]
voice = sys.argv[4]
mode = sys.argv[5]
mic = sys.argv[6]
keyboard = sys.argv[7]
ptt_key = sys.argv[8]
output = sys.argv[9]

with open(config_path, "r", encoding="utf-8") as f:
    content = f.read()

if mic == "null":
    mic_js = "null"
else:
    mic_js = mic

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

            micDeviceIndex: {mic_js},

            keyboardDevice: "{keyboard}",

            pttKey: "{ptt_key}",

            audioOutput: "{output}",

            model: "qwen2.5:1.5b",

            hideDelay: 18000,

            autoHideTimeout: 30000

        }}
    }},
'''

marker = "modules: ["

if marker not in content:
    print("[ERROR] No se encontró modules: [")
    sys.exit(1)

content = content.replace(
    marker,
    marker + "\n" + block,
    1
)

with open(output_path, "w", encoding="utf-8") as f:
    f.write(content)

print("[OK] Configuración generada")

PY

            if [ -f "$TEMP_CONFIG" ] &&
               grep -q 'MMM-TuAsistente' "$TEMP_CONFIG"
            then

                mv "$TEMP_CONFIG" "$CONFIG_PATH"

                echo -e "${GREEN}[OK] config.js configurado.${NC}"

            else

                echo -e "${RED}[ERROR] No se pudo modificar config.js.${NC}"

            fi

        fi

    fi

else

    echo -e "${YELLOW}[AVISO] No se encontró config.js:${NC}"
    echo "$CONFIG_PATH"

fi

# ==============================================================================
# PERMISOS
# ==============================================================================

chmod +x "$BASE_DIR/install.sh" 2>/dev/null || true
chmod +x "$BASE_DIR/listen_key.py" 2>/dev/null || true
chmod +x "$BASE_DIR/transcribe.py" 2>/dev/null || true

if [ -d "$BASE_DIR/scripts" ]; then
    chmod +x "$BASE_DIR/scripts/"*.py 2>/dev/null || true
fi

deactivate 2>/dev/null || true

# ==============================================================================
# COMPROBACIONES
# ==============================================================================

echo
echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN} COMPROBACIONES${NC}"
echo -e "${CYAN}====================================================${NC}"

if node --check "$BASE_DIR/node_helper.js"; then
    echo -e "${GREEN}[OK] node_helper.js${NC}"
else
    echo -e "${RED}[ERROR] node_helper.js${NC}"
fi

if [ -f "$BASE_DIR/listen_key.py" ]; then

    if "$BASE_DIR/venv/bin/python" -m py_compile \
        "$BASE_DIR/listen_key.py" 2>/dev/null
    then
        echo -e "${GREEN}[OK] listen_key.py${NC}"
    else
        echo -e "${RED}[ERROR] listen_key.py${NC}"
    fi

fi

if [ -f "$BASE_DIR/transcribe.py" ]; then

    if "$BASE_DIR/venv/bin/python" -m py_compile \
        "$BASE_DIR/transcribe.py" 2>/dev/null
    then
        echo -e "${GREEN}[OK] transcribe.py${NC}"
    else
        echo -e "${RED}[ERROR] transcribe.py${NC}"
    fi

fi

if [ -x "$PIPER_DIR/piper/piper" ]; then
    echo -e "${GREEN}[OK] Piper${NC}"
else
    echo -e "${RED}[ERROR] Piper${NC}"
fi

if [ "$MODE_CHOICE" = "ptt" ]; then

    if [ -e "$KEYBOARD_PATH" ]; then
        echo -e "${GREEN}[OK] Teclado PTT${NC}"
        echo "     $KEYBOARD_PATH"
    else
        echo -e "${RED}[ERROR] Teclado PTT${NC}"
    fi

fi

# ==============================================================================
# RESUMEN
# ==============================================================================

echo
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}       INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}====================================================${NC}"
echo

echo "Idioma        : $LANGUAGE"
echo "Voz Piper     : $VOICE"
echo "Activación    : $MODE_CHOICE"

if [ "$MODE_CHOICE" = "ptt" ]; then
    echo "Teclado       : $KEYBOARD_NAME"
    echo "Dispositivo   : $KEYBOARD_PATH"
    echo "Tecla PTT     : $PTT_KEY"
fi

echo "Entrada audio : $MIC_NAME"
echo "Mic índice    : $MIC_INDEX"
echo "Salida audio  : $OUTPUT_NAME"
echo "Salida ALSA   : $OUTPUT_DEVICE"

echo

if [ "$MODE_CHOICE" = "ptt" ]; then
    echo -e "${CYAN}PTT:${NC}"
    echo "Pulsa $PTT_KEY para hablar."
else
    echo -e "${CYAN}Wake Word:${NC}"
    echo "Di: Hey Mycroft"
fi

echo
echo -e "${GREEN}Reinicia MagicMirror con:${NC}"
echo
echo "pm2 restart mm"
echo