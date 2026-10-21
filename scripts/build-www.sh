#!/usr/bin/env bash
# Build the SOPCheck web app for the native shell: static export at the app root, native flags on, Pyodide + Python wheels +
# Tesseract OCR vendored so the app starts and parses offline. AI parsing uses the same proxy as the web preview (optional).
set -euo pipefail
cd "$(dirname "$0")/.."
MOBILE="$PWD"; FE="$MOBILE/../frontend"
AI_URL="${NEXT_PUBLIC_AI_PROXY_URL:-$(cat "$MOBILE/../worker/WORKER_URL" 2>/dev/null || true)}"
# 1) static export (root base path) with the in-app backend
( cd "$FE" && NEXT_PUBLIC_BASE_PATH= NEXT_PUBLIC_NATIVE=1 NEXT_PUBLIC_HIDE_PURCHASE_ON="${NEXT_PUBLIC_HIDE_PURCHASE_ON-ios}" NEXT_PUBLIC_PYODIDE_LOCAL=1 NEXT_PUBLIC_AI_PROXY_URL="$AI_URL" ./scripts_build_demo.sh )
rm -rf www && cp -r "$FE/out" www && rm -f www/.nojekyll
# 2) vendor Pyodide core + the packages the backend needs (from the same version the web preview uses)
PYV=0.27.7; CDN="https://cdn.jsdelivr.net/pyodide/v$PYV/full"; CACHE="$MOBILE/.cache/pyodide-$PYV"; mkdir -p "$CACHE/wheels"
for f in pyodide.js pyodide.asm.js pyodide.asm.wasm python_stdlib.zip pyodide-lock.json; do [ -s "$CACHE/$f" ] || curl -fsSL "$CDN/$f" -o "$CACHE/$f"; done
python3 - "$CACHE" "$CDN" <<'PY'
import json, sys, urllib.request, os
cache, cdn = sys.argv[1], sys.argv[2]
L = json.load(open(f"{cache}/pyodide-lock.json"))["packages"]
want = ["sqlalchemy","pydantic","tzdata","ssl","httpx","bcrypt","anyio","sniffio","idna","typing-extensions","annotated-types","h11","httpcore","certifi"]
seen, stack = set(), list(want)
while stack:
    n = stack.pop().lower().replace("_", "-")
    if n in seen: continue
    seen.add(n); stack += L[n]["depends"]
for n in sorted(seen):
    fn = L[n]["file_name"]; p = f"{cache}/{fn}"
    if not os.path.exists(p): urllib.request.urlretrieve(f"{cdn}/{fn}", p)
print("pyodide packages:", len(seen))
PY
# pure-Python wheels not in the Pyodide distribution (same pins as the web preview)
VENV="$MOBILE/.cache/pipvenv"; [ -x "$VENV/bin/pip" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" download -q --no-deps --only-binary=:all: -d "$CACHE/wheels" fastapi==0.115.6 "starlette>=0.40,<0.42" python-multipart pyjwt pypdf
( cd "$CACHE/wheels" && python3 -c "import json,glob;json.dump(sorted(glob.glob('*.whl')),open('index.json','w'))" )
mkdir -p www/vendor && cp -r "$CACHE" www/vendor/pyodide
# 3) on-device OCR for camera scans (Tesseract, English model)
T=www/vendor/tesseract; mkdir -p "$T/core" "$T/lang"
cp node_modules/tesseract.js/dist/tesseract.min.js node_modules/tesseract.js/dist/worker.min.js "$T/"
cp node_modules/tesseract.js-core/tesseract-core*.wasm.js node_modules/tesseract.js-core/tesseract-core*.wasm "$T/core/" 2>/dev/null || true
LANG_GZ="$MOBILE/.cache/eng.traineddata.gz"; [ -s "$LANG_GZ" ] || curl -fsSL https://cdn.jsdelivr.net/npm/@tesseract.js-data/eng@1.0.0/4.0.0_best_int/eng.traineddata.gz -o "$LANG_GZ"
cp "$LANG_GZ" "$T/lang/"
du -sh www | cut -f1 | sed 's/^/www size: /'
