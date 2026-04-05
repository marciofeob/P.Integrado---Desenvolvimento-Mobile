import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Serviço centralizado de feedback sonoro e tátil do STOX.
///
/// Cada chamada cria um [AudioPlayer] independente que é descartado
/// automaticamente ao final da reprodução, garantindo que sons nunca
/// sejam cortados — mesmo quando disparados em sequência rápida.
///
/// Vibração e áudio operam em blocos independentes: uma falha na
/// vibração não impede o som, e vice-versa.
///
/// Padrões de vibração por tipo de evento:
/// | Evento          | Som                     | Vibração                    |
/// |-----------------|-------------------------|-----------------------------|
/// | Sucesso / scan  | `sounds/check.mp3`      | `duration: 150ms`           |
/// | Beep simples    | `sounds/beep.mp3`       | `duration: 150ms`           |
/// | Aviso / duplicata | `sounds/error_beep.mp3` | `[0, 200, 100, 300]`     |
/// | Falha grave     | `sounds/fail.mp3`       | `[0, 400, 100, 400]`       |
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
  /// - [isError]: padrão de vibração para avisos/duplicatas (pulso duplo)
  /// - [isFail]: padrão de vibração para falhas graves (pulso longo duplo)
  ///
  /// Se o dispositivo não suportar vibração nativa, usa [HapticFeedback]
  /// como fallback (taptic engine do sistema).
  static Future<void> play(
    String asset, {
    bool isError = false,
    bool isFail = false,
  }) async {
    // ── Vibração (independente — falha aqui não impede o som) ──
    try {
      final temVibrador = await Vibration.hasVibrator();
      if (temVibrador) {
        if (isFail) {
          Vibration.vibrate(pattern: [0, 400, 100, 400]);
        } else if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 150);
        }
      } else {
        // Fallback para dispositivos sem motor de vibração
        if (isFail || isError) {
          HapticFeedback.vibrate();
        } else {
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('StoxAudio.play (vibração): $e');
    }

    // ── Som com player independente (nunca corta o anterior) ──
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      player.onPlayerComplete.listen((_) => player?.dispose());
      await player.play(AssetSource(asset));
    } catch (e) {
      player?.dispose();
      if (kDebugMode) debugPrint('StoxAudio.play (áudio): $e');
    }
  }
}