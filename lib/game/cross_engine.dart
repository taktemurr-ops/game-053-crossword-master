import '../core/level_plan.dart';
import '../core/rng.dart';
import 'word_kit.dart';

/// Crossword: words placed on a grid with clues.
class CrossEntry {
  final int row;
  final int col;
  final bool down;
  final String word;
  final String clue;
  final int number;
  const CrossEntry(this.row, this.col, this.down, this.word, this.clue, this.number);

  int cell(int k, int w) => down ? (row + k) * w + col : row * w + col + k;
}

class CrossPuzzle {
  final int w;
  final int h;

  /// Solution letter per cell, '' for a block.
  final List<String> cells;
  final List<CrossEntry> entries;
  const CrossPuzzle(this.w, this.h, this.cells, this.entries);
}

class CrossLevel {
  final Dual<CrossPuzzle> p;
  final int timeLimit;
  final int mistakeLimit;
  const CrossLevel(this.p, this.timeLimit, this.mistakeLimit);
}

const int _g = 17;

CrossPuzzle makeCross(WordLang lang, SeededRandom r, int difficulty) {
  final target = (4 + (difficulty * 0.8).round()).clamp(4, 12);
  final pool = [
    for (final e in lang.bank)
      if (!e.word.contains(' ') && e.word.length >= 3 && e.word.length <= 9) e
  ];
  r.shuffle(pool);
  final grid = List.filled(_g * _g, '');
  final placed = <(int, int, bool, Entry)>[];
  bool inside(int r0, int c0) => r0 >= 0 && r0 < _g && c0 >= 0 && c0 < _g;
  String at(int r0, int c0) => inside(r0, c0) ? grid[r0 * _g + c0] : '';

  int fits(String w, int r0, int c0, bool down) {
    final dr = down ? 1 : 0, dc = down ? 0 : 1;
    final er = r0 + dr * (w.length - 1), ec = c0 + dc * (w.length - 1);
    if (!inside(r0, c0) || !inside(er, ec)) return -1;
    if (at(r0 - dr, c0 - dc) != '' || at(er + dr, ec + dc) != '') return -1;
    var cross = 0;
    for (var k = 0; k < w.length; k++) {
      final rr = r0 + dr * k, cc = c0 + dc * k;
      final c = grid[rr * _g + cc];
      if (c == w[k]) {
        cross++;
        continue;
      }
      if (c != '') return -1;
      // Side neighbours must be empty for a non-crossing cell.
      if (at(rr + dc, cc + dr) != '' || at(rr - dc, cc - dr) != '') return -1;
    }
    return cross;
  }

  void put(Entry e, int r0, int c0, bool down) {
    for (var k = 0; k < e.word.length; k++) {
      grid[(r0 + (down ? k : 0)) * _g + c0 + (down ? 0 : k)] = e.word[k];
    }
    placed.add((r0, c0, down, e));
  }

  if (pool.isEmpty) return const CrossPuzzle(0, 0, [], []);
  final first = pool.firstWhere((e) => e.word.length >= 5, orElse: () => pool.first);
  put(first, _g ~/ 2, (_g - first.word.length) ~/ 2, false);
  for (final e in pool) {
    if (placed.length >= target) break;
    if (placed.any((p) => p.$4.word == e.word)) continue;
    var best = 0;
    (int, int, bool)? where;
    for (final p in placed) {
      final pw = p.$4.word;
      for (var i = 0; i < pw.length; i++) {
        for (var j = 0; j < e.word.length; j++) {
          if (pw[i] != e.word[j]) continue;
          final down = !p.$3;
          final pr = p.$1 + (p.$3 ? i : 0), pc = p.$2 + (p.$3 ? 0 : i);
          final r0 = down ? pr - j : pr, c0 = down ? pc : pc - j;
          final f = fits(e.word, r0, c0, down);
          if (f > best || (f == best && f > 0 && r.chance(0.3))) {
            best = f;
            where = (r0, c0, down);
          }
        }
      }
    }
    if (where != null && best > 0) put(e, where.$1, where.$2, where.$3);
  }
  var minR = _g, minC = _g, maxR = 0, maxC = 0;
  for (var i = 0; i < grid.length; i++) {
    if (grid[i] == '') continue;
    final rr = i ~/ _g, cc = i % _g;
    if (rr < minR) minR = rr;
    if (rr > maxR) maxR = rr;
    if (cc < minC) minC = cc;
    if (cc > maxC) maxC = cc;
  }
  final w = maxC - minC + 1, h = maxR - minR + 1;
  final cells = [for (var rr = minR; rr <= maxR; rr++) for (var cc = minC; cc <= maxC; cc++) grid[rr * _g + cc]];
  final starts = placed.map((p) => (p.$1 - minR) * w + p.$2 - minC).toSet().toList()..sort();
  final entries = [
    for (final p in placed)
      CrossEntry(p.$1 - minR, p.$2 - minC, p.$3, p.$4.word, p.$4.clue, starts.indexOf((p.$1 - minR) * w + p.$2 - minC) + 1)
  ]..sort((a, b) => a.number != b.number ? a.number.compareTo(b.number) : (a.down ? 1 : 0) - (b.down ? 1 : 0));
  return CrossPuzzle(w, h, cells, entries);
}

CrossLevel generateCross(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final en = makeCross(WordLang.of(false), SeededRandom(r.nextUint32()), spec.difficulty);
  final tr = makeCross(WordLang.of(true), SeededRandom(r.nextUint32()), spec.difficulty);
  return CrossLevel(Dual(en, tr), spec.has('timer') ? 120 + en.entries.length * 30 : 0, spec.has('mistake_limit') ? 6 : 0);
}

String? checkCross(CrossPuzzle p) {
  if (p.entries.length < 4) return 'few words';
  if (p.w > _g || p.h > _g) return 'too big';
  for (final e in p.entries) {
    for (var k = 0; k < e.word.length; k++) {
      if (p.cells[e.cell(k, p.w)] != e.word[k]) return 'mismatch ${e.word}';
    }
  }
  // every letter cell belongs to at least one entry
  final used = <int>{for (final e in p.entries) for (var k = 0; k < e.word.length; k++) e.cell(k, p.w)};
  for (var i = 0; i < p.cells.length; i++) {
    if (p.cells[i] != '' && !used.contains(i)) return 'orphan cell';
  }
  // connected
  final seen = <int>{};
  final stack = [used.first];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    if (!seen.add(c)) continue;
    final rr = c ~/ p.w, cc = c % p.w;
    for (final (dr, dc) in const [(0, 1), (1, 0), (0, -1), (-1, 0)]) {
      final nr = rr + dr, nc = cc + dc;
      if (nr < 0 || nr >= p.h || nc < 0 || nc >= p.w) continue;
      final n = nr * p.w + nc;
      if (p.cells[n] != '' && !seen.contains(n)) stack.add(n);
    }
  }
  if (seen.length != used.length) return 'disconnected';
  return null;
}

class CrossGame {
  final CrossPuzzle p;
  final List<String> input;
  final Set<int> locked = {};
  int mistakes = 0;
  int moves = 0;
  CrossGame(this.p) : input = List.filled(p.cells.length, '');

  bool get won {
    for (var i = 0; i < p.cells.length; i++) {
      if (p.cells[i] != '' && input[i] != p.cells[i]) return false;
    }
    return true;
  }

  bool isBlock(int i) => p.cells[i] == '';

  /// Types [letter] into [cell]. Returns true when correct.
  bool type(int cell, String letter) {
    if (isBlock(cell) || locked.contains(cell)) return true;
    moves++;
    input[cell] = letter;
    if (letter == p.cells[cell]) return true;
    mistakes++;
    return false;
  }

  void erase(int cell) {
    if (!locked.contains(cell)) input[cell] = '';
  }

  bool entryDone(CrossEntry e) =>
      List.generate(e.word.length, (k) => input[e.cell(k, p.w)] == e.word[k]).every((x) => x);

  List<CrossEntry> entriesAt(int cell) => [
        for (final e in p.entries)
          if (List.generate(e.word.length, (k) => e.cell(k, p.w)).contains(cell)) e
      ];

  /// Reveals [cell] or the first unsolved cell.
  int? hint([int? cell]) {
    var c = cell;
    if (c == null || isBlock(c) || input[c] == p.cells[c]) {
      c = null;
      for (var i = 0; i < p.cells.length; i++) {
        if (!isBlock(i) && input[i] != p.cells[i]) {
          c = i;
          break;
        }
      }
    }
    if (c == null) return null;
    input[c] = p.cells[c];
    locked.add(c);
    return c;
  }

  void revealEntry(CrossEntry e) {
    for (var k = 0; k < e.word.length; k++) {
      final c = e.cell(k, p.w);
      input[c] = e.word[k];
      locked.add(c);
    }
  }

  String serialize() => [input.map((s) => s.isEmpty ? '.' : s).join(), locked.join(','), '$mistakes', '$moves'].join('|');

  factory CrossGame.restore(CrossPuzzle p, String s) {
    final g = CrossGame(p);
    final parts = s.split('|');
    if (parts.length < 4) return g;
    final letters = parts[0].split('');
    if (letters.length == p.cells.length) {
      for (var i = 0; i < letters.length; i++) {
        g.input[i] = letters[i] == '.' ? '' : letters[i];
      }
    }
    g.locked.addAll(splitList(parts[1]).map(int.parse));
    g.mistakes = int.tryParse(parts[2]) ?? 0;
    g.moves = int.tryParse(parts[3]) ?? 0;
    return g;
  }
}
