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

1. Download `PhotoSorter.dmg` (Mac) or `PhotoSorter-windows.zip` from the [Actions tab](../../actions) (open the latest successful run, scroll to **Artifacts**)
2. **Mac:** open the DMG, drag `PhotoSorter.app` into your photos folder
3. **Windows:** unzip and put `PhotoSorter.exe` in your photos folder

### Mac — first launch only

macOS blocks downloaded apps until you allow them once. The DMG includes `FIRST TIME ON MAC.txt` with full steps. Short version:

1. Double-click `PhotoSorter.app` once (macOS will block it)
2. Open **System Settings → Privacy & Security** → click **Open Anyway**

If that button doesn’t appear, use the drag-to-Terminal trick in `FIRST TIME ON MAC.txt` (or run this from the folder containing the app):

```bash
xattr -dr com.apple.quarantine PhotoSorter.app
```

After that one-time step, double-click `PhotoSorter.app` normally.

> Right-click → Open often does **not** work on recent macOS for unsigned downloads. An Apple Developer account (~$99/year) is required to sign and notarize the app so it opens with no extra steps.

### Windows

Double-click `PhotoSorter.exe`, confirm the folder shown, and click **Sort Photos**.

**GPS support:** GPS sorting requires `exiftool.exe`. Download it from [exiftool.org](https://exiftool.org) and place it in the same folder as `PhotoSorter.exe`. Without it, photos are sorted by date only with no country folders.

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
