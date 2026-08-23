'use strict';

const NodeHelper = require('node_helper');
const { Ollama } = require('ollama');
const { spawn, exec } = require('child_process');

module.exports = NodeHelper.create({
  systemPrompt:
    'Eres Jarvis, un asistente de voz conciso para un espejo inteligente (MagicMirror). ' +
    'Responde siempre en español, con oraciones breves, claras y sin usar formato Markdown o listas, ' +
    'ya que las respuestas se leerán en voz alta.',

  async start() {
    console.log('[MMM-TuAsistente] Node helper iniciado (PTT + Cancelación + YouTube).');

    this.ollama = new Ollama({
      host: 'http://localhost:11434'
    });

    this.audioProcesses = [];
    this.isSpeaking = false;
    this.isThinking = false;

    this.listenToKeyboard();
  },

  stopAudio() {
    exec('pkill -9 aplay; pkill -9 piper', () => {});

    this.audioProcesses = [];
    this.isSpeaking = false;
    this.isThinking = false;
  },

  listenToKeyboard() {
    const pythonExec = __dirname + '/venv/bin/python';
    const listenerScript = __dirname + '/listen_key.py';

    const listener = spawn(pythonExec, [listenerScript]);

    listener.stdout.on('data', (data) => {
      const output = data.toString();

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

          this.handleChat({
            prompt: query
          });
        } else {
          this.sendSocketNotification('STATUS', 'ERROR');
        }
      }
    });

    listener.stderr.on('data', (data) => {
      console.error(
        '[MMM-TuAsistente] Error en listener Python:',
        data.toString()
      );
    });
  },

  socketNotificationReceived(notification, payload) {
    if (notification === 'INIT_CONFIG') {
      this.config = payload;
    }
  },

  buscarYouTube(query, callback) {
    const ytDlpBin = __dirname + '/venv/bin/yt-dlp';

    const cmd =
      `${ytDlpBin} "ytsearch1:${query}" --get-id --no-warnings`;

    exec(cmd, (error, stdout) => {
      if (error || !stdout.trim()) {
        console.error(
          '[MMM-TuAsistente] Error al buscar en YouTube:',
          error
        );

        callback(null);
      } else {
        callback(stdout.trim());
      }
    });
  },

  async handleChat({ prompt }) {
    const lowerPrompt = prompt.toLowerCase();

    // ==========================================
    // 1. DETENER YOUTUBE
    // ==========================================

    if (
      lowerPrompt.includes('quita el video') ||
      lowerPrompt.includes('cierra youtube') ||
      lowerPrompt.includes('para el video')
    ) {
      this.sendSocketNotification('STOP_YOUTUBE');

      this.speakText('Vídeo cerrado');

      this.sendSocketNotification(
        'ASSISTANT_RESPONSE',
        'Vídeo cerrado.'
      );

      this.isThinking = false;

      return;
    }

    // ==========================================
    // 2. REPRODUCIR YOUTUBE
    // ==========================================

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

        this.sendSocketNotification(
          'ASSISTANT_RESPONSE',
          `Poniendo vídeo: ${busqueda}...`
        );

        this.buscarYouTube(busqueda, (videoId) => {
          if (videoId) {
            this.sendSocketNotification(
              'PLAY_YOUTUBE',
              {
                videoId: videoId
              }
            );
          } else {
            this.speakText(
              'No pude encontrar ese vídeo en YouTube'
            );

            this.sendSocketNotification(
              'STATUS',
              'ERROR'
            );
          }
        });

        this.isThinking = false;

        return;
      }
    }

    // ==========================================
    // 3. OLLAMA / QWEN
    // ==========================================

    try {
      const modelName =
        (this.config && this.config.model)
          ? this.config.model
          : 'qwen2.5:1.5b';

      console.log(
        `[MMM-TuAsistente] Pregunta a Ollama: ${prompt}`
      );

      const responseStream = await this.ollama.chat({
        model: modelName,

        messages: [
          {
            role: 'system',
            content: this.systemPrompt
          },
          {
            role: 'user',
            content: prompt
          }
        ],

        stream: true,

        options: {
          // Menor contexto = menos trabajo
          num_ctx: 2048,

          // Respuestas cortas para voz
          num_predict: 60,

          // Máximo 6 hilos
          num_thread: 6,

          // Respuesta natural
          temperature: 0.7
        }
      });

      let fullResponse = '';
      let sentenceBuffer = '';

      for await (const chunk of responseStream) {
        const content =
          chunk.message?.content || '';

        if (!content) {
          continue;
        }

        fullResponse += content;
        sentenceBuffer += content;

        // Hablar por frases
        if (/[.!?\n]/.test(content)) {
          const cleanText =
            sentenceBuffer
              .replace(/["'$`]/g, '')
              .trim();

          if (cleanText.length > 0) {
            this.isSpeaking = true;
            this.speakText(cleanText);
          }

          sentenceBuffer = '';
        }
      }

      // Último fragmento
      if (sentenceBuffer.trim().length > 0) {
        this.isSpeaking = true;

        this.speakText(
          sentenceBuffer
            .replace(/["'$`]/g, '')
            .trim()
        );
      }

      this.isThinking = false;

      this.sendSocketNotification(
        'ASSISTANT_RESPONSE',
        fullResponse.trim()
      );

      console.log(
        `[MMM-TuAsistente] Respuesta: ${fullResponse.trim()}`
      );

    } catch (err) {
      console.error(
        '[MMM-TuAsistente] Error en Ollama:',
        err
      );

      this.isThinking = false;

      this.sendSocketNotification(
        'STATUS',
        'ERROR'
      );
    }
  },

  // ==========================================
  // PIPER TTS
  // ==========================================

  speakText(text) {
    if (!text || !text.trim()) {
      return;
    }

    const piperBin =
      __dirname + '/piper_tts/piper/piper';

    const modelPath =
      __dirname +
      '/piper_tts/es_ES-davefx-medium.onnx';

    const safeText = text
      .replace(/"/g, '\\"')
      .replace(/\$/g, '\\$')
      .replace(/`/g, '\\`');

    const command =
      `echo "${safeText}" | ` +
      `${piperBin} --model "${modelPath}" ` +
      `--output-raw | ` +
      `aplay -r 22050 -f S16_LE -t raw`;

    const p = exec(command);

    this.audioProcesses.push(p);

    p.on('exit', () => {
      this.audioProcesses =
        this.audioProcesses.filter(
          process => process !== p
        );

      if (this.audioProcesses.length === 0) {
        this.isSpeaking = false;
      }
    });
  }
});