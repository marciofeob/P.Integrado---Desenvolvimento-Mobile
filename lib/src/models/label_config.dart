import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Protocolo de comunicação com a impressora Bluetooth.
///
/// - [tspl] : TSPL (PT-260, Argox, TSC e compatíveis)
/// - [escpos]: ESC/POS (MPT-260, Rongta, Munbyn, Epson e compatíveis)
enum ProtocoloBluetooth { tspl, escpos }

/// Configuração da etiqueta térmica para impressão.
///
/// Controla dimensões, elementos visíveis, quantidade de cópias e
/// protocolo Bluetooth. Persistida em [SharedPreferences] via
/// [carregar] e [salvar].
class LabelConfig {
  // ── Dimensões ─────────────────────────────────────────────────────────────

  /// Largura da etiqueta em milímetros.
  int larguraMm;

  /// Altura da etiqueta em milímetros.
  int alturaMm;

  // ── Elementos visíveis ────────────────────────────────────────────────────

  /// Exibe o nome/descrição do item na etiqueta.
  bool mostrarNomeItem;

  /// Exibe o código de barras (Code 128) na etiqueta.
  bool mostrarCodigoBarras;

  /// Exibe o código do item como texto legível.
  bool mostrarCodigoTexto;

  /// Exibe o código do depósito (warehouse) na etiqueta.
  bool mostrarDeposito;

  // ── Impressão ─────────────────────────────────────────────────────────────

  /// Quantidade de cópias impressas por item (mínimo 1).
  int copiasPorItem;

  /// Protocolo de comunicação Bluetooth com a impressora.
  ///
  /// Use [ProtocoloBluetooth.tspl] para PT-260 e compatíveis TSPL.
  /// Use [ProtocoloBluetooth.escpos] para MPT-260 e compatíveis ESC/POS.
  ProtocoloBluetooth protocoloBluetooth;

  LabelConfig({
    this.larguraMm = 60,
    this.alturaMm = 40,
    this.mostrarNomeItem = true,
    this.mostrarCodigoBarras = true,
    this.mostrarCodigoTexto = true,
    this.mostrarDeposito = true,
    this.copiasPorItem = 1,
    this.protocoloBluetooth = ProtocoloBluetooth.tspl,
  });

  // ── Serialização ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'larguraMm': larguraMm,
        'alturaMm': alturaMm,
        'mostrarNomeItem': mostrarNomeItem,
        'mostrarCodigoBarras': mostrarCodigoBarras,
        'mostrarCodigoTexto': mostrarCodigoTexto,
        'mostrarDeposito': mostrarDeposito,
        'copiasPorItem': copiasPorItem,
        'protocoloBluetooth': protocoloBluetooth.name,
      };

  factory LabelConfig.fromJson(Map<String, dynamic> json) {
    final protocoloStr = json['protocoloBluetooth'] as String? ?? 'tspl';
    final protocolo = ProtocoloBluetooth.values.firstWhere(
      (e) => e.name == protocoloStr,
      orElse: () => ProtocoloBluetooth.tspl,
    );

    return LabelConfig(
      larguraMm: _parseInt(json['larguraMm'], 60),
      alturaMm: _parseInt(json['alturaMm'], 40),
      mostrarNomeItem: json['mostrarNomeItem'] as bool? ?? true,
      mostrarCodigoBarras: json['mostrarCodigoBarras'] as bool? ?? true,
      mostrarCodigoTexto: json['mostrarCodigoTexto'] as bool? ?? true,
      mostrarDeposito: json['mostrarDeposito'] as bool? ?? true,
      copiasPorItem: _parseInt(json['copiasPorItem'], 1).clamp(1, 99),
      protocoloBluetooth: protocolo,
    );
  }

  static int _parseInt(dynamic valor, int fallback) {
    if (valor is int) return valor;
    if (valor is double) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? fallback;
    return fallback;
  }

  // ── Persistência ──────────────────────────────────────────────────────────

  static const String _key = 'label_config';

  static Future<LabelConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return LabelConfig();
    try {
      return LabelConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('LabelConfig.carregar: erro ao decodificar — $e');
      return LabelConfig();
    }
  }

  Future<void> salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  Future<void> resetar() async {
    larguraMm = 60;
    alturaMm = 40;
    mostrarNomeItem = true;
    mostrarCodigoBarras = true;
    mostrarCodigoTexto = true;
    mostrarDeposito = true;
    copiasPorItem = 1;
    protocoloBluetooth = ProtocoloBluetooth.tspl;
    await salvar();
  }

  // ── Cópia ─────────────────────────────────────────────────────────────────

  LabelConfig copyWith({
    int? larguraMm,
    int? alturaMm,
    bool? mostrarNomeItem,
    bool? mostrarCodigoBarras,
    bool? mostrarCodigoTexto,
    bool? mostrarDeposito,
    int? copiasPorItem,
    ProtocoloBluetooth? protocoloBluetooth,
  }) =>
      LabelConfig(
        larguraMm: larguraMm ?? this.larguraMm,
        alturaMm: alturaMm ?? this.alturaMm,
        mostrarNomeItem: mostrarNomeItem ?? this.mostrarNomeItem,
        mostrarCodigoBarras: mostrarCodigoBarras ?? this.mostrarCodigoBarras,
        mostrarCodigoTexto: mostrarCodigoTexto ?? this.mostrarCodigoTexto,
        mostrarDeposito: mostrarDeposito ?? this.mostrarDeposito,
        copiasPorItem: copiasPorItem ?? this.copiasPorItem,
        protocoloBluetooth: protocoloBluetooth ?? this.protocoloBluetooth,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelConfig &&
          runtimeType == other.runtimeType &&
          larguraMm == other.larguraMm &&
          alturaMm == other.alturaMm &&
          mostrarNomeItem == other.mostrarNomeItem &&
          mostrarCodigoBarras == other.mostrarCodigoBarras &&
          mostrarCodigoTexto == other.mostrarCodigoTexto &&
          mostrarDeposito == other.mostrarDeposito &&
          copiasPorItem == other.copiasPorItem &&
          protocoloBluetooth == other.protocoloBluetooth;

  @override
  int get hashCode => Object.hash(
        larguraMm,
        alturaMm,
        mostrarNomeItem,
        mostrarCodigoBarras,
        mostrarCodigoTexto,
        mostrarDeposito,
        copiasPorItem,
        protocoloBluetooth,
      );

  @override
  String toString() =>
      'LabelConfig(${larguraMm}x${alturaMm}mm, '
      'cópias: $copiasPorItem, '
      'protocolo: ${protocoloBluetooth.name})';
}