import json, os, platform, re, shutil, subprocess, sys, time, threading, urllib.request
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, scrolledtext

IS_MACOS = platform.system() == 'Darwin'
IS_FROZEN = getattr(sys, 'frozen', False)

MEDIA_EXTS = {
    '.jpg', '.jpeg', '.heic', '.heif', '.png', '.tiff', '.tif',
    '.cr2', '.cr3', '.nef', '.arw', '.dng', '.rw2', '.orf', '.raf',
    '.mp4', '.mov', '.m4v', '.avi', '.mkv', '.3gp',
}
SIDECAR_EXTS = {'.aae', '.xmp', '.thm'}
MONTHS = ['', 'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December']


def _default_source():
    if len(sys.argv) > 1:
        return Path(sys.argv[1]).resolve()
    if IS_FROZEN:
        exe_parent = Path(sys.executable).parent
        # Inside a macOS .app bundle: PhotoSorter.app/Contents/MacOS/ — step up to the folder
        # containing the .app so photos next to the .app are the default
        if IS_MACOS and exe_parent.name == 'MacOS' and exe_parent.parent.name == 'Contents':
            return exe_parent.parent.parent.parent.resolve()
        return exe_parent.resolve()
    return Path(__file__).parent.resolve()


# ── Metadata ──────────────────────────────────────────────────────────────────

def _find_exiftool():
    exe_dir = Path(sys.executable).parent if IS_FROZEN else Path(__file__).parent
    candidates = [str(exe_dir / 'exiftool.exe'), str(exe_dir / 'exiftool'), 'exiftool']
    for c in candidates:
        try:
            if subprocess.run([c, '-ver'], capture_output=True, timeout=5).returncode == 0:
                return c
        except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
            pass
    return None

EXIFTOOL = None if IS_MACOS else _find_exiftool()

def get_metadata(path):
    if IS_MACOS:
        return _get_metadata_mdls(path)
    return _get_metadata_exiftool(path)

def _get_metadata_mdls(path):
    try:
        out = subprocess.run(
            ['mdls', str(path)], capture_output=True, text=True, timeout=15
        ).stdout

        def flt(k):
            m = re.search(r'{}[ \t]*=[ \t]*(-?[\d.]+)'.format(re.escape(k)), out)
            return float(m.group(1)) if m else None

        def dat(k):
            m = re.search(
                r'{}[ \t]*=[ \t]*"?(\d{{4}}-\d{{2}}-\d{{2}} \d{{2}}:\d{{2}}:\d{{2}})'.format(re.escape(k)),
                out,
            )
            if m:
                try:
                    return datetime.strptime(m.group(1), '%Y-%m-%d %H:%M:%S')
                except ValueError:
                    pass
            return None

        return (
            flt('kMDItemLatitude'),
            flt('kMDItemLongitude'),
            dat('kMDItemContentCreationDate') or dat('kMDItemRecordingDate'),
        )
    except Exception:
        return None, None, None

def _get_metadata_exiftool(path):
    if EXIFTOOL is None:
        try:
            return None, None, datetime.fromtimestamp(path.stat().st_mtime)
        except Exception:
            return None, None, None
    try:
        result = subprocess.run(
            [EXIFTOOL, '-j', '-n',
             '-GPSLatitude', '-GPSLongitude',
             '-DateTimeOriginal', '-CreateDate', '-TrackCreateDate', '-MediaCreateDate',
             str(path)],
            capture_output=True, text=True, timeout=15
        )
        if not result.stdout.strip():
            return None, None, None
        data = json.loads(result.stdout)[0]
        lat = data.get('GPSLatitude')
        lon = data.get('GPSLongitude')
        dt = None
        for key in ('DateTimeOriginal', 'CreateDate', 'TrackCreateDate', 'MediaCreateDate'):
            val = data.get(key)
            if val and isinstance(val, str):
                try:
                    dt = datetime.strptime(val[:19], '%Y:%m:%d %H:%M:%S')
                    break
                except ValueError:
                    pass
        return lat, lon, dt
    except Exception:
        return None, None, None


# ── Geocoding ─────────────────────────────────────────────────────────────────

_cache = {}
_last_req = 0.0

def geocode(lat, lon):
    global _last_req
    if lat is None or lon is None:
        return None
    key = (round(lat, 2), round(lon, 2))
    if key in _cache:
        return _cache[key]
    elapsed = time.time() - _last_req
    if elapsed < 1.1:
        time.sleep(1.1 - elapsed)
    country = None
    try:
        req = urllib.request.Request(
            'https://nominatim.openstreetmap.org/reverse'
            '?format=json&lat={:.5f}&lon={:.5f}&zoom=3'.format(lat, lon),
            headers={'User-Agent': 'PhotoSorter/1.0'},
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            country = json.loads(r.read()).get('address', {}).get('country') or None
    except Exception:
        pass
    _last_req = time.time()
    _cache[key] = country
    return country


# ── Destination path ──────────────────────────────────────────────────────────

def sanitize(name):
    return re.sub(r'[<>:"/\\|?*\x00-\x1f]', '-', name).strip(' .-')[:60]

def dest_for(source, lat, lon, dt):
    if dt is None:
        return source / 'Unsorted'
    country = geocode(lat, lon)
    location = sanitize(country) if country else 'Unknown Location'
    return source / str(dt.year) / '{} - {}'.format(location, MONTHS[dt.month])

def unique_dest(dest_dir, filename):
    target = dest_dir / filename
    if target.exists():
        p = Path(filename)
        n = 1
        while target.exists():
            target = dest_dir / '{}_{}{}'.format(p.stem, n, p.suffix)
            n += 1
    return target


# ── GUI ───────────────────────────────────────────────────────────────────────

BG    = '#1c1c1e'
FG    = '#f0f0f0'
DIM   = '#888'
GREEN = '#34C759'
BLUE  = '#0a84ff'
MONO  = 'Menlo' if IS_MACOS else 'Courier'


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('PhotoSorter')
        self.geometry('640x460')
        self.minsize(480, 360)
        self.configure(bg=BG)

        # Header
        hdr = tk.Frame(self, bg='#2c2c2e')
        hdr.pack(fill='x')
        tk.Label(hdr, text='PhotoSorter', bg='#2c2c2e', fg=FG,
                 font=('Helvetica', 14, 'bold'), pady=9).pack(side='left', padx=14)

        # Folder row
        folder_row = tk.Frame(self, bg='#2c2c2e')
        folder_row.pack(fill='x', padx=8, pady=(0, 0))
        tk.Label(folder_row, text='Folder:', bg='#2c2c2e', fg=DIM,
                 font=('Helvetica', 10)).pack(side='left', pady=6)
        self._folder_var = tk.StringVar(value=str(_default_source()))
        self._folder_entry = tk.Entry(
            folder_row, textvariable=self._folder_var,
            bg='#3a3a3c', fg=FG, font=('Helvetica', 10),
            relief='flat', bd=4, insertbackground=FG,
        )
        self._folder_entry.pack(side='left', fill='x', expand=True, padx=(6, 4), pady=6)
        tk.Button(
            folder_row, text='Browse…', command=self._browse,
            bg='#3a3a3c', fg=FG, activebackground='#4a4a4c',
            font=('Helvetica', 10), relief='flat', pady=3, cursor='hand2',
        ).pack(side='left', padx=(0, 4))

        # Sort button — tk.Button ignores bg on macOS; Frame+Label gives reliable colour
        self._sort_active = True
        self._sort_frame = tk.Frame(self, bg=BLUE, cursor='hand2')
        self._sort_frame.pack(fill='x', padx=8, pady=6)
        self._sort_lbl = tk.Label(
            self._sort_frame, text='Sort Photos',
            bg=BLUE, fg='white',
            font=('Helvetica', 12, 'bold'), pady=7, cursor='hand2',
        )
        self._sort_lbl.pack(fill='x')
        self._sort_frame.bind('<Button-1>', lambda e: self._start_sort())
        self._sort_lbl.bind('<Button-1>',   lambda e: self._start_sort())

        # Status bar
        self._status_var = tk.StringVar(value='Select your photos folder, then click Sort Photos.')
        status_bar = tk.Frame(self, bg='#2c2c2e', height=28)
        status_bar.pack(fill='x')
        tk.Label(
            status_bar, textvariable=self._status_var,
            bg='#2c2c2e', fg=FG, font=('Helvetica', 11), anchor='w',
        ).pack(side='left', padx=12, pady=4)

        # Log
        self._log = scrolledtext.ScrolledText(
            self, bg=BG, fg=FG, font=(MONO, 10),
            state='disabled', relief='flat', bd=0, insertbackground=FG,
        )
        self._log.tag_config('folder', foreground=BLUE)
        self._log.tag_config('skip',   foreground=DIM)
        self._log.tag_config('err',    foreground='#ff453a')
        self._log.tag_config('done',   foreground=GREEN, font=(MONO, 10, 'bold'))
        self._log.tag_config('warn',   foreground='#FF9F0A')
        self._log.pack(fill='both', expand=True, padx=2, pady=2)

        # Close button (disabled until done)
        self._close_btn = tk.Button(
            self, text='Close', command=self.destroy,
            state='disabled', font=('Helvetica', 12),
            bg='#3a3a3c', fg=FG, activebackground='#4a4a4c',
            relief='flat', pady=6, cursor='hand2',
        )
        self._close_btn.pack(fill='x', padx=8, pady=(0, 6))

    def _browse(self):
        current = self._folder_var.get()
        initial = current if Path(current).is_dir() else str(Path.home())
        chosen = filedialog.askdirectory(title='Select photos folder', initialdir=initial)
        if chosen:
            self._folder_var.set(chosen)

    def _start_sort(self):
        if not self._sort_active:
            return
        source = Path(self._folder_var.get()).resolve()
        if not source.is_dir():
            self._status_var.set('Folder not found: {}'.format(source))
            return
        self._sort_active = False
        self._sort_lbl.config(fg='#666', cursor='')
        self._sort_frame.config(bg='#333', cursor='')
        self._sort_lbl.config(bg='#333')
        self._folder_entry.config(state='disabled')
        threading.Thread(target=self._worker, args=(source,), daemon=True).start()

    def _log_line(self, msg, tag=''):
        self._log.config(state='normal')
        self._log.insert('end', msg + '\n', tag)
        self._log.see('end')
        self._log.config(state='disabled')

    def _set_status(self, msg):
        self._status_var.set(msg)

    def _worker(self, source):
        log      = lambda m, t='': self.after(0, self._log_line, m, t)
        status   = lambda m:       self.after(0, self._set_status, m)
        done_btn = lambda:         self.after(0, self._close_btn.config, {'state': 'normal'})

        if not IS_MACOS and EXIFTOOL is None:
            log('WARNING: exiftool not found — GPS location unavailable.', 'warn')
            log('Download exiftool.exe from https://exiftool.org', 'warn')
            log('and place it in the same folder as PhotoSorter.', 'warn')
            log('Photos will be sorted by date only (no country folders).\n', 'skip')

        all_files = []
        sidecar_files = []
        for root, dirs, filenames in os.walk(str(source)):
            dirs.sort()
            for fn in sorted(filenames):
                if fn.startswith('.'):
                    continue
                p = Path(root) / fn
                ext = p.suffix.lower()
                if ext in MEDIA_EXTS:
                    all_files.append(p)
                elif ext in SIDECAR_EXTS:
                    sidecar_files.append(p)

        total = len(all_files)
        if total == 0:
            status('No media files found.')
            log('No supported media files found in:\n  {}'.format(source), 'err')
            log('\nSupported: JPEG · HEIC · PNG · TIFF · RAW · MP4 · MOV · MKV', 'skip')
            done_btn()
            return

        status('Sorting {} files...'.format(total))
        moved = skipped = errors = 0
        stem_to_dest = {}

        for i, fp in enumerate(all_files):
            status('[{}/{}]  {}'.format(i + 1, total, fp.name))
            lat, lon, dt = get_metadata(fp)
            dest_dir = dest_for(source, lat, lon, dt)
            target   = unique_dest(dest_dir, fp.name)
            stem_to_dest[fp.stem.lower()] = dest_dir

            if fp.resolve() == target.resolve():
                skipped += 1
                continue

            dest_dir.mkdir(parents=True, exist_ok=True)
            try:
                shutil.move(str(fp), str(target))
                moved += 1
                rel = '/'.join(target.relative_to(source).parts[:-1])
                log('  {:<40}  →  {}'.format(fp.name, rel), 'folder')
            except Exception as exc:
                errors += 1
                log('  ERROR {}:  {}'.format(fp.name, exc), 'err')

        for sc in sidecar_files:
            dest_dir = stem_to_dest.get(sc.stem.lower())
            if dest_dir is None:
                continue
            target = unique_dest(dest_dir, sc.name)
            if sc.resolve() == target.resolve():
                continue
            try:
                shutil.move(str(sc), str(target))
            except Exception:
                pass

        for dirpath, dirnames, filenames in os.walk(str(source), topdown=False):
            dp = Path(dirpath)
            if dp == source:
                continue
            try:
                if not any(dp.iterdir()):
                    dp.rmdir()
            except Exception:
                pass

        summary = 'Done!  {} moved'.format(moved)
        if skipped: summary += '  ·  {} already sorted'.format(skipped)
        if errors:  summary += '  ·  {} errors'.format(errors)
        log('\n' + summary, 'done')
        status(summary)
        done_btn()


App().mainloop()
