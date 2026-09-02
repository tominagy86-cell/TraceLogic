#!/usr/bin/env bash
# Átnevezés MINDENHOL (macOS/Linux változat). Windows-on: scripts/rename-project.ps1
# Használat:  ./scripts/rename-project.sh <UjNev> [com.ujprefix]
set -euo pipefail

NEW_NAME="${1:?add meg az uj nevet}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/project.config.json"

python3 - "$NEW_NAME" "${2:-}" "$ROOT" "$CONFIG" <<'PY'
import json, os, re, sys, pathlib
new_name, new_prefix, root, config_path = sys.argv[1:5]
if not re.match(r'^[A-Za-z][A-Za-z0-9]*$', new_name):
    sys.exit(f"Ervenytelen nev: {new_name}")
cfg = json.load(open(config_path, encoding='utf-8'))
old_name = cfg['projectName']
old_prefix = cfg['bundleIdPrefix']
new_prefix = new_prefix or old_prefix

def repl(p):
    p = pathlib.Path(p)
    if not p.exists(): return
    s = p.read_text(encoding='utf-8')
    n = s.replace(old_name, new_name)
    if old_prefix != new_prefix:
        n = n.replace(old_prefix, new_prefix)
    if n != s:
        p.write_text(n, encoding='utf-8')
        print("  modositva:", p.relative_to(root))

app_old = pathlib.Path(root, f"App/Sources/App/{old_name}App.swift")
app_new = pathlib.Path(root, f"App/Sources/App/{new_name}App.swift")
repl(app_old)
if app_old.exists() and app_old != app_new:
    app_old.rename(app_new)
    print("  atnevezve:", app_new.relative_to(root))

for rel in ["project.yml", "README.md", "App/Sources/App/Branding.swift", "App/Tests/AppSmokeTests.swift"]:
    repl(pathlib.Path(root, rel))
for md in pathlib.Path(root, "docs").glob("*.md"):
    repl(md)

cfg.update(projectName=new_name, displayName=new_name,
           bundleIdPrefix=new_prefix, organizationName=new_name)
json.dump(cfg, open(config_path, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print("Kesz. Mac-en:  ./scripts/bootstrap-mac.sh")
PY
