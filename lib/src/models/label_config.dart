import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de configuração de etiqueta térmica (layout 40×60 mm).
///
/// Persiste automaticamente em [SharedPreferences] via [carregar] e [salvar].
/// Imutabilidade parcial garantida por [copyWith].
class LabelConfig {
  String cabecalhoLinha1;
  String cabecalhoLinha2;
  bool mostrarCabecalho;

  bool mostrarNomeItem;
  bool mostrarCodigoBarras;
  bool mostrarCodigoTexto;
  bool mostrarDeposito;

  String rodapeTexto;
  bool mostrarRodape;

  /// Número de cópias impressas por item (1–99).
  int copiasPorItem;

  LabelConfig({
    this.cabecalhoLinha1  = 'STOX AGRO',
    this.cabecalhoLinha2  = '',
    this.mostrarCabecalho = true,
    this.mostrarNomeItem      = true,
    this.mostrarCodigoBarras  = true,
    this.mostrarCodigoTexto   = true,
    this.mostrarDeposito      = true,
    this.rodapeTexto   = 'VER. 1.0',
    this.mostrarRodape = true,
    this.copiasPorItem = 1,
  });

  // ── Serialização ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'cabecalhoLinha1':  cabecalhoLinha1,
        'cabecalhoLinha2':  cabecalhoLinha2,
        'mostrarCabecalho': mostrarCabecalho,
        'mostrarNomeItem':      mostrarNomeItem,
        'mostrarCodigoBarras':  mostrarCodigoBarras,
        'mostrarCodigoTexto':   mostrarCodigoTexto,
        'mostrarDeposito':      mostrarDeposito,
        'rodapeTexto':  rodapeTexto,
        'mostrarRodape': mostrarRodape,
        'copiasPorItem': copiasPorItem,
      };

  factory LabelConfig.fromJson(Map<String, dynamic> json) {
    return LabelConfig(
      cabecalhoLinha1:  json['cabecalhoLinha1']  ?? 'STOX AGRO',
      cabecalhoLinha2:  json['cabecalhoLinha2']  ?? '',
      mostrarCabecalho: json['mostrarCabecalho'] ?? true,
      mostrarNomeItem:      json['mostrarNomeItem']      ?? true,
      mostrarCodigoBarras:  json['mostrarCodigoBarras']  ?? true,
      mostrarCodigoTexto:   json['mostrarCodigoTexto']   ?? true,
      mostrarDeposito:      json['mostrarDeposito']      ?? true,
      rodapeTexto:  json['rodapeTexto']  ?? 'VER. 1.0',
      mostrarRodape: json['mostrarRodape'] ?? true,
      copiasPorItem: json['copiasPorItem'] ?? 1,
    );
  }

  // ── Persistência ─────────────────────────────────────────────────────────

  static const String _key = 'label_config';

  /// Carrega a configuração salva. Retorna os valores padrão se não houver dados.
  static Future<LabelConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_key);
    if (raw == null) return LabelConfig();
    try {
      return LabelConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return LabelConfig();
    }
  }

  /// Persiste a configuração atual.
  Future<void> salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  // ── Cópia imutável ───────────────────────────────────────────────────────

  LabelConfig copyWith({
    String? cabecalhoLinha1,
    String? cabecalhoLinha2,
    bool?   mostrarCabecalho,
    bool?   mostrarNomeItem,
    bool?   mostrarCodigoBarras,
    bool?   mostrarCodigoTexto,
    bool?   mostrarDeposito,
    String? rodapeTexto,
    bool?   mostrarRodape,
    int?    copiasPorItem,
  }) =>
      LabelConfig(
        cabecalhoLinha1:  cabecalhoLinha1  ?? this.cabecalhoLinha1,
        cabecalhoLinha2:  cabecalhoLinha2  ?? this.cabecalhoLinha2,
        mostrarCabecalho: mostrarCabecalho ?? this.mostrarCabecalho,
        mostrarNomeItem:      mostrarNomeItem      ?? this.mostrarNomeItem,
        mostrarCodigoBarras:  mostrarCodigoBarras  ?? this.mostrarCodigoBarras,
        mostrarCodigoTexto:   mostrarCodigoTexto   ?? this.mostrarCodigoTexto,
        mostrarDeposito:      mostrarDeposito      ?? this.mostrarDeposito,
        rodapeTexto:  rodapeTexto  ?? this.rodapeTexto,
        mostrarRodape: mostrarRodape ?? this.mostrarRodape,
        copiasPorItem: copiasPorItem ?? this.copiasPorItem,
      );
}