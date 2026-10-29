#!/usr/bin/python3
"""Fixed Python conversion helper for structured data and markup conversions.

Accepts the operation name and file paths strictly as separate argv arguments
(never interpolating paths into Python source code).
"""

import csv
import html as html_lib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.dont_write_bytecode = True


def _write_tabular_csv(data: object, output_path: Path) -> None:
    data_list = data if isinstance(data, list) else [data]
    is_dict_rows = bool(data_list and isinstance(data_list[0], dict))
    fieldnames = list(data_list[0].keys()) if is_dict_rows else ["value"]
    rows = data_list if is_dict_rows else [{"value": str(d)} for d in data_list]
    with open(output_path, "w", encoding="utf-8", newline="") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def run_conversion(operation: str, input_path: Path, output_path: Path) -> None:
    if operation == "json-to-txt":
        with open(input_path, "r", encoding="utf-8") as infile:
            data = json.load(infile)
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(json.dumps(data, indent=2) + "\n")

    elif operation == "json-to-xml":
        with open(input_path, "r", encoding="utf-8") as infile:
            data = json.load(infile)
        root = ET.Element("root")
        ET.SubElement(root, "data").text = str(data)
        ET.ElementTree(root).write(output_path, encoding="unicode")

    elif operation == "json-to-yaml":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = json.load(infile)
        with open(output_path, "w", encoding="utf-8") as outfile:
            yaml.safe_dump(data, outfile, default_flow_style=False)

    elif operation == "yaml-to-json":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = yaml.safe_load(infile)
        with open(output_path, "w", encoding="utf-8") as outfile:
            json.dump(data, outfile, indent=2)

    elif operation == "yaml-to-txt":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = yaml.safe_load(infile)
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(yaml.safe_dump(data, default_flow_style=False) + "\n")

    elif operation == "yaml-to-xml":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = yaml.safe_load(infile)
        root = ET.Element("root")
        ET.SubElement(root, "data").text = str(data)
        ET.ElementTree(root).write(output_path, encoding="unicode")

    elif operation == "html-to-yaml":
        from bs4 import BeautifulSoup
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            soup = BeautifulSoup(infile, "html.parser")
        data = {
            "title": soup.title.string if soup.title and soup.title.string else "",
            "body": soup.get_text(),
        }
        with open(output_path, "w", encoding="utf-8") as outfile:
            yaml.safe_dump(data, outfile, default_flow_style=False)

    elif operation == "md-to-yaml":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = {"content": infile.read()}
        with open(output_path, "w", encoding="utf-8") as outfile:
            yaml.safe_dump(data, outfile, default_flow_style=False)

    elif operation == "xml-to-yaml":
        import yaml

        tree = ET.parse(input_path)
        root = tree.getroot()
        data = {child.tag: child.text for child in root}
        with open(output_path, "w", encoding="utf-8") as outfile:
            yaml.safe_dump(data, outfile, default_flow_style=False)

    elif operation == "json-to-html":
        with open(input_path, "r", encoding="utf-8") as infile:
            data = json.load(infile)
        body = html_lib.escape(json.dumps(data, indent=2))
        out_html = f"<html><body><pre>{body}</pre></body></html>"
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(out_html)

    elif operation == "json-to-md":
        with open(input_path, "r", encoding="utf-8") as infile:
            data = json.load(infile)
        md = "```json\n" + json.dumps(data, indent=2) + "\n```"
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(md)

    elif operation == "yaml-to-html":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = yaml.safe_load(infile)
        body = html_lib.escape(yaml.safe_dump(data, default_flow_style=False))
        out_html = f"<html><body><pre>{body}</pre></body></html>"
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(out_html)

    elif operation == "yaml-to-md":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = yaml.safe_load(infile)
        md = "```yaml\n" + yaml.safe_dump(data, default_flow_style=False) + "```"
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(md)

    elif operation == "json-to-csv":
        with open(input_path, "r", encoding="utf-8") as infile:
            data = json.load(infile)
        _write_tabular_csv(data, output_path)

    elif operation == "yaml-to-csv":
        import yaml

        with open(input_path, "r", encoding="utf-8") as infile:
            data = yaml.safe_load(infile)
        _write_tabular_csv(data, output_path)

    elif operation == "csv-to-json":
        with open(input_path, "r", encoding="utf-8", newline="") as infile:
            rows = list(csv.DictReader(infile))
        with open(output_path, "w", encoding="utf-8") as outfile:
            json.dump(rows, outfile, indent=2)

    elif operation == "csv-to-yaml":
        import yaml

        with open(input_path, "r", encoding="utf-8", newline="") as infile:
            rows = [dict(r) for r in csv.DictReader(infile)]
        with open(output_path, "w", encoding="utf-8") as outfile:
            yaml.safe_dump(rows, outfile, default_flow_style=False)

    elif operation == "csv-to-html":
        with open(input_path, "r", encoding="utf-8", newline="") as infile:
            rows = list(csv.DictReader(infile))
        out_html = "<html><body><table border=1>"
        if rows:
            headers = "".join(f"<th>{html_lib.escape(str(h))}</th>" for h in rows[0].keys())
            out_html += f"<tr>{headers}</tr>"
            for r in rows:
                cells = "".join(f"<td>{html_lib.escape(str(v))}</td>" for v in r.values())
                out_html += f"<tr>{cells}</tr>"
        out_html += "</table></body></html>"
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(out_html)

    elif operation == "csv-to-md":
        with open(input_path, "r", encoding="utf-8", newline="") as infile:
            rows = list(csv.reader(infile))
        if rows:
            md = (
                "| "
                + " | ".join(rows[0])
                + " |\n|"
                + ("---|" * len(rows[0]))
                + "\n"
                + "".join("| " + " | ".join(r) + " |\n" for r in rows[1:])
            )
        else:
            md = ""
        with open(output_path, "w", encoding="utf-8") as outfile:
            outfile.write(md)

    else:
        raise ValueError(f"Unsupported python_helper operation: {operation}")


def main() -> None:
    args = sys.argv[1:]
    if not args:
        sys.stderr.write("Usage: python_helper.py <operation> [--] <input> <output>\n")
        sys.exit(2)

    operation = args[0]
    rest = args[1:]
    if rest and rest[0] == "--":
        rest = rest[1:]
    if len(rest) != 2:
        sys.stderr.write("Usage: python_helper.py <operation> [--] <input> <output>\n")
        sys.exit(2)

    input_path = Path(rest[0])
    output_path = Path(rest[1])
    run_conversion(operation, input_path, output_path)


if __name__ == "__main__":
    main()
