"""Reduce simulator system logs to closed categories; never export raw messages."""
import json, sys
from collections import Counter
from pathlib import Path
raw = Path(sys.argv[1]).read_text(errors='replace')
try:
    events = json.loads(raw)
except json.JSONDecodeError:
    events = []
counts = Counter()
for e in events if isinstance(events, list) else []:
    message = str(e.get('eventMessage', '')).lower()
    level = str(e.get('messageType', '')).lower()
    if level in {'error', 'fault'}:
        counts['native_error_or_fault'] += 1
    for key, signature in {
        'uncaught_exception': 'uncaught exception',
        'fatal_exception': 'fatal exception',
        'webkit_process_terminated': 'webcontentprocessdidterminate',
        'tls_auth_cancelled': 'authentication challenge',
        'cancelled_url_request': '-999',
        'tls_failure': '-1200',
        'certificate_failure': '-1202',
        'network_unreachable': '-1009',
        'connection_failure': '-1004',
    }.items():
        if signature in message:
            counts[key] += 1
print(json.dumps({'parsedNativeEvents': len(events), 'categories': dict(counts),
                  'rawMessagesExported': False}, indent=2))
