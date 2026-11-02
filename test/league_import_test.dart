import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/data/league_import.dart';
import 'package:planthead_fanta/data/fanta_store.dart';

Uint8List csv(String value) => Uint8List.fromList(utf8.encode(value));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offline classifica CSV reads real names and points only', () {
    final data=LeagueFileImporter.parse('classifica.csv',csv('Pos;Squadra;Punti;PG\n1;Milanesi;25,5;10\n2;Napoli;0;10\n'));
    expect(data.ranking.length,2);
    expect(data.ranking[0].points,25.5);
    expect(data.ranking[1].points,0);
    expect(data.matches,isEmpty);
  });
  test('offline roster CSV supports quoted separators', () {
    final data=LeagueFileImporter.parse('rose.csv',csv('Fantasquadra;Calciatore;Ruolo;Club;Costo\nSquadra A;"Rossi; Mario";A;Roma;25\n'));
    expect(data.playerCount,1);
    expect(data.rosters['Squadra A']!.first.name,'Rossi; Mario');
  });
  test('offline calendar contains no fictional score', () {
    final data=LeagueFileImporter.parse('partite.csv',csv('Giornata,Casa,Ospite\n2,Squadra A,Squadra B\n'));
    expect(data.matches.single.round,2);
    expect(data.matches.single.completed,false);
  });
  test('unknown file and schema reject instead of fabricating data', () {
    expect(()=>LeagueFileImporter.parse('other.csv',csv('foo,bar\n1,2')),throwsFormatException);
    expect(()=>LeagueFileImporter.parse('other.txt',csv('Squadra,Punti\nA,5')),throwsFormatException);
    expect(()=>LeagueImportData.fromJson({'schema':'other'}),throwsFormatException);
  });
  test('snapshot round trip retains real imported data', () {
    final imported=LeagueFileImporter.parse('classifica.csv',csv('Squadra;Punti\nRossi;15\n'));
    final restored=LeagueImportData.fromJson(imported.toJson());
    expect(restored.ranking.single.name,'Rossi');
    final store=FantaStore()..applyImported(restored);
    expect(store.offlineImport,true);
    expect(store.ranking.single.points,15);
    store.dispose();
  });
}