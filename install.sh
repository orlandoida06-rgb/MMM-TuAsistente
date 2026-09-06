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
    VOICE="es_ES-davefx-medium"

    echo
    echo -e "${CYAN}===== VOZ PIPER =====${NC}"
    echo

    local piper_dir="$BASE_DIR/piper_tts"
    local installed_voices=""
    local installed_count=0

    # ----------------------------------------------------------------------
    # Detectar voces ya instaladas
    # ----------------------------------------------------------------------

    if [ -d "$piper_dir" ]; then
        installed_voices=$(
            find "$piper_dir" -maxdepth 1 -type f -name "*.onnx" \
                -printf "%f\n" 2>/dev/null |
            sed 's/\.onnx$//' |
            sort
        )
    fi

    if [ -n "$installed_voices" ]; then
        installed_count=$(printf '%s\n' "$installed_voices" | grep -c .)
    fi

    echo -e "${BLUE}Voces Piper instaladas:${NC}"

    if [ "$installed_count" -gt 0 ]; then
        printf '%s\n' "$installed_voices" | sed 's/^/  ✓ /'
    else
        echo "  (ninguna)"
    fi

    echo

    # ----------------------------------------------------------------------
    # Voces recomendadas
    # ----------------------------------------------------------------------

    local recommended=(
        "es_ES-davefx-medium"
        "es_ES-sharvard-medium"
        "en_US-lessac-medium"
        "fr_FR-upmc-medium"
        "de_DE-thorsten-medium"
        "it_IT-riccardo-x_low"
    )

    local selected=""
    local installed_array=()

    if [ -n "$installed_voices" ]; then
        while IFS= read -r voice; do
            [ -n "$voice" ] && installed_array+=("$voice")
        done <<< "$installed_voices"
    fi

    # ----------------------------------------------------------------------
    # GUI
    # ----------------------------------------------------------------------

    if [ "$USE_GUI" = true ]; then

        local args=()
        local first=true

        for voice in "${recommended[@]}"; do
            if [ "$first" = true ] && [ "$voice" = "$VOICE" ]; then
                args+=(TRUE "$voice")
                first=false
            else
                args+=(FALSE "$voice")
            fi
            args+=("Voz recomendada")
        done

        for voice in "${installed_array[@]}"; do
            case "$voice" in
                es_ES-davefx-medium|es_ES-sharvard-medium|en_US-lessac-medium|fr_FR-upmc-medium|de_DE-thorsten-medium|it_IT-riccardo-x_low)
                    continue
                    ;;
            esac

            args+=(FALSE "$voice" "Voz instalada")
        done

        args+=(FALSE "Otro modelo" "Introducir manualmente")

        selected=$(
            zenity --list \
                --title="$TITLE" \
                --text="Selecciona la voz de Piper:" \
                --radiolist \
                --column="Seleccionar" \
                --column="Voz" \
                --column="Tipo" \
                "${args[@]}" \
                --width=700 \
                --height=500 \
                2>/dev/null
        )

        [ $? -eq 0 ] || abort_install

        if [ "$selected" = "Otro modelo" ]; then
            selected=$(
                zenity --entry \
                    --title="$TITLE" \
                    --text="Introduce el nombre exacto de la voz Piper:" \
                    --entry-text="$VOICE" \
                    2>/dev/null
            )

            [ $? -eq 0 ] || abort_install
        fi

        if [ -n "$selected" ]; then
            VOICE="$selected"
        fi

    # ----------------------------------------------------------------------
    # TUI
    # ----------------------------------------------------------------------

    else

        echo "Voces recomendadas:"
        echo

        local menu_index=1

        for voice in "${recommended[@]}"; do
            if [ "$voice" = "$VOICE" ]; then
                echo "  $menu_index) $voice  [recomendada]"
            else
                echo "  $menu_index) $voice"
            fi
            menu_index=$((menu_index + 1))
        done

        local installed_start=$menu_index

        for voice in "${installed_array[@]}"; do
            case "$voice" in
                es_ES-davefx-medium|es_ES-sharvard-medium|en_US-lessac-medium|fr_FR-upmc-medium|de_DE-thorsten-medium|it_IT-riccardo-x_low)
                    continue
                    ;;
            esac

            echo "  $menu_index) $voice  [instalada]"
            menu_index=$((menu_index + 1))
        done

        local custom_choice=$menu_index
        echo "  $custom_choice) Otra voz"
        echo

        local voice_choice

        read -r -p "Selecciona una opción [$VOICE]: " voice_choice

        if [ -z "$voice_choice" ]; then
            voice_choice=1
        fi

        if ! [[ "$voice_choice" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}[INFO] Opción no válida. Se mantiene $VOICE${NC}"
            return 0
        fi

        if [ "$voice_choice" -ge 1 ] && [ "$voice_choice" -le 6 ]; then
            VOICE="${recommended[$((voice_choice - 1))]}"

        elif [ "$voice_choice" -ge "$installed_start" ] && [ "$voice_choice" -lt "$custom_choice" ]; then
            local installed_index=$((voice_choice - installed_start))

            if [ "$installed_index" -ge 0 ] && [ "$installed_index" -lt "${#installed_array[@]}" ]; then
                VOICE="${installed_array[$installed_index]}"
            fi

        elif [ "$voice_choice" -eq "$custom_choice" ]; then
            read -r -p "Introduce el nombre exacto de la voz Piper: " custom_voice

            if [ -n "$custom_voice" ]; then
                VOICE="$custom_voice"
            fi
        else
            echo -e "${YELLOW}[INFO] Opción fuera de rango. Se mantiene $VOICE${NC}"
        fi
    fi

    echo
    echo -e "${GREEN}[OK] Voz seleccionada: $VOICE${NC}"
    echo
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
        # NO FIJAR ÍNDICE SOUNDEVICE
        # ==================================================================
        #
        # MIC_CARD/MIC_DEVICE identifican el dispositivo ALSA real.
        #
        # El índice de SoundDevice puede cambiar entre reinicios debido
        # a PipeWire/ALSA, por lo que transcribe.py lo resolverá dinámicamente.

        MIC_INDEX="null"

        echo -e "${GREEN}[OK] Micrófono seleccionado: $MIC_NAME${NC}"
        echo -e "${GREEN}[OK] Identidad ALSA: hw:${MIC_CARD},${MIC_DEVICE}${NC}"
        echo -e "${YELLOW}[INFO] SoundDevice se resolverá dinámicamente al iniciar.${NC}"

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

Se utilizará la salida predeterminada de PipeWire."

        fi

    fi

    echo
    echo -e "${CYAN}===== AUDIO SELECCIONADO =====${NC}"
    echo "Micrófono: $MIC_NAME"
    echo "MIC_INDEX: $MIC_INDEX"
    echo "ALSA: hw:${MIC_CARD},${MIC_DEVICE}"
    echo "Salida: $OUTPUT_NAME"
    echo "OUTPUT_DEVICE: $OUTPUT_DEVICE"
    echo
}


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
    # OLLAMA NO INSTALADO
    # ======================================================================

    if ! command -v ollama >/dev/null 2>&1; then
        echo -e "${YELLOW}[INFO] Ollama todavía no está instalado.${NC}"
        echo -e "${YELLOW}[INFO] Se utilizará el modelo: $OLLAMA_MODEL${NC}"
        return 0
    fi

    # ======================================================================
    # OBTENER MODELOS EXISTENTES
    # ======================================================================

    local installed_models=""
    installed_models="$(
        ollama list 2>/dev/null |
        awk 'NR > 1 && $1 != "" {print $1}'
    )"

    echo "Modelos encontrados en Ollama:"
    echo

    if [ -n "$installed_models" ]; then
        while IFS= read -r model; do
            [ -n "$model" ] && echo "  ✓ $model"
        done <<< "$installed_models"
    else
        echo "  Ninguno"
    fi

    echo

    # ======================================================================
    # MODO GRÁFICO
    # ======================================================================

    if [ "$USE_GUI" = true ] &&
       command -v zenity >/dev/null 2>&1; then

        local zenity_args=()

        # Modelos recomendados
        zenity_args+=(
            TRUE  "qwen2.5:1.5b"
            "Ligero — recomendado para Raspberry Pi"
        )

        zenity_args+=(
            FALSE "gemma3:1b"
            "Muy ligero — respuestas rápidas"
        )

        zenity_args+=(
            FALSE "gemma3:4b"
            "Más capaz — necesita más recursos"
        )

        # Modelos instalados que no están en la lista anterior
        while IFS= read -r model; do

            [ -n "$model" ] || continue

            case "$model" in
                qwen2.5:1.5b|gemma3:1b|gemma3:4b)
                    continue
                    ;;
            esac

            zenity_args+=(
                FALSE "$model"
                "Ya instalado en este equipo"
            )

        done <<< "$installed_models"

        zenity_args+=(
            FALSE "Otro modelo"
            "Introducir el nombre exacto del modelo"
        )

        MODEL_CHOICE="$(
            zenity --list \
                --title="MMM-TuAsistente — Modelo de IA" \
                --text="Selecciona el modelo de Ollama que quieres utilizar:" \
                --radiolist \
                --width=850 \
                --height=500 \
                --column="Seleccionar" \
                --column="Modelo" \
                --column="Descripción" \
                "${zenity_args[@]}" \
                2>/dev/null
        )"

        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}[AVISO] Selección cancelada.${NC}"
            echo -e "${BLUE}[INFO] Se utilizará: qwen2.5:1.5b${NC}"
            OLLAMA_MODEL="qwen2.5:1.5b"
            return 0
        fi

        if [ "$MODEL_CHOICE" = "Otro modelo" ]; then

            OLLAMA_MODEL="$(
                zenity --entry \
                    --title="MMM-TuAsistente — Modelo personalizado" \
                    --text="Introduce el nombre exacto del modelo de Ollama:" \
                    --entry-text="qwen2.5:1.5b" \
                    --width=650 \
                    2>/dev/null
            )"

            [ -n "$OLLAMA_MODEL" ] ||
                OLLAMA_MODEL="qwen2.5:1.5b"

        else

            OLLAMA_MODEL="$MODEL_CHOICE"

        fi

    # ======================================================================
    # MODO TEXTO
    # ======================================================================

    else

        echo "Modelos recomendados:"
        echo
        echo "1) qwen2.5:1.5b — Ligero"
        echo "2) gemma3:1b    — Muy ligero"
        echo "3) gemma3:4b    — Más capaz"
        echo

        local menu_index=4
        local model_number=0
        local -a installed_array=()

        while IFS= read -r model; do

            [ -n "$model" ] || continue

            case "$model" in
                qwen2.5:1.5b|gemma3:1b|gemma3:4b)
                    continue
                    ;;
            esac

            installed_array+=("$model")

            echo "$menu_index) $model — Ya instalado"

            menu_index=$((menu_index + 1))

        done <<< "$installed_models"

        echo "$menu_index) Otro modelo"
        echo

        read -rp "Elige [1-$menu_index]: " MODEL_CHOICE

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

            *)
                local installed_index=$((MODEL_CHOICE - 4))

                if [ "$installed_index" -ge 0 ] &&
                   [ "$installed_index" -lt "${#installed_array[@]}" ]; then

                    OLLAMA_MODEL="${installed_array[$installed_index]}"

                elif [ "$MODEL_CHOICE" -eq "$menu_index" ]; then

                    read -rp "Nombre exacto del modelo: " OLLAMA_MODEL

                    [ -n "$OLLAMA_MODEL" ] ||
                        OLLAMA_MODEL="qwen2.5:1.5b"

                else

                    echo -e "${YELLOW}[AVISO] Opción no válida.${NC}"
                    OLLAMA_MODEL="qwen2.5:1.5b"

                fi
                ;;

        esac

    fi

    echo
    echo -e "${GREEN}[OK] Modelo seleccionado: $OLLAMA_MODEL${NC}"
    echo

    return 0
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


# ==============================================================================
# SELECCIÓN DE COMPONENTES
# ==============================================================================

select_components()
{
    INSTALL_MAGICMIRROR_CONFIG=false
    # Valores por defecto
    INSTALL_TUASISTENTE=false
    INSTALL_SPOTIFY=false
    INSTALL_LIBRESPOT=false
    INSTALL_OLLAMA=false
    INSTALL_PIPER=false
    INSTALL_WAKEWORD=false
    INSTALL_AUDIO=false

    local selected=""

    echo
    echo -e "${CYAN}===== COMPONENTES A INSTALAR =====${NC}"
    echo

    # --------------------------------------------------------------------------
    # GUI
    # --------------------------------------------------------------------------

    if [ "$USE_GUI" = true ]; then

        selected=$(
            zenity --list \
                --title="$TITLE" \
                --text="Selecciona los componentes que quieres instalar:" \
                --checklist \
                --column="Instalar" \
                --column="Componente" \
                --column="Descripción" \
                FALSE "MMM-TuAsistente" "Asistente de voz e IA" \
                FALSE "MMM-TuAsistente-Spotify" "Interfaz y control de Spotify" \
                FALSE "LibreSpot" "Spotify Connect independiente" \
                FALSE "Ollama" "Motor de IA local" \
                FALSE "Piper TTS" "Síntesis de voz" \
                FALSE "Wake Word / PTT" "Activación por voz o teclado" \
                FALSE "Audio" "Configuración de entrada y salida" \
                FALSE "Configuración automática de MagicMirror" "Añadir automáticamente los módulos a config.js" \
                --separator="|" \
                --width=900 \
                --height=500 \
                2>/dev/null
        )

        [ $? -eq 0 ] || abort_install

    # --------------------------------------------------------------------------
    # TUI
    # --------------------------------------------------------------------------

    else

        selected=$(
            whiptail \
                --title="$TITLE" \
                --checklist \
                "Selecciona los componentes que quieres instalar:" \
                20 90 10 \
                "MMM-TuAsistente" \
                "Asistente de voz e IA" \
                OFF \
                "MMM-TuAsistente-Spotify" \
                "Interfaz y control de Spotify" \
                OFF \
                "LibreSpot" \
                "Spotify Connect independiente" \
                OFF \
                "Ollama" \
                "Motor de IA local" \
                OFF \
                "Piper TTS" \
                "Síntesis de voz" \
                OFF \
                "Wake Word / PTT" \
                "Activación por voz o teclado" \
                OFF \
                "Audio" \
                "Configuración de entrada y salida" \
                OFF \
                "Configuración automática de MagicMirror" \
                "Añadir automáticamente los módulos a config.js" \
                OFF \
                3>&1 1>&2 2>&3
        )

        [ $? -eq 0 ] || abort_install

    fi

    # --------------------------------------------------------------------------
    # Procesar selección
    # --------------------------------------------------------------------------

    if [[ "$selected" == *"MMM-TuAsistente"* ]]; then
        INSTALL_TUASISTENTE=true
    fi

    if [[ "$selected" == *"MMM-TuAsistente-Spotify"* ]]; then
        INSTALL_SPOTIFY=true
    fi

    if [[ "$selected" == *"LibreSpot"* ]]; then
        INSTALL_LIBRESPOT=true
    fi

    if [[ "$selected" == *"Ollama"* ]]; then
        INSTALL_OLLAMA=true
    fi

    if [[ "$selected" == *"Piper TTS"* ]]; then
        INSTALL_PIPER=true
    fi

    if [[ "$selected" == *"Wake Word / PTT"* ]]; then
        INSTALL_WAKEWORD=true
    fi

    if [[ "$selected" == *"Audio"* ]]; then
        INSTALL_AUDIO=true
    fi

    if [[ "$selected" == *"Configuración automática de MagicMirror"* ]]; then
        INSTALL_MAGICMIRROR_CONFIG=true
    fi

    # --------------------------------------------------------------------------
    # Dependencias automáticas
    # --------------------------------------------------------------------------

    # TuAsistente necesita Piper y activación.
    if [ "$INSTALL_TUASISTENTE" = true ]; then
        INSTALL_PIPER=true
        INSTALL_WAKEWORD=true
        INSTALL_AUDIO=true
    fi

    # Spotify necesita Node/npm y LibreSpot para reproducir audio.
    if [ "$INSTALL_SPOTIFY" = true ]; then
        INSTALL_LIBRESPOT=true
        echo -e "${BLUE}[INFO] MMM-TuAsistente-Spotify requiere Node.js/npm.${NC}"
        echo -e "${BLUE}[INFO] LibreSpot se seleccionará automáticamente como dependencia.${NC}"
    fi

    echo
    echo -e "${CYAN}===== SELECCIÓN =====${NC}"

    [ "$INSTALL_TUASISTENTE" = true ] && \
        echo -e "${GREEN}✓ MMM-TuAsistente${NC}"

    [ "$INSTALL_SPOTIFY" = true ] && \
        echo -e "${GREEN}✓ MMM-TuAsistente-Spotify${NC}"

    [ "$INSTALL_LIBRESPOT" = true ] && \
        echo -e "${GREEN}✓ LibreSpot${NC}"

    [ "$INSTALL_OLLAMA" = true ] && \
        echo -e "${GREEN}✓ Ollama${NC}"

    [ "$INSTALL_PIPER" = true ] && \
        echo -e "${GREEN}✓ Piper TTS${NC}"

    [ "$INSTALL_WAKEWORD" = true ] && \
        echo -e "${GREEN}✓ Wake Word / PTT${NC}"

    [ "$INSTALL_AUDIO" = true ] && \
        echo -e "${GREEN}✓ Audio${NC}"

    echo

    return 0
}


configure_spotify()
{
    SPOTIFY_ENABLED="false"
    SPOTIFY_MODE=""

    if [ "$INSTALL_SPOTIFY" != true ]; then
        echo -e "${YELLOW}[OMITIDO] MMM-TuAsistente-Spotify no seleccionado.${NC}"
        return 0
    fi

    echo
    echo -e "${CYAN}===== CONFIGURACIÓN MMM-TuAsistente-SPOTIFY =====${NC}"
    echo

    if [ "$USE_GUI" = true ]; then

        if gui_question \
            "¿Quieres activar la integración con Spotify?

MMM-TuAsistente-Spotify proporciona:

• Interfaz de Spotify
• Búsqueda de canciones
• Reproducción
• Controles
• Portadas

LibreSpot se gestiona mediante su propio componente.

¿Quieres activar Spotify?"
        then
            SPOTIFY_ENABLED="true"
            SPOTIFY_MODE="connect"
        else
            return 0
        fi

    else

        if whiptail \
            --title="$TITLE" \
            --yesno \
            "¿Quieres activar la integración con Spotify?

MMM-TuAsistente-Spotify proporciona:

• Interfaz de Spotify
• Búsqueda de canciones
• Reproducción
• Controles
• Portadas

LibreSpot se gestiona mediante su propio componente.

¿Quieres activar Spotify?" \
            20 78
        then
            SPOTIFY_ENABLED="true"
            SPOTIFY_MODE="connect"
        else
            return 0
        fi

    fi

    echo
    echo -e "${GREEN}[OK] Integración Spotify seleccionada.${NC}"
    echo -e "${BLUE}[INFO] MMM-TuAsistente-Spotify se instalará de forma independiente.${NC}"
    echo -e "${BLUE}[INFO] LibreSpot se gestiona mediante su propio componente.${NC}"
}

install_spotify()
{
    echo
    echo -e "${BLUE}[SPOTIFY] Preparando MMM-TuAsistente-Spotify...${NC}"

    if [ "$INSTALL_SPOTIFY" != true ]; then
        echo -e "${YELLOW}[OMITIDO] MMM-TuAsistente-Spotify no seleccionado.${NC}"
        return 0
    fi

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se prepararía MMM-TuAsistente-Spotify.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Se comprobaría Node.js/npm.${NC}"
        echo -e "${GREEN}[OK] Spotify simulado.${NC}"
        return 0
    fi

    echo
    echo -e "${CYAN}===== MMM-TuAsistente-SPOTIFY =====${NC}"
    echo

    # --------------------------------------------------------------
    # DESCARGAR / COMPROBAR MÓDULO
    # --------------------------------------------------------------

    SPOTIFY_MODULE_DIR="$(cd "$BASE_DIR/../MMM-TuAsistente-Spotify" && pwd)"
    SPOTIFY_REPO="https://github.com/orlandoida06-rgb/MMM-TuAsistente-Spotify.git"

    if [ ! -d "$SPOTIFY_MODULE_DIR" ]; then
        echo
        echo "[INFO] MMM-TuAsistente-Spotify no está instalado."
        echo "[INFO] Descargando desde GitHub..."
        echo "[INFO] $SPOTIFY_REPO"
        echo

        git clone "$SPOTIFY_REPO" "$SPOTIFY_MODULE_DIR" || {
            echo -e "${RED}[ERROR] No se pudo descargar MMM-TuAsistente-Spotify.${NC}"
            abort_install
        }

        echo -e "${GREEN}[OK] MMM-TuAsistente-Spotify descargado.${NC}"
    else
        echo "[OK] Módulo encontrado:"
        echo "$SPOTIFY_MODULE_DIR"
    fi

    # --------------------------------------------------------------
    # NODE / NPM
    # --------------------------------------------------------------

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] Node.js no está instalado.${NC}"
        abort_install
    fi

    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] npm no está instalado.${NC}"
        abort_install
    fi

    echo "[INFO] Node.js: $(node --version)"
    echo "[INFO] npm: $(npm --version)"

    # --------------------------------------------------------------
    # DEPENDENCIAS DEL MÓDULO
    # --------------------------------------------------------------

    if [ -f "$SPOTIFY_MODULE_DIR/package.json" ]; then
        echo
        echo "[INFO] Instalando dependencias de MMM-TuAsistente-Spotify..."

        (
            cd "$SPOTIFY_MODULE_DIR" || exit 1
            npm install --omit=dev
        ) || abort_install

        echo -e "${GREEN}[OK] Dependencias de Spotify preparadas.${NC}"
    else
        echo -e "${YELLOW}[INFO] El módulo no contiene package.json.${NC}"
        echo "[INFO] No hay dependencias npm que instalar."
    fi

    # --------------------------------------------------------------
    # COMPROBACIONES DEL MÓDULO
    # --------------------------------------------------------------

    if [ ! -f "$SPOTIFY_MODULE_DIR/MMM-TuAsistente-Spotify.js" ]; then
        echo -e "${RED}[ERROR] Falta MMM-TuAsistente-Spotify.js.${NC}"
        abort_install
    fi

    if [ ! -f "$SPOTIFY_MODULE_DIR/node_helper.js" ]; then
        echo -e "${RED}[ERROR] Falta node_helper.js.${NC}"
        abort_install
    fi

    node --check "$SPOTIFY_MODULE_DIR/MMM-TuAsistente-Spotify.js" \
        || abort_install

    node --check "$SPOTIFY_MODULE_DIR/node_helper.js" \
        || abort_install

    echo -e "${GREEN}[OK] Código de MMM-TuAsistente-Spotify correcto.${NC}"

    # --------------------------------------------------------------
    # SOCKET LIBRESPOT
    # --------------------------------------------------------------

    if [ -S "/tmp/tuasistente-spotify.sock" ]; then
        echo -e "${GREEN}[OK] Socket LibreSpot detectado.${NC}"
    else
        echo -e "${YELLOW}[AVISO] Socket LibreSpot no detectado.${NC}"
        echo "[INFO] El módulo Spotify podrá instalarse, pero LibreSpot"
        echo "[INFO] deberá estar seleccionado o instalado por separado."
    fi

    echo
    echo -e "${GREEN}[OK] MMM-TuAsistente-Spotify preparado.${NC}"
}


# ==============================================================================
# INSTALAR LIBRESPOT INDEPENDIENTE
# ==============================================================================

install_librespot()
{
    echo
    echo -e "${BLUE}[LIBRESPOT] Preparando LibreSpot independiente...${NC}"

    if [ "$INSTALL_LIBRESPOT" != true ]; then
        echo -e "${YELLOW}[OMITIDO] LibreSpot no seleccionado.${NC}"
        return 0
    fi

    # ------------------------------------------------------------------
    # SIMULACIÓN
    # ------------------------------------------------------------------

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se comprobaría LibreSpot.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Servicio: tuasistente-spotify.service${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] Socket: /tmp/tuasistente-spotify.sock${NC}"
        echo -e "${GREEN}[OK] LibreSpot simulado.${NC}"
        return 0
    fi

    echo
    echo -e "${CYAN}===== LIBRESPOT =====${NC}"
    echo

    # ------------------------------------------------------------------
    # ARQUITECTURA
    # ------------------------------------------------------------------

    ARCH="$(uname -m)"

    case "$ARCH" in
        aarch64|arm64)
            echo -e "${GREEN}[OK] Arquitectura compatible: $ARCH${NC}"
            ;;
        *)
            echo -e "${RED}[ERROR] LibreSpot requiere ARM64/aarch64.${NC}"
            echo "[INFO] Arquitectura detectada: $ARCH"
            abort_install
            ;;
    esac

    # ------------------------------------------------------------------
    # INSTALACIÓN ACTUAL
    # ------------------------------------------------------------------

    LIBRESPOT_DIR="/opt/tuasistente/librespot"
    LIBRESPOT_BIN="$LIBRESPOT_DIR/target/release/librespot"
    LIBRESPOT_SERVICE="/etc/systemd/system/tuasistente-spotify.service"
    LIBRESPOT_SOCKET="/tmp/tuasistente-spotify.sock"

    # ------------------------------------------------------------------
    # SI YA EXISTE UNA INSTALACIÓN FUNCIONAL, NO TOCARLA
    # ------------------------------------------------------------------

    if [ -x "$LIBRESPOT_BIN" ] &&
       [ -f "$LIBRESPOT_SERVICE" ]; then

        echo -e "${GREEN}[OK] Instalación de LibreSpot existente detectada.${NC}"
        echo
        echo "Binario:"
        echo "$LIBRESPOT_BIN"
        echo
        echo "Servicio:"
        echo "tuasistente-spotify.service"

        echo
        echo "[INFO] No se reinstalará LibreSpot."
        echo "[INFO] Se conservará la instalación existente."

        sudo systemctl daemon-reload >/dev/null 2>&1 || true

        if systemctl is-active --quiet tuasistente-spotify.service; then
            echo -e "${GREEN}[OK] Servicio LibreSpot activo.${NC}"
        else
            echo -e "${YELLOW}[AVISO] Servicio LibreSpot no está activo.${NC}"
            echo "[INFO] Intentando iniciarlo..."

            sudo systemctl start tuasistente-spotify.service \
                || abort_install

            sleep 2

            if ! systemctl is-active --quiet tuasistente-spotify.service; then
                echo -e "${RED}[ERROR] LibreSpot no pudo iniciarse.${NC}"
                sudo systemctl status \
                    tuasistente-spotify.service \
                    --no-pager || true
                abort_install
            fi

            echo -e "${GREEN}[OK] Servicio LibreSpot iniciado.${NC}"
        fi

        if [ -S "$LIBRESPOT_SOCKET" ]; then
            echo -e "${GREEN}[OK] Socket LibreSpot detectado.${NC}"
        else
            echo -e "${YELLOW}[AVISO] Socket todavía no detectado.${NC}"
            echo "[INFO] Se comprobará cuando el servicio esté operativo."
        fi

        echo
        echo -e "${GREEN}[OK] LibreSpot existente conservado.${NC}"
        return 0
    fi

    # ------------------------------------------------------------------
    # INSTALACIÓN NUEVA
    # ------------------------------------------------------------------

    echo -e "${YELLOW}[INFO] No se encontró una instalación completa de LibreSpot.${NC}"
    echo
    echo "[INFO] Esta versión del instalador requiere preparar LibreSpot"
    echo "[INFO] desde el repositorio independiente del proyecto."
    echo

    if [ ! -d "$LIBRESPOT_DIR/.git" ]; then
        echo -e "${RED}[ERROR] No existe el repositorio LibreSpot en:${NC}"
        echo "$LIBRESPOT_DIR"
        echo
        echo "[INFO] No se realizará una instalación alternativa antigua."
        echo "[INFO] Esto evita crear el servicio obsoleto"
        abort_install
    fi

    echo -e "${GREEN}[OK] Repositorio LibreSpot encontrado.${NC}"

    if [ ! -x "$LIBRESPOT_BIN" ]; then
        echo -e "${YELLOW}[INFO] El binario de LibreSpot todavía no está compilado.${NC}"
        echo
        echo "[INFO] Compilación de LibreSpot pendiente."
        echo "[INFO] No se modificará la instalación actual automáticamente."
        abort_install
    fi

    echo -e "${GREEN}[OK] Binario LibreSpot encontrado.${NC}"

    if [ ! -f "$LIBRESPOT_SERVICE" ]; then
        echo -e "${RED}[ERROR] Falta el servicio:${NC}"
        echo "$LIBRESPOT_SERVICE"
        abort_install
    fi

    sudo systemctl daemon-reload || abort_install
    sudo systemctl enable tuasistente-spotify.service || abort_install
    sudo systemctl start tuasistente-spotify.service || abort_install

    sleep 2

    if ! systemctl is-active --quiet tuasistente-spotify.service; then
        echo -e "${RED}[ERROR] LibreSpot no está activo.${NC}"
        sudo systemctl status \
            tuasistente-spotify.service \
            --no-pager || true
        abort_install
    fi

    echo -e "${GREEN}[OK] LibreSpot activo.${NC}"

    if [ -S "$LIBRESPOT_SOCKET" ]; then
        echo -e "${GREEN}[OK] Socket LibreSpot disponible.${NC}"
    else
        echo -e "${YELLOW}[AVISO] Socket LibreSpot todavía no detectado.${NC}"
    fi

    echo
    echo -e "${GREEN}[OK] LibreSpot preparado.${NC}"
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

    if [ "$INSTALL_TUASISTENTE" != true ]; then
        echo -e "${YELLOW}[OMITIDO] Axios no necesario para los componentes seleccionados.${NC}"
        return 0
    fi

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se omite npm install axios.${NC}"
        echo -e "${GREEN}[OK] Dependencias Node simuladas.${NC}"
        return 0
    fi

    cd "$BASE_DIR" || abort_install

    npm install axios ||
        abort_install

    echo -e "${GREEN}[OK] Axios preparado para MMM-TuAsistente.${NC}"
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

    # --------------------------------------------------------------------------
    # Componente no seleccionado
    # --------------------------------------------------------------------------

    if [ "$INSTALL_WAKEWORD" != true ]; then
        echo -e "${YELLOW}[OMITIDO] Wake Word / PTT no seleccionado.${NC}"
        return 0
    fi

    echo -e "${BLUE}[ACTIVACIÓN] Configurando sistema de activación...${NC}"

    # --------------------------------------------------------------------------
    # PTT
    # --------------------------------------------------------------------------

    if [ "$MODE_CHOICE" = "ptt" ]; then
        echo -e "${GREEN}[OK] PTT seleccionado.${NC}"
        echo -e "${BLUE}[INFO] No se instalará OpenWakeWord.${NC}"
        return 0
    fi

    # --------------------------------------------------------------------------
    # Wake Word
    # --------------------------------------------------------------------------

    if [ "$MODE_CHOICE" != "wakeword" ]; then
        echo -e "${YELLOW}[OMITIDO] No se ha seleccionado Wake Word.${NC}"
        return 0
    fi

    if [ "$SIMULATION" = true ]; then
        echo -e "${YELLOW}[SIMULACIÓN] Se instalaría OpenWakeWord.${NC}"
        echo -e "${YELLOW}[SIMULACIÓN] También se instalaría PyAudio.${NC}"
        echo -e "${GREEN}[OK] Wake Word simulado.${NC}"
        return 0
    fi

    echo "[INFO] Comprobando OpenWakeWord..."

    # --------------------------------------------------------------------------
    # Instalar solamente si no está disponible
    # --------------------------------------------------------------------------

    if "$BASE_DIR/venv/bin/python" - <<'PYTHON'
try:
    import openwakeword
    print("[OK] OpenWakeWord ya está instalado.")
except Exception:
    raise SystemExit(1)
PYTHON
    then
        :
    else
        echo "[INFO] Instalando OpenWakeWord..."
        "$BASE_DIR/venv/bin/python" -m pip install \
            openwakeword \
            -q ||
            abort_install
    fi

    # --------------------------------------------------------------------------
    # PyAudio
    # --------------------------------------------------------------------------

    if "$BASE_DIR/venv/bin/python" - <<'PYTHON'
try:
    import pyaudio
    print("[OK] PyAudio ya está instalado.")
except Exception:
    raise SystemExit(1)
PYTHON
    then
        :
    else
        echo "[INFO] Instalando PyAudio..."
        "$BASE_DIR/venv/bin/python" -m pip install \
            pyaudio \
            -q ||
            abort_install
    fi

    # --------------------------------------------------------------------------
    # Verificación del modelo
    # --------------------------------------------------------------------------

    echo "[INFO] Comprobando modelo hey_mycroft..."

    if "$BASE_DIR/venv/bin/python" - <<'PYTHON'
from pathlib import Path
import openwakeword

models_dir = (
    Path(openwakeword.__file__).resolve().parent
    / "resources"
    / "models"
)

models = sorted(models_dir.glob("hey_mycroft_v*.onnx"))

if not models:
    raise SystemExit(1)

print(f"[OK] Modelo encontrado: {models[0]}")
PYTHON
    then
        :
    else
        echo -e "${RED}[ERROR] No se encontró el modelo hey_mycroft.${NC}"
        abort_install
    fi

    echo -e "${GREEN}[OK] OpenWakeWord preparado.${NC}"
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
# ALSA_DEVICE
# ------------------------------------------------------------
# Guardamos la identidad ALSA del micrófono, pero NO fijamos
# DEVICE_INDEX porque SoundDevice/PipeWire puede cambiar sus
# índices entre reinicios.

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

# ------------------------------------------------------------
# DEVICE_INDEX
# ------------------------------------------------------------
# La selección real se hará dinámicamente al arrancar
# transcribe.py.

content = re.sub(
    r"^\s*DEVICE_INDEX\s*=.*$",
    "DEVICE_INDEX = None",
    content,
    count=1,
    flags=re.MULTILINE
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(
    f"[OK] transcribe.py configurado: "
    f"DEVICE_INDEX=None, "
    f"ALSA_DEVICE={alsa_device}"
)

PYTHON
}

# ==============================================================================
# CONFIG.JS
# ==============================================================================

configure_magicmirror()
{
    # ------------------------------------------------------------------
    # CONFIGURACIÓN AUTOMÁTICA DE MAGICMIRROR
    # ------------------------------------------------------------------

    if [ "$INSTALL_MAGICMIRROR_CONFIG" != true ]; then
        echo -e "${YELLOW}[OMITIDO] Configuración automática de MagicMirror no seleccionada.${NC}"
        return 0
    fi

    # ------------------------------------------------------------------
    # Comprobar config.js
    # ------------------------------------------------------------------

    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "${RED}[ERROR] No se encontró config.js:${NC}"
        echo "$CONFIG_PATH"
        abort_install
    fi

    # ------------------------------------------------------------------
    # Detectar módulos que se pueden configurar
    # ------------------------------------------------------------------

    DETECT_TUASISTENTE=false
    DETECT_SPOTIFY=false

    TUASISTENTE_MODULE_DIR="$BASE_DIR"
    SPOTIFY_MODULE_DIR="$BASE_DIR/../MMM-TuAsistente-Spotify"

    if [ -d "$TUASISTENTE_MODULE_DIR" ] &&
       [ -f "$TUASISTENTE_MODULE_DIR/MMM-TuAsistente.js" ]; then
        DETECT_TUASISTENTE=true
    fi

    if [ -d "$SPOTIFY_MODULE_DIR" ] &&
       [ -f "$SPOTIFY_MODULE_DIR/MMM-TuAsistente-Spotify.js" ]; then
        DETECT_SPOTIFY=true
    fi

    # Si el módulo fue seleccionado explícitamente, tiene prioridad
    if [ "$INSTALL_TUASISTENTE" = true ]; then
        DETECT_TUASISTENTE=true
    fi

    if [ "$INSTALL_SPOTIFY" = true ]; then
        DETECT_SPOTIFY=true
    fi

    # ------------------------------------------------------------------
    # Comprobar si hay módulos disponibles
    # ------------------------------------------------------------------

    if [ "$DETECT_TUASISTENTE" != true ] &&
       [ "$DETECT_SPOTIFY" != true ]; then

        echo -e "${YELLOW}[OMITIDO] No se encontraron módulos MagicMirror instalados para configurar.${NC}"
        return 0
    fi

    echo
    echo "===== MÓDULOS DETECTADOS PARA CONFIGURACIÓN ====="

    [ "$DETECT_TUASISTENTE" = true ] &&
        echo "✓ MMM-TuAsistente"

    [ "$DETECT_SPOTIFY" = true ] &&
        echo "✓ MMM-TuAsistente-Spotify"

    echo

    # ------------------------------------------------------------------
    # Preguntar si se quiere configurar automáticamente
    # ------------------------------------------------------------------

    ADD_CONFIG=false

    if [ "$USE_GUI" = true ]; then

        CONFIG_QUESTION="¿Quieres configurar automáticamente estos módulos en config.js?

"

        [ "$DETECT_TUASISTENTE" = true ] &&
            CONFIG_QUESTION+="• MMM-TuAsistente
"

        [ "$DETECT_SPOTIFY" = true ] &&
            CONFIG_QUESTION+="• MMM-TuAsistente-Spotify
"

        if gui_question "$CONFIG_QUESTION"; then
            ADD_CONFIG=true
        fi

    else

        CONFIG_QUESTION="¿Quieres configurar automáticamente estos módulos en config.js?

"

        [ "$DETECT_TUASISTENTE" = true ] &&
            CONFIG_QUESTION+="• MMM-TuAsistente\n"

        [ "$DETECT_SPOTIFY" = true ] &&
            CONFIG_QUESTION+="• MMM-TuAsistente-Spotify\n"

        if whiptail \
            --title="$TITLE" \
            --yesno "$CONFIG_QUESTION" \
            15 75
        then
            ADD_CONFIG=true
        fi

    fi

    [ "$ADD_CONFIG" = true ] || return 0

    # ------------------------------------------------------------------
    # Simulación
    # ------------------------------------------------------------------

    if [ "$SIMULATION" = true ]; then

        if [ "$DETECT_TUASISTENTE" = true ]; then
            echo -e "${YELLOW}[SIMULACIÓN] Se añadiría MMM-TuAsistente a config.js.${NC}"
        fi

        if [ "$DETECT_SPOTIFY" = true ]; then
            echo -e "${YELLOW}[SIMULACIÓN] Se añadiría MMM-TuAsistente-Spotify a config.js.${NC}"
        fi

        return 0
    fi

    # ------------------------------------------------------------------
    # Detectar qué módulos faltan realmente en config.js
    # ------------------------------------------------------------------

    ADD_TUASISTENTE=false
    ADD_SPOTIFY=false

    if [ "$DETECT_TUASISTENTE" = true ]; then

        if grep -q 'module: "MMM-TuAsistente"' "$CONFIG_PATH"; then
            echo -e "${YELLOW}[AVISO] MMM-TuAsistente ya está presente en config.js.${NC}"
        else
            ADD_TUASISTENTE=true
        fi

    fi

    if [ "$DETECT_SPOTIFY" = true ]; then

        if grep -q 'module: "MMM-TuAsistente-Spotify"' "$CONFIG_PATH"; then
            echo -e "${YELLOW}[AVISO] MMM-TuAsistente-Spotify ya está presente en config.js.${NC}"
        else
            ADD_SPOTIFY=true
        fi

    fi

    if [ "$ADD_TUASISTENTE" != true ] &&
       [ "$ADD_SPOTIFY" != true ]; then

        echo -e "${GREEN}[OK] Los módulos detectados ya están en config.js.${NC}"
        return 0
    fi

    # ------------------------------------------------------------------
    # Copia de seguridad
    # ------------------------------------------------------------------

    BACKUP="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"

    cp "$CONFIG_PATH" "$BACKUP" || abort_install

    echo "[INFO] Copia de seguridad creada:"
    echo "$BACKUP"

    TEMP_CONFIG="/tmp/config_mmm_tuasistente_$$.js"

    # ------------------------------------------------------------------
    # Crear bloques seleccionados
    # ------------------------------------------------------------------

    : > "$TEMP_CONFIG"

    if [ "$ADD_TUASISTENTE" = true ]; then

        cat >> "$TEMP_CONFIG" <<CONFIGBLOCK
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
            model: "$OLLAMA_MODEL",
            hideDelay: 18000,
            autoHideTimeout: 30000
        }
    },
CONFIGBLOCK

    fi

    if [ "$ADD_SPOTIFY" = true ]; then

        cat >> "$TEMP_CONFIG" <<CONFIGBLOCK
    {
        module: "MMM-TuAsistente-Spotify",
        position: "bottom_left"
    },
CONFIGBLOCK

    fi

    # ------------------------------------------------------------------
    # Insertar después de modules: [
    # ------------------------------------------------------------------

    if ! python3 - \
        "$CONFIG_PATH" \
        "$TEMP_CONFIG" <<'PYTHON'

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

content = content.replace(
    marker,
    marker + "\n" + block,
    1
)

with open(config_path, "w", encoding="utf-8") as f:
    f.write(content)

PYTHON
    then
        echo -e "${RED}[ERROR] No se pudo modificar config.js.${NC}"
        echo "[INFO] Restaurando copia de seguridad..."
        cp "$BACKUP" "$CONFIG_PATH" || true
        echo -e "${GREEN}[OK] config.js restaurado desde el backup.${NC}"
        rm -f "$TEMP_CONFIG"
        abort_install
    fi

    rm -f "$TEMP_CONFIG"

    # ------------------------------------------------------------------
    # Verificación
    # ------------------------------------------------------------------

    if node --check "$CONFIG_PATH" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Sintaxis de config.js correcta.${NC}"
    else
        echo -e "${RED}[ERROR] config.js contiene un error de sintaxis.${NC}"
        echo "[INFO] Restaurando copia de seguridad..."
        cp "$BACKUP" "$CONFIG_PATH" || true
        rm -f "$TEMP_CONFIG"
        abort_install
    fi

    if [ "$ADD_TUASISTENTE" = true ]; then
        if grep -q 'module: "MMM-TuAsistente"' "$CONFIG_PATH"; then
            echo -e "${GREEN}[OK] MMM-TuAsistente añadido a config.js.${NC}"
        else
            echo -e "${RED}[ERROR] No se pudo añadir MMM-TuAsistente.${NC}"
            echo "[INFO] Restaurando copia de seguridad..."
            cp "$BACKUP" "$CONFIG_PATH" || true
            abort_install
        fi
    fi

    if [ "$ADD_SPOTIFY" = true ]; then
        if grep -q 'module: "MMM-TuAsistente-Spotify"' "$CONFIG_PATH"; then
            echo -e "${GREEN}[OK] MMM-TuAsistente-Spotify añadido a config.js.${NC}"
        else
            echo -e "${RED}[ERROR] No se pudo añadir MMM-TuAsistente-Spotify.${NC}"
            echo "[INFO] Restaurando copia de seguridad..."
            cp "$BACKUP" "$CONFIG_PATH" || true
            abort_install
        fi
    fi

    echo -e "${GREEN}[OK] Configuración automática de MagicMirror completada.${NC}"
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

    # ------------------------------------------------------------------
    # MMM-TuAsistente
    # ------------------------------------------------------------------

    if [ "$INSTALL_TUASISTENTE" = true ]; then

        if node --check "$BASE_DIR/node_helper.js" >/dev/null 2>&1; then
            RESULTS+="✓ MMM-TuAsistente: node_helper.js\n"
        else
            RESULTS+="✗ MMM-TuAsistente: node_helper.js\n"
            CHECK_OK=false
        fi

        if [ -f "$BASE_DIR/MMM-TuAsistente.js" ] &&
           node --check "$BASE_DIR/MMM-TuAsistente.js" >/dev/null 2>&1
        then
            RESULTS+="✓ MMM-TuAsistente.js\n"
        else
            RESULTS+="✗ MMM-TuAsistente.js\n"
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

    fi

    # ------------------------------------------------------------------
    # PTT
    # ------------------------------------------------------------------

    if [ "$INSTALL_WAKEWORD" = true ] &&
       [ "$MODE_CHOICE" = "ptt" ]; then

        if [ -f "$BASE_DIR/listen_key.py" ] &&
           "$BASE_DIR/venv/bin/python" -m py_compile \
           "$BASE_DIR/listen_key.py" >/dev/null 2>&1
        then
            RESULTS+="✓ PTT / listen_key.py\n"
        else
            RESULTS+="✗ PTT / listen_key.py\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Wake Word
    # ------------------------------------------------------------------

    if [ "$INSTALL_WAKEWORD" = true ] &&
       [ "$MODE_CHOICE" = "wakeword" ]; then

        if "$BASE_DIR/venv/bin/python" - <<'PYTHON' >/dev/null 2>&1
import openwakeword
from pathlib import Path

models_dir = (
    Path(openwakeword.__file__).resolve().parent
    / "resources"
    / "models"
)

models = list(models_dir.glob("hey_mycroft_v*.onnx"))

if not models:
    raise SystemExit(1)
PYTHON
        then
            RESULTS+="✓ Wake Word / hey_mycroft\n"
        else
            RESULTS+="✗ Wake Word / hey_mycroft\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Piper
    # ------------------------------------------------------------------

    if [ "$INSTALL_PIPER" = true ]; then

        if [ -x "$BASE_DIR/piper_tts/piper/piper" ]; then
            RESULTS+="✓ Piper TTS\n"
        else
            RESULTS+="✗ Piper TTS\n"
            CHECK_OK=false
        fi

        if [ -n "$VOICE" ] &&
           [ -s "$BASE_DIR/piper_tts/${VOICE}.onnx" ]; then
            RESULTS+="✓ Voz: $VOICE\n"
        elif [ -n "$VOICE" ]; then
            RESULTS+="✗ Voz: $VOICE\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Audio
    # ------------------------------------------------------------------

    if [ "$INSTALL_AUDIO" = true ]; then

        if "$BASE_DIR/venv/bin/python" - <<'PYTHON' >/dev/null 2>&1
import sounddevice
PYTHON
        then
            RESULTS+="✓ Audio / sounddevice\n"
        else
            RESULTS+="✗ Audio / sounddevice\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Spotify
    # ------------------------------------------------------------------

    if [ "$INSTALL_SPOTIFY" = true ]; then

        SPOTIFY_MODULE_DIR="$(cd "$BASE_DIR/../MMM-TuAsistente-Spotify" && pwd)"

        if [ -f "$SPOTIFY_MODULE_DIR/MMM-TuAsistente-Spotify.js" ] &&
           [ -f "$SPOTIFY_MODULE_DIR/node_helper.js" ]
        then
            RESULTS+="✓ MMM-TuAsistente-Spotify\n"
        else
            RESULTS+="✗ MMM-TuAsistente-Spotify\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # LibreSpot
    # ------------------------------------------------------------------

    if [ "$INSTALL_LIBRESPOT" = true ]; then

        LIBRESPOT_BIN="/opt/tuasistente/librespot/target/release/librespot"

        if [ -x "$LIBRESPOT_BIN" ]; then
            RESULTS+="✓ LibreSpot\n"
        else
            RESULTS+="✗ LibreSpot\n"
            CHECK_OK=false
        fi

        if systemctl is-active --quiet tuasistente-spotify.service; then
            RESULTS+="✓ Servicio tuasistente-spotify.service\n"
        else
            RESULTS+="✗ Servicio tuasistente-spotify.service\n"
            CHECK_OK=false
        fi

        if [ -S "/tmp/tuasistente-spotify.sock" ]; then
            RESULTS+="✓ Socket tuasistente-spotify.sock\n"
        else
            RESULTS+="✗ Socket tuasistente-spotify.sock\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Ollama
    # ------------------------------------------------------------------

    if [ "$INSTALL_OLLAMA" = true ]; then

        if command -v ollama >/dev/null 2>&1; then
            RESULTS+="✓ Ollama\n"
        else
            RESULTS+="✗ Ollama\n"
            CHECK_OK=false
        fi

        if [ -n "$OLLAMA_MODEL" ] &&
           ollama list 2>/dev/null |
           awk 'NR > 1 {print $1}' |
           grep -Fxq "$OLLAMA_MODEL"
        then
            RESULTS+="✓ Modelo: $OLLAMA_MODEL\n"
        elif [ -n "$OLLAMA_MODEL" ]; then
            RESULTS+="⚠ Modelo: $OLLAMA_MODEL no detectado\n"
        fi

    fi

    # ------------------------------------------------------------------
    # Node.js solo cuando algún componente lo necesita
    # ------------------------------------------------------------------

    if [ "$INSTALL_TUASISTENTE" = true ] ||
       [ "$INSTALL_SPOTIFY" = true ] ||
       [ "$INSTALL_OLLAMA" = true ]; then

        if command -v node >/dev/null 2>&1; then
            RESULTS+="✓ Node.js $(node --version)\n"
        else
            RESULTS+="✗ Node.js\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Python virtualenv solo cuando algún componente lo necesita
    # ------------------------------------------------------------------

    if [ "$INSTALL_TUASISTENTE" = true ] ||
       [ "$INSTALL_PIPER" = true ] ||
       [ "$INSTALL_WAKEWORD" = true ] ||
       [ "$INSTALL_AUDIO" = true ]; then

        if [ -x "$BASE_DIR/venv/bin/python" ]; then
            RESULTS+="✓ Python virtualenv\n"
        else
            RESULTS+="✗ Python virtualenv\n"
            CHECK_OK=false
        fi

    fi

    # ------------------------------------------------------------------
    # Resultado
    # ------------------------------------------------------------------

    if [ "$USE_GUI" = true ]; then

        if [ "$CHECK_OK" = true ]; then

            zenity --info \
                --title="$TITLE" \
                --text="COMPROBACIÓN FINAL

$RESULTS" \
                --width=700 \
                2>/dev/null || true

        else

            zenity --warning \
                --title="$TITLE" \
                --text="COMPROBACIÓN FINAL

$RESULTS" \
                --width=700 \
                2>/dev/null || true

        fi

    else

        echo
        echo -e "${CYAN}===== COMPROBACIÓN FINAL =====${NC}"
        echo
        echo -e "$RESULTS"

        if [ "$CHECK_OK" = true ]; then
            echo -e "${GREEN}[OK] Todas las comprobaciones seleccionadas han pasado.${NC}"
        else
            echo -e "${RED}[AVISO] Algunas comprobaciones han fallado.${NC}"
        fi

        echo

    fi

    return 0
}

# ==============================================================================
# RESUMEN
# ==============================================================================

show_summary()
{
    SUMMARY=""

    SUMMARY+="\n===== COMPONENTES INSTALADOS =====\n"

    if [ "$INSTALL_TUASISTENTE" = true ]; then
        SUMMARY+="✓ MMM-TuAsistente\n"
    fi

    if [ "$INSTALL_SPOTIFY" = true ]; then
        SUMMARY+="✓ MMM-TuAsistente-Spotify\n"
    fi

    if [ "$INSTALL_LIBRESPOT" = true ]; then
        SUMMARY+="✓ LibreSpot\n"
    fi

    if [ "$INSTALL_OLLAMA" = true ]; then
        SUMMARY+="✓ Ollama"
        if [ -n "$OLLAMA_MODEL" ]; then
            SUMMARY+=" — $OLLAMA_MODEL"
        fi
        SUMMARY+="\n"
    fi

    if [ "$INSTALL_PIPER" = true ]; then
        SUMMARY+="✓ Piper TTS"
        if [ -n "$VOICE" ]; then
            SUMMARY+=" — $VOICE"
        fi
        SUMMARY+="\n"
    fi

    if [ "$INSTALL_WAKEWORD" = true ]; then
        if [ "$MODE_CHOICE" = "ptt" ]; then
            SUMMARY+="✓ Activación PTT"
            if [ -n "$PTT_KEY" ]; then
                SUMMARY+=" — tecla $PTT_KEY"
            fi
            SUMMARY+="\n"
        else
            SUMMARY+="✓ Wake Word — Hey Mycroft\n"
        fi
    fi

    if [ "$INSTALL_AUDIO" = true ]; then
        SUMMARY+="✓ Audio"
        if [ -n "$MIC_NAME" ]; then
            SUMMARY+=" — entrada: $MIC_NAME"
        fi
        if [ -n "$OUTPUT_NAME" ]; then
            SUMMARY+=" — salida: $OUTPUT_NAME"
        fi
        SUMMARY+="\n"
    fi

    SUMMARY+="\n"

    if [ "$INSTALL_TUASISTENTE" = true ]; then
        SUMMARY+="Idioma: $LANGUAGE\n"
    fi

    if [ "$INSTALL_SPOTIFY" = true ]; then
        SUMMARY+="Spotify: ✓ Módulo independiente\n"
    fi

    if [ "$INSTALL_LIBRESPOT" = true ]; then
        if [ -S "/tmp/tuasistente-spotify.sock" ]; then
            SUMMARY+="LibreSpot: ✓ Servicio y socket disponibles\n"
        else
            SUMMARY+="LibreSpot: ⚠ Socket no detectado\n"
        fi
    fi

    SUMMARY+="\nInstalación completada."

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
# MENÚ PRINCIPAL MODULAR
# ==============================================================================

select_components

# ------------------------------------------------------------------------------
# MMM-TuAsistente
# ------------------------------------------------------------------------------

if [ "$INSTALL_TUASISTENTE" = true ]; then

    echo
    echo -e "${CYAN}===== CONFIGURACIÓN MMM-TuAsistente =====${NC}"
    echo

    select_language
    select_voice
    select_mode

    if [ "$MODE_CHOICE" = "ptt" ]; then
        select_keyboard
        select_ptt_key
    fi

    select_audio_devices

fi


# ------------------------------------------------------------------------------
# Wake Word / PTT independiente
# ------------------------------------------------------------------------------

if [ "$INSTALL_WAKEWORD" = true ] &&
   [ "$INSTALL_TUASISTENTE" != true ]; then

    echo
    echo -e "${CYAN}===== CONFIGURACIÓN DE ACTIVACIÓN =====${NC}"
    echo

    select_mode

    if [ "$MODE_CHOICE" = "ptt" ]; then
        select_keyboard
        select_ptt_key
    fi

fi


# ------------------------------------------------------------------------------
# Audio independiente
# ------------------------------------------------------------------------------

if [ "$INSTALL_AUDIO" = true ] &&
   [ "$INSTALL_TUASISTENTE" != true ]; then

    echo
    echo -e "${CYAN}===== CONFIGURACIÓN DE AUDIO =====${NC}"
    echo

    select_audio_devices

fi


# ------------------------------------------------------------------------------
# Ollama
# ------------------------------------------------------------------------------

if [ "$INSTALL_OLLAMA" = true ]; then

    echo
    echo -e "${CYAN}===== CONFIGURACIÓN OLLAMA =====${NC}"
    echo

    OLLAMA_ENABLED="true"

    select_ollama

    if [ "$OLLAMA_ENABLED" = "true" ]; then
        select_ollama_model
    fi

else

    OLLAMA_ENABLED="false"

    echo
    echo -e "${YELLOW}[INFO] Ollama no seleccionado.${NC}"
    echo

fi


# ------------------------------------------------------------------------------
# Spotify
# ------------------------------------------------------------------------------

if [ "$INSTALL_SPOTIFY" = true ]; then

    echo
    echo -e "${GREEN}[OK] MMM-TuAsistente-Spotify seleccionado.${NC}"
    echo -e "${BLUE}[INFO] Se instalará como módulo independiente.${NC}"
    echo

fi


# ------------------------------------------------------------------------------
# LibreSpot
# ------------------------------------------------------------------------------

if [ "$INSTALL_LIBRESPOT" = true ]; then

    echo
    echo -e "${GREEN}[OK] LibreSpot seleccionado.${NC}"
    echo -e "${BLUE}[INFO] Se preparará como servicio independiente.${NC}"
    echo

fi


# ==============================================================================
# INSTALACIÓN
# ==============================================================================

progress_start

# ------------------------------------------------------------------------------
# Dependencias del sistema
# ------------------------------------------------------------------------------

if [ "$INSTALL_TUASISTENTE" = true ] ||
   [ "$INSTALL_SPOTIFY" = true ] ||
   [ "$INSTALL_LIBRESPOT" = true ] ||
   [ "$INSTALL_OLLAMA" = true ] ||
   [ "$INSTALL_PIPER" = true ] ||
   [ "$INSTALL_WAKEWORD" = true ] ||
   [ "$INSTALL_AUDIO" = true ]; then

    progress_update 10 "Preparando dependencias del sistema..."
    install_system_dependencies
fi

# ------------------------------------------------------------------------------
# Node.js / npm
# ------------------------------------------------------------------------------

if [ "$INSTALL_TUASISTENTE" = true ] ||
   [ "$INSTALL_SPOTIFY" = true ] ||
   [ "$INSTALL_OLLAMA" = true ]; then

    progress_update 20 "Comprobando Node.js y npm..."
    install_node
    install_node_dependencies
else
    echo -e "${YELLOW}[OMITIDO] Node.js/npm no necesario para los componentes seleccionados.${NC}"
fi

# ------------------------------------------------------------------------------
# Entorno Python
# ------------------------------------------------------------------------------

if [ "$INSTALL_TUASISTENTE" = true ] ||
   [ "$INSTALL_PIPER" = true ] ||
   [ "$INSTALL_WAKEWORD" = true ] ||
   [ "$INSTALL_AUDIO" = true ]; then

    progress_update 30 "Preparando entorno Python..."
    install_python_environment

    progress_update 40 "Comprobando librerías Python..."
    install_python_dependencies
else
    echo -e "${YELLOW}[OMITIDO] Python no necesario para los componentes seleccionados.${NC}"
fi

# ------------------------------------------------------------------------------
# Wake Word / PTT
# ------------------------------------------------------------------------------

if [ "$INSTALL_WAKEWORD" = true ]; then

    progress_update 50 "Configurando activación..."
    install_openwakeword

    if [ "$MODE_CHOICE" = "ptt" ]; then
        configure_listen_key
    fi

else
    echo -e "${YELLOW}[OMITIDO] Activación no seleccionada.${NC}"
fi

# ------------------------------------------------------------------------------
# Piper TTS
# ------------------------------------------------------------------------------

if [ "$INSTALL_PIPER" = true ]; then

    progress_update 60 "Preparando Piper TTS..."
    install_piper
else
    echo -e "${YELLOW}[OMITIDO] Piper TTS no seleccionado.${NC}"
fi

# ------------------------------------------------------------------------------
# Spotify independiente
# ------------------------------------------------------------------------------

if [ "$INSTALL_SPOTIFY" = true ]; then

    progress_update 70 "Preparando MMM-TuAsistente-Spotify..."

    configure_spotify
    install_spotify

else
    echo -e "${YELLOW}[OMITIDO] MMM-TuAsistente-Spotify no seleccionado.${NC}"
fi

# ------------------------------------------------------------------------------
# LibreSpot independiente
# ------------------------------------------------------------------------------

if [ "$INSTALL_LIBRESPOT" = true ]; then

    progress_update 75 "Preparando LibreSpot..."

    echo -e "${BLUE}[INFO] LibreSpot seleccionado.${NC}"

    # La función actual de instalación se conectará aquí.
    install_librespot

else
    echo -e "${YELLOW}[OMITIDO] LibreSpot no seleccionado.${NC}"
fi

# ------------------------------------------------------------------------------
# Ollama
# ------------------------------------------------------------------------------

if [ "$INSTALL_OLLAMA" = true ]; then

    progress_update 80 "Preparando Ollama..."

    if ! install_ollama_system; then
        echo -e "${RED}[ERROR] No se pudo instalar Ollama.${NC}"
        abort_install
    fi

    if ! install_ollama_node; then
        echo -e "${RED}[ERROR] No se pudo preparar Ollama para Node.js.${NC}"
        abort_install
    fi

    if ! download_ollama_model; then
        echo -e "${RED}[ERROR] No se pudo preparar el modelo de Ollama.${NC}"
        abort_install
    fi

else
    echo -e "${YELLOW}[OMITIDO] Ollama no seleccionado.${NC}"
fi

# ------------------------------------------------------------------------------
# Configuración de transcripción
# ------------------------------------------------------------------------------

if [ "$INSTALL_TUASISTENTE" = true ]; then

    progress_update 85 "Configurando transcripción..."

    configure_transcribe

else
    echo -e "${YELLOW}[OMITIDO] Transcripción de TuAsistente no seleccionada.${NC}"
fi

# ------------------------------------------------------------------------------
# Configuración automática de MagicMirror
# ------------------------------------------------------------------------------

if [ "$INSTALL_MAGICMIRROR_CONFIG" = true ]; then

    progress_update 90 "Configurando MagicMirror..."

    configure_magicmirror

else
    echo -e "${YELLOW}[OMITIDO] Configuración automática de MagicMirror no seleccionada.${NC}"
fi

# ------------------------------------------------------------------------------
# Permisos finales
# ------------------------------------------------------------------------------

progress_update 95 "Aplicando permisos y finalizando..."

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
