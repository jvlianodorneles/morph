#!/usr/bin/python3
"""Save Convert Orb settings to config file and re-evaluate Hyprland bindings."""

import json
import os
import subprocess
import sys
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "omarchy"
CONFIG_FILE = CONFIG_DIR / "convert-orb.json"
SETUP_SCRIPT = Path(__file__).parent / "setup"

def main():
    try:
        if len(sys.argv) > 1:
            data = json.loads(sys.argv[1])
        else:
            data = json.load(sys.stdin)
    except Exception as e:
        sys.stderr.write(f"Failed to parse JSON input: {e}\n")
        sys.exit(1)

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    
    # Write atomically via temp file
    temp_file = CONFIG_FILE.with_suffix(".tmp")
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    temp_file.replace(CONFIG_FILE)

    # Run setup to update Hyprland keybinding if shortcut changed
    if SETUP_SCRIPT.exists() and os.access(SETUP_SCRIPT, os.X_OK):
        try:
            subprocess.run([str(SETUP_SCRIPT)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    sys.stdout.write(json.dumps({"success": True, "path": str(CONFIG_FILE)}) + "\n")
    sys.exit(0)

if __name__ == "__main__":
    main()
