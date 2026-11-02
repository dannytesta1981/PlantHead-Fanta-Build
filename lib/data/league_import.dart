import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'models.dart';

class LeagueImportData {
  const LeagueImportData(this.source, this.ranking, this.matches, this.rosters);
  final String source;
  final List<TeamData> ranking;
  final List<MatchData> matches;
  final Map<String,List<PlayerData>> rosters;
  int get playerCount => rosters.values.fold(0,(int a,b)=>a+b.length);
  bool get hasData => ranking.isNotEmpty || matches.isNotEmpty || playerCount>0;
  Map<String,dynamic> toJson() => {
    'schema':'ph-import/1','source':source,
    'ranking':[for(final t in ranking) {'name':t.name,'points':t.points,'rank':t.rank,'played':t.played}],
    'matches':[for(final m in matches) {'home':m.home,'away':m.away,'round':m.round,'homeScore':m.homeScore,'awayScore':m.awayScore}],
    'rosters':{for(final e in rosters.entries) e.key:[for(final p in e.value) {'name':p.name,'role':p.role,'club':p.club,'cost':p.cost,'value':p.value}]},
  };
  factory LeagueImportData.fromJson(Map<String,dynamic> j) {
    if(j['schema']!='ph-import/1') throw const FormatException('Schema import non valido');
    final rosters=<String,List<PlayerData>>{};
    if(j['rosters'] is Map) {
      for(final e in (j['rosters'] as Map).entries.take(100)) {
        final key=cleanText(e.key);
        if(key.isNotEmpty) rosters[key]=objects(e.value).map(PlayerData.fromJson).where((p)=>p.name.isNotEmpty&&p.role.isNotEmpty).toList();
      }
    }
    return LeagueImportData(cleanText(j['source']),
      objects(j['ranking']).map(TeamData.fromJson).where((t)=>t.name.isNotEmpty&&t.points!=null).toList(),
      objects(j['matches']).map(MatchData.fromJson).where((m)=>m.home.isNotEmpty&&m.away.isNotEmpty).toList(),rosters);
  }
}

class LeagueFileImporter {
  static String norm(String s)=>s.toLowerCase().replaceAll(RegExp('[àáâä]'),'a')
    .replaceAll(RegExp('[èéêë]'),'e').replaceAll(RegExp('[ìíîï]'),'i')
    .replaceAll(RegExp('[òóôö]'),'o').replaceAll(RegExp('[ùúûü]'),'u')
    .replaceAll(RegExp('[^a-z0-9]'),'');
  static String cell(CellValue? v)=>v==null?'':v.toString();
  static num? number(String s)=>num.tryParse(s.trim().replaceAll(' ','').replaceAll(',','.'));

  static LeagueImportData parse(String filename,Uint8List bytes) {
    if(bytes.isEmpty||bytes.length>4*1024*1024) throw const FormatException('File vuoto o oltre 4 MB');
    final tables=<List<List<String>>>[];
    if(filename.toLowerCase().endsWith('.csv')) {
      tables.add(csv(utf8.decode(bytes,allowMalformed:true).replaceFirst('\uFEFF','')));
    } else if(filename.toLowerCase().endsWith('.xlsx')) {
      final workbook=Excel.decodeBytes(bytes);
      for(final sheet in workbook.tables.values.take(20)) {
        tables.add([for(final row in sheet.rows.take(5000)) [for(final c in row.take(40)) cell(c?.value)]]);
      }
    } else {throw const FormatException('Formati consentiti: CSV e XLSX');}
    final standings=<String,TeamData>{};
    final matches=<String,MatchData>{};
    final rosters=<String,Map<String,PlayerData>>{};
    for(final table in tables) {
      for(var h=0;h<table.length&&h<12;h++){
        final cols=table[h].map(norm).toList();
        int idx(List<String> choices)=>cols.indexWhere(choices.contains);
        final team=idx(['fantasquadra','nomesquadra','squadra','team','squadrafantacalcio']);
        final pts=idx(['punti','pt','pti','puntitotali','punticlassifica']);
        final player=idx(['calciatore','nomecalciatore','giocatore','nomegiocatore','player']);
        final role=idx(['ruolo','r']);
        final home=idx(['casa','squadracasa','home','ospitante']);
        final away=idx(['trasferta','squadraospite','ospite','away']);
        final kind=home>=0&&away>=0?1:player>=0&&role>=0&&team>=0?2:team>=0&&pts>=0?3:0;
        if(kind==0)continue;
        final rank=idx(['pos','posizione','piazzamento','rank']);
        final played=idx(['giocate','partitegiocate','pg']);
        final round=idx(['giornata','giorn','turno','round']);
        final hs=idx(['golcasa','punteggiocasa','risultatocasa','homegoals']);
        final as=idx(['golospite','punteggioospite','risultatoospite','awaygoals']);
        final club=idx(['squadrareale','club','squadraseriea']);
        final cost=idx(['costo','prezzo','crediti','pagato','acquisto']);
        final value=idx(['quotazione','valore','qatt','quot']);
        String get(List<String> row,int i)=>i<0||i>=row.length?'':row[i].trim();
        for(final row in table.skip(h+1).take(4800)){
          if(kind==1) {
            final a=cleanText(get(row,home)),b=cleanText(get(row,away));
            if(a.isEmpty||b.isEmpty)continue;
            final m=MatchData(home:a,away:b,round:number(get(row,round))?.toInt(),
              homeScore:number(get(row,hs))?.toInt(),awayScore:number(get(row,as))?.toInt());
            matches[a+'/'+b+'/'+(m.round?.toString()??'')]=m;
          } else if(kind==2) {
            final squad=cleanText(get(row,team)),name=cleanText(get(row,player)),
              position=cleanText(get(row,role));
            if(squad.isEmpty||name.isEmpty||position.isEmpty)continue;
            final p=PlayerData(name:name,role:position,club:cleanText(get(row,club)),
              cost:number(get(row,cost)),value:number(get(row,value)));
            (rosters[squad]??={})[name+'/'+position]=p;
          } else {
            final name=cleanText(get(row,team)),points=number(get(row,pts));
            if(name.isEmpty||points==null)continue;
            standings[name]=TeamData(name:name,points:points,rank:number(get(row,rank))?.toInt(),
              played:number(get(row,played))?.toInt());
          }
        }
        break;
      }
    }
    final data=LeagueImportData(filename,standings.values.toList(),matches.values.toList(),
      {for(final e in rosters.entries)e.key:e.value.values.toList()});
    if(!data.hasData)throw const FormatException('Colonne non riconosciute: servono Squadra/Punti, Casa/Ospite o Fantasquadra/Calciatore/Ruolo');
    return data;
  }

  static List<List<String>> csv(String text){
    final first=text.split(RegExp(r'\r?\n')).first;
    final sep=';'.allMatches(first).length>','.allMatches(first).length?';':',';
    final rows=<List<String>>[];
    var row=<String>[],quoted=false;
    final buffer=StringBuffer();
    void add(){row.add(buffer.toString());buffer.clear();}
    void end(){add();if(row.any((s)=>s.trim().isNotEmpty))rows.add(row);row=[];}
    for(var i=0;i<text.length&&rows.length<5000;i++){
      final c=text[i];
      if(c=='"'){if(quoted&&i+1<text.length&&text[i+1]=='"'){buffer.write('"');i++;}else{quoted=!quoted;}}
      else if(c==sep&&!quoted){add();}
      else if((c=='\n'||c=='\r')&&!quoted){if(c=='\r'&&i+1<text.length&&text[i+1]=='\n')i++;end();}
      else{buffer.write(c);}
    }
    if(buffer.isNotEmpty||row.isNotEmpty)end();
    return rows;
  }
}
