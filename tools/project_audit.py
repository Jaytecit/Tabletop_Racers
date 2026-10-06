"""Project reference checks; regenerate the documentation classification CSV."""
from pathlib import Path
import collections
import csv
import json
import os
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', '.godot', '.summer', 'archive', '__MACOSX', '__pycache__', '.assetmanager', 'builds', 'node_modules'}
TEXT = {'.gd', '.tscn', '.tres', '.godot', '.gdshader', '.cfg', '.json', '.fnt', '.gdextension'}

def inventory():
    files = {}
    for folder, directories, names in os.walk(ROOT):
        directories[:] = [name for name in directories if name not in SKIP]
        for name in names:
            path = Path(folder) / name
            files[path.relative_to(ROOT).as_posix()] = path
    # Audit durable project instructions without traversing local engine caches.
    for path in [ROOT/'.summer/art-bible.md', *(ROOT/'.summer/plans').glob('*.md')]:
        if path.is_file():
            files[path.relative_to(ROOT).as_posix()] = path
    texts = {k: p.read_text(encoding='utf-8', errors='replace')
             for k, p in files.items() if p.suffix in TEXT}
    refs = {k: set(re.findall(r'res://([^"\n]+)', text)) for k, text in texts.items()}
    prefixes = ('tracks/', 'environments/', 'tests/', 'tools/', 'scripts/tracks/',
                'scripts/race/', 'scripts/vehicles/', 'assets/', 'audio/',
                'addons/asset_manager/', 'addons/godot_mcp_toolkit/')
    todo = [k for k in texts if k.startswith(prefixes) or '/' not in k]
    todo += ['scenes/app.tscn', 'scripts/profile_store.gd', 'scripts/app.gd']
    seen = set()
    while todo:
        key = todo.pop()
        if key in seen:
            continue
        seen.add(key)
        todo.extend(x for x in refs.get(key, ()) if x in files)
    return files, texts, refs, seen

def documentation_audit(files):
    rows = []
    broken = []
    for key, path in sorted(files.items()):
        if path.suffix.lower() not in {'.md', '.txt', '.pdf'}:
            continue
        decision = ('historical evidence' if key.startswith(('tests/', 'docs/verification/')) else
                    'vendor source documentation' if key.startswith('addons/') else
                    'source attribution' if 'credit' in path.name.lower() or 'licen' in path.name.lower() else
                    'retained specification with current-status override' if key.startswith('.summer/plans/') else
                    'editorial/reference documentation' if key.startswith(('marketing/', 'assets/video/', 'docs/art-reference/')) else
                    'current project documentation')
        rows.append({'path': key, 'classification': decision,
                     'review': 'retain original run/source meaning' if decision in {'historical evidence', 'vendor source documentation', 'source attribution'} else 'reconciled with current-build authority',
                     'authority': 'docs/current-build.md' if decision not in {'vendor source documentation', 'source attribution'} else 'scoped source notice'})
        if path.suffix != '.md' or decision in {'historical evidence', 'vendor source documentation'}:
            continue
        content = path.read_text(encoding='utf-8', errors='replace')
        for target in re.findall(r'\]\(([^)]+)\)', content):
            target = unquote(target.strip('<>').split('#')[0])
            if not target or '://' in target or target.startswith(('mailto:', 'app:', 'codex:')):
                continue
            if not (path.parent / target).exists():
                broken.append({'file': key, 'target': target})
    return rows, broken

def build_checks():
    """Check high-risk current claims against source constants, without running gameplay."""
    catalog = (ROOT/'scripts/tracks/content_catalog.gd').read_text(encoding='utf-8')
    ids = re.findall(r'"([^"]+)"', re.search(r'const IDS: Array\[String\] = \[(.*?)\]', catalog).group(1))
    schema = int(re.search(r'const SCHEMA_VERSION: int = (\d+)', (ROOT/'scripts/profile_store.gd').read_text(encoding='utf-8')).group(1))
    current = (ROOT/'docs/current-build.md').read_text(encoding='utf-8')
    course_readme = (ROOT/'tracks/README.md').read_text(encoding='utf-8')
    checks = {
        'eleven_catalogue_entries': len(ids)==11,
        'all_catalogue_ids_documented': all(f'| {course} |' in course_readme for course in ids),
        'profile_schema_documented': f'Profile schema is {schema}.' in current,
        'eight_car_scope_documented': '0–7 AI' in current,
        'pending_solid_finishers_documented': 'solid run-out/parking is pending' in current,
    }
    return {'checks':checks, 'passed':all(checks.values()), 'active_ids':ids, 'profile_schema':schema}

if __name__ == '__main__':
    files, texts, refs, seen = inventory()
    docs, broken = documentation_audit(files)
    output = ROOT / 'docs/documentation-audit.csv'
    with output.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=['path', 'classification', 'review', 'authority'])
        writer.writeheader()
        writer.writerows(docs)
    report = {
        'root_counts': dict(collections.Counter(k.split('/')[0] for k in files)),
        'protected_roots': sorted({k.split('/')[0] for k in seen}),
        'protected_addons': sorted({'/'.join(k.split('/')[:2]) for k in seen if k.startswith('addons/')}),
        'protected_other_scripts': sorted(k for k in seen if k.startswith('scripts/') and not k.startswith(('scripts/race/', 'scripts/tracks/', 'scripts/vehicles/'))),
        'documentation_files': len(docs),
        'documentation_classes': dict(collections.Counter(row['classification'] for row in docs)),
        'broken_current_document_links': broken,
        'current_build_consistency': build_checks(),
    }
    (ROOT/'docs/documentation-audit-summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report, indent=2))
    raise SystemExit(1 if broken or not report['current_build_consistency']['passed'] else 0)
