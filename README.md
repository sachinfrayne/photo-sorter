# PhotoSorter

Sorts a folder of photos and videos into subfolders organised by country and year/month, using GPS coordinates embedded in the files.

```
Photos/
  2024/
    Italy - January/
    Italy - March/
    Spain - July/
  2025/
    United Kingdom - December/
  Unsorted/          ← no date metadata
```

Supports JPEG, HEIC, PNG, TIFF, RAW (CR2/CR3/NEF/ARW/DNG), MP4, MOV, MKV and more. Sidecar files (`.aae`, `.xmp`) are moved alongside their paired photo.

---

## Using the app

1. Download `PhotoSorter-mac.zip` or `PhotoSorter-windows.zip` from the [Actions tab](../../actions) (open the latest successful run, scroll to **Artifacts**)
2. Unzip and put the app in your photos folder
3. Double-click it, confirm the folder shown, click **Sort Photos**

**Mac first launch:** macOS blocks unverified apps. Right-click → Open to run it once, or strip the quarantine flag:
```bash
xattr -cr PhotoSorter.app
```

**Windows GPS support:** GPS sorting requires `exiftool.exe`. Download it from [exiftool.org](https://exiftool.org) and place it in the same folder as `PhotoSorter.exe`. Without it, photos are sorted by date only with no country folders.

---

## Building

Both scripts create an isolated virtual environment, build, and clean up after themselves.

**Mac** → `dist/PhotoSorter.app`
```bash
./build_mac.sh
```

**Windows** → `dist\PhotoSorter.exe`
```
build_windows.bat
```

Requires Python 3.9+ from [python.org](https://python.org).

Alternatively, push to GitHub — the Actions workflow builds both platforms automatically and uploads them as downloadable artifacts.

---

## Running from source

```bash
python3 PhotoSorter.py
```

Requires Python 3.9+ with tkinter. On macOS this is included with Xcode Command Line Tools (`xcode-select --install`). On Windows, install Python from python.org (tkinter is included by default).
