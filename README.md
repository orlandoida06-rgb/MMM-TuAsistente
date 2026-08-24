# MMM-TuAsistente

**MMM-TuAsistente** es un módulo inteligente y local para **MagicMirror²** impulsado por modelos LLM locales (**Ollama / Qwen**), síntesis de voz offline (**Piper TTS**) y detección de voz/PTT (**OpenWakeWord** / Tecla física). Diseñado y optimizado para funcionar de manera fluida en placas SBC como **Orange Pi 5** y **Raspberry Pi**.

---

## ?? Características

* ?? **LLM 100% Local:** Integración directa con Ollama (por defecto `qwen2.5:1.5b` o `gemma3:4b`).
* ??? **Síntesis de Voz Offline:** Voz natural y rápida usando **Piper TTS** (`es_ES-davefx-medium`).
* ??? **Doble Modo de Activación:**
  * **Wake Word (Voz):** Escucha continua usando **OpenWakeWord** (*"Hey Mycroft"*).
  * **PTT (Push-To-Talk):** Activación por teclado o botón físico mediante script dedicado.
* ?? **Control de YouTube:** Reproduce y cierra vídeos mediante comandos de voz directos (vía `yt-dlp`).
* ? **Optimizado para ARM64:** Uso eficiente de recursos sin depender de APIs en la nube.

---

## ??? Requisitos Previos

1. **MagicMirror²** instalado y en funcionamiento.
2. **Ollama** instalado y corriendo en la máquina local (`http://localhost:11434`).
   ```bash
   ollama pull qwen2.5:1.5b