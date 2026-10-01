#!/usr/bin/env bash
# Kopieert de hero-mockups uit vtk-website-new naar deze repo, herschrijft de
# paden naar apps/web/public naar een lokale assets/-map en pusht naar GitHub
# Pages. Gebruik: ./sync.sh ["commitboodschap"]
set -euo pipefail
SRC="${SRC:-$HOME/immich-test/vtk-website-new}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# Oude kopie weg (behalve repo-bestanden), nieuwe erin.
find . -mindepth 1 -maxdepth 1 ! -name .git ! -name sync.sh ! -name README.md ! -name .nojekyll -exec rm -rf {} +
cp -R "$SRC/design/hero-varianten/." .

# Enkel de assets die echt gebruikt worden.
grep -rhoE '(\.\./)+apps/web/public/[^"'"'"' )]+' --include='*.html' . \
  | sed -E 's#^(\.\./)+apps/web/public/##' | sort -u | while read -r f; do
    mkdir -p "assets/$(dirname "$f")"
    cp "$SRC/apps/web/public/$f" "assets/$f"
  done

# Diepte 2 (zot/, voorstel/, kleur/) eerst, dan diepte 1.
find . -name '*.html' -not -path './.git/*' -exec sed -i '' \
  -e 's#\.\./\.\./\.\./apps/web/public/#../assets/#g' \
  -e 's#\.\./\.\./apps/web/public/#assets/#g' {} +

# Mappen die nog niet in de index staan, krijgen er een sectie bij.
python3 - <<'PY'
import pathlib, re, json
idx = pathlib.Path("index.html"); html = idx.read_text()
for d in sorted(p for p in pathlib.Path(".").iterdir() if p.is_dir() and not p.name.startswith(".") and p.name != "assets"):
    if f'"{d.name}/' in html: continue
    items = []
    for f in sorted(d.glob("*.html")):
        m = re.search(r"<title>(.*?)</title>", f.read_text(), re.S)
        items.append([f"{d.name}/{f.name}", m.group(1).strip() if m else f.stem, ""])
    if not items: continue
    block = f"<h2>{d.name.capitalize()}</h2>\n<div class=\"grid\" data-list='{json.dumps(items, ensure_ascii=False)}'></div>\n\n"
    html = html.replace("<script>", block + "<script>", 1)
idx.write_text(html)
PY

git add -A
if git diff --cached --quiet; then echo "Niets veranderd."; exit 0; fi
git commit -q -m "${1:-Mockups bijgewerkt}"
git push -q
echo "Gepusht. Pages bouwt opnieuw (± 1 min)."
