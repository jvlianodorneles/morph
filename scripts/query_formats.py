#!/usr/bin/env python3
"""Query compatible conversion target formats for a file using SimplyConvertFile."""

import sys
import os
import json
from pathlib import Path

# Add local SimplyConvertFile repository if not already in path
scf_path = Path("/home/dorneles/Projects/universal/SimplyConvertFile/src")
if scf_path.exists() and str(scf_path) not in sys.path:
    sys.path.insert(0, str(scf_path))

try:
    from simplyconvertfile.config import format_config
    from simplyconvertfile.utils.validation import FileValidator
    from simplyconvertfile.actions.batch_helpers import FormatValidator
except Exception as e:
    sys.stdout.write(json.dumps({
        "valid": False,
        "error": f"Failed to import simplyconvertfile: {e}"
    }) + "\n")
    sys.exit(1)


def detect_category(fmt: str) -> str:
    group = format_config.get_format_group(fmt)
    if not group:
        return "other"
    name = str(group).lower()
    if "image" in name:
        return "image"
    if "video" in name:
        return "video"
    if "audio" in name:
        return "audio"
    if "document" in name or "office" in name or "pdf" in name:
        return "document"
    if "spreadsheet" in name:
        return "spreadsheet"
    if "presentation" in name:
        return "presentation"
    if "archive" in name:
        return "archive"
    if "markup" in name or "data" in name:
        return "data"
    return "other"


def main():
    if len(sys.argv) < 2:
        sys.stdout.write(json.dumps({"valid": False, "error": "No file specified"}) + "\n")
        sys.exit(1)

    file_paths = [Path(p).resolve() for p in sys.argv[1:]]

    if len(file_paths) == 1:
        file_path = file_paths[0]
        if not file_path.exists() or not file_path.is_file():
            sys.stdout.write(json.dumps({"valid": False, "error": f"File not found or not a regular file: {file_path}"}) + "\n")
            sys.exit(0)

        source_fmt = FileValidator.get_file_format(file_path)
        if not source_fmt:
            sys.stdout.write(json.dumps({"valid": False, "error": "Unknown format or extension"}) + "\n")
            sys.exit(0)

        available = list(FileValidator.get_available_formats(source_fmt))
        default_fmt = FileValidator.get_default_format(source_fmt)
        cat = detect_category(source_fmt)

        result = {
            "valid": len(available) > 0,
            "batch": False,
            "files": [str(file_path)],
            "filename": file_path.name,
            "source_format": source_fmt,
            "category": cat,
            "available_formats": available,
            "default_format": default_fmt or (available[0] if available else "")
        }
        sys.stdout.write(json.dumps(result) + "\n")
    else:
        # Batch
        valid_files, groups, errors = FormatValidator.validate_batch_files(file_paths)
        if not valid_files or len(groups) > 1:
            sys.stdout.write(json.dumps({
                "valid": False,
                "batch": True,
                "error": "Batch files have incompatible format groups" if len(groups) > 1 else "No valid files"
            }) + "\n")
            sys.exit(0)

        first_fmt = FileValidator.get_file_format(valid_files[0])
        available = list(FormatValidator.get_common_formats(valid_files))
        default_fmt = FileValidator.get_default_format(first_fmt)
        cat = detect_category(first_fmt)

        result = {
            "valid": len(available) > 0,
            "batch": True,
            "files": [str(f) for f in valid_files],
            "filename": f"{len(valid_files)} items",
            "source_format": first_fmt,
            "category": cat,
            "available_formats": available,
            "default_format": default_fmt or (available[0] if available else "")
        }
        sys.stdout.write(json.dumps(result) + "\n")


if __name__ == "__main__":
    main()
