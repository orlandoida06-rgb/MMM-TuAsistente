# MMM-TuAsistente

## 🚀 INSTALACIÓN

```bash
cd ~/MagicMirror/modules
git clone https://github.com/orlandoida06-rgb/MMM-TuAsistente.git
cd MMM-TuAsistente
chmod +x install.sh
./install.sh
```

El instalador es modular. Permite seleccionar exactamente los componentes que quieres instalar.

### Componentes

- MMM-TuAsistente
- MMM-TuAsistente-Spotify
- LibreSpot
- Ollama
- Piper TTS
- Wake Word / PTT
- Audio
- Configuración automática de MagicMirror

### Spotify independiente

Selecciona `MMM-TuAsistente-Spotify`. LibreSpot se selecciona automáticamente como dependencia.

```text
✓ MMM-TuAsistente-Spotify
✓ LibreSpot
```

No se instalan automáticamente TuAsistente, Ollama, Piper, Wake Word/PTT ni Audio.

### Asistente completo

Selecciona `MMM-TuAsistente`, `Ollama`, `Piper TTS`, `Wake Word / PTT` y `Audio`. Las dependencias se resuelven automáticamente.

### Configuración automática

Puedes seleccionar la configuración automática de MagicMirror. Se realiza copia de seguridad de `config.js` y comprobación de sintaxis.

### Reiniciar

```bash
pm2 restart mm
```

---

# MMM-TuAsistente

**MMM-TuAsistente** es un módulo inteligente y local para **MagicMirror²** impulsado por modelos LLM locales (**Ollama / Qwen**), síntesis de voz offline (**Piper TTS**) y detección de voz/PTT (**OpenWakeWord** / Tecla física). Diseñado y optimizado para funcionar de manera fluida en placas SBC como **Orange Pi 5** y **Raspberry Pi**.

---

## 🧩 Características

* 🤖 **LLM 100% Local:** Integración directa con Ollama (por defecto `qwen2.5:1.5b` o `gemma3:4b`).
* 🔊 **Síntesis de Voz Offline:** Voz natural y rápida usando **Piper TTS** (`es_ES-davefx-medium`).
* 🎙️ **Doble Modo de Activación:**
  * **Wake Word (Voz):** Escucha continua usando **OpenWakeWord** (*"Hey Mycroft"*).
  * **PTT (Push-To-Talk):** Activación por teclado o botón físico mediante script dedicado.
* ▶️ **Control de YouTube:** Reproduce y cierra vídeos mediante comandos de voz directos (vía `yt-dlp`).
* ⚡ **Optimizado para ARM64:** Uso eficiente de recursos sin depender de APIs en la nube.

---

## 🛠️ Requisitos Previos

1. **MagicMirror²** instalado y en funcionamiento.
2. **Ollama** instalado y corriendo en la máquina local (`http://localhost:11434`).
   ```bash
   ollama pull qwen2.5:1.5b