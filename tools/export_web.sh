#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${GODOT_BIN:-}" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT_BIN=godot
  else GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot; fi
fi
mkdir -p build/web
"$GODOT_BIN" --headless --editor --path . --import --quit
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html
cp web/cover.png web/hover.wav web/press.wav build/web/
python3 - <<'PY'
from pathlib import Path
import zipfile, hashlib, json
web=Path("build/web")
pack=web / "index.pck"
name="game-"+hashlib.sha256(pack.read_bytes()).hexdigest()[:12]+".pck"
pack.rename(web / name)
html=web / "index.html"
html.write_text(html.read_text().replace("const canvas=", "config.mainPack="+json.dumps(name)+";\nconst canvas=",1))
with zipfile.ZipFile('build/corsair-tides-web.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(Path('build/web').iterdir()):
  if p.is_file() and (not p.name.startswith("game-") or p.name==name):z.write(p,p.name)
PY
