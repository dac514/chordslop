#!/usr/bin/env python3
"""Capture the ChordSlop dialog window as a PNG, for compose.py.

Works on Linux (X11, or XWayland: Renoise is an X11 program), Windows and
macOS. It needs Pillow on Windows, ImageMagick's `import` and `xprop` on
Linux, and nothing extra on macOS. See scripts/cover/README.md.

    python3 scripts/cover/capture.py dist/cover/window.png
"""

import argparse
import importlib.util
import subprocess
import sys
import time
from pathlib import Path

TITLE = "ChordSlop"  # App.name in src/app.lua: the dialog's window title

HERE = Path(__file__).resolve().parent
EXIT_UNSUPPORTED = 5  # the same code as scripts/renoise.py


def load_renoise_py():
    """scripts/renoise.py as a module, for its platform and X11 helpers."""
    spec = importlib.util.spec_from_file_location("renoise_cli", HERE.parent / "renoise.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fail(message, code=1):
    print("error " + message)
    sys.exit(code)


def capture_linux(rn, out):
    """Find the dialog among Renoise's X11 windows and grab only that window."""
    if not rn.which("xprop") or not rn.which("import"):
        fail("needs xprop and ImageMagick's import (dnf install xprop ImageMagick)", EXIT_UNSUPPORTED)
    # a dialog that has just opened can take a moment to be mapped
    for _ in range(10):
        windows = rn.x11_renoise_windows()
        match = [wid for wid, name in windows if name == TITLE]
        if match:
            break
        time.sleep(0.3)
    if not match:
        names = ", ".join('"%s"' % name for _, name in windows) or "none"
        fail("no %s window; open the dialog first (Renoise windows: %s)" % (TITLE, names))
    r = rn.run(["import", "-window", match[0], str(out)], timeout=30)
    if r.returncode != 0:
        fail("import failed: " + (r.stderr.strip() or "no output"))


def capture_windows(out):
    """Bring the dialog to the front and grab its rectangle from the screen."""
    import ctypes
    from ctypes import wintypes

    try:
        from PIL import ImageGrab
    except ImportError:
        fail("needs Pillow: python -m pip install pillow")
    user32 = ctypes.windll.user32
    user32.SetProcessDPIAware()  # window rectangles in real pixels on scaled screens
    found = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def visit(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            if buf.value == TITLE:
                found.append(hwnd)
                return False
        return True

    user32.EnumWindows(visit, 0)
    if not found:
        fail("no %s window; open the dialog first" % TITLE)
    user32.SetForegroundWindow(found[0])
    time.sleep(0.5)
    rect = wintypes.RECT()
    user32.GetWindowRect(found[0], ctypes.byref(rect))
    bbox = (rect.left, rect.top, rect.right, rect.bottom)
    ImageGrab.grab(bbox=bbox, all_screens=True).save(out)


def capture_macos(out):
    """Ask System Events where the dialog is, then grab that rectangle."""
    script = (
        'tell application "Renoise" to activate\n'
        'tell application "System Events" to tell process "Renoise"\n'
        '  set {x, y} to position of window "%s"\n'
        '  set {w, h} to size of window "%s"\n'
        "end tell\n"
        'return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)'
    ) % (TITLE, TITLE)
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    if r.returncode != 0:
        fail(
            "cannot find the %s window (%s). Open the dialog, and allow the terminal "
            "under System Settings > Privacy > Accessibility." % (TITLE, r.stderr.strip())
        )
    time.sleep(0.4)
    r = subprocess.run(["screencapture", "-x", "-R", r.stdout.strip(), str(out)])
    if r.returncode != 0:
        fail("screencapture failed")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("out", help="PNG file to write, e.g. dist/cover/window.png")
    args = ap.parse_args()
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    rn = load_renoise_py()
    if rn.PLATFORM == "linux":
        capture_linux(rn, out)
    elif rn.PLATFORM == "windows":
        capture_windows(out)
    elif rn.PLATFORM == "macos":
        capture_macos(out)
    else:
        fail(
            "WSL cannot see Windows windows; run this script with Windows Python instead",
            EXIT_UNSUPPORTED,
        )
    if not out.is_file() or out.stat().st_size == 0:
        fail("no image was written")
    print("ok %s" % out)


if __name__ == "__main__":
    main()
