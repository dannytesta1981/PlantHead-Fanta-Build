import 'dart:convert';
import 'package:flutter/foundation.dart';

class CompareObserver {
  static final clock = Stopwatch()..start();
  static final events = <Map<String, Object>>[];
  static void event(String category) {
    events.add({'ms':clock.elapsedMilliseconds,'event':category});
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
