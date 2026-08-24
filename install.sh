#!/bin/bash

# ==============================================================================
# MMM-TuAsistente
# Instalador completo
# Idioma + Voz Piper + Wake Word / PTT
# ==============================================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TITLE="MMM-TuAsistente - Instalación"

echo -e "${GREEN}"
echo "===================================================="
echo "       MMM-TuAsistente - INSTALADOR"
echo "===================================================="
echo -e "${NC}"

# ==============================================================================
# 1. COMPROBAR DIRECTORIO
# ==============================================================================

if [ ! -f "node_helper.js" ]; then

    echo -e "${RED}[ERROR] Ejecuta este instalador desde:${NC}"
    echo
    echo "cd ~/MagicMirror/modules/MMM-TuAsistente"
    echo "./install.sh"
    echo

    exit 1
fi

BASE_DIR="$(pwd)"

echo -e "${GREEN}[OK] Módulo encontrado:${NC}"
echo "$BASE_DIR"
echo

# ==============================================================================
# 2. DETECTAR GUI / TUI
# ==============================================================================

USE_GUI=false

if [ "${1:-}" = "--gui" ]; then
    USE_GUI=true
elif [ "${1:-}" = "--tui" ]; then
    USE_GUI=false
else
    if [ -n "${DISPLAY:-}" ]; then
        USE_GUI=true
    fi
fi

# ==============================================================================
# 3. INSTALAR INTERFAZ
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
# FUNCIONES DE SELECCIÓN
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
            --menu "Selecciona el idioma del asistente:" \
            16 70 5 \
            "es" "Español" \
            "en" "English" \
            "fr" "Français" \
            "de" "Deutsch" \
            "it" "Italiano" \
            3>&1 1>&2 2>&3)

    fi

    case "$LANGUAGE" in

        "Español")
            LANGUAGE="es"
            ;;

        "English")
            LANGUAGE="en"
            ;;

        "Français")
            LANGUAGE="fr"
            ;;

        "Deutsch")
            LANGUAGE="de"
            ;;

        "Italiano")
            LANGUAGE="it"
            ;;

        es|en|fr|de|it)
            ;;

        *)
            echo -e "${RED}Instalación cancelada.${NC}"
            exit 1
            ;;

    esac
}


# ==============================================================================
# SELECCIONAR VOZ
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
                    "es_ES-davefx-medium" \
                    "DaveFX" \
                    "Voz española masculina" \
                    "es_ES-sharvard-medium" \
                    "Sharvard" \
                    "Voz española" \
                    --hide-column=1 \
                    --width=650 \
                    --height=300 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu "Selecciona la voz Piper:" \
                    15 75 2 \
                    "es_ES-davefx-medium" \
                    "DaveFX - Voz española masculina" \
                    "es_ES-sharvard-medium" \
                    "Sharvard - Voz española" \
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
                    "en_US-lessac-medium" \
                    "Lessac" \
                    "US English - neutral" \
                    --hide-column=1 \
                    --width=650 \
                    --height=250 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu "Select Piper voice:" \
                    15 75 1 \
                    "en_US-lessac-medium" \
                    "Lessac - US English" \
                    3>&1 1>&2 2>&3)

            fi
            ;;

        fr)

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Sélectionnez la voix Piper:" \
                    --column="ID" \
                    --column="Voix" \
                    --column="Description" \
                    "fr_FR-upmc-medium" \
                    "UPMC" \
                    "Voix française" \
                    --hide-column=1 \
                    --width=650 \
                    --height=250 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu "Sélectionnez la voix Piper:" \
                    15 75 1 \
                    "fr_FR-upmc-medium" \
                    "UPMC - Français" \
                    3>&1 1>&2 2>&3)

            fi
            ;;

        de)

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Piper-Stimme auswählen:" \
                    --column="ID" \
                    --column="Stimme" \
                    --column="Beschreibung" \
                    "de_DE-thorsten-medium" \
                    "Thorsten" \
                    "Deutsche Stimme" \
                    --hide-column=1 \
                    --width=650 \
                    --height=250 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu "Piper-Stimme auswählen:" \
                    15 75 1 \
                    "de_DE-thorsten-medium" \
                    "Thorsten - Deutsch" \
                    3>&1 1>&2 2>&3)

            fi
            ;;

        it)

            if [ "$USE_GUI" = true ]; then

                VOICE=$(zenity --list \
                    --title="$TITLE" \
                    --text="Seleziona la voce Piper:" \
                    --column="ID" \
                    --column="Voce" \
                    --column="Descrizione" \
                    "it_IT-riccardo-x_low" \
                    "Riccardo" \
                    "Voce italiana" \
                    --hide-column=1 \
                    --width=650 \
                    --height=250 \
                    2>/dev/null)

            else

                VOICE=$(whiptail \
                    --title="$TITLE" \
                    --menu "Seleziona la voce Piper:" \
                    15 75 1 \
                    "it_IT-riccardo-x_low" \
                    "Riccardo - Italiano" \
                    3>&1 1>&2 2>&3)

            fi
            ;;

    esac

    if [ -z "${VOICE:-}" ]; then

        echo -e "${RED}[ERROR] No se seleccionó ninguna voz.${NC}"
        exit 1

    fi
}


# ==============================================================================
# SELECCIONAR MODO
# ==============================================================================

select_activation_mode() {

    if [ "$USE_GUI" = true ]; then

        MODE_CHOICE=$(zenity --list \
            --title="$TITLE" \
            --text="Selecciona el método de activación:" \
            --column="ID" \
            --column="Método" \
            --column="Descripción" \
            "wakeword" \
            "Wake Word" \
            "Escucha continua con OpenWakeWord" \
            "ptt" \
            "Push-To-Talk" \
            "Mantener pulsada la barra espaciadora" \
            --hide-column=1 \
            --width=700 \
            --height=300 \
            2>/dev/null)

    else

        MODE_CHOICE=$(whiptail \
            --title="$TITLE" \
            --menu "Selecciona el método de activación:" \
            15 75 2 \
            "wakeword" \
            "Wake Word - OpenWakeWord" \
            "ptt" \
            "PTT - Barra espaciadora" \
            3>&1 1>&2 2>&3)

    fi

    if [ -z "${MODE_CHOICE:-}" ]; then

        echo -e "${RED}Instalación cancelada.${NC}"
        exit 1

    fi
}


# ==============================================================================
# SELECCIONES
# ==============================================================================

select_language
select_voice
select_activation_mode

# ==============================================================================
# MOSTRAR CONFIGURACIÓN
# ==============================================================================

echo
echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN} CONFIGURACIÓN SELECCIONADA${NC}"
echo -e "${CYAN}====================================================${NC}"
echo "Idioma       : $LANGUAGE"
echo "Voz          : $VOICE"
echo "Activación   : $MODE_CHOICE"
echo -e "${CYAN}====================================================${NC}"
echo

# ==============================================================================
# APT
# ==============================================================================

echo -e "${BLUE}[1/7] Instalando dependencias del sistema...${NC}"

sudo apt-get update -qq

sudo apt-get install -y \
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
    >/dev/null 2>&1

# ==============================================================================
# VENV
# ==============================================================================

echo -e "${BLUE}[2/7] Creando entorno Python...${NC}"

if [ ! -d "$BASE_DIR/venv" ]; then

    python3 -m venv "$BASE_DIR/venv"

fi

source "$BASE_DIR/venv/bin/activate"

python -m pip install --upgrade pip setuptools wheel -q

# ==============================================================================
# PYTHON
# ==============================================================================

echo -e "${BLUE}[3/7] Instalando librerías Python...${NC}"

pip install \
    numpy \
    requests \
    ollama \
    sounddevice \
    faster-whisper \
    evdev \
    -q

# ==============================================================================
# OPENWAKEWORD
# ==============================================================================

if [ "$MODE_CHOICE" = "wakeword" ]; then

    echo -e "${BLUE}[4/7] Instalando OpenWakeWord...${NC}"

    pip install \
        openwakeword \
        pyaudio \
        tflite-runtime \
        -q

else

    echo -e "${BLUE}[4/7] Modo PTT: OpenWakeWord no necesario.${NC}"

fi

# ==============================================================================
# PIPER
# ==============================================================================

echo -e "${BLUE}[5/7] Preparando Piper TTS...${NC}"

mkdir -p "$BASE_DIR/piper_tts"

PIPER_DIR="$BASE_DIR/piper_tts"

# ------------------------------------------------------------------------------
# Descargar Piper binario si no existe
# ------------------------------------------------------------------------------

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
# DESCARGAR VOZ
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
# CONFIGURAR TRANSCRIBE.PY
# ==============================================================================

echo -e "${BLUE}[6/7] Configurando idioma de reconocimiento...${NC}"

# El idioma se pasa dinámicamente desde listen_key.py.
# No modificamos el código fuente aquí.

# ==============================================================================
# CONFIG.JS
# ==============================================================================

echo -e "${BLUE}[7/7] Configurando MagicMirror...${NC}"

CONFIG_PATH="$BASE_DIR/../../config/config.js"

if [ ! -f "$CONFIG_PATH" ]; then

    echo -e "${YELLOW}[AVISO] No se encontró config.js automáticamente:${NC}"
    echo "$CONFIG_PATH"

else

    ADD_CONFIG=false

    if [ "$USE_GUI" = true ]; then

        zenity --question \
            --title="$TITLE" \
            --text="¿Quieres añadir MMM-TuAsistente automáticamente a config.js?" \
            --width=450 \
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

        echo -e "${GREEN}[OK] Copia de seguridad:${NC}"
        echo "$BACKUP"

        # Evitar duplicados
        if grep -q "MMM-TuAsistente" "$CONFIG_PATH"; then

            echo -e "${YELLOW}[AVISO] MMM-TuAsistente ya existe en config.js.${NC}"
            echo "No se ha añadido otra entrada."

        else

            TEMP_CONFIG="/tmp/config_mmm_tuasistente.js"

            python3 - "$CONFIG_PATH" "$TEMP_CONFIG" "$LANGUAGE" "$VOICE" "$MODE_CHOICE" <<'PY'
import sys

config_path = sys.argv[1]
output_path = sys.argv[2]
language = sys.argv[3]
voice = sys.argv[4]
mode = sys.argv[5]

with open(config_path, "r", encoding="utf-8") as f:
    content = f.read()

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
            micDeviceIndex: null,
            model: "qwen2.5:1.5b",
            autoHideTimeout: 30000
        }}
    }},
'''

marker = "modules: ["

if marker not in content:
    print("ERROR: No se encontró 'modules: ['")
    sys.exit(1)

content = content.replace(
    marker,
    marker + "\n" + block,
    1
)

with open(output_path, "w", encoding="utf-8") as f:
    f.write(content)
PY

            if [ $? -eq 0 ]; then

                mv "$TEMP_CONFIG" "$CONFIG_PATH"

                echo -e "${GREEN}[OK] Configuración añadida a config.js${NC}"

            else

                echo -e "${RED}[ERROR] No se pudo modificar config.js${NC}"

            fi

        fi

    fi

fi

# ==============================================================================
# PERMISOS
# ==============================================================================

chmod +x "$BASE_DIR/install.sh" 2>/dev/null
chmod +x "$BASE_DIR/listen_key.py" 2>/dev/null
chmod +x "$BASE_DIR/transcribe.py" 2>/dev/null

if [ -d "$BASE_DIR/scripts" ]; then

    chmod +x "$BASE_DIR/scripts/"*.py 2>/dev/null

fi

deactivate

# ==============================================================================
# FINAL
# ==============================================================================

echo
echo -e "${GREEN}"
echo "===================================================="
echo "       INSTALACIÓN COMPLETADA"
echo "===================================================="
echo -e "${NC}"

echo "Idioma       : $LANGUAGE"
echo "Voz Piper    : $VOICE"
echo "Activación   : $MODE_CHOICE"
echo

echo -e "${GREEN}Voz instalada:${NC}"
echo "$PIPER_DIR/${VOICE}.onnx"
echo

echo -e "${GREEN}Reinicia MagicMirror:${NC}"
echo
echo "pm2 restart mm"
echo

if [ "$MODE_CHOICE" = "ptt" ]; then

    echo -e "${CYAN}PTT:${NC}"
    echo "Mantén pulsada la BARRA ESPACIADORA para hablar."

else

    echo -e "${CYAN}Wake Word:${NC}"
    echo "Di: Hey Mycroft"

fi

echo