import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamanhos de etiqueta pré-definidos (largura x altura em mm)
enum TamanhoEtiqueta {
  mm40x25('40 x 25 mm', 40, 25),
  mm40x60('40 x 60 mm', 40, 60),
  mm50x25('50 x 25 mm', 50, 25),
  mm58x40('58 x 40 mm', 58, 40),
  mm80x50('80 x 50 mm', 80, 50),
  mm100x50('100 x 50 mm', 100, 50),
  personalizado('Personalizado', 0, 0);

  const TamanhoEtiqueta(this.label, this.larguraMm, this.alturaMm);
  final String label;
  final int larguraMm;
  final int alturaMm;
}

/// Configuração completa de uma etiqueta — persiste em SharedPreferences
class LabelConfig {
  // ── Tamanho ──
  TamanhoEtiqueta tamanho;
  int larguraMmCustom;   // usado quando tamanho == personalizado
  int alturaMmCustom;

  // ── Cabeçalho ──
  String cabecalhoLinha1;  // ex: "STOX AGRO"
  String cabecalhoLinha2;  // ex: "Grupo JCN"
  bool mostrarCabecalho;

  // ── Campos do item ──
  bool mostrarNomeItem;
  bool mostrarCodigoBarras;
  bool mostrarCodigoTexto;
  bool mostrarDeposito;
  bool mostrarUnidade;

  // ── Rodapé ──
  String rodapeTexto;     // ex: "VER. 1.0"
  bool mostrarRodape;

  // ── Impressão ──
  int copiasPorItem;       // quantas cópias imprimir por item

  LabelConfig({
    this.tamanho = TamanhoEtiqueta.mm40x60,
    this.larguraMmCustom = 50,
    this.alturaMmCustom = 30,
    this.cabecalhoLinha1 = 'STOX AGRO',
    this.cabecalhoLinha2 = '',
    this.mostrarCabecalho = true,
    this.mostrarNomeItem = true,
    this.mostrarCodigoBarras = true,
    this.mostrarCodigoTexto = true,
    this.mostrarDeposito = true,
    this.mostrarUnidade = false,
    this.rodapeTexto = 'VER. 1.0',
    this.mostrarRodape = true,
    this.copiasPorItem = 1,
  });

  int get largura =>
      tamanho == TamanhoEtiqueta.personalizado ? larguraMmCustom : tamanho.larguraMm;
  int get altura =>
      tamanho == TamanhoEtiqueta.personalizado ? alturaMmCustom : tamanho.alturaMm;

  // ── Serialização ──
  Map<String, dynamic> toJson() => {
        'tamanho': tamanho.name,
        'larguraMmCustom': larguraMmCustom,
        'alturaMmCustom': alturaMmCustom,
        'cabecalhoLinha1': cabecalhoLinha1,
        'cabecalhoLinha2': cabecalhoLinha2,
        'mostrarCabecalho': mostrarCabecalho,
        'mostrarNomeItem': mostrarNomeItem,
        'mostrarCodigoBarras': mostrarCodigoBarras,
        'mostrarCodigoTexto': mostrarCodigoTexto,
        'mostrarDeposito': mostrarDeposito,
        'mostrarUnidade': mostrarUnidade,
        'rodapeTexto': rodapeTexto,
        'mostrarRodape': mostrarRodape,
        'copiasPorItem': copiasPorItem,
      };

  factory LabelConfig.fromJson(Map<String, dynamic> json) {
    final tamanhoName = json['tamanho'] as String? ?? TamanhoEtiqueta.mm40x60.name;
    final tamanho = TamanhoEtiqueta.values.firstWhere(
      (t) => t.name == tamanhoName,
      orElse: () => TamanhoEtiqueta.mm40x60,
    );
    return LabelConfig(
      tamanho: tamanho,
      larguraMmCustom: json['larguraMmCustom'] ?? 50,
      alturaMmCustom: json['alturaMmCustom'] ?? 30,
      cabecalhoLinha1: json['cabecalhoLinha1'] ?? 'STOX AGRO',
      cabecalhoLinha2: json['cabecalhoLinha2'] ?? '',
      mostrarCabecalho: json['mostrarCabecalho'] ?? true,
      mostrarNomeItem: json['mostrarNomeItem'] ?? true,
      mostrarCodigoBarras: json['mostrarCodigoBarras'] ?? true,
      mostrarCodigoTexto: json['mostrarCodigoTexto'] ?? true,
      mostrarDeposito: json['mostrarDeposito'] ?? true,
      mostrarUnidade: json['mostrarUnidade'] ?? false,
      rodapeTexto: json['rodapeTexto'] ?? 'VER. 1.0',
      mostrarRodape: json['mostrarRodape'] ?? true,
      copiasPorItem: json['copiasPorItem'] ?? 1,
    );
  }

  static const _key = 'label_config';

  static Future<LabelConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return LabelConfig();
    try {
      return LabelConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      return LabelConfig();
    }
  }

  Future<void> salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  LabelConfig copyWith({
    TamanhoEtiqueta? tamanho,
    int? larguraMmCustom,
    int? alturaMmCustom,
    String? cabecalhoLinha1,
    String? cabecalhoLinha2,
    bool? mostrarCabecalho,
    bool? mostrarNomeItem,
    bool? mostrarCodigoBarras,
    bool? mostrarCodigoTexto,
    bool? mostrarDeposito,
    bool? mostrarUnidade,
    String? rodapeTexto,
    bool? mostrarRodape,
    int? copiasPorItem,
  }) =>
      LabelConfig(
        tamanho: tamanho ?? this.tamanho,
        larguraMmCustom: larguraMmCustom ?? this.larguraMmCustom,
        alturaMmCustom: alturaMmCustom ?? this.alturaMmCustom,
        cabecalhoLinha1: cabecalhoLinha1 ?? this.cabecalhoLinha1,
        cabecalhoLinha2: cabecalhoLinha2 ?? this.cabecalhoLinha2,
        mostrarCabecalho: mostrarCabecalho ?? this.mostrarCabecalho,
        mostrarNomeItem: mostrarNomeItem ?? this.mostrarNomeItem,
        mostrarCodigoBarras: mostrarCodigoBarras ?? this.mostrarCodigoBarras,
        mostrarCodigoTexto: mostrarCodigoTexto ?? this.mostrarCodigoTexto,
        mostrarDeposito: mostrarDeposito ?? this.mostrarDeposito,
        mostrarUnidade: mostrarUnidade ?? this.mostrarUnidade,
        rodapeTexto: rodapeTexto ?? this.rodapeTexto,
        mostrarRodape: mostrarRodape ?? this.mostrarRodape,
        copiasPorItem: copiasPorItem ?? this.copiasPorItem,
      );
}