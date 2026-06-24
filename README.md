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

1. Download `PhotoSorter-mac.tar.gz` or `PhotoSorter-windows.zip` from the [Actions tab](../../actions) (open the latest successful run, scroll to **Artifacts**)
2. Unzip the GitHub download if needed, then extract the Mac archive (`PhotoSorter-mac.tar.gz`) or Windows zip
3. Put the files in your photos folder

### Mac

Use **Open PhotoSorter.command** to launch the app (not `PhotoSorter.app` directly).

**First time only** — macOS blocks apps downloaded from the internet:

1. Right-click **Open PhotoSorter.command** → **Open** → click **Open** in the dialog
2. From then on, just double-click **Open PhotoSorter.command**

The launcher clears macOS’s download block automatically — no Terminal needed. See `FIRST TIME ON MAC.txt` in the download if you get stuck.

If macOS still refuses, open **System Settings → Privacy & Security** and click **Open Anyway** (appears after a blocked launch attempt).

<details>
<summary>Terminal fallback (technical)</summary>

```bash
xattr -dr com.apple.quarantine PhotoSorter.app
```

</details>

> To skip the first-time step entirely you would need an Apple Developer account to sign and notarize the app (~$99/year).

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
