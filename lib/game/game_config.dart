import 'package:flutter/material.dart';

import '../app/game_api.dart';
import 'cross_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-053-crossword-master',
  title: const ['Çengel Bulmaca Ustası', 'Crossword Master', 'Kreuzworträtsel Meister', 'Maestro del Crucigrama', 'Maître des Mots Croisés'],
  tagline: const ['İpuçlarını çöz, kareleri doldur!', 'Solve the clues and fill the grid!', 'Löse die Hinweise!', '¡Resuelve las pistas!', 'Résolvez les définitions !'],
  seedColor: const Color(0xFF1D3557),
  icon: Icons.grid_4x4,
  rules: CrossRules(),
  buildPlay: (ctx) => CrossView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.grid_4x4, ['Kareye dokun, ipucu altta görünür.', 'Tap a square to see its clue below.', 'Feld antippen für den Hinweis.', 'Toca una casilla para ver la pista.', 'Touchez une case pour la définition.']),
    TutorialStep(Icons.swap_vert, ['Aynı kareye tekrar dokun: yatay/dikey değişir.', 'Tap it again to switch across/down.', 'Nochmal tippen: Richtung wechseln.', 'Toca de nuevo para cambiar dirección.', 'Retouchez pour changer de sens.']),
    TutorialStep(Icons.lightbulb, ['İpucu bir harfi, güçlendirme bütün kelimeyi açar.', 'Hint reveals a letter, the booster a whole word.', 'Tipp: ein Buchstabe, Booster: ein Wort.', 'Pista: una letra; potenciador: palabra.', 'Indice : une lettre ; bonus : un mot.']),
  ],
);
