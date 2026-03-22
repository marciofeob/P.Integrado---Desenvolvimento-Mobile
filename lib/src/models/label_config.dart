import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de configuração de etiqueta térmica.
///
/// Persiste automaticamente em [SharedPreferences] via [carregar] e [salvar].
class LabelConfig {
  int larguraMm;
  int alturaMm;

  bool mostrarNomeItem;
  bool mostrarCodigoBarras;
  bool mostrarCodigoTexto;
  bool mostrarDeposito;

  int copiasPorItem;

  LabelConfig({
    this.larguraMm        = 60,
    this.alturaMm         = 40,
    this.mostrarNomeItem      = true,
    this.mostrarCodigoBarras  = true,
    this.mostrarCodigoTexto   = true,
    this.mostrarDeposito      = true,
    this.copiasPorItem = 1,
  });

  Map<String, dynamic> toJson() => {
        'larguraMm':  larguraMm,
        'alturaMm':   alturaMm,
        'mostrarNomeItem':      mostrarNomeItem,
        'mostrarCodigoBarras':  mostrarCodigoBarras,
        'mostrarCodigoTexto':   mostrarCodigoTexto,
        'mostrarDeposito':      mostrarDeposito,
        'copiasPorItem': copiasPorItem,
      };

  factory LabelConfig.fromJson(Map<String, dynamic> json) {
    return LabelConfig(
      larguraMm:  json['larguraMm']  ?? 60,
      alturaMm:   json['alturaMm']   ?? 40,
      mostrarNomeItem:      json['mostrarNomeItem']      ?? true,
      mostrarCodigoBarras:  json['mostrarCodigoBarras']  ?? true,
      mostrarCodigoTexto:   json['mostrarCodigoTexto']   ?? true,
      mostrarDeposito:      json['mostrarDeposito']      ?? true,
      copiasPorItem: json['copiasPorItem'] ?? 1,
    );
  }

  static const String _key = 'label_config';

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

  Future<void> salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  LabelConfig copyWith({
    int?  larguraMm,
    int?  alturaMm,
    bool? mostrarNomeItem,
    bool? mostrarCodigoBarras,
    bool? mostrarCodigoTexto,
    bool? mostrarDeposito,
    int?  copiasPorItem,
  }) =>
      LabelConfig(
        larguraMm:  larguraMm  ?? this.larguraMm,
        alturaMm:   alturaMm   ?? this.alturaMm,
        mostrarNomeItem:      mostrarNomeItem      ?? this.mostrarNomeItem,
        mostrarCodigoBarras:  mostrarCodigoBarras  ?? this.mostrarCodigoBarras,
        mostrarCodigoTexto:   mostrarCodigoTexto   ?? this.mostrarCodigoTexto,
        mostrarDeposito:      mostrarDeposito      ?? this.mostrarDeposito,
        copiasPorItem: copiasPorItem ?? this.copiasPorItem,
      );
}