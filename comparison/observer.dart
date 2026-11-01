import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class CompareObserver {
  static bool get naturalStop => Platform.environment['PH_NATURAL_STOP'] == '1';
  static Directory? directory;
  static void prepare(Directory value) {
    directory = value;
    for (final name in ['ph-comparison-probes.log','ph-comparison-events.log']) {
      File('${value.path}/$name').writeAsStringSync('',flush:true);
    }
  }
  static void probe(Map<String,dynamic> record) {
    File('${directory!.path}/ph-comparison-probes.log').writeAsStringSync(
      'PHCMP:'+jsonEncode(record)+'\n',mode:FileMode.append,flush:true);
  }
  static final clock = Stopwatch()..start();
  static final events = <Map<String, Object>>[];
  static void event(String category) {
    events.add({'ms':clock.elapsedMilliseconds,'event':category});
    if (directory != null) File('${directory!.path}/ph-comparison-events.log').writeAsStringSync(
      'PHCMP:'+jsonEncode({'callbacks':[events.last]})+'\n',mode:FileMode.append,flush:true);
    debugPrint('PHCMP:'+jsonEncode({'callbacks':[events.last]}));
  }
  static const script = r'''
  (()=>{
    const c={jsErrors:0,unhandledRejections:0,resourceErrors:0,scriptErrors:0,styleErrors:0,imageErrors:0};
    window.__phComparison=c;
    addEventListener('error',e=>{
      if(e.target===window){c.jsErrors++;return;}
      c.resourceErrors++;
      const t=e.target?.tagName;
      if(t==='SCRIPT')c.scriptErrors++;
      if(t==='LINK')c.styleErrors++;
      if(t==='IMG')c.imageErrors++;
    },true);
    addEventListener('unhandledrejection',()=>c.unhandledRejections++);
  })();
  ''';
}
