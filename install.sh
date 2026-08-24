#!/bin/bash
# ==============================================================================
# MMM-TuAsistente - Script de Instalación Unificado (GUI / TUI)
# ==============================================================================

# Colores para la salida en consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}   Iniciando instalador de MMM-TuAsistente         ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. Comprobar que estamos en la raíz del módulo
if [ ! -f "node_helper.js" ]; then
    echo -e "${RED}[ERROR] Debes ejecutar este script desde la carpeta del módulo:${NC}"
    echo "cd ~/MagicMirror/modules/MMM-TuAsistente && ./install.sh"
    exit 1
fi

# 2. Detección del modo de interfaz (GUI Zenity vs TUI Whiptail)
USE_GUI=false

if [ "$1" == "--gui" ]; then
    USE_GUI=true
elif [ "$1" == "--tui" ]; then
    USE_GUI=false
else
    if [ -n "$DISPLAY" ]; then
        USE_GUI=true
    fi
fi

# 3. Instalación de herramientas de interfaz si faltan
if [ "$USE_GUI" = true ]; then
    if ! command -v zenity &> /dev/null; then
        echo -e "${YELLOW}Instalando Zenity para interfaz gráfica local...${NC}"
        sudo apt-get update -qq && sudo apt-get install -y -qq zenity >/dev/null 2>&1
    fi
else
    if ! command -v whiptail &> /dev/null; then
        echo -e "${YELLOW}Instalando Whiptail para interfaz de consola/SSH...${NC}"
        sudo apt-get update -qq && sudo apt-get install -y -qq whiptail >/dev/null 2>&1
    fi
fi

TITLE="MMM-TuAsistente - Instalación"
echo -e "${GREEN}[OK] Entorno de instalación:${NC} $( [ "$USE_GUI" = true ] && echo "Interfaz Gráfica (Zenity)" || echo "Consola / SSH (Whiptail)" )"

# 4. Selección del modo de activación
TEXT_MODE="Selecciona el modo de activación principal para el asistente:"

if [ "$USE_GUI" = true ]; then
    MODE_CHOICE=$(zenity --list --title="$TITLE" --text="$TEXT_MODE" \
        --column="ID" --column="Modo" --column="Descripción" \
        "1" "Wake Word" "Escucha continua local (openwakeword)" \
        "2" "Push-To-Talk" "Activación manual mediante botón o GPIO" \
        --hide-column=1 --height=260 --width=620 2>/dev/null)
else
    MODE_CHOICE=$(whiptail --title "$TITLE" --menu "$TEXT_MODE" 14 72 2 \
        "1" "Wake Word (openwakeword - Escucha continua local)" \
        "2" "Push-To-Talk (Activación por botón o teclado)" 3>&1 1>&2 2>&3)
fi

if [ -z "$MODE_CHOICE" ]; then
    echo -e "${RED}[!] Instalación cancelada por el usuario.${NC}"
    exit 1
fi

# 5. Instalación de paquetes de sistema (APT)
echo -e "${BLUE}==> [1/4] Instalando dependencias del sistema (apt)...${NC}"
sudo apt-get update -qq
sudo apt-get install -y -qq python3-venv python3-pip python3-dev portaudio19-dev libasound2-dev ffmpeg git >/dev/null 2>&1

# 6. Creación del entorno virtual (venv)
echo -e "${BLUE}==> [2/4] Configurando entorno virtual Python (venv)...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip -q

# 7. Instalación de paquetes Python base
echo -e "${BLUE}==> [3/4] Instalando librerías base de Python...${NC}"
pip install numpy requests ollama -q

# 8. Configuración e Instalación de openwakeword
ACTIVATION_KEY="ptt"

if [[ "$MODE_CHOICE" == "1" || "$MODE_CHOICE" == *"Wake Word"* ]]; then
    ACTIVATION_KEY="wakeword"
    echo -e "${BLUE}==> [4/4] Instalando openwakeword y motores de audio...${NC}"
    
    pip install pyaudio tflite-runtime openwakeword -q

    echo -e "${YELLOW}?? Pre-descargando modelo de voz 'hey_mycroft'...${NC}"
    python3 -c "
from openwakeword.model import Model
try:
    Model(wakeword_models=['hey_mycroft'], inference_framework='tflite')
    print('Modelo hey_mycroft guardado en caché.')
except Exception as e:
    pass
" >/dev/null 2>&1

else
    echo -e "${BLUE}==> [4/4] Modo Push-To-Talk seleccionado. Omitiendo openwakeword.${NC}"
fi

deactivate

# Dar permisos a scripts
if [ -d "scripts" ]; then
    chmod +x scripts/*.py 2>/dev/null
fi

# 9. Preguntar sobre la inyección automática en config.js
CONFIG_PATH="../../config/config.js"
ADD_CONFIG=false

TEXT_CONF="¿Deseas añadir automáticamente la configuración por defecto de MMM-TuAsistente a tu archivo config.js?"

if [ -f "$CONFIG_PATH" ]; then
    if [ "$USE_GUI" = true ]; then
        zenity --question --title="$TITLE" --text="$TEXT_CONF" --width=400 2>/dev/null && ADD_CONFIG=true
    else
        whiptail --title "$TITLE" --yesno "$TEXT_CONF" 10 60 && ADD_CONFIG=true
    fi
fi

if [ "$ADD_CONFIG" = true ]; then
    echo -e "${YELLOW}Inyectando bloque de configuración en config.js...${NC}"
    
    BLOCK="
    {
        module: \"MMM-TuAsistente\",
        position: \"middle_center\",
        config: {
            language: \"es\",
            activationMode: \"$ACTIVATION_KEY\",
            wakeWordModel: \"hey_mycroft\",
            wakeWordThreshold: 0.5,
            autoHideTimeout: 30000
        }
    },"

    # Insertar antes del cierre de la lista de módulos
    sed -i "/modules: \[/a $BLOCK" "$CONFIG_PATH" 2>/dev/null
    echo -e "${GREEN}[OK] Configuración añadida a config.js${NC}"
fi

# 10. Mensaje final
MSG_FIN="¡Instalación completada con éxito!\n\nModo configurado: $ACTIVATION_KEY\nReinicia MagicMirror para aplicar los cambios (pm2 restart mm)."

if [ "$USE_GUI" = true ]; then
    zenity --info --title="Instalación Finalizada" --text="$MSG_FIN" --width=400 2>/dev/null
else
    whiptail --title "Instalación Finalizada" --msgbox "$MSG_FIN" 12 60
fi

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}   Instalación finalizada. ¡Todo listo!            ${NC}"
echo -e "${GREEN}====================================================${NC}"