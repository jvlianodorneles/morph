# Morph

A high-craft radial format conversion orb for **Omarchy** on Wayland / Hyprland, powered by [**SimplyConvertFile**](https://github.com/ThigSchuch/SimplyConvertFile).

Convert files instantly across 80+ supported formats without opening traditional dialogs: click any file while holding <kbd>Alt</kbd> (or press <kbd>Alt</kbd> + <kbd>C</kbd>), click your desired output format on the blooming orb, and transform instantly.

![Morph Preview](preview.png)

---

## Features

- **Alt + Left Click Summon:** Click any supported file in your file manager (GNOME Files / Nautilus, Flea, Dolphin, Nemo, Thunar) while holding <kbd>Alt</kbd> to summon Morph directly under your cursor.
- **Dynamic Radial Sectors:** Automatically detects the source file type and generates radial wheel slices for compatible conversion formats.
- **Powered by SimplyConvertFile:** Supports Images, Audio, Video, Documents, Spreadsheets, Presentations, and Archives.
- **Intelligent Ranking & Paging:** Prioritizes your favorite formats at the top 12 o'clock position; supports mouse wheel scroll or footer paging when 8+ formats are available.
- **Multi-File Batch Conversion:** Select multiple files simultaneously to convert them all in one operation.
- **Integrated Settings Panel:** Click the center hub (or press <kbd>Home</kbd> / <kbd>S</kbd>) to configure preferred formats by category, output directory, triggers, and appearance.
- **Wayland Native & Performant:** Zero CPU overhead when idle; uses Wayland LayerShell and pure Qt Quick / HTML5 Canvas rendering.

---

## Dependencies

Morph relies on the following runtime tools and libraries:
- **Python 3** (and standard library modules)
- [**SimplyConvertFile**](https://github.com/ThigSchuch/SimplyConvertFile) (file format conversion backend)
- **wl-clipboard** (`wl-copy` / `wl-paste` for clipboard detection)
- **wtype** (Wayland keystroke emulation to retrieve selected files from active file managers)
- **jq** (used by setup scripts for reading settings)
- **libnotify** (`notify-send` for desktop conversion notifications)
- **Hyprland** (`hyprctl` for dynamic keybinding evaluation and window state)

---

## Installation

### 1. Prerequisites

Install system dependencies via `pacman`:

```bash
sudo pacman -S --needed python wl-clipboard wtype jq libnotify
```

Install the conversion backend [**SimplyConvertFile**](https://github.com/ThigSchuch/SimplyConvertFile):

```bash
git clone https://github.com/ThigSchuch/SimplyConvertFile.git
cd SimplyConvertFile
pip install .
```

### 2. Install Plugin

#### Option 1: Via Omarchy CLI (Recommended)

```bash
omarchy plugin add https://github.com/jvlianodorneles/morph.git --enable
```

#### Option 2: Manual Installation

```bash
git clone https://github.com/jvlianodorneles/morph.git ~/.config/omarchy/plugins/dorneles.convert-orb
omarchy plugin enable dorneles.convert-orb
```

### 3. Update

To update the plugin to the latest version:

```bash
omarchy plugin update dorneles.convert-orb
```

---

## Usage

### 1. Instant Conversion
1. In your favorite file manager (or desktop), select a file.
2. Hold down the <kbd>Alt</kbd> key and click the file (or press <kbd>Alt</kbd> + <kbd>C</kbd>).
3. Morph blooms around your pointer with slices for all compatible target formats.
4. Move your cursor onto the target format (e.g. `WEBP`, `PNG`, `MP3`, `PDF`) and click.
5. Morph converts the file in the background and sends a desktop notification when complete.

### 2. Settings Panel
- Press <kbd>Alt</kbd> + <kbd>C</kbd> or click the center hub of the wheel to open settings.
- Rearrange preferred formats per category (Images, Video, Audio, Documents, Archives).
- Toggle Alt + Click trigger, change diameter, or choose a custom output destination folder.

---

## Configuration

Settings are saved in `~/.config/omarchy/convert-orb.json`:

```json
{
  "diameter": 280,
  "slotCount": 8,
  "animation": true,
  "outputDirectoryMode": "source",
  "customOutputPath": "",
  "notifications": true,
  "altLeftClick": true,
  "shortcut": "ALT + C",
  "preferredFormats": {
    "image": ["PNG", "WEBP", "JPEG", "AVIF", "PDF", "SVG", "GIF", "BMP"],
    "video": ["MP4", "WEBM", "MKV", "MP3", "GIF", "MOV", "AVI"],
    "audio": ["MP3", "WAV", "FLAC", "OGG", "AAC", "OPUS", "M4A"],
    "document": ["PDF", "DOCX", "ODT", "TXT", "EPUB", "HTML"],
    "archive": ["ZIP", "TAR.GZ", "TAR.XZ", "7Z"]
  }
}
```

---

## Uninstallation

To remove Morph from your system:

### Via Omarchy CLI

```bash
omarchy plugin remove dorneles.convert-orb
```

### Manual Removal

```bash
omarchy plugin disable dorneles.convert-orb
rm -rf ~/.config/omarchy/plugins/dorneles.convert-orb
```

### Clean Configuration *(Optional)*

To delete saved preferences and user configuration:

```bash
rm -f ~/.config/omarchy/convert-orb.json
```

---

## Acknowledgements

- Radial wheel UI structure and geometry inspired by [**Orb** (`io.github.tcballard.orb`)](https://github.com/tcballard/omarchy-plugin-orb) by Tom Ballard.
- Format conversion powered by [**SimplyConvertFile**](https://github.com/ThigSchuch/SimplyConvertFile).

---

## License

MIT
