import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de contagem do inventário.
///
/// - [single]: um operador conta sozinho (padrão atual).
/// - [multiple]: equipe com múltiplos contadores no mesmo documento.
enum CountingMode {
  single,
  multiple;

  /// Valor usado no banco SQLite e no payload SAP.
  String get valor => name;

  /// Tipo SAP correspondente para o campo `CountingType`.
  String get tipoSap => switch (this) {
        single => 'ctSingleCounter',
        multiple => 'ctMultipleCounters',
      };

  /// Rótulo amigável para exibição na UI.
  String get rotulo => switch (this) {
        single => 'Contador Simples',
        multiple => 'Contadores Múltiplos',
      };

  /// Converte string do banco/prefs de volta para enum.
  static CountingMode fromString(String? valor) => switch (valor) {
        'multiple' => multiple,
        _ => single,
      };
}

/// Informações de um contador individual da equipe.
///
/// Corresponde ao bloco `IndividualCounters` do JSON SAP:
/// ```json
/// {
///   "CounterID": 9,
///   "CounterType": "ctUser",
///   "CounterName": "Rafael Valentim",
///   "CounterNumber": 1
/// }
/// ```
class CounterInfo {
  /// ID do usuário no SAP (campo `CounterID`).
  final int id;

  /// Nome do contador (campo `CounterName`).
  final String nome;

  /// Tipo do contador no SAP (geralmente `ctUser`).
  final String tipo;

  const CounterInfo({
    required this.id,
    required this.nome,
    this.tipo = 'ctUser',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'tipo': tipo,
      };

  factory CounterInfo.fromJson(Map<String, dynamic> json) => CounterInfo(
        id: json['id'] as int? ?? 0,
        nome: json['nome'] as String? ?? '',
        tipo: json['tipo'] as String? ?? 'ctUser',
      );

  /// Gera o objeto para o bloco `IndividualCounters` do payload SAP.
  ///
  /// [numero] é a posição sequencial do contador na equipe (1-based).
  Map<String, dynamic> toSapPayload(int numero) => {
        'CounterID': id,
        'CounterType': tipo,
        'CounterName': nome,
        'CounterNumber': numero,
        'CounterVisualOrder': numero,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CounterInfo(id: $id, nome: $nome)';
}

/// Configuração do modo de contagem, persistida em [SharedPreferences].
///
/// Gerencia o modo ativo (simples/múltiplo), a lista de contadores
/// da equipe e o contador ativo no dispositivo.
///
/// Uso:
/// ```dart
/// final config = await CountingConfig.carregar();
/// print(config.modo);           // CountingMode.single
/// print(config.contadores);     // []
/// print(config.contadorAtivo);  // null
///
/// // Configurar equipe
/// config.modo = CountingMode.multiple;
/// config.contadores = [
///   CounterInfo(id: 9, nome: 'Rafael Valentim'),
///   CounterInfo(id: 56, nome: 'Brugge'),
/// ];
/// config.contadorAtivoID = 9;
/// await config.salvar();
/// ```
class CountingConfig {
  /// Modo de contagem ativo.
  CountingMode modo;

  /// Lista de contadores da equipe (só usado em modo múltiplo).
  List<CounterInfo> contadores;

  /// ID do contador ativo neste dispositivo.
  ///
  /// Em modo múltiplo, identifica quem está usando o celular.
  /// Null quando nenhum contador foi selecionado ou em modo simples.
  int? contadorAtivoID;

  CountingConfig({
    this.modo = CountingMode.single,
    this.contadores = const [],
    this.contadorAtivoID,
  });

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Retorna o [CounterInfo] do contador ativo, ou null se não configurado.
  CounterInfo? get contadorAtivo {
    if (contadorAtivoID == null) return null;
    try {
      return contadores.firstWhere((c) => c.id == contadorAtivoID);
    } catch (_) {
      return null;
    }
  }

  /// Verifica se o modo múltiplo está totalmente configurado.
  ///
  /// Retorna `true` quando há pelo menos 2 contadores e um ativo selecionado.
  bool get multiploConfigurado =>
      modo == CountingMode.multiple &&
      contadores.length >= 2 &&
      contadorAtivo != null;

  /// Verifica se está pronto para contar (simples sempre OK, múltiplo precisa config).
  bool get prontoParaContar =>
      modo == CountingMode.single || multiploConfigurado;

  // ── Serialização ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'modo': modo.valor,
        'contadores': contadores.map((c) => c.toJson()).toList(),
        'contadorAtivoID': contadorAtivoID,
      };

  factory CountingConfig.fromJson(Map<String, dynamic> json) {
    final lista = (json['contadores'] as List?)
            ?.map((c) => CounterInfo.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    return CountingConfig(
      modo: CountingMode.fromString(json['modo'] as String?),
      contadores: lista,
      contadorAtivoID: json['contadorAtivoID'] as int?,
    );
  }

  // ── Persistência ──────────────────────────────────────────────────────────

  static const String _key = 'counting_config';

  /// Carrega a configuração salva ou retorna os defaults (modo simples).
  static Future<CountingConfig> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return CountingConfig();
    try {
      return CountingConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return CountingConfig();
    }
  }

  /// Persiste a configuração atual.
  Future<void> salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  /// Reseta para o modo simples e limpa a equipe.
  Future<void> resetar() async {
    modo = CountingMode.single;
    contadores = [];
    contadorAtivoID = null;
    await salvar();
  }

  // ── Gerenciamento de contadores ───────────────────────────────────────────

  /// Adiciona um contador à equipe.
  void adicionarContador(CounterInfo contador) {
    if (!contadores.contains(contador)) {
      contadores = [...contadores, contador];
    }
  }

  /// Remove um contador da equipe pelo ID.
  void removerContador(int id) {
    contadores = contadores.where((c) => c.id != id).toList();
    if (contadorAtivoID == id) contadorAtivoID = null;
  }

  CountingConfig copyWith({
    CountingMode? modo,
    List<CounterInfo>? contadores,
    int? contadorAtivoID,
  }) =>
      CountingConfig(
        modo: modo ?? this.modo,
        contadores: contadores ?? this.contadores,
        contadorAtivoID: contadorAtivoID ?? this.contadorAtivoID,
      );
}