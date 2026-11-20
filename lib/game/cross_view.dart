import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';
import 'cross_engine.dart';
import 'rules.dart';
import 'word_kit.dart';
import 'word_ui.dart';

class CrossView extends StatefulWidget {
  final PlayContext ctx;
  const CrossView({super.key, required this.ctx});

  @override
  State<CrossView> createState() => _CrossViewState();
}

class _CrossViewState extends State<CrossView> with RoundClock {
  late CrossLevel level;
  late CrossGame game;
  int _sel = -1;
  bool _down = false;
  int _hints = 0;
  int _solved = 0;
  int _letters = 0;
  int _mistakeBase = 0;
  bool _ended = false;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<CrossLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? CrossGame.restore(level.p.of(_tr), snap) : CrossGame(level.p.of(_tr));
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _solved = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    _selectEntry(game.p.entries.first);
    startClock(
        initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
        limit: ctx.spec.mode == GameModeId.timeAttack ? 240 : level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_chain ? _solved > 0 : game.won);

  void _persist() =>
      ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _solved});

  CrossEntry? get _entry {
    if (_sel < 0) return null;
    final list = game.entriesAt(_sel);
    if (list.isEmpty) return null;
    return list.firstWhere((e) => e.down == _down, orElse: () => list.first);
  }

  void _selectEntry(CrossEntry e) {
    _down = e.down;
    _sel = e.cell(0, game.p.w);
    for (var k = 0; k < e.word.length; k++) {
      final c = e.cell(k, game.p.w);
      if (game.input[c] != e.word[k]) {
        _sel = c;
        break;
      }
    }
  }

  void _tapCell(int i) {
    if (game.isBlock(i)) return;
    setState(() {
      if (i == _sel) {
        _down = !_down;
      } else {
        _sel = i;
        final list = game.entriesAt(i);
        if (list.isNotEmpty && !list.any((e) => e.down == _down)) _down = list.first.down;
      }
    });
    ctx.sfx(Sfx.tap);
  }

  void _type(String l) {
    final e = _entry;
    if (e == null || _ended) return;
    final ok = game.type(_sel, l);
    _letters++;
    ctx.sfx(ok ? Sfx.place : Sfx.error);
    setState(() {
      final cells = List.generate(e.word.length, (k) => e.cell(k, game.p.w));
      final at = cells.indexOf(_sel);
      for (var k = at + 1; k < cells.length; k++) {
        if (game.input[cells[k]] != e.word[k]) {
          _sel = cells[k];
          break;
        }
      }
      if (game.entryDone(e)) {
        final next = game.p.entries.where((x) => !game.entryDone(x)).toList();
        if (next.isNotEmpty) _selectEntry(next.first);
      }
    });
    _persist();
    if (!ok && level.mistakeLimit > 0 && game.mistakes - _mistakeBase >= level.mistakeLimit) {
      _offerContinue();
      return;
    }
    _checkWin();
  }

  Future<void> _offerContinue() async {
    if (ctx.spec.mode == GameModeId.zen) {
      _mistakeBase = game.mistakes;
      return;
    }
    clockPaused = true;
    final again = await ctx.requestContinue();
    clockPaused = false;
    if (!mounted) return;
    if (again) {
      _mistakeBase = game.mistakes;
    } else {
      _end(false);
    }
  }

  void _checkWin() {
    if (!game.won) return;
    if (_chain) {
      _solved++;
      ctx.sfx(Sfx.combo);
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _solved]));
      setState(() {
        level = CrossRules().build(next).puzzle;
        game = CrossGame(level.p.of(_tr));
        _selectEntry(game.p.entries.first);
      });
      _persist();
      return;
    }
    _end(true);
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    var stars = game.mistakes == 0 && _hints == 0 ? 3 : (game.mistakes <= 3 ? 2 : 1);
    if (_chain) stars = _solved >= 3 ? 3 : (_solved >= 1 ? 2 : 1);
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _solved * 1500 : (won ? (5000 - seconds * 2 - game.mistakes * 150).clamp(100, 9000) : 0),
      stars: won ? stars : 0,
      seconds: seconds,
      moves: game.moves,
      hintsUsed: _hints,
      gameStats: {
        'letters_typed': _letters,
        'clean_crosswords': won && game.mistakes == 0 ? 1 : 0,
        'words_solved': game.p.entries.where(game.entryDone).length,
      },
    ));
  }

  Future<void> _hint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => game.hint(_sel));
    _persist();
    _checkWin();
  }

  Future<void> _booster() async {
    final e = _entry;
    if (e == null || !await ctx.requestBooster()) return;
    setState(() => game.revealEntry(e));
    _persist();
    _checkWin();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = _entry;
    final lang = WordLang.of(_tr);
    final highlight = e == null ? <int>{} : {for (var k = 0; k < e.word.length; k++) e.cell(k, game.p.w)};
    return WordBackdrop(
      colors: ctx.background,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, timeText),
          (Icons.close, level.mistakeLimit > 0 ? '${game.mistakes - _mistakeBase}/${level.mistakeLimit}' : '${game.mistakes}'),
          (Icons.check_circle, '${game.p.entries.where(game.entryDone).length}/${game.p.entries.length}'),
          if (_chain) (Icons.emoji_events, '$_solved'),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final cell = math.min(c.maxWidth / game.p.w, c.maxHeight / game.p.h).clamp(10.0, 46.0);
            final size = Size(cell * game.p.w, cell * game.p.h);
            return Center(
              child: GestureDetector(
                onTapUp: (d) {
                  final x = (d.localPosition.dx / cell).floor().clamp(0, game.p.w - 1);
                  final y = (d.localPosition.dy / cell).floor().clamp(0, game.p.h - 1);
                  _tapCell(y * game.p.w + x);
                },
                child: Semantics(
                  label: 'crossword grid',
                  child: CustomPaint(size: size, painter: _CrossPainter(game, _sel, highlight, cs.primary)),
                ),
              ),
            );
          }),
        ),
        if (e != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Text('${e.number}${e.down ? '↓' : '→'}  ${e.clue}  (${e.word.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
          ),
        WordKeyboard(
          alphabet: lang.alphabet,
          onKey: _type,
          onBackspace: _sel >= 0 ? () => setState(() => game.erase(_sel)) : null,
        ),
        BoosterBar(buttons: [
          BoosterButton(Icons.swap_vert, tx(ctx, 'Direction', 'Yön'), () => setState(() => _down = !_down)),
          BoosterButton(Icons.auto_fix_high, tx(ctx, 'Reveal word', 'Kelimeyi aç'), _booster),
          BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
        ]),
      ]),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final CrossGame g;
  final int sel;
  final Set<int> hl;
  final Color accent;
  _CrossPainter(this.g, this.sel, this.hl, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = g.p.w;
    final c = size.width / w;
    final numbers = {for (final e in g.p.entries) e.cell(0, w): e.number};
    for (var i = 0; i < g.p.cells.length; i++) {
      if (g.isBlock(i)) continue;
      final r = Rect.fromLTWH((i % w) * c, (i ~/ w) * c, c, c);
      var bg = Colors.white;
      if (hl.contains(i)) bg = const Color(0xFFE3F2FD);
      if (i == sel) bg = accent.withValues(alpha: 0.35);
      canvas.drawRect(r.deflate(1), Paint()..color = bg);
      canvas.drawRect(r.deflate(1),
          Paint()
            ..color = Colors.black54
            ..style = PaintingStyle.stroke);
      final n = numbers[i];
      if (n != null) paintText(canvas, '$n', r.topLeft + Offset(c * 0.2, c * 0.2), c * 0.24, Colors.black54);
      final v = g.input[i];
      if (v.isNotEmpty) {
        final col = g.locked.contains(i) ? Colors.indigo : (v == g.p.cells[i] ? Colors.black87 : Colors.red);
        paintText(canvas, v, r.center + Offset(0, c * 0.06), c * 0.56, col);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
