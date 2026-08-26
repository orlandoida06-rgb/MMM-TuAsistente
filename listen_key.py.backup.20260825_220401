# -*- coding: utf-8 -*-

import evdev
from evdev import InputDevice, categorize, ecodes
import sys
import subprocess
import os
import threading

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

python_bin = os.path.join(BASE_DIR, "venv", "bin", "python")
transcribe_script = os.path.join(BASE_DIR, "transcribe.py")


def find_keyboard():

    configured = '/dev/input/by-id/usb-Logitech_USB_Keyboard-event-kbd'

    if configured != "null":

        import os

        if os.path.exists(configured):
            return configured

    try:

        for device_path in evdev.list_devices():

            try:

                dev = evdev.InputDevice(device_path)

                if "keyboard" in dev.name.lower():

                    return dev.path

            except Exception:

                continue

    except Exception:

        pass

    return None


KEYBOARD_PATH = find_keyboard()

if not KEYBOARD_PATH:

    print(
        "ERROR: No keyboard with SPACE key found.",
        flush=True
    )

    sys.exit(1)


print(
    f"[MMM-TuAsistente] Keyboard: {KEYBOARD_PATH}",
    flush=True
)


try:

    keyboard = InputDevice(KEYBOARD_PATH)

except Exception as e:

    print(
        f"ERROR opening keyboard: {e}",
        flush=True
    )

    sys.exit(1)


if not os.path.exists(python_bin):

    print(
        f"ERROR: Python not found: {python_bin}",
        flush=True
    )

    sys.exit(1)


if not os.path.exists(transcribe_script):

    print(
        f"ERROR: transcribe.py not found: {transcribe_script}",
        flush=True
    )

    sys.exit(1)


try:

    transcribe_proc = subprocess.Popen(
        [
            python_bin,
            transcribe_script
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )

except Exception as e:

    print(
        f"ERROR starting transcribe.py: {e}",
        flush=True
    )

    sys.exit(1)


def read_output():

    try:

        for line in transcribe_proc.stdout:

            print(
                line,
                end="",
                flush=True
            )

    except Exception as e:

        print(
            f"ERROR reading transcribe.py: {e}",
            flush=True
        )


def read_errors():

    try:

        for line in transcribe_proc.stderr:

            print(
                f"[transcribe ERROR] {line}",
                end="",
                flush=True
            )

    except Exception as e:

        print(
            f"ERROR reading stderr: {e}",
            flush=True
        )


threading.Thread(
    target=read_output,
    daemon=True
).start()


threading.Thread(
    target=read_errors,
    daemon=True
).start()


def send_command(command):

    if transcribe_proc.poll() is not None:

        print(
            f"ERROR: transcribe.py stopped: "
            f"{transcribe_proc.returncode}",
            flush=True
        )

        return

    try:

        transcribe_proc.stdin.write(
            command + "\n"
        )

        transcribe_proc.stdin.flush()

    except Exception as e:

        print(
            f"ERROR sending command: {e}",
            flush=True
        )


is_pressed = False


print(
    "[MMM-TuAsistente] Press SPACE to talk.",
    flush=True
)


try:

    for event in keyboard.read_loop():

        if event.type != ecodes.EV_KEY:
            continue

        # 1 = pulsación
        # 0 = liberación
        # 2 = autorepetición
        if event.value == 2:
            continue

        # Comprobamos directamente el código numérico
        # KEY_SPACE = 57
        if event.code != ecodes.KEY_SPACE:
            continue

        if event.value == 1:

            if not is_pressed:

                is_pressed = True

                print(
                    "RECORD_START",
                    flush=True
                )

                send_command("START")

        elif event.value == 0:

            if is_pressed:

                is_pressed = False

                print(
                    "RECORD_STOP",
                    flush=True
                )

                send_command("STOP")


except KeyboardInterrupt:

    pass


except Exception as e:

    print(
        f"ERROR keyboard loop: {e}",
        flush=True
    )


finally:

    try:

        if transcribe_proc.poll() is None:

            transcribe_proc.terminate()

            try:

                transcribe_proc.wait(timeout=2)

            except subprocess.TimeoutExpired:

                transcribe_proc.kill()

    except Exception:

        pass
