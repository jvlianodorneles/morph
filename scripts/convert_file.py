#!/usr/bin/python3
"""Execute file format conversion using SimplyConvertFile and send desktop notifications."""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# Add local SimplyConvertFile repository if not already in path
scf_path = Path("/home/dorneles/Projects/universal/SimplyConvertFile/src")
if scf_path.exists() and str(scf_path) not in sys.path:
    sys.path.insert(0, str(scf_path))

try:
    from simplyconvertfile.core import ConverterFactory
    from simplyconvertfile.converters.helpers.file_manager import FileManager
    from simplyconvertfile.utils.validation import FileValidator
    import simplyconvertfile.ui as scf_ui

    # Suppress all GTK progress and dialog windows completely
    class SilentDialog:
        def __init__(self, *args, **kwargs):
            self.dialog = self
            self.progressbar = self
        def connect(self, *args, **kwargs): pass
        def set_pulse_step(self, *args, **kwargs): pass
        def show_all(self): pass
        def hide(self): pass
        def destroy(self): pass
        def run(self): return 0

    scf_ui.ProgressbarDialogWindow = SilentDialog
    scf_ui.InfoDialogWindow = SilentDialog
    scf_ui.DialogWindow = SilentDialog
except Exception as e:
    sys.stdout.write(json.dumps({
        "success": False,
        "error": f"Failed to import simplyconvertfile: {e}"
    }) + "\n")
    sys.exit(1)


def send_notification(summary: str, body: str, urgency: str = "normal", icon: str = "document-send"):
    try:
        subprocess.run(
            ["notify-send", "-a", "Morph", "-u", urgency, "-i", icon, summary, body],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        pass


def convert_single(file_path: Path, target_fmt: str, output_dir: Path | None = None) -> tuple[bool, Path | None, str | None]:
    try:
        if output_dir:
            output_dir.mkdir(parents=True, exist_ok=True)

        converter = ConverterFactory.create_converter(
            file=file_path,
            target_format=target_fmt.upper(),
            batch_mode=True,
            output_dir=output_dir,
        )
        if not converter:
            return False, None, f"No converter available for {file_path.name} -> {target_fmt}"

        converter.batch_mode = True
        if hasattr(converter, "conversion_manager") and converter.conversion_manager:
            converter.conversion_manager.batch_mode = True
        if hasattr(converter, "error_manager") and converter.error_manager:
            converter.error_manager.batch_mode = True

        success = converter.convert()
        if success and converter.target_file.exists():
            return True, converter.target_file, None
        return False, None, "Conversion failed during processing"
    except Exception as e:
        return False, None, str(e)


def main():
    parser = argparse.ArgumentParser(description="Convert files via SimplyConvertFile")
    parser.add_argument("target_format", help="Target format extension (e.g. WEBP, PNG, MP3)")
    parser.add_argument("files", nargs="+", help="File paths to convert")
    parser.add_argument("--output-dir", default=None, help="Custom output directory")
    parser.add_argument("--no-notify", action="store_true", help="Suppress desktop notifications")

    args = parser.parse_args()

    target_fmt = args.target_format.upper()
    output_dir = Path(args.output_dir).resolve() if args.output_dir else None

    input_paths = [Path(p).resolve() for p in args.files]
    converted_files = []
    errors = []

    for file_path in input_paths:
        if not file_path.exists():
            errors.append(f"File not found: {file_path.name}")
            continue

        ok, target_path, err = convert_single(file_path, target_fmt, output_dir)
        if ok and target_path:
            converted_files.append(str(target_path))
        else:
            errors.append(f"{file_path.name}: {err or 'Conversion failed'}")

    success = len(converted_files) > 0 and len(errors) == 0

    if not args.no_notify:
        if success:
            if len(converted_files) == 1:
                p = Path(converted_files[0])
                send_notification(
                    "Conversion Completed",
                    f"{p.name} created successfully.",
                    icon="emblem-default"
                )
            else:
                send_notification(
                    "Batch Conversion Completed",
                    f"{len(converted_files)} files converted to {target_fmt}.",
                    icon="emblem-default"
                )
        else:
            err_summary = "\n".join(errors[:3])
            send_notification(
                "Conversion Failed",
                err_summary,
                urgency="critical",
                icon="dialog-error"
            )

    result = {
        "success": success,
        "target_format": target_fmt,
        "converted": converted_files,
        "errors": errors
    }
    sys.stdout.write(json.dumps(result) + "\n")
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
