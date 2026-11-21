import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:game_053_crossword_master/game/cross_engine.dart';
import 'package:game_053_crossword_master/game/rules.dart';

void main() {
  final rules = CrossRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('crosswords are connected and consistent in both languages', () {
    for (final n in [1, 8, 90, 777, 6000, 49999]) {
      final l = rules.build(planner.spec(n)).puzzle;
      for (final tr in [false, true]) {
        final p = l.p.of(tr);
        expect(checkCross(p), isNull, reason: 'level $n tr=$tr');
        expect(p.entries.every((e) => e.clue.isNotEmpty), isTrue);
      }
    }
  });

  test('typing the solution wins; wrong letters are mistakes', () {
    final p = rules.build(planner.spec(20)).puzzle.p.en;
    final g = CrossGame(p);
    final first = p.entries.first;
    final c0 = first.cell(0, p.w);
    expect(g.type(c0, first.word[0] == 'Z' ? 'Q' : 'Z'), isFalse);
    expect(g.mistakes, 1);
    for (final e in p.entries) {
      for (var k = 0; k < e.word.length; k++) {
        g.type(e.cell(k, p.w), e.word[k]);
      }
    }
    expect(g.won, isTrue);
  });

  test('hints, reveal word and resume', () {
    final p = rules.build(planner.spec(5)).puzzle.p.tr;
    final g = CrossGame(p);
    g.revealEntry(p.entries.first);
    expect(g.entryDone(p.entries.first), isTrue);
    var guard = 0;
    while (!g.won && guard++ < 400) {
      g.hint();
    }
    expect(g.won, isTrue);
    expect(CrossGame.restore(p, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..50 valid', () {
    for (var n = 1; n <= 50; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
