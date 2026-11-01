import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:planthead_fanta/ui/fanta_home.dart';
import 'package:planthead_fanta/ui/components.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/runtime_fixture.dart';
void main(){
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('deterministic WKWebView readiness and single official integration',(tester) async {
  final docs=await getApplicationDocumentsDirectory();
  final report=<String,dynamic>{'assertions':<Object>[],'integration':<Object>[]};
  void save()=>File('${docs.path}/runtime-result.json').writeAsStringSync(jsonEncode(report),flush:true);
  void check(String name,bool value){(report['assertions'] as List).add({'name':name,'passed':value});save();expect(value,isTrue,reason:name);}
  Future<void> tick([int ms=250])async{await tester.runAsync(()=>Future<void>.delayed(Duration(milliseconds:ms)));await tester.pump();}
  Future<bool> until(bool Function() condition,int seconds)async{final c=Stopwatch()..start();while(c.elapsed.inSeconds<seconds){if(condition())return true;await tick();}return condition();}
  Future<void> shot(String name)async{
   File('${docs.path}/runtime-shot.txt').writeAsStringSync(name,flush:true);
   final ack=File('${docs.path}/runtime-shot-ack.txt');
   check('screenshot_'+name,await until(()=>ack.existsSync()&&ack.readAsStringSync()==name,15));
  }
  HttpServer? server;FantaStore? store;
  final key=GlobalKey<OfficialWebPageState>();
  try{
   server=await tester.runAsync(()=>HttpServer.bind(InternetAddress.loopbackIPv4,0));
   server!.listen((request){
    request.response.headers.contentType=ContentType.html;
    request.response.write('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:24px;font:24px sans-serif}main{padding:24px;background:#dceaff}button{font-size:24px}</style></head><body>${request.uri.path=='/empty'?'':'<main id="content" hidden><h1>Contenuto locale verificabile</h1><button>Controllo visibile</button></main><script>window.reveal=()=>document.getElementById("content").hidden=false;</script>'}</body></html>');request.response.close();
   });
   Uri local(String path)=>Uri.parse('http://127.0.0.1:${server!.port}$path');
   final probe=await rootBundle.loadString('assets/content_readiness.js');
   Future<void> mount(Uri url,bool stop)async{
    await tester.pumpWidget(const SizedBox.shrink());store?.dispose();await tick();
    RuntimeFixture.start=url;RuntimeFixture.forwardStop=stop;RuntimeFixture.stops=0;RuntimeFixture.hold=null;RuntimeFixture.held=false;
    store=FantaStore();await tester.pumpWidget(MaterialApp(home:OfficialWebPage(key:key,store:store!,onReturn:(){})));await tick();
   }
   Map<String,dynamic> state()=>key.currentState!.testState();
   bool loading()=>find.text('Caricamento del sito ufficiale…').evaluate().isNotEmpty;
   bool error()=>find.byType(LoadFailurePanel).evaluate().isNotEmpty;
   Future<void> reveal()async{await store!.controller!.evaluateJavascript(source:'window.reveal()');}
   Future<bool> renderable()async=>await store!.controller!.evaluateJavascript(source:probe)==true;
   await mount(local('/delayed'),false);
   check('held_commit_received',await until(()=>state()['committed']==true,25));
   check('held_not_ready_without_content',state()['ready']==false&&loading());
   check('hidden_fixture_not_renderable',!await renderable());
   await shot('held-before-content');await reveal();
   check('held_content_unblocks',await until(()=>state()['ready']==true,12));
   check('held_no_stop_dependency',state()['stopped']==false);
   check('held_actual_content_and_no_overlays',await renderable()&&!loading()&&!error());
   await shot('held-visible');
   await mount(local('/normal'),true);
   check('normal_stop_received',await until(()=>state()['stopped']==true&&RuntimeFixture.stops>0,25));
   await reveal();check('normal_content_unblocks',await until(()=>state()['ready']==true,12));
   check('normal_actual_content_and_no_overlays',await renderable()&&!loading()&&!error());await shot('normal-visible');
   await mount(local('/empty'),false);
   check('empty_committed',await until(()=>state()['committed']==true,25));
   check('empty_timeout_observed',await until(()=>state()['failure']=='timeout',40));
   check('empty_not_renderable_and_retry_visible',!await renderable()&&error()&&find.text('Riprova').evaluate().isNotEmpty);
   await shot('empty-timeout');
   final oldGeneration=state()['generation'];await tester.tap(find.text('Riprova').first);await tick();
   check('retry_starts_new_navigation',state()['generation']>oldGeneration&&loading()&&!error());
   await mount(local('/stale'),false);
   check('stale_initial_commit',await until(()=>state()['committed']==true,25));
   final gate=Completer<void>();RuntimeFixture.hold=gate;await reveal();
   unawaited(key.currentState!.testVerify());
   check('stale_probe_really_inflight',await until(()=>RuntimeFixture.held,12));
   final previous=state()['generation'];await key.currentState!.testNavigate(local('/empty'));
   check('stale_new_document_committed',await until(()=>state()['committed']==true&&state()['generation']>previous,25));
   gate.complete();await tick(1500);
   check('stale_result_ignored',state()['ready']==false&&loading()&&!await renderable());await shot('stale-ignored');
   report['deterministicPassed']=true;save();
   // One official-site attempt, no click, login, retry or credentials.
   await mount(Uri.parse('https://leghe.fantacalcio.it/'),true);
   var integrationRegression=false;var usableObserved=false;
   for(var i=0;i<24;i++){
    await tick(5000);
    var usable=false;var probeFailed=false;
    try{usable=await renderable().timeout(const Duration(seconds:4));}catch(_){probeFailed=true;}
    final snap=state();
    (report['integration'] as List).add({'sample':i,'renderable':usable,'probeFailed':probeFailed,'committed':snap['committed'],'ready':snap['ready'],'failure':snap['failure'],'loading':loading(),'error':error(),'stopReceived':snap['stopped']});save();
    if(usable){usableObserved=true;await tick(3000);if(state()['ready']!=true||loading()||error())integrationRegression=true;break;}
   }
   report['integrationResult']=integrationRegression?'observed_regression':usableObserved?'usable_content_visible':'external_document_not_usable_in_window';
   await shot('official-integration');
   check('integration_no_observed_loader_regression',!integrationRegression);
   report['passed']=true;
  }catch(_){report['passed']=false;rethrow;}
  finally{report['finished']=true;save();await tester.pumpWidget(const SizedBox.shrink());store?.dispose();await server?.close(force:true);}
 });
}
