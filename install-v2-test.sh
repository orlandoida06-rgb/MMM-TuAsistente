#!/usr/bin/env bash

# ==============================================================================
# MMM-TuAsistente - INSTALADOR V2
# Instalador gráfico completo con Zenity
#
# Compatible:
#   Ubuntu 24.04
#   Raspberry Pi
#   Orange Pi
#   ARM64 / ARMv7 / x86_64
#
# Mantiene:
#   - PTT
#   - Wake Word
#   - Selección de teclado
#   - Selección de tecla PTT
#   - Selección de micrófono
#   - Selección de salida de audio
#   - Piper TTS
#   - Whisper / faster-whisper
#   - Ollama
#   - Configuración automática de config.js
#
# Añade:
#   - Instalador completamente gráfico
#   - Configuración Spotify
#   - Credenciales Spotify protegidas
#   - Barra de progreso
#   - Resumen final
#   - Comprobaciones
#   - Modo TUI de emergencia
# ==============================================================================

set -u
set -o pipefail

# ==============================================================================
# COLORES TERMINAL
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# VARIABLES
# ==============================================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="$BASE_DIR/../../config/config.js"

TITLE="MMM-TuAsistente"
SIMULATION=false

LANGUAGE="es"
VOICE=""
MODE_CHOICE=""

KEYBOARD_PATH="null"
KEYBOARD_NAME="No utilizado"
PTT_KEY="KEY_SPACE"

MIC_INDEX="null"
MIC_CARD="null"
MIC_DEVICE="null"
MIC_NAME="Sistema"

OUTPUT_DEVICE="default"
OLLAMA_ENABLED="false"
OLLAMA_MODEL="qwen2.5:1.5b"
OUTPUT_NAME="Sistema"

SPOTIFY_ENABLED="false"
SPOTIFY_CLIENT_ID=""
SPOTIFY_CLIENT_SECRET=""
SPOTIFY_REDIRECT_URI=""

USE_GUI=false

# ==============================================================================
# DETECCIÓN DE INTERFAZ
# ==============================================================================
# SSH / PuTTY siempre utiliza modo terminal.
# El modo gráfico solo se activa desde una sesión local con DISPLAY o Wayland.

if [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CONNECTION:-}" ]; then
    USE_GUI=false
elif [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    USE_GUI=true
else
    USE_GUI=false
fi

install_zenity()
{
    if command -v zenity >/dev/null 2>&1; then
        return 0
    fi

    echo
    echo "[INFO] Instalando Zenity..."

    if ! sudo apt-get update -qq; then
        return 1
    fi

    if ! sudo apt-get install -y zenity; then
        return 1
    fi

    command -v zenity >/dev/null 2>&1
}

if [ "$USE_GUI" = true ]; then

    if ! install_zenity; then

        echo
        echo -e "${YELLOW}[AVISO] No se pudo instalar Zenity.${NC}"
        echo
        echo "Continuando en modo texto..."
        echo

        USE_GUI=false

    fi

fi

# ==============================================================================
# WHIPTAIL
# ==============================================================================

if [ "$USE_GUI" = false ]; then

    if ! command -v whiptail >/dev/null 2>&1; then

        echo "[INFO] Instalando whiptail..."

        sudo apt-get update -qq &&
        sudo apt-get install -y whiptail

        if ! command -v whiptail >/dev/null 2>&1; then
            echo -e "${RED}[ERROR] No se pudo instalar whiptail.${NC}"
            exit 1
        fi

    fi

fi

# ==============================================================================
# FUNCIONES GRÁFICAS
# ==============================================================================

gui_error()
{
    zenity --error \
        --title="$TITLE" \
        --text="$1" \
        --width=600 \
        2>/dev/null || true
}

gui_info()
{
    zenity --info \
        --title="$TITLE" \
        --text="$1" \
        --width=650 \
        2>/dev/null || true
}

gui_question()
{
    zenity --question \
        --title="$TITLE" \
        --text="$1" \
        --width=650 \
        2>/dev/null
}

# ==============================================================================
# ABORTAR
# ==============================================================================

abort_install()
{
    if [ "$USE_GUI" = true ]; then
        gui_error "La instalación ha sido cancelada o se ha producido un error."
    else
        echo
        echo -e "${RED}[ERROR] Instalación cancelada.${NC}"
    fi

    deactivate 2>/dev/null || true
    exit 1
}

# ==============================================================================
# PROGRESO
# ==============================================================================

PROGRESS_PID=""
PROGRESS_FIFO=""

progress_start()
{
    if [ "$USE_GUI" = true ]; then

        PROGRESS_FIFO="/tmp/mmm-tu-asistente-progress-$$"

        rm -f "$PROGRESS_FIFO"
        mkfifo "$PROGRESS_FIFO"

        zenity --progress \
            --title="$TITLE" \
            --text="Preparando instalación..." \
            --percentage=0 \
            --auto-close \
            --width=650 \
            < "$PROGRESS_FIFO" \
            >/dev/null 2>&1 &

        PROGRESS_PID=$!

        exec 9>"$PROGRESS_FIFO"

        echo "0" >&9
        echo "# Preparando instalación..." >&9
    fi
}

progress_update()
{
    local percent="$1"
    local text="$2"

    if [ "$USE_GUI" = true ]; then

        if [ -n "${PROGRESS_PID:-}" ] &&
           kill -0 "$PROGRESS_PID" 2>/dev/null; then

            echo "$percent" >&9
            echo "# $text" >&9
        fi

    else

        echo
        echo -e "${BLUE}[$percent%] $text${NC}"
    fi
}

progress_close()
{
    if [ "$USE_GUI" = true ]; then

        if [ -n "${PROGRESS_PID:-}" ] &&
           kill -0 "$PROGRESS_PID" 2>/dev/null; then

            echo "100" >&9
            echo "# Instalación completada." >&9

            sleep 1

            exec 9>&-

            wait "$PROGRESS_PID" 2>/dev/null || true
        fi

        rm -f "${PROGRESS_FIFO:-}"

        PROGRESS_PID=""
        PROGRESS_FIFO=""
    fi
}

# CONFIRMACIÓN INICIAL
# ==============================================================================

if [ "$USE_GUI" = true ]; then

    if ! gui_question \
        "Bienvenido al instalador de MMM-TuAsistente.

Vamos a configurar:
• Idioma
• Activación
• Teclado y tecla PTT (si corresponde)
• Audio de entrada y salida
• Voz Piper
• Spotify
• Ollama
• Modelo de IA
• Descarga del modelo de IA
• MagicMirror

¿Quieres continuar?"
    then
        exit 0
    fi

else

    if ! whiptail \
        --title="$TITLE" \
        --yesno \
        "Bienvenido al instalador de MMM-TuAsistente.

Vamos a configurar:
- Idioma
- Activación
- Teclado y tecla PTT (si corresponde)
- Audio de entrada y salida
- Voz Piper
- Spotify
- Ollama
- Modelo de IA
- Descarga del modelo de IA
- MagicMirror

¿Quieres continuar?" \
        20 75
    then
        exit 0
    fi

fi

# ==============================================================================
# IDIOMA
# ==============================================================================

select_language()
{
    if [ "$USE_GUI" = true ]; then

        LANGUAGE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el idioma del asistente:" \
            --radiolist \
            --column="" \
            --column="ID" \
            --column="Idioma" \
            TRUE  "es" "Español" \
            FALSE "en" "English" \
            FALSE "fr" "Français" \
            FALSE "de" "Deutsch" \
            FALSE "it" "Italiano" \
            --hide-column=2 \
            --width=600 \
            --height=400 \
            2>/dev/null)

    else

        LANGUAGE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el idioma:" \
            18 70 5 \
            "es" "Español" \
            "en" "English" \
            "fr" "Français" \
            "de" "Deutsch" \
            "it" "Italiano" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${LANGUAGE:-}" ] || abort_install
}

# ==============================================================================
# VOZ PIPER
# ==============================================================================

select_voice()
{
    case "$LANGUAGE" in

        es)

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Selecciona la voz Piper:" \
                    --radiolist \
                    --column="" \
                    --column="ID" \
                    --column="Voz" \
                    TRUE  "es_ES-davefx-medium" "DaveFX - Español" \
                    FALSE "es_ES-sharvard-medium" "Sharvard - Español" \
                    --hide-column=2 \
                    --width=650 \
                    --height=350 \
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
            abort_install
            ;;

    esac

    [ -n "${VOICE:-}" ] || abort_install
}

# ==============================================================================
# MODO ACTIVACIÓN
# ==============================================================================

select_mode()
{
    if [ "$USE_GUI" = true ]; then

        MODE_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="¿Cómo quieres activar TuAsistente?" \
            --radiolist \
            --column="" \
            --column="ID" \
            --column="Modo" \
            --column="Descripción" \
            FALSE "ptt"      "PTT"      "Pulsar una tecla para hablar" \
            TRUE  "wakeword" "Wake Word" "Decir Hey Mycroft" \
            --hide-column=2 \
            --width=750 \
            --height=350 \
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

    [ -n "${MODE_CHOICE:-}" ] || abort_install
}

# ==============================================================================
# DETECTAR TECLADOS
# ==============================================================================

detect_keyboards()
{
    KEYBOARD_PATHS=()
    KEYBOARD_NAMES=()

    [ -d /dev/input/by-id ] || return

    while IFS= read -r link; do

        [ -L "$link" ] || continue
        [ -e "$link" ] || continue

        target="$(readlink -f "$link")"

        name="$(
            udevadm info \
                --query=property \
                --name="$target" 2>/dev/null |
            sed -n 's/^ID_MODEL_FROM_DATABASE=//p' |
            head -n1
        )"

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

# ==============================================================================
# SELECCIONAR TECLADO
# ==============================================================================

select_keyboard()
{
    detect_keyboards

    COUNT=${#KEYBOARD_PATHS[@]}

    if [ "$COUNT" -eq 0 ]; then

        if [ "$USE_GUI" = true ]; then

            gui_error \
                "No se ha detectado ningún teclado físico.

Comprueba que el teclado esté conectado."

        else

            echo -e "${RED}[ERROR] No se encontró ningún teclado físico.${NC}"

        fi

        abort_install

    fi

    if [ "$COUNT" -eq 1 ]; then

        KEYBOARD_PATH="${KEYBOARD_PATHS[0]}"
        KEYBOARD_NAME="${KEYBOARD_NAMES[0]}"
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
            --text="Selecciona el teclado para PTT:" \
            --radiolist \
            --column="" \
            --column="ID" \
            --column="Teclado" \
            $(for ((i=0;i<COUNT;i++)); do
                if [ "$i" -eq 0 ]; then
                    printf 'TRUE "%s" "%s" ' "$((i+1))" "${KEYBOARD_NAMES[$i]}"
                else
                    printf 'FALSE "%s" "%s" ' "$((i+1))" "${KEYBOARD_NAMES[$i]}"
                fi
              done) \
            --hide-column=2 \
            --width=750 \
            --height=450 \
            2>/dev/null)

    else

        KEYBOARD_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona el teclado:" \
            20 80 "$COUNT" \
            "${MENU_ARGS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${KEYBOARD_CHOICE:-}" ] || abort_install

    INDEX=$((KEYBOARD_CHOICE - 1))

    KEYBOARD_PATH="${KEYBOARD_PATHS[$INDEX]}"
    KEYBOARD_NAME="${KEYBOARD_NAMES[$INDEX]}"
}

# ==============================================================================
# SELECCIONAR TECLA PTT
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

    if [ "$USE_GUI" = true ]; then

        MENU=""

        for ((i=0; i<${#KEY_CODES[@]}; i++)); do

            if [ "$i" -eq 0 ]; then
                MENU+="TRUE ${KEY_CODES[$i]} ${KEY_NAMES[$i]} "
            else
                MENU+="FALSE ${KEY_CODES[$i]} ${KEY_NAMES[$i]} "
            fi

        done

        PTT_KEY=$(eval zenity --list \
            --title=\"$TITLE\" \
            --text=\"Selecciona la tecla PTT:\" \
            --radiolist \
            --column=\"\" \
            --column=\"Código\" \
            --column=\"Tecla\" \
            $MENU \
            --width=600 \
            --height=550 \
            2>/dev/null)

    else

        MENU_ARGS=()

        for ((i=0; i<${#KEY_CODES[@]}; i++)); do
            MENU_ARGS+=(
                "${KEY_CODES[$i]}"
                "${KEY_NAMES[$i]}"
            )
        done

        PTT_KEY=$(whiptail \
            --title="$TITLE" \
            --menu \
            "Selecciona la tecla PTT:" \
            20 65 10 \
            "${MENU_ARGS[@]}" \
            3>&1 1>&2 2>&3)

    fi

    [ -n "${PTT_KEY:-}" ] || abort_install
}

# ==============================================================================
# AUDIO
# ==============================================================================

select_audio_devices()
{
    MIC_INDEX="null"
    MIC_CARD="null"
    MIC_DEVICE="null"
    MIC_NAME="Sistema"

    OUTPUT_DEVICE="default"
    OUTPUT_NAME="Sistema"

    # ======================================================================
    # MICRÓFONO
    # ======================================================================

    mapfile -t CAPTURE_LINES < <(
        arecord -l 2>/dev/null |
        sed -nE 's/^card ([0-9]+): .*device ([0-9]+):.*/\1|\2/p'
    )

    if [ "${#CAPTURE_LINES[@]}" -gt 0 ]; then

        MENU_ARGS=()

        for line in "${CAPTURE_LINES[@]}"; do

            IFS='|' read -r card device <<< "$line"

            description="$(
                arecord -l 2>/dev/null |
                grep "^card $card:" |
                grep "device $device:" |
                head -n1 |
                sed -E 's/^card [0-9]+: (.*)$/\1/'
            )"

            [ -n "$description" ] ||
                description="ALSA hw:${card},${device}"

            MENU_ARGS+=(
                "${card},${device}"
                "$description"
            )

        done

        if [ "$USE_GUI" = true ]; then

            MIC_CHOICE=$(
                zenity --list \
                    --title="$TITLE" \
                    --text="Selecciona la entrada de audio:" \
                    --radiolist \
                    --column="" \
                    --column="ID" \
                    --column="Micrófono" \
                    TRUE "${MENU_ARGS[0]}" "${MENU_ARGS[1]}" \
                    $(for ((i=2;i<${#MENU_ARGS[@]};i+=2)); do
                        printf 'FALSE "%s" "%s" ' \
                            "${MENU_ARGS[$i]}" \
                            "${MENU_ARGS[$((i+1))]}"
                    done) \
                    --width=850 \
                    --height=450 \
                    2>/dev/null
            )

        else

            MIC_CHOICE=$(
                whiptail \
                    --title="$TITLE" \
                    --menu \
                    "Selecciona entrada de audio:" \
                    20 90 8 \
                    "${MENU_ARGS[@]}" \
                    3>&1 1>&2 2>&3
            )

        fi

        [ -n "${MIC_CHOICE:-}" ] || abort_install

        MIC_CARD="${MIC_CHOICE%,*}"
        MIC_DEVICE="${MIC_CHOICE#*,}"

        MIC_NAME="ALSA hw:${MIC_CARD},${MIC_DEVICE}"

        # ==================================================================
        # BUSCAR ÍNDICE REAL DE SOUNDDEVICE
        # ==================================================================

        if [ -x "$BASE_DIR/venv/bin/python" ]; then

            MIC_INDEX="$(
                "$BASE_DIR/venv/bin/python" - \
                    "$MIC_CARD" \
                    "$MIC_DEVICE" <<'PYTHON'
import sys
import sounddevice as sd

card = sys.argv[1]
device = sys.argv[2]

target_hw = f"hw:{card},{device}"
target_plughw = f"plughw:{card},{device}"

try:
    devices = sd.query_devices()

    # 1. Coincidencia exacta.
    for index, info in enumerate(devices):

        name = str(info.get("name", ""))

        if int(info.get("max_input_channels", 0)) <= 0:
            continue

        if target_hw in name or target_plughw in name:
            print(index)
            sys.exit(0)

    # 2. Coincidencia por "card,device".
    target_pair = f"({target_hw})"

    for index, info in enumerate(devices):

        name = str(info.get("name", ""))

        if int(info.get("max_input_channels", 0)) <= 0:
            continue

        if target_pair in name:
            print(index)
            sys.exit(0)

    # 3. Último intento: dispositivo USB.
    for index, info in enumerate(devices):

        name = str(info.get("name", "")).lower()

        if int(info.get("max_input_channels", 0)) <= 0:
            continue

        if (
            "usb camera" in name
            or "usb audio" in name
            or "omnivision" in name
        ):
            print(index)
            sys.exit(0)

    print("null")

except Exception:
    print("null")
PYTHON
            )"

            if [[ "$MIC_INDEX" =~ ^[0-9]+$ ]]; then

                echo -e "${GREEN}[OK] ÍNDICE ENCONTRADO: $MIC_INDEX${NC}"

            else

                echo -e "${YELLOW}[AVISO] No se pudo obtener el índice SoundDevice.${NC}"

                MIC_INDEX="null"

            fi

        fi

    else

        if [ "$USE_GUI" = true ]; then

            gui_info \
                "No se han detectado micrófonos ALSA.

Se utilizará el dispositivo de audio predeterminado."

        fi

    fi

    # ======================================================================
    # SALIDA DE AUDIO
    # ======================================================================

    mapfile -t PLAYBACK_LINES < <(
        aplay -l 2>/dev/null |
        sed -nE 's/^card ([0-9]+): .*device ([0-9]+):.*/\1|\2/p'
    )

    if [ "${#PLAYBACK_LINES[@]}" -gt 0 ]; then

        MENU_ARGS=()

        for line in "${PLAYBACK_LINES[@]}"; do

            IFS='|' read -r card device <<< "$line"

            description="$(
                aplay -l 2>/dev/null |
                grep "^card $card:" |
                grep "device $device:" |
                head -n1 |
                sed -E 's/^card [0-9]+: (.*)$/\1/'
            )"

            [ -n "$description" ] ||
                description="ALSA hw:${card},${device}"

            MENU_ARGS+=(
                "${card},${device}"
                "$description"
            )

        done

        if [ "$USE_GUI" = true ]; then

            OUTPUT_CHOICE=$(
                zenity --list \
                    --title="$TITLE" \
                    --text="Selecciona la salida de audio:" \
                    --radiolist \
                    --column="" \
                    --column="ID" \
                    --column="Salida" \
                    TRUE "${MENU_ARGS[0]}" "${MENU_ARGS[1]}" \
                    $(for ((i=2;i<${#MENU_ARGS[@]};i+=2)); do
                        printf 'FALSE "%s" "%s" ' \
                            "${MENU_ARGS[$i]}" \
                            "${MENU_ARGS[$((i+1))]}"
                    done) \
                    --width=850 \
                    --height=450 \
                    2>/dev/null
            )

        else

            OUTPUT_CHOICE=$(
                whiptail \
                    --title="$TITLE" \
                    --menu \
                    "Selecciona salida de audio:" \
                    20 90 8 \
                    "${MENU_ARGS[@]}" \
                    3>&1 1>&2 2>&3
            )

        fi

        [ -n "${OUTPUT_CHOICE:-}" ] || abort_install

        OUTPUT_CARD="${OUTPUT_CHOICE%,*}"
        OUTPUT_DEVICE_NUM="${OUTPUT_CHOICE#*,}"

        OUTPUT_DEVICE="plughw:${OUTPUT_CARD},${OUTPUT_DEVICE_NUM}"
        OUTPUT_NAME="ALSA hw:${OUTPUT_CARD},${OUTPUT_DEVICE_NUM}"

    else

        if [ "$USE_GUI" = true ]; then

            gui_info \
                "No se han detectado salidas ALSA.

Se utilizará la salida de audio predeterminada."

        fi

    fi

    echo
    echo "===== AUDIO SELECCIONADO ====="
    echo "Micrófono: $MIC_NAME"
    echo "MIC_INDEX: $MIC_INDEX"
    echo "ALSA: hw:${MIC_CARD},${MIC_DEVICE}"
    echo "Salida: $OUTPUT_NAME"
    echo "OUTPUT_DEVICE: $OUTPUT_DEVICE"
    echo
}

# ==============================================================================
# INSTALAR DEPENDENCIA NODE OLLAMA
# ==============================================================================

# ==============================================================================
# SELECCIONAR SI SE QUIERE INSTALAR OLLAMA
# ==============================================================================

select_ollama()
{
    OLLAMA_ENABLED="false"

    echo
    echo -e "${CYAN}===== OLLAMA =====${NC}"
    echo

    if [ "$SIMULATION" = true ]; then
        echo "[SIMULACIÓN] Se preguntaría si instalar Ollama."
        OLLAMA_ENABLED="true"
        return 0
    fi

    if [ "$USE_GUI" = true ] && command -v zenity >/dev/null 2>&1; then

        if zenity --question             --title="MMM-TuAsistente — Ollama"             --text="¿Quieres instalar y configurar Ollama?

Sí:
• Instala/prepara Ollama
• Configura llama-server
• Instala la dependencia Node de Ollama
• Permite seleccionar y descargar el modelo

No:
• No modifica Ollama
• No instala llama-server
• No descarga ningún modelo

Si ya tienes Ollama funcionando, puedes elegir NO."             --width=650             2>/dev/null
        then
            OLLAMA_ENABLED="true"
        else
            OLLAMA_ENABLED="false"
        fi

    else

        if whiptail             --title="$TITLE"             --yesno             "¿Quieres instalar y configurar Ollama?

SÍ:
- Instalar/preparar Ollama
- Configurar llama-server
- Instalar dependencia Node
- Seleccionar y descargar modelo

NO:
- No modificar Ollama
- No instalar llama-server
- No descargar modelos

Si ya tienes Ollama funcionando, puedes elegir NO."             18 75
        then
            OLLAMA_ENABLED="true"
        else
            OLLAMA_ENABLED="false"
        fi

    fi

    if [ "$OLLAMA_ENABLED" = "true" ]; then
        echo -e "${GREEN}[OK] Ollama seleccionado para instalación/configuración.${NC}"
    else
        echo -e "${YELLOW}[INFO] Ollama omitido.${NC}"
    fi

    echo
}

# ==============================================================================
# SELECCIONAR MODELO OLLAMA
# ==============================================================================

select_ollama_model()
{
    OLLAMA_MODEL="qwen2.5:1.5b"

    echo
    echo -e "${CYAN}===== MODELO DE IA =====${NC}"
    echo

    # ======================================================================
    # MODO SIMULACIÓN
    # ======================================================================

    if [ "$SIMULATION" = true ]; then
        echo "Modelo de prueba: $OLLAMA_MODEL"
        return 0
    fi

    # ======================================================================
    # MODO GRÁFICO
    # ======================================================================

    if [ "$USE_GUI" = true ] && command -v zenity >/dev/null 2>&1; then

        MODEL_CHOICE="$(
            zenity --list \
                --title="MMM-TuAsistente — Modelo de IA" \
                --text="Selecciona el modelo de Ollama que quieres utilizar:" \
                --radiolist \
                --width=700 \
                --height=420 \
                --column="Seleccionar" \
                --column="Modelo" \
                --column="Descripción" \
                TRUE  "qwen2.5:1.5b" "Ligero — recomendado para equipos con pocos recursos" \
                FALSE "gemma3:1b"     "Muy ligero — respuestas rápidas" \
                FALSE "gemma3:4b"     "Más capaz — necesita más recursos" \
                FALSE "Otro modelo"   "Introducir el nombre exacto del modelo" \
                2>/dev/null
        )"

        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}[AVISO] Selección cancelada. Se usará qwen2.5:1.5b.${NC}"
            OLLAMA_MODEL="qwen2.5:1.5b"
            return 0
        fi

        case "$MODEL_CHOICE" in

            qwen2.5:1.5b)
                OLLAMA_MODEL="qwen2.5:1.5b"
                ;;

            gemma3:1b)
                OLLAMA_MODEL="gemma3:1b"
                ;;

            gemma3:4b)
                OLLAMA_MODEL="gemma3:4b"
                ;;

            "Otro modelo")
                OLLAMA_MODEL="$(
                    zenity --entry \
                        --title="MMM-TuAsistente — Modelo personalizado" \
                        --text="Introduce el nombre exacto del modelo de Ollama:" \
                        --entry-text="qwen2.5:1.5b" \
                        --width=600 \
                        2>/dev/null
                )"

                [ -n "$OLLAMA_MODEL" ] || OLLAMA_MODEL="qwen2.5:1.5b"
                ;;

            *)
                OLLAMA_MODEL="qwen2.5:1.5b"
                ;;

        esac

    # ======================================================================
    # MODO TEXTO
    # ======================================================================

    else

        echo "1) qwen2.5:1.5b — Ligero"
        echo "2) gemma3:1b    — Muy ligero"
        echo "3) gemma3:4b    — Más capaz"
        echo "4) Otro modelo"
        echo

        read -rp "Elige [1-4]: " MODEL_CHOICE

        case "$MODEL_CHOICE" in

            1)
                OLLAMA_MODEL="qwen2.5:1.5b"
                ;;

            2)
                OLLAMA_MODEL="gemma3:1b"
                ;;

            3)
                OLLAMA_MODEL="gemma3:4b"
                ;;

            4)
                read -rp "Nombre exacto del modelo: " OLLAMA_MODEL
                [ -n "$OLLAMA_MODEL" ] || OLLAMA_MODEL="qwen2.5:1.5b"
                ;;

            *)
                echo -e "${YELLOW}[AVISO] Opción no válida. Se usará qwen2.5:1.5b.${NC}"
                OLLAMA_MODEL="qwen2.5:1.5b"
                ;;

        esac

    fi

    echo
    echo -e "${GREEN}[OK] Modelo seleccionado: $OLLAMA_MODEL${NC}"
    echo
}

install_ollama_system()
{
    echo
    echo -e "${CYAN}===== OLLAMA =====${NC}"
    echo

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se instalaría Ollama.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Se prepararía llama-server.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Se iniciaría el servidor Ollama.${NC}"
        return 0
    fi

    # --------------------------------------------------------------------------
    # Instalar Ollama si no existe
    # --------------------------------------------------------------------------

    if ! command -v ollama >/dev/null 2>&1; then

        echo -e "${CYAN}[INFO] Ollama no está instalado.${NC}"
        echo -e "${CYAN}[INFO] Instalando Ollama...${NC}"
        echo

        if curl -fsSL https://ollama.com/install.sh | sh; then
            echo -e "${GREEN}[OK] Ollama instalado correctamente.${NC}"
        else
            echo -e "${RED}[ERROR] No se pudo instalar Ollama.${NC}"
            return 1
        fi

    else

        echo -e "${GREEN}[OK] Ollama ya está instalado.${NC}"

    fi

    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

    if ! command -v ollama >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] El comando ollama no está disponible.${NC}"
        return 1
    fi

    # --------------------------------------------------------------------------
    # Preparar llama-server
    # --------------------------------------------------------------------------

    echo
    echo -e "${CYAN}[INFO] Comprobando llama-server...${NC}"

    LLAMA_SERVER=""

    for candidate in \
        /usr/lib/ollama/llama-server \
        /usr/local/lib/ollama/llama-server \
        /usr/local/bin/llama-server \
        /usr/bin/llama-server
    do
        if [ -x "$candidate" ]; then
            LLAMA_SERVER="$candidate"
            break
        fi
    done

    if [ -z "$LLAMA_SERVER" ]; then
        echo -e "${RED}[ERROR] No se encontró llama-server.${NC}"
        echo
        echo "Ollama está instalado pero falta su runtime de ejecución."
        return 1
    fi

    echo -e "${GREEN}[OK] llama-server encontrado:${NC}"
    echo "$LLAMA_SERVER"

    # --------------------------------------------------------------------------
    # Ollama 0.33.x busca llama-server en /usr/local/lib/ollama
    # --------------------------------------------------------------------------

    OLLAMA_RUNTIME="/usr/local/lib/ollama"

    sudo mkdir -p "$OLLAMA_RUNTIME" || return 1

    echo
    echo -e "${CYAN}[INFO] Preparando runtime de Ollama...${NC}"

    # Si llama-server ya está exactamente en el runtime, no crear
    # un enlace simbólico sobre sí mismo.
    if [ "$LLAMA_SERVER" = "$OLLAMA_RUNTIME/llama-server" ]; then
        echo -e "${GREEN}[OK] llama-server ya está en el runtime correcto.${NC}"
    else
        sudo ln -sf "$LLAMA_SERVER" \
            "$OLLAMA_RUNTIME/llama-server" || return 1
    fi

    LLAMA_DIR="$(dirname "$LLAMA_SERVER")"

    for lib in \
        libllama-server-impl.so \
        libllama-common.so.0 \
        libmtmd.so.0 \
        libllama.so.0 \
        libggml.so.0 \
        libggml-base.so.0
    do

        if [ -e "$LLAMA_DIR/$lib" ]; then
            sudo ln -sf "$LLAMA_DIR/$lib" \
                "$OLLAMA_RUNTIME/$lib" || return 1
        fi

    done

    echo -e "${GREEN}[OK] Runtime de Ollama preparado.${NC}"

    # --------------------------------------------------------------------------
    # Comprobar si Ollama ya está funcionando
    # --------------------------------------------------------------------------

    if curl -fsS \
        http://127.0.0.1:11434/api/tags \
        >/dev/null 2>&1; then

        echo -e "${GREEN}[OK] Servidor Ollama ya está funcionando.${NC}"

    else

        echo
        echo -e "${CYAN}[INFO] Iniciando servidor Ollama...${NC}"

        if systemctl list-unit-files 2>/dev/null | \
            grep -q '^ollama\.service'; then

            echo -e "${CYAN}[INFO] Utilizando servicio systemd.${NC}"

            sudo systemctl enable ollama.service \
                >/dev/null 2>&1 || true

            sudo systemctl restart ollama.service \
                >/dev/null 2>&1 || \
            sudo systemctl start ollama.service \
                >/dev/null 2>&1 || true

        else

            echo -e "${CYAN}[INFO] No existe ollama.service.${NC}"
            echo -e "${CYAN}[INFO] Iniciando ollama serve...${NC}"

            if ! pgrep -x ollama >/dev/null 2>&1; then

                nohup ollama serve \
                    >/tmp/mmm-tu-asistente-ollama.log \
                    2>&1 &

                OLLAMA_PID=$!

                echo -e "${GREEN}[OK] Ollama iniciado. PID: $OLLAMA_PID${NC}"

            else

                echo -e "${GREEN}[OK] Ollama ya estaba ejecutándose.${NC}"

            fi

        fi

    fi

    # --------------------------------------------------------------------------
    # Esperar al servidor
    # --------------------------------------------------------------------------

    echo
    echo -e "${CYAN}[INFO] Esperando a que Ollama esté disponible...${NC}"

    OLLAMA_READY=false

    for i in $(seq 1 30); do

        if curl -fsS \
            http://127.0.0.1:11434/api/tags \
            >/dev/null 2>&1; then

            OLLAMA_READY=true
            break

        fi

        printf "."
        sleep 1

    done

    echo

    if [ "$OLLAMA_READY" != true ]; then

        echo
        echo -e "${RED}[ERROR] Ollama no responde en el puerto 11434.${NC}"
        echo
        echo "Registro de Ollama:"
        echo
        tail -30 /tmp/mmm-tu-asistente-ollama.log \
            2>/dev/null || true
        echo

        return 1
    fi

    echo -e "${GREEN}[OK] Servidor Ollama activo.${NC}"

    # --------------------------------------------------------------------------
    # Comprobar versión
    # --------------------------------------------------------------------------

    OLLAMA_VERSION="$(ollama --version 2>/dev/null || true)"

    if [ -n "$OLLAMA_VERSION" ]; then
        echo -e "${GREEN}[OK] $OLLAMA_VERSION${NC}"
    fi

    echo
    return 0
}
install_ollama_node()
{
    # ======================================================================
    # SIMULACIÓN
    # ======================================================================

    if [ "$SIMULATION" = true ]; then

        if [ "$USE_GUI" = true ] && command -v zenity >/dev/null 2>&1; then
            zenity --info \
                --title="MMM-TuAsistente" \
                --text="Se instalaría la dependencia Node.js:

ollama" \
                --width=500 \
                2>/dev/null || true
        fi

        return 0
    fi

    # ======================================================================
    # COMPROBAR NODE / NPM
    # ======================================================================

    if ! command -v node >/dev/null 2>&1; then

        if [ "$USE_GUI" = true ]; then
            zenity --error \
                --title="MMM-TuAsistente" \
                --text="No se encontró Node.js." \
                --width=500 \
                2>/dev/null || true
        fi

        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then

        if [ "$USE_GUI" = true ]; then
            zenity --error \
                --title="MMM-TuAsistente" \
                --text="No se encontró npm." \
                --width=500 \
                2>/dev/null || true
        fi

        return 1
    fi

    cd "$BASE_DIR" || return 1

    # ======================================================================
    # YA INSTALADO
    # ======================================================================

    if npm list ollama --depth=0 >/dev/null 2>&1; then

        if [ "$USE_GUI" = true ]; then
            zenity --info \
                --title="MMM-TuAsistente" \
                --text="La dependencia <b>ollama</b> ya está instalada." \
                --width=500 \
                2>/dev/null || true
        fi

        return 0
    fi

    # ======================================================================
    # INSTALACIÓN GRÁFICA
    # ======================================================================

    if [ "$USE_GUI" = true ] && command -v zenity >/dev/null 2>&1; then

        if npm install ollama 2>&1 | \
            zenity --progress \
                --title="MMM-TuAsistente" \
                --text="Instalando la dependencia Node.js de Ollama..." \
                --pulsate \
                --no-cancel \
                --auto-close \
                --width=600 \
                2>/dev/null
        then

            if npm list ollama --depth=0 >/dev/null 2>&1; then

                zenity --info \
                    --title="MMM-TuAsistente" \
                    --text="✓ <b>Ollama Node.js instalado correctamente.</b>" \
                    --width=550 \
                    2>/dev/null || true

                return 0
            fi
        fi

        zenity --error \
            --title="MMM-TuAsistente" \
            --text="No se pudo instalar la dependencia Node.js:

<b>ollama</b>" \
            --width=550 \
            2>/dev/null || true

        return 1

    fi

    # ======================================================================
    # MODO TEXTO
    # ======================================================================

    echo
    echo "===== OLLAMA NODE.JS ====="
    echo "Instalando dependencia npm: ollama..."

    if npm install ollama; then

        if npm list ollama --depth=0 >/dev/null 2>&1; then
            echo "[OK] ollama instalado correctamente."
            return 0
        fi

    fi

    echo "[ERROR] No se pudo instalar la dependencia ollama."
    return 1
}


download_ollama_model()
{
    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se preguntaría si descargar: $OLLAMA_MODEL${NC}"
        return 0
    fi

    DOWNLOAD_MODEL=false

    if [ "$USE_GUI" = true ]; then

        if whiptail \
            --title="⬇️ MODELO OLLAMA" \
            --yesno \
            "¿Quieres descargar ahora el modelo?\n\nModelo:\n$OLLAMA_MODEL\n\nLa descarga puede ocupar bastante espacio en disco." \
            13 70
        then
            DOWNLOAD_MODEL=true
        fi

    else

        echo
        echo "¿Quieres descargar ahora el modelo?"
        echo
        echo "Modelo: $OLLAMA_MODEL"
        echo

        read -rp "¿Descargar ahora? [S/n]: " ANSWER

        case "$ANSWER" in
            n|N|no|NO|No)
                DOWNLOAD_MODEL=false
                ;;
            *)
                DOWNLOAD_MODEL=true
                ;;
        esac

    fi

    if [ "$DOWNLOAD_MODEL" != true ]; then

        if [ "$USE_GUI" = true ]; then

            whiptail \
                --title="MODELO OLLAMA" \
                --msgbox \
                "Se ha omitido la descarga.\n\nPuedes descargarlo posteriormente con:\n\nollama pull $OLLAMA_MODEL" \
                11 75

        else

            echo
            echo "[INFO] Se omite la descarga."
            echo
            echo "Puedes descargarlo posteriormente con:"
            echo
            echo "ollama pull $OLLAMA_MODEL"
            echo

        fi

        return 0
    fi

    if ! command -v ollama >/dev/null 2>&1; then

        if [ "$USE_GUI" = true ]; then
            whiptail \
                --title="❌ OLLAMA" \
                --msgbox \
                "No se encontró el comando ollama.\n\nInstala Ollama antes de descargar el modelo." \
                10 70
        else
            echo -e "${RED}[ERROR] No se encontró el comando ollama.${NC}"
        fi

        return 1
    fi

    if [ "$USE_GUI" = true ]; then

        (
            echo "1"
            echo "XXX"
            echo "Descargando $OLLAMA_MODEL..."
            echo "XXX"

            ollama pull "$OLLAMA_MODEL" >/tmp/mmm-tuasistente-ollama-pull.log 2>&1
            RESULT=$?

            echo "100"
            echo "XXX"

            if [ "$RESULT" -eq 0 ]; then
                echo "Modelo descargado correctamente."
            else
                echo "Error descargando el modelo."
            fi

            echo "XXX"

            exit "$RESULT"

        ) | whiptail \
            --title="⬇️ DESCARGANDO OLLAMA" \
            --gauge \
            "Descargando $OLLAMA_MODEL..." \
            10 75 0

        RESULT=${PIPESTATUS[0]}

    else

        echo
        echo "===== DESCARGANDO MODELO OLLAMA ====="
        echo
        ollama pull "$OLLAMA_MODEL"
        RESULT=$?

    fi

    if [ "$RESULT" -ne 0 ]; then

        if [ "$USE_GUI" = true ]; then

            whiptail \
                --title="❌ ERROR" \
                --msgbox \
                "No se pudo descargar:\n\n$OLLAMA_MODEL\n\nPuedes revisar el registro:\n/tmp/mmm-tuasistente-ollama-pull.log" \
                11 75

        else

            echo -e "${RED}[ERROR] No se pudo descargar $OLLAMA_MODEL.${NC}"

        fi

        return 1
    fi

    if [ "$USE_GUI" = true ]; then

        whiptail \
            --title="✅ MODELO LISTO" \
            --msgbox \
            "El modelo $OLLAMA_MODEL se ha descargado correctamente.\n\nTuAsistente ya puede utilizarlo." \
            10 70

    else

        echo -e "${GREEN}[OK] Modelo $OLLAMA_MODEL descargado correctamente.${NC}"

    fi

    return 0
}

configure_spotify()
{
    SPOTIFY_ENABLED="false"
    SPOTIFY_MODE=""

    if [ "$USE_GUI" = true ]; then

        if ! gui_question \
            "¿Quieres activar Spotify Connect?

MMM-TuAsistente se convertirá en un dispositivo
Spotify Connect que aparecerá directamente en
la aplicación Spotify.

No necesitas introducir:
• Usuario
• Contraseña
• Client ID
• Client Secret

Se instalará Librespot y se configurará
automáticamente como servicio del sistema.

El dispositivo aparecerá en Spotify como:

    MMM-TuAsistente

Podrás seleccionarlo desde Spotify para
reproducir música en el espejo.

¿Quieres activar Spotify Connect?"
        then
            return 0
        fi

        SPOTIFY_ENABLED="true"

        SPOTIFY_MODE=$(
            zenity --list \
                --title="$TITLE" \
                --text="Selecciona el modo de Spotify Connect:" \
                --radiolist \
                --column="" \
                --column="ID" \
                --column="Modo" \
                TRUE "connect" "Spotify Connect — recomendado" \
                --hide-column=2 \
                --width=700 \
                --height=300 \
                2>/dev/null
        )

        [ -n "${SPOTIFY_MODE:-}" ] || return 0

    else

        if whiptail \
            --title="$TITLE" \
            --yesno \
            "¿Quieres activar Spotify Connect?

MMM-TuAsistente aparecerá directamente en Spotify
como un dispositivo disponible para reproducir música.

No necesitas introducir:

• Usuario
• Contraseña
• Client ID
• Client Secret

Se instalará Librespot y se configurará
automáticamente como servicio del sistema.

El dispositivo aparecerá como:

    MMM-TuAsistente

Podrás seleccionarlo desde Spotify para
reproducir música en el espejo.

¿Quieres activar Spotify Connect?" \
            24 78
        then

            SPOTIFY_ENABLED="true"
            SPOTIFY_MODE="connect"

        fi

    fi

    if [ "$SPOTIFY_ENABLED" = "true" ]; then

        echo
        echo -e "${GREEN}[OK] Spotify Connect seleccionado.${NC}"
        echo -e "${BLUE}[INFO] Se instalará Librespot automáticamente.${NC}"
        echo -e "${BLUE}[INFO] No se necesitan Client ID ni Client Secret.${NC}"
        echo -e "${BLUE}[INFO] Nombre del dispositivo: MMM-TuAsistente${NC}"

    fi
}


# ==============================================================================
# GUARDAR SPOTIFY
# ==============================================================================

# ==============================================================================
# INSTALAR SPOTIFY / LIBRESPOT
# ==============================================================================

install_spotify()
{
    echo
    echo -e "${BLUE}[8/9] Instalando Spotify Connect...${NC}"

    if [ "$SPOTIFY_ENABLED" != "true" ]; then
        echo -e "${YELLOW}[INFO] Spotify Connect desactivado.${NC}"
        return 0
    fi

    if [ "$SIMULATION" = true ]; then

        echo -e "${YELLOW}[SIMULACIÓN] Se instalaría Librespot.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Arquitectura: aarch64.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Se crearía el servicio Spotify Connect.${NC}"
        echo -e "${GREEN}[OK] Spotify Connect preparado.${NC}"

        return 0
    fi

    echo
    echo -e "${CYAN}===== SPOTIFY CONNECT =====${NC}"
    echo
    echo "[INFO] Instalando Librespot..."
    echo "[INFO] Dispositivo: MMM-TuAsistente"
    echo "[INFO] No se necesitan credenciales de Spotify."
    echo

    # --------------------------------------------------------------
    # LIBRESPOT PRECOMPILADO
    # --------------------------------------------------------------

    if [ "$(uname -m)" != "aarch64" ]; then
        echo -e "${RED}[ERROR] Esta versión de Librespot requiere arquitectura aarch64.${NC}"
        echo "[INFO] Arquitectura detectada: $(uname -m)"
        abort_install
    fi

    LIBRESPOT_SOURCE="$BASE_DIR/binaries/librespot/aarch64/librespot"
    LIBRESPOT_TARGET="/usr/local/bin/librespot"

    if [ ! -f "$LIBRESPOT_SOURCE" ]; then
        echo -e "${RED}[ERROR] No se encontró el binario precompilado de Librespot.${NC}"
        echo
        echo "Se esperaba:"
        echo "$LIBRESPOT_SOURCE"
        echo
        echo "Asegúrate de que el repositorio contiene:"
        echo "binaries/librespot/aarch64/librespot"
        abort_install
    fi

    if [ ! -x "$LIBRESPOT_SOURCE" ]; then
        echo "[INFO] Ajustando permisos del binario..."
        chmod +x "$LIBRESPOT_SOURCE" || abort_install
    fi

    echo "[INFO] Instalando Librespot..."

    sudo install -m 0755 \
        "$LIBRESPOT_SOURCE" \
        "$LIBRESPOT_TARGET" || abort_install

    if [ ! -x "$LIBRESPOT_TARGET" ]; then
        echo -e "${RED}[ERROR] No se pudo instalar Librespot.${NC}"
        abort_install
    fi

    echo -e "${GREEN}[OK] Librespot instalado.${NC}"

    echo "[INFO] Versión:"
    "$LIBRESPOT_TARGET" --version 2>/dev/null || true

    # --------------------------------------------------------------
    # SERVICIO SYSTEMD
    # --------------------------------------------------------------

    echo
    echo "[INFO] Creando servicio Spotify Connect..."

    sudo tee /etc/systemd/system/mmm-tu-asistente-spotify.service > /dev/null <<EOF2
[Unit]
Description=MMM-TuAsistente - Spotify Connect
After=network-online.target pipewire.service
Wants=network-online.target

[Service]
Type=simple
User=pi
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/local/bin/librespot --name "MMM-TuAsistente" --backend rodio
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF2

    sudo systemctl daemon-reload || abort_install
    sudo systemctl enable mmm-tu-asistente-spotify.service || abort_install
    sudo systemctl restart mmm-tu-asistente-spotify.service || abort_install

    sleep 2

    if ! systemctl is-active --quiet mmm-tu-asistente-spotify.service; then

        echo -e "${RED}[ERROR] Spotify Connect no se pudo iniciar.${NC}"

        sudo systemctl status \
            mmm-tu-asistente-spotify.service \
            --no-pager || true

        abort_install
    fi

    echo
    echo -e "${GREEN}[OK] Spotify Connect activo.${NC}"
    echo -e "${GREEN}[OK] Dispositivo disponible como: MMM-TuAsistente${NC}"
}

save_spotify()
{
    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite creación/modificación de config/spotify.env.${NC}"
        echo -e "${GREEN}[OK] Configuración de Spotify simulada.${NC}"
        return 0
    fi

    mkdir -p "$BASE_DIR/config"

    SPOTIFY_FILE="$BASE_DIR/config/spotify.env"

    if [ "$SPOTIFY_ENABLED" = "true" ]; then

        cat > "$SPOTIFY_FILE" <<EOF2
# MMM-TuAsistente - Spotify
SPOTIFY_ENABLED=true
SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID
SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET
SPOTIFY_REDIRECT_URI=$SPOTIFY_REDIRECT_URI
EOF2

        chmod 600 "$SPOTIFY_FILE"

    else

        cat > "$SPOTIFY_FILE" <<EOF2
# MMM-TuAsistente - Spotify
SPOTIFY_ENABLED=false
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
SPOTIFY_REDIRECT_URI=
EOF2

        chmod 600 "$SPOTIFY_FILE"

    fi
}

# ==============================================================================
# INSTALAR DEPENDENCIAS DEL SISTEMA
# ==============================================================================

install_system_dependencies()
{
    echo
    echo -e "${BLUE}[1/9] Instalando dependencias del sistema...${NC}"

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite apt-get update.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Se omite instalación de paquetes del sistema.${NC}"
        echo -e "${GREEN}[OK] Dependencias del sistema simuladas.${NC}"
        return 0
    fi

    sudo apt-get update || abort_install

    sudo apt-get install -y \
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
        udev \
        || abort_install

    echo -e "${GREEN}[OK] Dependencias del sistema.${NC}"
}

# ==============================================================================
# NODE
# ==============================================================================

install_node()
{
    echo
    echo -e "${BLUE}[2/9] Comprobando Node.js y npm...${NC}"

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se comprobaría Node.js y npm.${NC}"
        echo -e "${GREEN}[OK] Node.js/npm simulados.${NC}"
        return 0
    fi

    if ! command -v node >/dev/null 2>&1; then

        echo "[INFO] Node.js no está instalado."

        curl -fsSL \
            https://deb.nodesource.com/setup_22.x |
            sudo -E bash - ||
            abort_install

        sudo apt-get install -y nodejs ||
            abort_install

    fi

    command -v node >/dev/null 2>&1 ||
        abort_install

    command -v npm >/dev/null 2>&1 ||
        abort_install

    echo -e "${GREEN}[OK] Node: $(node --version)${NC}"
    echo -e "${GREEN}[OK] npm : $(npm --version)${NC}"
}

# ==============================================================================
# NODE DEPENDENCIES
# ==============================================================================

install_node_dependencies()
{
    echo
    echo -e "${BLUE}[3/9] Instalando dependencias Node...${NC}"

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite npm install axios.${NC}"
        echo -e "${GREEN}[OK] Dependencias Node simuladas.${NC}"
        return 0
    fi

    npm install axios ||
        abort_install

    echo -e "${GREEN}[OK] Axios instalado.${NC}"
}

# ==============================================================================
# VENV
# ==============================================================================

install_python_environment()
{
    echo
    echo -e "${BLUE}[4/9] Preparando Python...${NC}"

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite creación/modificación del entorno Python.${NC}"
        echo -e "${GREEN}[OK] Entorno Python simulado.${NC}"
        return 0
    fi

    VENV_DIR="$BASE_DIR/venv"

    # --------------------------------------------------------------------------
    # COMPROBAR VENV EXISTENTE
    # --------------------------------------------------------------------------

    if [ -d "$VENV_DIR" ]; then

        if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then

            echo -e "${YELLOW}[AVISO] El entorno Python existente no es válido.${NC}"
            echo "[INFO] Recreando venv con Python $(python3 --version)..."

            rm -rf "$VENV_DIR"

        fi

    fi

    # --------------------------------------------------------------------------
    # CREAR VENV
    # --------------------------------------------------------------------------

    if [ ! -d "$VENV_DIR" ]; then

        echo "[INFO] Creando entorno virtual Python..."

        python3 -m venv "$VENV_DIR" ||
            abort_install

    fi

    # --------------------------------------------------------------------------
    # COMPROBACIÓN FINAL DE PIP
    # --------------------------------------------------------------------------

    if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then

        echo -e "${RED}[ERROR] pip no está disponible dentro del entorno Python.${NC}"
        abort_install

    fi

    # --------------------------------------------------------------------------
    # ACTIVAR ENTORNO
    # --------------------------------------------------------------------------

    source "$VENV_DIR/bin/activate"

    # --------------------------------------------------------------------------
    # ACTUALIZAR HERRAMIENTAS PYTHON
    # --------------------------------------------------------------------------

    python -m pip install         --upgrade         pip         setuptools         wheel         -q ||
        abort_install

    echo -e "${GREEN}[OK] Entorno Python preparado.${NC}"
}

install_python_dependencies()
{
    echo
    echo -e "${BLUE}[5/9] Instalando librerías Python...${NC}"

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite pip install de las librerías Python.${NC}"
        echo -e "${GREEN}[OK] Librerías Python simuladas.${NC}"
        return 0
    fi

    python -m pip install \
        numpy \
        requests \
        ollama \
        sounddevice \
        faster-whisper \
        evdev \
        scipy \
        -q ||
        abort_install

    echo -e "${GREEN}[OK] Librerías Python instaladas.${NC}"
}

# ==============================================================================
# OPENWAKEWORD
# ==============================================================================

install_openwakeword()
{
    echo
    echo -e "${BLUE}[6/9] Configuración de activación...${NC}"

    if [ "$SIMULATION" = true ]; then
        if [ "$MODE_CHOICE" = "wakeword" ]; then
            echo -e "${YELLOW}[SIMULACIÓN] Se instalaría OpenWakeWord.${NC}"
        else
            echo -e "${YELLOW}[SIMULACIÓN] PTT seleccionado; no se instalaría OpenWakeWord.${NC}"
        fi
        echo -e "${GREEN}[OK] Activación simulada.${NC}"
        return 0
    fi

    if [ "$MODE_CHOICE" = "wakeword" ]; then

        echo "[INFO] Instalando OpenWakeWord..."

        python -m pip install \
            openwakeword \
            pyaudio \
            tflite-runtime \
            -q ||
            abort_install

        echo -e "${GREEN}[OK] OpenWakeWord instalado.${NC}"

    else

        echo -e "${GREEN}[OK] PTT seleccionado.${NC}"

    fi
}

# ==============================================================================
# PIPER
# ==============================================================================

install_piper()
{
    echo
    echo -e "${BLUE}[7/9] Preparando Piper TTS...${NC}"

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite descarga/instalación de Piper.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Voz seleccionada: $VOICE${NC}"
        echo -e "${GREEN}[OK] Piper simulado.${NC}"
        return 0
    fi

    PIPER_DIR="$BASE_DIR/piper_tts"

    mkdir -p "$PIPER_DIR"

    case "$(uname -m)" in

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
            echo -e "${RED}[ERROR] Arquitectura no soportada.${NC}"
            abort_install
            ;;

    esac

    if [ ! -x "$PIPER_DIR/piper/piper" ]; then

        PIPER_VERSION="2023.11.14-2"

        PIPER_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_linux_${PIPER_ARCH}.tar.gz"

        TEMP_PIPER="/tmp/piper_mmm_tuasistente.tar.gz"

        echo "[INFO] Descargando Piper..."

        wget -q --show-progress \
            "$PIPER_URL" \
            -O "$TEMP_PIPER" ||
            abort_install

        rm -rf "$PIPER_DIR/piper"

        mkdir -p "$PIPER_DIR/piper"

        tar -xzf "$TEMP_PIPER" \
            -C "$PIPER_DIR/piper" \
            --strip-components=1 ||
            abort_install

        rm -f "$TEMP_PIPER"

    fi

    chmod +x "$PIPER_DIR/piper/piper" 2>/dev/null || true

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
            abort_install
            ;;

    esac

    VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx"
    VOICE_JSON_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/${VOICE_PATH}/${VOICE}.onnx.json"

    if [ ! -s "$PIPER_DIR/${VOICE}.onnx" ]; then

        echo "[INFO] Descargando modelo $VOICE..."

        wget -q --show-progress \
            "$VOICE_URL" \
            -O "$PIPER_DIR/${VOICE}.onnx" ||
            abort_install

    fi

    if [ ! -s "$PIPER_DIR/${VOICE}.onnx.json" ]; then

        echo "[INFO] Descargando configuración de voz..."

        wget -q --show-progress \
            "$VOICE_JSON_URL" \
            -O "$PIPER_DIR/${VOICE}.onnx.json" ||
            abort_install

    fi

    echo -e "${GREEN}[OK] Piper preparado: $VOICE${NC}"
}

# ==============================================================================
# CONFIGURAR LISTEN_KEY
# ==============================================================================

configure_listen_key()
{
    if [ "$MODE_CHOICE" != "ptt" ]; then
        return
    fi

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite modificación de listen_key.py.${NC}"
        echo -e "${GREEN}[OK] Configuración de PTT simulada.${NC}"
        return 0
    fi

    [ -f "$BASE_DIR/listen_key.py" ] || return

    cp "$BASE_DIR/listen_key.py" \
       "$BASE_DIR/listen_key.py.backup.$(date +%Y%m%d_%H%M%S)" \
       2>/dev/null || true

    "$BASE_DIR/venv/bin/python" - \
        "$BASE_DIR/listen_key.py" \
        "$KEYBOARD_PATH" \
        "$PTT_KEY" <<'PYTHON'

import sys
import re

path = sys.argv[1]
keyboard = sys.argv[2]
key = sys.argv[3]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# ============================================================
# CONFIGURAR TECLADO
# ============================================================

replacement = (
    'configured = ' + repr(keyboard)
)

content, count = re.subn(
    r'configured\s*=\s*os\.environ\.get\(\s*"MMM_TUASISTENTE_KEYBOARD"\s*,\s*"null"\s*\)',
    replacement,
    content,
    count=1
)

if count == 1:
    print(f"[OK] Teclado configurado: {keyboard}")
else:
    print("[AVISO] No se encontró la configuración del teclado.")

# ============================================================
# CONFIGURAR TECLA PTT
# ============================================================

content, count = re.subn(
    r'ecodes\.KEY_[A-Z0-9_]+',
    f'ecodes.{key}',
    content,
    count=1
)

if count == 1:
    print(f"[OK] Tecla PTT configurada: {key}")
else:
    print("[AVISO] No se encontró la tecla PTT.")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

PYTHON
}

# ==============================================================================


configure_transcribe()
{
    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite modificación de transcribe.py.${NC}"
        echo -e "${GREEN}[OK] Configuración de transcripción simulada.${NC}"
        return 0
    fi

    [ -f "$BASE_DIR/transcribe.py" ] || return

    cp "$BASE_DIR/transcribe.py" \
       "$BASE_DIR/transcribe.py.backup.$(date +%Y%m%d_%H%M%S)" \
       2>/dev/null || true

    "$BASE_DIR/venv/bin/python" - \
        "$BASE_DIR/transcribe.py" \
        "$MIC_INDEX" \
        "$MIC_CARD" \
        "$MIC_DEVICE" <<'PYTHON'

import sys
import re

path = sys.argv[1]
mic_index = sys.argv[2]
mic_card = sys.argv[3]
mic_device = sys.argv[4]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# ------------------------------------------------------------
# DEVICE_INDEX
# ------------------------------------------------------------

if mic_index == "null":
    device_index = "None"
else:
    device_index = mic_index

content = re.sub(
    r"^\s*DEVICE_INDEX\s*=.*$",
    f"DEVICE_INDEX = {device_index}",
    content,
    count=1,
    flags=re.MULTILINE
)

# ------------------------------------------------------------
# ALSA_DEVICE
# ------------------------------------------------------------

if mic_card != "null" and mic_device != "null":
    alsa_device = f'hw:{mic_card},{mic_device}'
else:
    alsa_device = "null"

if re.search(r"^\s*ALSA_DEVICE\s*=", content, re.MULTILINE):
    content = re.sub(
        r"^\s*ALSA_DEVICE\s*=.*$",
        f'ALSA_DEVICE = "{alsa_device}"',
        content,
        count=1,
        flags=re.MULTILINE
    )
else:
    content = content.replace(
        "DEVICE_INDEX =",
        f'ALSA_DEVICE = "{alsa_device}"\nDEVICE_INDEX =',
        1
    )

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(
    f"[OK] transcribe.py configurado: "
    f"DEVICE_INDEX={device_index}, "
    f"ALSA_DEVICE={alsa_device}"
)

PYTHON
}

# ==============================================================================
# CONFIG.JS
# ==============================================================================

configure_magicmirror()
{
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "${RED}[ERROR] No se encontró config.js:${NC}"
        echo "$CONFIG_PATH"
        abort_install
    fi

    ADD_CONFIG=false

    if [ "$USE_GUI" = true ]; then
        if gui_question "¿Quieres añadir MMM-TuAsistente automáticamente a config.js?"; then
            ADD_CONFIG=true
        fi
    else
        if whiptail --title="$TITLE" --yesno "¿Quieres añadir MMM-TuAsistente automáticamente a config.js?" 10 70; then
            ADD_CONFIG=true
        fi
    fi

    [ "$ADD_CONFIG" = true ] || return 0

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se añadiría MMM-TuAsistente a config.js.${NC}"
        return 0
    fi

    if grep -q 'module: "MMM-TuAsistente"' "$CONFIG_PATH"; then
        echo -e "${YELLOW}[AVISO] MMM-TuAsistente ya está presente en config.js.${NC}"
        return 0
    fi

    BACKUP="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_PATH" "$BACKUP" || abort_install

    TEMP_CONFIG="/tmp/config_mmm_tuasistente_$$.js"

    cat > "$TEMP_CONFIG" <<CONFIGBLOCK
    {
        module: "MMM-TuAsistente",
        position: "middle_center",
        config: {
            language: "$LANGUAGE",
            activationMode: "$MODE_CHOICE",
            voice: "$VOICE",
            wakeWordModel: "hey_mycroft",
            wakeWordThreshold: 0.5,
            micDeviceIndex: $MIC_INDEX,
            keyboardDevice: "$KEYBOARD_PATH",
            pttKey: "$PTT_KEY",
            audioOutput: "$OUTPUT_DEVICE",
            spotifyEnabled: $SPOTIFY_ENABLED,
            model: "$OLLAMA_MODEL",
            hideDelay: 18000,
            autoHideTimeout: 30000
        }
    },
CONFIGBLOCK

    "$BASE_DIR/venv/bin/python" - "$CONFIG_PATH" "$TEMP_CONFIG" <<'PYTHON'
import sys

config_path = sys.argv[1]
block_path = sys.argv[2]

with open(config_path, "r", encoding="utf-8") as f:
    content = f.read()

with open(block_path, "r", encoding="utf-8") as f:
    block = f.read()

marker = "modules: ["

if marker not in content:
    print("[ERROR] No se encontró modules: [")
    sys.exit(1)

content = content.replace(marker, marker + "\n" + block, 1)

with open(config_path, "w", encoding="utf-8") as f:
    f.write(content)
PYTHON

    rm -f "$TEMP_CONFIG"

    if grep -q 'module: "MMM-TuAsistente"' "$CONFIG_PATH"; then
        echo -e "${GREEN}[OK] MMM-TuAsistente añadido a config.js.${NC}"
    else
        echo -e "${RED}[ERROR] No se pudo modificar config.js.${NC}"
        echo "[INFO] Copia de seguridad: $BACKUP"
        abort_install
    fi
}

# ==============================================================================
# PERMISOS
# ==============================================================================

set_permissions()
{
    chmod +x "$BASE_DIR/install.sh" 2>/dev/null || true
    chmod +x "$BASE_DIR/listen_key.py" 2>/dev/null || true
    chmod +x "$BASE_DIR/transcribe.py" 2>/dev/null || true

    if [ -d "$BASE_DIR/scripts" ]; then
        chmod +x "$BASE_DIR/scripts/"*.py 2>/dev/null || true
    fi
}

# ==============================================================================
# COMPROBACIONES
# ==============================================================================

run_checks()
{
    CHECK_OK=true

    RESULTS=""

    if node --check "$BASE_DIR/node_helper.js" >/dev/null 2>&1; then
        RESULTS+="✓ node_helper.js\n"
    else
        RESULTS+="✗ node_helper.js\n"
        CHECK_OK=false
    fi

    if [ -f "$BASE_DIR/listen_key.py" ] &&
       "$BASE_DIR/venv/bin/python" -m py_compile \
       "$BASE_DIR/listen_key.py" >/dev/null 2>&1
    then
        RESULTS+="✓ listen_key.py\n"
    elif [ "$MODE_CHOICE" = "ptt" ]; then
        RESULTS+="✗ listen_key.py\n"
        CHECK_OK=false
    fi

    if [ -f "$BASE_DIR/transcribe.py" ] &&
       "$BASE_DIR/venv/bin/python" -m py_compile \
       "$BASE_DIR/transcribe.py" >/dev/null 2>&1
    then
        RESULTS+="✓ transcribe.py\n"
    else
        RESULTS+="✗ transcribe.py\n"
        CHECK_OK=false
    fi

    if [ -x "$BASE_DIR/piper_tts/piper/piper" ]; then
        RESULTS+="✓ Piper\n"
    else
        RESULTS+="✗ Piper\n"
        CHECK_OK=false
    fi

    if command -v node >/dev/null 2>&1; then
        RESULTS+="✓ Node.js $(node --version)\n"
    else
        RESULTS+="✗ Node.js\n"
        CHECK_OK=false
    fi

    if [ -x "$BASE_DIR/venv/bin/python" ]; then
        RESULTS+="✓ Python virtualenv\n"
    else
        RESULTS+="✗ Python virtualenv\n"
        CHECK_OK=false
    fi

    if [ -f "$BASE_DIR/config/spotify.env" ]; then

        if grep -q '^SPOTIFY_ENABLED=true' \
            "$BASE_DIR/config/spotify.env"
        then
            RESULTS+="✓ Spotify configurado\n"
        else
            RESULTS+="○ Spotify desactivado\n"
        fi

    else

        RESULTS+="○ Spotify no configurado\n"

    fi

    if [ "$USE_GUI" = true ]; then

        if [ "$CHECK_OK" = true ]; then

            zenity --info \
                --title="$TITLE" \
                --text="COMPROBACIÓN FINAL

$RESULTS" \
                --width=650 \
                2>/dev/null || true

        else

            zenity --warning \
                --title="$TITLE" \
                --text="COMPROBACIÓN FINAL

$RESULTS" \
                --width=650 \
                2>/dev/null || true

        fi

    else

        echo
        echo "$RESULTS"

    fi

    return 0
}

# ==============================================================================
# RESUMEN
# ==============================================================================

show_summary()
{
    SUMMARY=""

    SUMMARY+="Idioma: $LANGUAGE\n"
    SUMMARY+="Voz Piper: $VOICE\n"

    if [ "$MODE_CHOICE" = "ptt" ]; then
        SUMMARY+="Activación: PTT\n"
        SUMMARY+="Teclado: $KEYBOARD_NAME\n"
        SUMMARY+="Tecla: $PTT_KEY\n"
    else
        SUMMARY+="Activación: Wake Word\n"
        SUMMARY+="Wake Word: Hey Mycroft\n"
    fi

    SUMMARY+="Entrada: $MIC_NAME\n"
    SUMMARY+="Salida: $OUTPUT_NAME\n"

    if [ "$SPOTIFY_ENABLED" = "true" ]; then
        SUMMARY+="Spotify: ✓ Configurado\n"
    else
        SUMMARY+="Spotify: ○ Desactivado\n"
    fi

    SUMMARY+="\nMMM-TuAsistente está listo."

    if [ "$USE_GUI" = true ]; then

        zenity --info \
            --title="$TITLE" \
            --text="INSTALACIÓN COMPLETADA

$SUMMARY

Reinicia MagicMirror con:

pm2 restart mm" \
            --width=700 \
            2>/dev/null || true

    else

        echo
        echo -e "${GREEN}====================================================${NC}"
        echo -e "${GREEN}          INSTALACIÓN COMPLETADA${NC}"
        echo -e "${GREEN}====================================================${NC}"
        echo
        echo -e "$SUMMARY"
        echo
        echo "Reinicia MagicMirror con:"
        echo
        echo "pm2 restart mm"
        echo

    fi
}

# ==============================================================================
# MENÚ PRINCIPAL GRÁFICO
# ==============================================================================

if [ "$USE_GUI" = true ]; then

    # --------------------------------------------------------------------------
    # IDIOMA
    # --------------------------------------------------------------------------

    select_language

    # --------------------------------------------------------------------------
    # VOZ
    # --------------------------------------------------------------------------

    select_voice

    # --------------------------------------------------------------------------
    # ACTIVACIÓN
    # --------------------------------------------------------------------------

    select_mode

    # --------------------------------------------------------------------------
    # PTT
    # --------------------------------------------------------------------------

    if [ "$MODE_CHOICE" = "ptt" ]; then

        select_keyboard
        select_ptt_key

    fi

    # --------------------------------------------------------------------------
    # AUDIO
    # --------------------------------------------------------------------------

    select_audio_devices

    # --------------------------------------------------------------------------
    # OLLAMA
    # --------------------------------------------------------------------------

    select_ollama

    if [ "$OLLAMA_ENABLED" = "true" ]; then
        select_ollama_model
    fi

    # --------------------------------------------------------------------------
    # SPOTIFY
    # --------------------------------------------------------------------------

    configure_spotify

else

    select_language
    select_voice
    select_mode

    if [ "$MODE_CHOICE" = "ptt" ]; then
        select_keyboard
        select_ptt_key
    fi

    select_audio_devices

    select_ollama

    if [ "$OLLAMA_ENABLED" = "true" ]; then
        select_ollama_model
    fi

    configure_spotify

fi

# ==============================================================================
# INSTALACIÓN
# ==============================================================================

progress_start

progress_update 11 "Fase 1/9 — Instalando dependencias del sistema..."
install_system_dependencies

progress_update 22 "Fase 2/9 — Comprobando Node.js y npm..."
install_node

progress_update 33 "Fase 3/9 — Instalando dependencias Node..."
install_node_dependencies

progress_update 44 "Fase 4/9 — Preparando Python..."
install_python_environment

progress_update 55 "Fase 5/9 — Instalando librerías Python..."
install_python_dependencies

progress_update 66 "Fase 6/9 — Configurando activación..."
install_openwakeword

progress_update 77 "Fase 7/9 — Preparando Piper TTS..."
install_piper

progress_update 88 "Fase 8/9 — Preparando Spotify Connect..."
install_spotify

# ==============================================================================
# CONFIGURACIONES
# ===============================================================================

progress_update 100 "Fase 9/9 — Configurando TuAsistente..."

# ------------------------------------------------------------------------------
# Guardar configuración de Spotify
# ------------------------------------------------------------------------------

save_spotify

# ------------------------------------------------------------------------------
# Instalar Ollama completo
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Ollama
# ------------------------------------------------------------------------------

if [ "$OLLAMA_ENABLED" = "true" ]; then

    if ! install_ollama_system; then
        echo -e "${RED}[ERROR] No se pudo instalar Ollama.${NC}"
        abort_install
    fi

    # --------------------------------------------------------------------------
    # Dependencia Node.js para MMM-TuAsistente
    # --------------------------------------------------------------------------

    if ! install_ollama_node; then
        echo -e "${RED}[ERROR] No se pudo instalar la dependencia Node.js de Ollama.${NC}"
        abort_install
    fi

else

    echo
    echo -e "${YELLOW}[INFO] Ollama omitido por el usuario.${NC}"
    echo -e "${YELLOW}[INFO] No se modificará la instalación existente de Ollama.${NC}"
    echo

fi

# ------------------------------------------------------------------------------
# Descargar modelo Ollama
# ------------------------------------------------------------------------------

if [ "$OLLAMA_ENABLED" = "true" ]; then

    if ! download_ollama_model; then
        echo -e "${RED}[ERROR] No se pudo preparar el modelo de Ollama.${NC}"
        abort_install
    fi

else

    echo -e "${YELLOW}[INFO] Descarga del modelo Ollama omitida.${NC}"

fi

configure_listen_key

configure_transcribe


configure_magicmirror

set_permissions

deactivate 2>/dev/null || true

# ==============================================================================
# COMPROBACIONES
# ==============================================================================

progress_close

run_checks

# ==============================================================================
# FINAL
# ==============================================================================

show_summary

exit 0
