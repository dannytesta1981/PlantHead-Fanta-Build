"""One retry only when no real baseline document was available for comparison."""
import json,sys
from pathlib import Path
d=json.loads(Path('evidence/baseline-held/breadcrumbs.json').read_text())
samples=[r['sample'] for r in d['records'] if 'sample'in r]
events=[e['event'] for r in d['records'] for e in r.get('callbacks',[])]
retry=len(samples)==24 and not any(s.get('renderable') is True for s in samples) and ('main_error'in events or not any(s.get('commitSeen') for s in samples))
sys.exit(0 if retry else 1)
