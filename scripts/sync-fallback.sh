#!/usr/bin/env bash
# sync-fallback.sh — Fetch Google Sheet via gws, convert to nested JSON,
# and patch the FALLBACK_DATA line in ai-landscape.html.
set -euo pipefail

SHEET_ID="${SHEET_ID:?SHEET_ID must be set}"
TAB="${TAB:?TAB must be set}"
HTML="${HTML:-ai-landscape.html}"

# Resolve HTML path relative to repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HTML_PATH="$REPO_DIR/$HTML"

if [ ! -f "$HTML_PATH" ]; then
  echo "ERROR: $HTML_PATH not found" >&2
  exit 1
fi

echo "Fetching sheet data..."
CSV=$(gws sheets +read --spreadsheet "$SHEET_ID" --range "$TAB" --format csv)

if [ -z "$CSV" ]; then
  echo "ERROR: Got empty response from gws" >&2
  exit 1
fi

echo "Converting CSV to FALLBACK_DATA JSON..."
FALLBACK_JSON=$(python3 -c "
import csv, json, sys, io

reader = csv.DictReader(io.StringIO(sys.stdin.read()))
category_map = {}

for row in reader:
    cat = row['category']
    if cat not in category_map:
        category_map[cat] = {
            'name': cat,
            'color': row['category_color'],
            'icon': row['category_icon'],
            'children': []
        }
    overall = 0
    ai = 0
    try:
        overall = float(row['overall_revenue_B'])
    except (ValueError, TypeError):
        pass
    try:
        ai = float(row['pure_ai_revenue_B'])
    except (ValueError, TypeError):
        pass
    pure_play = row.get('pure_play', '').strip().upper() == 'TRUE'
    note = row.get('note', '') or ''

    category_map[cat]['children'].append({
        'name': row['company'],
        'value': overall,
        'ai': ai,
        'purePlay': pure_play,
        'note': note
    })

tree = {'name': 'AI Landscape', 'children': list(category_map.values())}
print(json.dumps(tree, ensure_ascii=False, separators=(',', ':')))
" <<< "$CSV")

if [ -z "$FALLBACK_JSON" ]; then
  echo "ERROR: JSON conversion produced empty output" >&2
  exit 1
fi

echo "Patching $HTML_PATH..."
python3 -c "
import sys, re

html_path = sys.argv[1]
new_json = sys.argv[2]

with open(html_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

found = False
for i, line in enumerate(lines):
    if line.strip().startswith('const FALLBACK_DATA ='):
        lines[i] = 'const FALLBACK_DATA = ' + new_json + ';\n'
        found = True
        break

if not found:
    print('ERROR: Could not find FALLBACK_DATA line in HTML', file=sys.stderr)
    sys.exit(1)

with open(html_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print('Done — FALLBACK_DATA updated on line', i + 1)
" "$HTML_PATH" "$FALLBACK_JSON"
