import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Serviço centralizado de feedback sonoro e tátil do STOX.
///
/// Cada chamada cria um [AudioPlayer] independente que é descartado
/// automaticamente ao final da reprodução, garantindo que sons nunca
/// sejam cortados — mesmo quando disparados em sequência rápida.
///
/// Uso:
/// ```dart
/// await StoxAudio.play('sounds/check.mp3');
/// await StoxAudio.play('sounds/error_beep.mp3', isError: true);
/// await StoxAudio.play('sounds/fail.mp3', isFail: true);
/// ```
class StoxAudio {
  StoxAudio._();

  /// Toca um som de asset e dispara vibração de acordo com o tipo de evento.
  ///
  /// - [asset]: caminho relativo ao diretório `assets/` (ex: `sounds/check.mp3`)
  /// - [isError]: padrão de vibração para avisos/duplicatas
  /// - [isFail]: padrão de vibração para falhas graves
  static Future<void> play(
    String asset, {
    bool isError = false,
    bool isFail = false,
  }) async {
    try {
      // ── Vibração ──
      final temVibrador = await Vibration.hasVibrator();
      if (temVibrador == true) {
        if (isFail) {
          Vibration.vibrate(pattern: [0, 400, 100, 400]);
        } else if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 150);
        }
      } else {
        (isFail || isError)
            ? HapticFeedback.vibrate()
            : HapticFeedback.lightImpact();
      }

      // ── Som com player independente (nunca corta o anterior) ──
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) => player.dispose());
      await player.play(AssetSource(asset));
    } catch (e) {
      if (kDebugMode) debugPrint('StoxAudio.play: $e');
    }
  }
}