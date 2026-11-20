import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'cross_engine.dart';

class CrossRules extends GameRules<CrossLevel> {
  @override
  String get gameId => 'game-053-crossword-master';

  @override
  List<String> get optionalMechanics => const ['mistake_limit', 'timer'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('letters_typed', 'Yazılan harf', 'Letters typed', scale: 300),
        GameStat('clean_crosswords', 'Hatasız bulmaca', 'Flawless crosswords', scale: 3),
        GameStat('words_solved', 'Çözülen kelime', 'Words solved', scale: 60),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'letters_typed', [10, 25, 50]),
        MissionTemplate('m2', 'clean_crosswords', [1, 3, 5], coinReward: 80),
      ];

  @override
  CrossLevel generate(LevelSpec spec) => generateCross(spec);

  @override
  Validation validate(CrossLevel l, LevelSpec spec) {
    final e = checkCross(l.p.en) ?? checkCross(l.p.tr);
    return e == null ? Validation.ok(l.p.en.entries.length) : Validation.fail(e);
  }
}

GameRules createRules() => CrossRules();
