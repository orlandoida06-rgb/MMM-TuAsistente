'use strict';

const NodeHelper = require('node_helper');
const { Ollama } = require('ollama');
const { spawn, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

module.exports = NodeHelper.create({
  systemPrompt:
    'Eres Jarvis, un asistente de voz conciso para un espejo inteligente (MagicMirror). ' +
    'Responde siempre en español, con oraciones breves, claras y sin usar formato Markdown o listas, ' +
    'ya que las respuestas se leerán en voz alta.',

  async start() {
    console.log('[MMM-TuAsistente] Node helper iniciado.');

    this.ollama = new Ollama({
      host: 'http://localhost:11434'
    });

    this.audioProcesses = [];
    this.isSpeaking = false;
    this.isThinking = false;

    this.keyListenerProcess = null;
    this.wakeWordProcess = null;
  },

  stopAudio() {
    exec('pkill -9 aplay; pkill -9 piper', () => {});

    this.audioProcesses = [];
    this.isSpeaking = false;
    this.isThinking = false;
  },

  // ==========================================
  // OPCIÓN 1: PTT / ESCUCHA POR TECLA O BOTÓN
  // ==========================================
  listenToKeyboard() {
    if (this.keyListenerProcess !== null) return;

    const pythonExec = path.join(__dirname, 'venv', 'bin', 'python3');
    const listenerScript = path.join(__dirname, 'listen_key.py');

    if (!fs.existsSync(listenerScript)) {
      console.error('[MMM-TuAsistente] Error: No existe listen_key.py');
      return;
    }

    console.log('[MMM-TuAsistente] Iniciando servicio de activación por Tecla/PTT...');
    this.keyListenerProcess = spawn(pythonExec, [listenerScript]);

    this.keyListenerProcess.stdout.on('data', (data) => {
      this.handleTranscriptionOutput(data.toString());
    });

    this.keyListenerProcess.stderr.on('data', (data) => {
      console.error('[MMM-TuAsistente] Error en listener PTT:', data.toString());
    });
  },

  // ==========================================
  // OPCIÓN 2: ESCUCHA POR VOZ (OPENWAKEWORD)
  // ==========================================
  startWakeWordListener() {
    if (this.wakeWordProcess !== null) return;

    const pythonExec = path.join(__dirname, 'venv', 'bin', 'python3');
    const scriptPath = path.join(__dirname, 'scripts', 'wakeword_listener.py');

    if (!fs.existsSync(scriptPath)) {
      console.error('[MMM-TuAsistente] Error: No existe scripts/wakeword_listener.py');
      return;
    }

    const modelName = (this.config && this.config.wakeWordModel) ? this.config.wakeWordModel : 'hey_mycroft';
    const threshold = (this.config && this.config.wakeWordThreshold) ? String(this.config.wakeWordThreshold) : '0.5';
    const micIndex = (this.config && this.config.micDeviceIndex !== undefined) ? String(this.config.micDeviceIndex) : 'null';

    console.log(`[MMM-TuAsistente] Iniciando OpenWakeWord (${modelName}, umbral: ${threshold})...`);

    this.wakeWordProcess = spawn(pythonExec, [scriptPath, modelName, threshold, micIndex]);

    this.wakeWordProcess.stdout.on('data', (data) => {
      const lines = data.toString().split('\n');
      lines.forEach((line) => {
        if (!line.trim()) return;

        try {
          const message = JSON.parse(line.trim());

          if (message.status === 'detected') {
            console.log(`[MMM-TuAsistente] ¡Palabra clave detectada por voz!: ${message.wakeword}`);

            // Si está hablando o pensando, cancela la reproducción
            if (this.isSpeaking || this.isThinking) {
              this.stopAudio();
            }

            this.sendSocketNotification('WAKEWORD_DETECTED', message);
            this.sendSocketNotification('STATUS', 'Grabando...');

            // Disparar la grabación de voz (STT) tras el Wake Word
            this.triggerVoiceRecording();
          }
        } catch (e) {
          // Ignorar logs que no sean JSON
        }
      });
    });

    this.wakeWordProcess.stderr.on('data', (data) => {
      console.error('[MMM-TuAsistente] Error en OpenWakeWord:', data.toString());
    });

    this.wakeWordProcess.on('close', () => {
      this.wakeWordProcess = null;
    });
  },

  // Método para procesar transcribir/grabar cuando se activa por Voz
  triggerVoiceRecording() {
    const pythonExec = path.join(__dirname, 'venv', 'bin', 'python3');
    const recordScript = path.join(__dirname, 'listen_key.py'); // O tu script de grabación STT

    if (!fs.existsSync(recordScript)) return;

    // Ejecutamos una ráfaga de grabación
    const recorder = spawn(pythonExec, [recordScript, '--once']);

    recorder.stdout.on('data', (data) => {
      this.handleTranscriptionOutput(data.toString());
    });
  },

  // Procesador común para las salidas de texto transcrito (Servicio único para PTT y Voz)
  handleTranscriptionOutput(output) {
    if (output.includes('RECORD_START')) {
      if (this.isSpeaking || this.isThinking) {
        this.stopAudio();
        this.sendSocketNotification('STATUS', 'CANCELLED');
        return;
      }
      this.stopAudio();
      this.sendSocketNotification('STATUS', 'Grabando...');
    }

    if (output.includes('RECORD_STOP')) {
      this.sendSocketNotification('STATUS', 'Pensando...');
    }

    const match = output.match(/TRANSCRIPTION:(.*)/);

    if (match) {
      const query = match[1].trim();

      if (query !== '') {
        this.isThinking = true;
        this.sendSocketNotification('USER_QUERY', query);
        this.sendSocketNotification('STATUS', 'Pensando...');

        this.handleChat({ prompt: query });
      } else {
        this.sendSocketNotification('STATUS', 'ERROR');
      }
    }
  },

  stopWakeWordListener() {
    if (this.wakeWordProcess !== null) {
      this.wakeWordProcess.kill('SIGINT');
      this.wakeWordProcess = null;
    }
  },

  // ==========================================
  // RECEPCIÓN DE CONFIGURACIÓN SEGÚN LA INSTALACIÓN
  // ==========================================
  socketNotificationReceived(notification, payload) {
    if (notification === 'INIT_CONFIG') {
      this.config = payload;

      const mode = this.config.activationMode || 'ptt';

      if (mode === 'wakeword') {
        console.log('[MMM-TuAsistente] Modo activo: VOZ (OpenWakeWord)');
        this.startWakeWordListener();
      } else {
        console.log('[MMM-TuAsistente] Modo activo: TECLA / PTT');
        this.listenToKeyboard();
      }
    } else if (notification === 'STOP_LISTENER') {
      this.stopWakeWordListener();
    }
  },

  buscarYouTube(query, callback) {
    const ytDlpBin = path.join(__dirname, 'venv', 'bin', 'yt-dlp');
    const cmd = `"${ytDlpBin}" "ytsearch1:${query}" --get-id --no-warnings`;

    exec(cmd, (error, stdout) => {
      if (error || !stdout.trim()) {
        console.error('[MMM-TuAsistente] Error al buscar en YouTube:', error);
        callback(null);
      } else {
        callback(stdout.trim());
      }
    });
  },

  async handleChat({ prompt }) {
    const lowerPrompt = prompt.toLowerCase();

    // 1. DETENER YOUTUBE
    if (
      lowerPrompt.includes('quita el video') ||
      lowerPrompt.includes('cierra youtube') ||
      lowerPrompt.includes('para el video')
    ) {
      this.sendSocketNotification('STOP_YOUTUBE');
      this.speakText('Vídeo cerrado');
      this.sendSocketNotification('ASSISTANT_RESPONSE', 'Vídeo cerrado.');
      this.isThinking = false;
      return;
    }

    // 2. REPRODUCIR YOUTUBE
    if (
      lowerPrompt.includes('pon') ||
      lowerPrompt.includes('reproduce') ||
      lowerPrompt.includes('video') ||
      lowerPrompt.includes('youtube')
    ) {
      let busqueda = lowerPrompt
        .replace(/pon/g, '')
        .replace(/reproduce/g, '')
        .replace(/un video de/g, '')
        .replace(/el video de/g, '')
        .replace(/video de/g, '')
        .replace(/en youtube/g, '')
        .trim();

      if (busqueda.length > 0) {
        this.speakText(`Buscando ${busqueda} en YouTube`);
        this.sendSocketNotification('ASSISTANT_RESPONSE', `Poniendo vídeo: ${busqueda}...`);

        this.buscarYouTube(busqueda, (videoId) => {
          if (videoId) {
            this.sendSocketNotification('PLAY_YOUTUBE', { videoId: videoId });
          } else {
            this.speakText('No pude encontrar ese vídeo en YouTube');
            this.sendSocketNotification('STATUS', 'ERROR');
          }
        });

        this.isThinking = false;
        return;
      }
    }

    // 3. OLLAMA / QWEN
    try {
      const modelName = (this.config && this.config.model) ? this.config.model : 'qwen2.5:1.5b';

      console.log(`[MMM-TuAsistente] Pregunta a Ollama: ${prompt}`);

      const responseStream = await this.ollama.chat({
        model: modelName,
        messages: [
          { role: 'system', content: this.systemPrompt },
          { role: 'user', content: prompt }
        ],
        stream: true,
        options: {
          num_ctx: 2048,
          num_predict: 60,
          num_thread: 6,
          temperature: 0.7
        }
      });

      let fullResponse = '';
      let sentenceBuffer = '';

      for await (const chunk of responseStream) {
        const content = chunk.message?.content || '';
        if (!content) continue;

        fullResponse += content;
        sentenceBuffer += content;

        if (/[.!?\n]/.test(content)) {
          const cleanText = sentenceBuffer.replace(/["'$`]/g, '').trim();
          if (cleanText.length > 0) {
            this.isSpeaking = true;
            this.speakText(cleanText);
          }
          sentenceBuffer = '';
        }
      }

      if (sentenceBuffer.trim().length > 0) {
        this.isSpeaking = true;
        this.speakText(sentenceBuffer.replace(/["'$`]/g, '').trim());
      }

      this.isThinking = false;
      this.sendSocketNotification('ASSISTANT_RESPONSE', fullResponse.trim());

    } catch (err) {
      console.error('[MMM-TuAsistente] Error en Ollama:', err);
      this.isThinking = false;
      this.sendSocketNotification('STATUS', 'ERROR');
    }
  },

  speakText(text) {
    if (!text || !text.trim()) return;

    const piperBin = path.join(__dirname, 'piper_tts', 'piper', 'piper');
    const modelPath = path.join(__dirname, 'piper_tts', 'es_ES-davefx-medium.onnx');

    const safeText = text
      .replace(/"/g, '\\"')
      .replace(/\$/g, '\\$')
      .replace(/`/g, '\\`');

    const command =
      `echo "${safeText}" | ` +
      `"${piperBin}" --model "${modelPath}" ` +
      `--output-raw | ` +
      `aplay -r 22050 -f S16_LE -t raw`;

    const p = exec(command);
    this.audioProcesses.push(p);

    p.on('exit', () => {
      this.audioProcesses = this.audioProcesses.filter(process => process !== p);
      if (this.audioProcesses.length === 0) {
        this.isSpeaking = false;
      }
    });
  },

  stop() {
    this.stopAudio();
    this.stopWakeWordListener();
    if (this.keyListenerProcess) {
      this.keyListenerProcess.kill();
    }
  }
});