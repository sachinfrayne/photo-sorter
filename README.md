# PhotoSorter

A native Mac app. Point it at a folder of photos and videos and it sorts
everything into subfolders by **year → month → location**, using the GPS
and date metadata embedded in each file, and renames each file to
`yyyy-MM-dd-XXXXXXX.ext` so it stays unique even if you later dump every
photo into one flat folder — no more `IMG_0001.jpg` collisions between
different cameras and phones.

```
Photos/
  2024/
    01 - January/
      Italy/
        2024-01-15-8QS5KTY.jpg
      Unknown Location/          ← has a date, but no GPS data
        2024-01-18-2N7RM4C.jpg
    03 - March/
      Japan/
        2024-03-02-QG8VGFW.mov
  Unknown Date/                  ← no usable date or GPS at all (rare)
    IMG_9999.jpg                 ← left as-is; nothing to build a name from
```

The 7-character suffix is random, drawn from an alphabet that skips
look-alike characters (`0/O`, `1/I/L`) — with ~34 billion combinations per
day, a collision is effectively impossible. On the rare occasion two files
do land on the exact same name, the usual `_1`, `_2` suffix kicks in.

Supports JPEG, HEIC, PNG, TIFF, RAW (CR2/CR3/NEF/ARW/DNG/RW2/ORF/RAF), MP4,
MOV, M4V, AVI and MKV. Sidecar files (`.aae`, `.xmp`, `.thm`) are renamed
and travel with their paired photo. Running it again on an already-sorted
folder is safe — files that are already renamed and in the right place are
left alone.

Built as a native SwiftUI app using Apple's own frameworks: `ImageIO` for
EXIF/GPS on photos, `AVFoundation` for video metadata, and `CoreLocation`
for turning GPS coordinates into a country name. No Python runtime, no
bundled `exiftool`, nothing to download separately.

---

## Using the app

1. Download `PhotoSorter.dmg` from the [Actions tab](../../actions) (open
   the latest successful run, scroll to **Artifacts**), or build it
   yourself (see below).
2. Open the DMG and drag `PhotoSorter.app` into your photos folder (or
   anywhere you like — it just needs to be pointed at the folder).
3. Double-click it, confirm the folder shown (or click **Browse…**, or
   drag a folder onto the window), then click **Sort Photos**.

### First launch only

macOS blocks apps downloaded from the internet until you allow them once —
this is Apple's Gatekeeper, not a bug in the app. `PhotoSorter.dmg` includes
`FIRST TIME ON MAC.txt` with the steps. Short version:

1. Double-click `PhotoSorter.app` once (macOS will block it — expected)
2. Open **System Settings → Privacy & Security**, scroll down, click
   **Open Anyway** next to the PhotoSorter message, then confirm

If that doesn't appear, the always-works fallback is Terminal:

```bash
xattr -dr com.apple.quarantine /path/to/PhotoSorter.app
```

(Easiest way to get the path right: type `xattr -dr com.apple.quarantine `
with a trailing space, then drag the `.app` from Finder into the Terminal
window before pressing Return.)

After that one-time step, double-click `PhotoSorter.app` normally, forever.

> Without a paid Apple Developer account there's no way to skip this
> Gatekeeper step entirely — that requires notarization ($99/year). The app
> *is* signed (ad-hoc), which avoids the separate "app is damaged" error
> that unsigned Apple Silicon builds can hit; this step is just the normal
> one-time "I trust this app" confirmation.

---

## Building

Requires the Xcode Command Line Tools (`xcode-select --install`) — full
Xcode isn't needed.

```bash
./build_mac.sh
```

Produces `dist/PhotoSorter.app` and `dist/PhotoSorter.dmg`.

Alternatively, push to GitHub — the Actions workflow builds it
automatically and uploads the DMG as a downloadable artifact.

## Running from source

```bash
swift run
```
