#!/bin/bash
# Builds PhotoSorter.app — run this once on a Mac.
# Output: dist/PhotoSorter.app  (double-clickable macOS app)
# Drop icon.png (1024x1024) in this folder to give the app a custom icon.
set -e
cd "$(dirname "$0")"

# Homebrew Python ships without tkinter — install python-tk if needed
if ! python3 -c "import tkinter" &>/dev/null 2>&1; then
  PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
  echo "Installing tkinter for Python $PY_VER..."
  brew install "python-tk@$PY_VER"
fi

echo "Creating build environment..."
python3 -m venv .venv
source .venv/bin/activate

echo "Installing PyInstaller..."
pip install --quiet pyinstaller

# Convert icon.png → icon.icns (macOS) and icon.ico (Windows) if present
ICON_FLAG=""
if [[ -f "icon.png" ]]; then
  echo "Generating icons from icon.png..."
  pip install --quiet pillow

  # macOS .icns via sips + iconutil (built-in macOS tools)
  mkdir -p icon.iconset
  for size in 16 32 128 256 512; do
    sips -z $size $size icon.png --out "icon.iconset/icon_${size}x${size}.png"       &>/dev/null
    sips -z $((size*2)) $((size*2)) icon.png --out "icon.iconset/icon_${size}x${size}@2x.png" &>/dev/null
  done
  iconutil -c icns icon.iconset && rm -rf icon.iconset
  ICON_FLAG="--icon icon.icns"

  # Windows .ico via Pillow (committed to repo so CI can use it too)
  python3 -c "
from PIL import Image
img = Image.open('icon.png').convert('RGBA')
img.save('icon.ico', format='ICO', sizes=[(256,256),(128,128),(64,64),(48,48),(32,32),(16,16)])
"
  echo "Also wrote icon.ico for the Windows build — commit both icon files."
fi

echo "Building PhotoSorter.app..."
pyinstaller --noconfirm --windowed \
    --name PhotoSorter \
    --hidden-import tkinter.scrolledtext \
    $ICON_FLAG \
    PhotoSorter.py

deactivate
rm -rf .venv build PhotoSorter.spec

echo ""
echo "Done: dist/PhotoSorter.app"
echo "Put PhotoSorter.app in your photos folder and double-click it."
