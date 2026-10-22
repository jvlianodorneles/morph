#!/usr/bin/env python3
"""Global mouse & key listener for Convert Orb.

Monitors input events via Linux evdev (/dev/input/event*):
Triggers Convert Orb when Left Mouse Button (BTN_LEFT) is clicked
while the ALT key (KEY_LEFTALT / KEY_RIGHTALT) is held down.
"""

import fcntl
import glob
import importlib.machinery
import importlib.util
import json
import os
import select
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path

EV_KEY = 0x01
BTN_LEFT = 0x110
BTN_TOUCH = 0x14A
KEY_LEFTALT = 56
KEY_RIGHTALT = 100

FMT = "llHHI"
EVENT_SIZE = struct.calcsize(FMT)

CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "omarchy" / "convert-orb.json"
SUMMON_SCRIPT = Path(__file__).resolve().parent / "summon_orb"

# Load summon_orb's detect_selected_files helper
detect_selected_files = None
try:
    if SUMMON_SCRIPT.exists():
        _loader = importlib.machinery.SourceFileLoader("summon_orb", str(SUMMON_SCRIPT))
        _spec = importlib.util.spec_from_loader("summon_orb", _loader)
        _mod = importlib.util.module_from_spec(_spec)
        _loader.exec_module(_mod)
        detect_selected_files = getattr(_mod, "detect_selected_files", None)
except Exception:
    pass


def _ioc(direction, kind, nr, size):
    return (direction << 30) | (size << 16) | (kind << 8) | nr


def get_device_bits(fd, ev_type, size):
    try:
        buf = bytearray(size)
        got = fcntl.ioctl(fd, _ioc(2, ord("E"), 0x20 + ev_type, size), buf)
        data = bytes(buf[:got])
        return [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
    except OSError:
        return []


def test_bit(words, bit):
    idx = bit // 32
    if idx >= len(words):
        return False
    return bool(words[idx] & (1 << (bit % 32)))


def open_devices():
    devs = {}
    for path in sorted(glob.glob("/dev/input/event*")):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            kwords = get_device_bits(fd, EV_KEY, 256)

            has_left = test_bit(kwords, BTN_LEFT) or test_bit(kwords, BTN_TOUCH)
            has_alt = test_bit(kwords, KEY_LEFTALT) or test_bit(kwords, KEY_RIGHTALT)

            if has_left or has_alt:
                devs[fd] = {
                    "path": path,
                    "has_left": has_left,
                    "has_alt": has_alt,
                }
            else:
                os.close(fd)
        except OSError:
            pass
    return devs


def load_config():
    cfg = {"altLeftClick": True}
    try:
        if CONFIG_PATH.exists():
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    cfg["altLeftClick"] = data.get("altLeftClick", True) is not False
    except Exception:
        pass
    return cfg


def emit(msg: dict):
    try:
        sys.stdout.write(json.dumps(msg) + "\n")
        sys.stdout.flush()
    except (IOError, BrokenPipeError):
        sys.exit(0)


def get_active_window_class():
    try:
        out = subprocess.check_output(
            ["hyprctl", "activewindow", "-j"],
            stderr=subprocess.DEVNULL,
            timeout=0.2
        ).decode("utf-8", "ignore")
        data = json.loads(out)
        cls = data.get("class", "").lower()
        init_cls = data.get("initialClass", "").lower()
        return cls, init_cls
    except Exception:
        return "", ""


def is_file_manager_active():
    cls, init_cls = get_active_window_class()
    fm_signatures = ("nautilus", "flea", "dolphin", "thunar", "nemo", "caja", "pcmanfm")
    return any(sig in cls or sig in init_cls for sig in fm_signatures)


def main():
    def cleanup(*_args):
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGHUP, cleanup)

    devices = open_devices()
    alt_pressed = 0

    last_rescan = time.monotonic()
    last_cfg_check = time.monotonic()
    last_trigger = 0.0
    config = load_config()
    parent_pid = os.getppid()

    key_states = {}  # (fd, code) -> bool

    try:
        while True:
            if os.getppid() != parent_pid or os.getppid() == 1:
                break

            now = time.monotonic()

            # Periodic config reload
            if now - last_cfg_check > 2.0:
                last_cfg_check = now
                config = load_config()

            # Rescan devices
            if now - last_rescan > 4.0:
                last_rescan = now
                current_paths = {d["path"] for d in devices.values()}
                available_paths = set(glob.glob("/dev/input/event*"))
                if available_paths != current_paths:
                    for fd in list(devices.keys()):
                        try:
                            os.close(fd)
                        except OSError:
                            pass
                    devices = open_devices()
                    key_states.clear()
                    alt_pressed = 0

            rlist = list(devices.keys())
            if not rlist:
                time.sleep(0.5)
                devices = open_devices()
                continue

            try:
                readable, _, _ = select.select(rlist, [], [], 1.0)
            except (OSError, select.error):
                continue

            for fd in readable:
                if fd not in devices:
                    continue
                info = devices[fd]
                try:
                    data = os.read(fd, EVENT_SIZE * 64)
                except OSError:
                    try:
                        os.close(fd)
                    except OSError:
                        pass
                    del devices[fd]
                    continue

                for i in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                    _sec, _usec, ev_type, ev_code, ev_val = struct.unpack(FMT, data[i:i + EVENT_SIZE])

                    if ev_type != EV_KEY or ev_val == 2:
                        continue

                    is_down = (ev_val == 1)
                    prev_state = key_states.get((fd, ev_code), False)
                    if prev_state == is_down:
                        continue
                    key_states[(fd, ev_code)] = is_down

                    # Alt key tracking
                    if ev_code in (KEY_LEFTALT, KEY_RIGHTALT) and info["has_alt"]:
                        if is_down:
                            alt_pressed += 1
                        else:
                            alt_pressed = max(0, alt_pressed - 1)

                    # Left button trigger with Alt held
                    elif ev_code in (BTN_LEFT, BTN_TOUCH) and info["has_left"]:
                        if is_down and config.get("altLeftClick", True):
                            if alt_pressed > 0 and (now - last_trigger > 0.6):
                                if is_file_manager_active():
                                    # Small delay to let the click select the file in Nautilus first
                                    time.sleep(0.08)
                                    if detect_selected_files:
                                        files = detect_selected_files()
                                        if files:
                                            last_trigger = now
                                            emit({"action": "summon", "payload": {"files": files}})

    finally:
        for fd in devices:
            try:
                os.close(fd)
            except OSError:
                pass


if __name__ == "__main__":
    main()
