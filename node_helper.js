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
    console.log('[MMM-TuAsistente] Node helper iniciado (PTT + Cancelación).');
    this.ollama = new Ollama({ host: 'http://localhost:11434' });
    this.audioProcesses = [];
    this.isSpeaking = false;
    this.isThinking = false;
    this.listenToKeyboard();
  },

  stopAudio() {
    // Matar procesos de audio inmediatamente
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
        // Si estaba hablando o pensando, una nueva pulsación cancela todo
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
    });

    listener.stderr.on('data', (data) => {
      console.error('[MMM-TuAsistente] Error en listener Python:', data.toString());
    });
  },

  socketNotificationReceived(notification, payload) {
    if (notification === 'INIT_CONFIG') {
      this.config = payload;
    }
  },

  async handleChat({ prompt }) {
    try {
      const modelName = (this.config && this.config.model) ? this.config.model : 'qwen2.5:1.5b';

      const responseStream = await this.ollama.chat({
        model: modelName,
        messages: [
          { role: 'system', content: this.systemPrompt },
          { role: 'user', content: prompt }
        ],
        stream: true,
      });

      let fullResponse = '';
      let sentenceBuffer = '';

      for await (const chunk of responseStream) {
        const content = chunk.message.content || '';
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

      this.sendSocketNotification('ASSISTANT_RESPONSE', fullResponse);

    } catch (err) {
      console.error('[MMM-TuAsistente] Error en Ollama:', err);
      this.sendSocketNotification('STATUS', 'ERROR');
    }
  },

  speakText(text) {
    const piperBin = __dirname + '/piper_tts/piper/piper';
    const modelPath = __dirname + '/piper_tts/es_ES-davefx-medium.onnx';

    const p = exec(`echo "${text}" | ${piperBin} --model ${modelPath} --output-raw | aplay -r 22050 -f S16_LE -t raw`);
    this.audioProcesses.push(p);
  }
});
