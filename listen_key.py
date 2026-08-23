import evdev
from evdev import InputDevice, categorize, ecodes
import sys
import subprocess
import os
import threading

python_bin = os.path.join(os.path.dirname(__file__), 'venv/bin/python')
transcribe_script = os.path.join(os.path.dirname(__file__), 'transcribe.py')

KEYBOARD_PATH = '/dev/input/event11'

try:
    keyboard = InputDevice(KEYBOARD_PATH)
except Exception as e:
    print(f"ERROR: No se pudo abrir {KEYBOARD_PATH}: {e}", flush=True)
    sys.exit(1)

# Arrancar el servidor de transcripción en segundo plano
transcribe_proc = subprocess.Popen(
    [python_bin, transcribe_script],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1
)

def read_output():
    for line in transcribe_proc.stdout:
        print(line, end='', flush=True)

threading.Thread(target=read_output, daemon=True).start()

is_pressed = False

# Bucle principal de eventos de teclado
for event in keyboard.read_loop():
    if event.type == ecodes.EV_KEY:
        key_event = categorize(event)
        if key_event.keycode == 'KEY_SPACE':
            
            # key_down = 1 (Pulsado inicial)
            if key_event.keystate == key_event.key_down:
                if not is_pressed:
                    is_pressed = True
                    print("RECORD_START", flush=True)
                    transcribe_proc.stdin.write("START\n")
                    transcribe_proc.stdin.flush()

            # key_up = 0 (Soltado)
            elif key_event.keystate == key_event.key_up:
                if is_pressed:
                    is_pressed = False
                    print("RECORD_STOP", flush=True)
                    transcribe_proc.stdin.write("STOP\n")
                    transcribe_proc.stdin.flush()
