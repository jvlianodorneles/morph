# Convert Orb

A high-craft radial format conversion orb for **Omarchy** on Wayland / Hyprland, powered by [**SimplyConvertFile**](https://github.com/ThigSchuch/SimplyConvertFile).

Convert files instantly across 80+ supported formats without opening traditional dialogs: drag any file while holding <kbd>Shift</kbd>, hover over your desired output format on the blooming orb, and drop.

![Convert Orb Preview](assets/convert-icon.svg)

---

## Features

- **Drag + Shift Summon:** Drag any supported file from any file manager (GNOME Files, Flea, Dolphin, Nemo, Thunar) while holding <kbd>Shift</kbd> to summon the orb directly under your cursor.
- **Dynamic Radial Sectors:** Automatically detects the source file type and generates radial wheel slices for compatible conversion formats.
- **Powered by SimplyConvertFile:** Supports Images, Audio, Video, Documents, Spreadsheets, Presentations, and Archives.
- **Intelligent Ranking & Paging:** Prioritizes your favorite formats at the top 12 o'clock position; supports mouse wheel scroll or footer paging when 8+ formats are available.
- **Multi-File Batch Conversion:** Drop multiple files simultaneously to convert them all in one operation.
- **Integrated Settings Panel:** Click the center hub (or press <kbd>Home</kbd> / <kbd>S</kbd>) to configure preferred formats by category, output directory, triggers, and appearance.
- **Wayland Native & Performant:** Zero CPU overhead when idle; uses Wayland LayerShell and pure Qt Quick / HTML5 Canvas rendering.

---

## Usage

### 1. Instant Drag-and-Drop Conversion
1. In your favorite file manager (or desktop), click and hold a file.
2. Hold down the <kbd>Shift</kbd> key.
3. The Convert Orb blooms around your pointer with slices for all compatible target formats.
4. Move your cursor onto the target format (e.g. `WEBP`, `PNG`, `MP3`, `PDF`) and release the mouse button.
5. Convert Orb converts the file in the background and sends a desktop notification when complete.

### 2. Settings Panel
- Press <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>C</kbd> or click the center hub of the wheel to open settings.
- Rearrange preferred formats per category (Images, Video, Audio, Documents, Archives).
- Toggle Drag + Shift detection, change diameter, or choose a custom output destination folder.

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
  "dragShift": true,
  "shortcut": "SUPER + ALT + C",
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

## License

MIT
