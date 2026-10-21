#!/usr/bin/env python3
"""Global drag-and-drop listener for Convert Orb.

Monitors pointer buttons (BTN_LEFT) and keyboard modifiers (KEY_LEFTSHIFT / KEY_RIGHTSHIFT)
via Linux evdev (/dev/input/event*). When both Left Mouse Button and Shift are held,
emits {"drag_shift": true} on stdout. When either is released, emits {"drag_shift": false}.
"""

import fcntl
import glob
import json
import os
import select
import signal
import struct
import sys
import time

EV_KEY = 0x01
BTN_LEFT = 0x110
BTN_TOUCH = 0x14A
KEY_LEFTSHIFT = 42
KEY_RIGHTSHIFT = 54

FMT = "llHHI"
EVENT_SIZE = struct.calcsize(FMT)


def _ioc(direction, kind, nr, size):
    return (direction << 30) | (size << 16) | (kind << 8) | nr


def get_device_key_bits(fd):
    try:
        buf = bytearray(256)
        got = fcntl.ioctl(fd, _ioc(2, ord("E"), 0x20 + EV_KEY, 256), buf)
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
            bits = get_device_key_bits(fd)
            has_pointer = test_bit(bits, BTN_LEFT) or test_bit(bits, BTN_TOUCH)
            has_shift = test_bit(bits, KEY_LEFTSHIFT) or test_bit(bits, KEY_RIGHTSHIFT)
            if has_pointer or has_shift:
                devs[fd] = {
                    "path": path,
                    "pointer": has_pointer,
                    "keyboard": has_shift,
                }
            else:
                os.close(fd)
        except OSError:
            pass
    return devs


def emit(active: bool):
    try:
        sys.stdout.write(json.dumps({"drag_shift": active}) + "\n")
        sys.stdout.flush()
    except (IOError, BrokenPipeError):
        sys.exit(0)


def main():
    def cleanup(*_args):
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGHUP, cleanup)

    devices = open_devices()
    left_button_pressed = 0
    shift_pressed = 0
    active_state = False
    last_rescan = time.monotonic()

    # Track per-device key state to avoid duplicate press counts
    key_states = {}  # (fd, code) -> bool

    try:
        while True:
            now = time.monotonic()
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
                    left_button_pressed = 0
                    shift_pressed = 0
                    if active_state:
                        active_state = False
                        emit(False)

            rlist = list(devices.keys())
            if not rlist:
                time.sleep(1.0)
                devices = open_devices()
                continue

            # Also watch stdin for EOF (when parent Quickshell process exits)
            rlist.append(sys.stdin.fileno())

            try:
                readable, _, _ = select.select(rlist, [], [], 2.0)
            except (OSError, select.error):
                continue

            if sys.stdin.fileno() in readable:
                # Parent closed stdin or exited
                break

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
                    if ev_type != EV_KEY:
                        continue

                    # ev_val: 0 = released, 1 = pressed, 2 = autorepeat
                    if ev_val == 2:
                        continue

                    is_down = (ev_val == 1)
                    prev_state = key_states.get((fd, ev_code), False)
                    if prev_state == is_down:
                        continue
                    key_states[(fd, ev_code)] = is_down

                    if ev_code in (BTN_LEFT, BTN_TOUCH) and info["pointer"]:
                        if is_down:
                            left_button_pressed += 1
                        else:
                            left_button_pressed = max(0, left_button_pressed - 1)

                    elif ev_code in (KEY_LEFTSHIFT, KEY_RIGHTSHIFT) and info["keyboard"]:
                        if is_down:
                            shift_pressed += 1
                        else:
                            shift_pressed = max(0, shift_pressed - 1)

            new_state = (left_button_pressed > 0 and shift_pressed > 0)
            if new_state != active_state:
                active_state = new_state
                emit(active_state)

    finally:
        for fd in devices:
            try:
                os.close(fd)
            except OSError:
                pass


if __name__ == "__main__":
    main()
