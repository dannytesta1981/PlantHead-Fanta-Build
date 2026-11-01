"""Identical observation-only instrumentation in disposable checkouts."""
from pathlib import Path
import sys,shutil,hashlib,json
r=Path(sys.argv[1]);p=r/'lib/ui/fanta_home.dart';s=p.read_text()
s="import '../comparison_observer.dart';\n"+s
for needle,event in [("_trace.event('web_created');",'created'),("_trace.started(_uri);",'start'),("widget.store.diagnostics.record(ok ? 'web_dom_ready' : 'web_dom_empty');",'dom_probe'),("_load.onTimeout = () {",'timeout')]:
 assert needle in s,needle;s=s.replace(needle,needle+"\n CompareObserver.event('"+event+"');",1)
stop = '_loadStopped = true;' if '_loadStopped = true;' in s else '_load.navigationStopped();'
assert stop in s
s=s.replace(stop,stop+" CompareObserver.event('stop');",1)
s=s.replace("onLoadStop: (_, url) => _finished(url),", "onLoadStop: (_, url) async { CompareObserver.event('stop_observed'); if (CompareObserver.naturalStop) { await _finished(url); } else { CompareObserver.event('stop_withheld'); } },",1)
if "widget.store.diagnostics.record('web_content_usable');" in s:
 s=s.replace("widget.store.diagnostics.record('web_content_usable');", "widget.store.diagnostics.record('web_content_usable'); CompareObserver.event('content_usable');",1)
needle="onPageCommitVisible: (_, url) => _trace.event("
if needle in s:
 s=s.replace(needle,"onPageCommitVisible: (_, url) { CompareObserver.event('commit'); _trace.event(",1)
 needle="mainFrame: true,\n      ),\n      onProgressChanged"
 assert needle in s;s=s.replace(needle,"mainFrame: true,\n      ); },\n      onProgressChanged",1)
else:
 needle='onPageCommitVisible: (_, url) {'
 assert needle in s;s=s.replace(needle,needle+" CompareObserver.event('commit');",1)
s=s.replace('onReceivedError: (_, request, error) {',"onReceivedError: (_, request, error) { CompareObserver.event(request.isForMainFrame == true ? 'main_error' : 'subframe_error');",1)
s=s.replace('onReceivedHttpError: (_, request, response) {',"onReceivedHttpError: (_, request, response) { CompareObserver.event(request.isForMainFrame == true ? 'main_http_error' : 'subframe_http_error');",1)
s=s.replace('onWebContentProcessDidTerminate: (_) {',"onWebContentProcessDidTerminate: (_) { CompareObserver.event('terminated');",1)
s=s.replace('initialUserScripts: UnmodifiableListView<UserScript>([]),',"initialUserScripts: UnmodifiableListView<UserScript>([UserScript(source: CompareObserver.script, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START)]),",1)
p.write_text(s)
for src,dst in [('observer.dart','lib/comparison_observer.dart'),('probe_test.dart','integration_test/comparison_test.dart'),('driver.dart','test_driver/comparison_driver.dart')]:shutil.copyfile(Path(__file__).parent/src,r/dst)
print('observation_instrumentation_applied')

# The same read-only policy is available to the test in the old baseline too.
asset='assets/content_readiness.js'
shutil.copyfile(Path(__file__).parent.parent/asset,r/asset)
manifest=r/'pubspec.yaml';m=manifest.read_text()
if asset not in m:manifest.write_text(m.rstrip()+'\n    - '+asset+'\n')
