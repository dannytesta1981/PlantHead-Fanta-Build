import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planthead_fanta/ui/components.dart';
import 'package:planthead_fanta/ui/fanta_home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/ui/native_home.dart';
import 'package:planthead_fanta/comparison_observer.dart';
void main(){
 final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(() async { CompareObserver.prepare(await getApplicationDocumentsDirectory()); });
 testWidgets('observe real official content and obstruction without login interaction',(tester)async{
  final store=FantaStore();final result=<String,dynamic>{'samples':<Object>[]};binding.reportData=result;
  debugPrint('PHCMP:'+jsonEncode({'phase':'started'}));
  CompareObserver.probe({'phase':'started'});
  try{
   await tester.pumpWidget(MaterialApp(home:NativeHome(store:store)));
   await tester.pump(const Duration(seconds:1));
   await tester.tap(find.byTooltip('Lega e accesso'));await tester.pump();
   final readiness = await rootBundle.loadString('assets/content_readiness.js');
   final clock=Stopwatch()..start();
   for(var i=0;i<24;i++){
    await tester.runAsync(()=>Future<void>.delayed(const Duration(seconds:5)));
    await tester.pump();
    Map<String,dynamic> sample={'ms':clock.elapsedMilliseconds,'commitSeen':CompareObserver.events.any((e)=>e['event']=='commit'),'errorOverlayVisible':find.byType(LoadFailurePanel).evaluate().isNotEmpty,'loadingOverlayVisible':find.text('Caricamento del sito ufficiale…').evaluate().isNotEmpty,'webPageVisible':tester.widget<OfficialWebPage>(find.byType(OfficialWebPage)).visible,'naturalStop':CompareObserver.naturalStop};
    try{
     final raw=await store.controller?.evaluateJavascript(source:r'''
     JSON.stringify((()=>{
       const b=document.body,r=b?.getBoundingClientRect();
       const entries=performance.getEntriesByType('resource');
       return {ready:['loading','interactive','complete'].includes(document.readyState)?document.readyState:'unknown',bodyPresent:!!b,bodySized:!!r&&r.width>0&&r.height>0,bodyHasContent:!!b&&(!!b.innerText.trim()||!!b.querySelector('input,button,img,canvas,iframe')),resourceCompleted:entries.length,resourceHttpFailure:entries.filter(e=>typeof e.responseStatus==='number'&&e.responseStatus>=400).length,resourceStatusUnknown:entries.filter(e=>!e.responseStatus).length,counters:window.__phComparison||null};
     })())
     ''').timeout(const Duration(seconds:4));
     if(raw is String)sample.addAll(Map<String,dynamic>.from(jsonDecode(raw) as Map));else sample['probe']='no_result';
     sample['renderable'] = await store.controller?.evaluateJavascript(source:readiness).timeout(const Duration(seconds:3)) == true;
    }catch(_){sample['probe']='failed_or_timeout';}
    (result['samples'] as List).add(sample);
    debugPrint('PHCMP:'+jsonEncode({'sample':sample,'callbacks':CompareObserver.events.toList()}));
    CompareObserver.probe({'sample':sample,'callbacks':CompareObserver.events.toList()});
   }
   result['callbacks']=CompareObserver.events;

  }finally{
   result['callbacks']=CompareObserver.events;
   debugPrint('PHCMP:'+jsonEncode({'phase':'finished','callbacks':CompareObserver.events.toList()}));
   CompareObserver.probe({'phase':'finished','callbacks':CompareObserver.events.toList()});
   await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  }
 });
}
