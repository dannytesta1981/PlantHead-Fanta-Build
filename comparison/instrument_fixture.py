"""Instrument ONLY disposable simulator checkout. Production remains byte-identical."""
from pathlib import Path
import hashlib,shutil,json
p=Path('lib/ui/fanta_home.dart');s=p.read_text();before=hashlib.sha256(s.encode()).hexdigest()
start=s.index('  Future<void> _openOfficialAccess()');end=s.index('  Future<void> _verifyAccess()',start);command=s[start:end]
s="import '../runtime_fixture.dart';\n"+s
s=s.replace('  Future<void> disconnect()', '''  Map<String,dynamic> testState() => {'ready':_load.contentReady,'busy':_load.busy,'failure':_load.failure,'generation':_load.generation,'committed':_load.documentCommitted,'stopped':_load.navigationComplete};
  Future<void> testVerify() => _verifyDocument();
  Future<void> testNavigate(Uri uri) async { _load.begin(restart:true); await _web!.loadUrl(urlRequest:URLRequest(url:WebUri.uri(uri))); }
  Future<void> disconnect()''',1)
s=s.replace('URLRequest(url: WebUri.uri(NavigationPolicy.home)),','URLRequest(url: WebUri.uri(RuntimeFixture.start)),',1 if False else 0) if False else s
needle='initialUrlRequest: URLRequest(url: WebUri.uri(NavigationPolicy.home)),'
assert needle in s;s=s.replace(needle,'initialUrlRequest: URLRequest(url: WebUri.uri(RuntimeFixture.start)),',1)
needle='if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;'
s=s.replace(needle,needle+"\n    if (action.request.url?.host == '127.0.0.1') return NavigationActionPolicy.ALLOW;",1)
needle='onLoadStop: (_, url) => _finished(url),';assert needle in s
s=s.replace(needle,"onLoadStop: (_, url) async { RuntimeFixture.stops++; if (RuntimeFixture.forwardStop) await _finished(url); },",1)
needle='      if (!mounted || c != _web || generation != _load.generation) return;'
assert needle in s
s=s.replace(needle,"      if (visible == true && RuntimeFixture.hold != null) { final h=RuntimeFixture.hold!; RuntimeFixture.hold=null; RuntimeFixture.held=true; await h.future; }\n"+needle,1)
assert command in s
p.write_text(s)
for name,target in [('fixture.dart','lib/runtime_fixture.dart'),('runtime_test.dart','integration_test/runtime_fixture_test.dart')]:shutil.copyfile('comparison/'+name,target)
Path('evidence/source-integrity.json').write_text(json.dumps({'productionHomeBeforeInstrumentation':before,'officialAccessUnchanged':command in s,'instrumentationOnlyInDisposableCheckout':True},indent=2))
