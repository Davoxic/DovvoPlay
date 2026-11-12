import 'package:flutter/foundation.dart';

/// Avvisi brevi che i servizi vogliono mostrare all'utente.
///
/// Un servizio non ha uno schermo a cui agganciare un messaggio: lo lascia
/// qui, e la schermata principale lo mostra in fondo. Cosi' player e party
/// possono dire "radio avviata" o "solo l'host controlla la musica" da
/// qualunque punto dell'app.
class AppNotice {
  AppNotice._();

  /// Cambia a ogni nuovo avviso: chi ascolta legge [last].
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static String _ultimo = '';
  static String get last => _ultimo;

  static void show(String messaggio) {
    if (messaggio.trim().isEmpty) return;
    _ultimo = messaggio;
    tick.value = tick.value + 1;
  }
}
