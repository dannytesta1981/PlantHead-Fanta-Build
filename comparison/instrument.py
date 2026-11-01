"""Identical observation-only instrumentation in disposable checkouts."""
from pathlib import Path
import sys,shutil,hashlib,json
r=Path(sys.argv[1]);p=r/'lib/ui/fanta_home.dart';s=p.read_text()
s="import '../comparison_observer.dart';\n"+s
for needle,event in [("_trace.event('web_created');",'created'),("_trace.started(_uri);",'start'),("_loadStopped = true;",'stop'),("widget.store.diagnostics.record(ok ? 'web_dom_ready' : 'web_dom_empty');",'dom_probe'),("_load.onTimeout = () {",'timeout')]:
 assert needle in s,needle;s=s.replace(needle,needle+"\n CompareObserver.event('"+event+"');",1)
needle="onPageCommitVisible: (_, url) => _trace.event("
assert needle in s;s=s.replace(needle,"onPageCommitVisible: (_, url) { CompareObserver.event('commit'); _trace.event(",1)
needle="mainFrame: true,\n      ),\n      onProgressChanged"
assert needle in s;s=s.replace(needle,"mainFrame: true,\n      ); },\n      onProgressChanged",1)
s=s.replace('onReceivedError: (_, request, error) {',"onReceivedError: (_, request, error) { CompareObserver.event(request.isForMainFrame == true ? 'main_error' : 'subframe_error');",1)
s=s.replace('onReceivedHttpError: (_, request, response) {',"onReceivedHttpError: (_, request, response) { CompareObserver.event(request.isForMainFrame == true ? 'main_http_error' : 'subframe_http_error');",1)
s=s.replace('onWebContentProcessDidTerminate: (_) {',"onWebContentProcessDidTerminate: (_) { CompareObserver.event('terminated');",1)
s=s.replace('initialUserScripts: UnmodifiableListView<UserScript>([]),',"initialUserScripts: UnmodifiableListView<UserScript>([UserScript(source: CompareObserver.script, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START)]),",1)
p.write_text(s)
for src,dst in [('observer.dart','lib/comparison_observer.dart'),('probe_test.dart','integration_test/comparison_test.dart'),('driver.dart','test_driver/comparison_driver.dart')]:shutil.copyfile(Path(__file__).parent/src,r/dst)
print('observation_instrumentation_applied')
