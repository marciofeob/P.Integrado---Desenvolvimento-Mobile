import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';

import '../services/database_helper.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';

/// Tela de importação de contagens a partir de arquivo CSV.
///
/// Compatível com o formato exportado pelo próprio STOX:
/// ```
/// Código do Item;Depósito;Quantidade;Data e Hora;Status
/// CONS0000027;01.01;5,0;28/03/2026 12:54:00;Pendente
/// ```
///
/// Também aceita formatos simplificados:
/// - `ItemCode;Quantidade` (depósito usa o padrão `01`)
/// - `ItemCode;Quantidade;WarehouseCode`
/// - Delimitadores `;` ou `,` (detecção automática)
///
/// Fluxo:
/// 1. Operador seleciona arquivo CSV/TXT
/// 2. Parser detecta delimitador, header e colunas automaticamente
/// 3. Preview com chips de resumo (itens, quantidade total, depósitos)
/// 4. Confirmação via [StoxDialog] antes de importar
/// 5. Inserção no SQLite e retorno ao painel
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<_ItemImportado> _itens = [];
  String? _nomeArquivo;
  bool _carregando = false;
  bool _importado = false;
  String? _erro;

  // ── Seleção de arquivo ────────────────────────────────────────────────────

  /// Abre o seletor de arquivo e processa o CSV selecionado.
  Future<void> _selecionarArquivo() async {
    HapticFeedback.selectionClick();
    setState(() {
      _erro = null;
      _importado = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        setState(() => _erro = 'Não foi possível acessar o arquivo.');
        return;
      }

      setState(() {
        _carregando = true;
        _nomeArquivo = file.name;
      });

      final conteudo = await File(file.path!).readAsString();
      final itens = _parseCsv(conteudo);

      if (!mounted) return;
      setState(() {
        _itens = itens;
        _carregando = false;
      });

      if (itens.isEmpty) {
        setState(
          () => _erro = 'Nenhum item válido encontrado no arquivo.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ImportPage._selecionarArquivo: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Erro ao ler o arquivo: $e';
      });
    }
  }

  // ── Parser CSV ────────────────────────────────────────────────────────────

  /// Analisa o conteúdo CSV e retorna a lista de itens importados.
  ///
  /// Lógica de detecção:
  /// 1. Remove BOM UTF-8 se presente
  /// 2. Detecta delimitador (`;` vs `,`) pela frequência na primeira linha
  /// 3. Detecta header por palavras-chave (item, código, quantidade)
  /// 4. Mapeia colunas por nome quando há header
  /// 5. Ignora linhas vazias e itens com quantidade <= 0
  List<_ItemImportado> _parseCsv(String conteudo) {
    final limpo = conteudo.replaceAll('\uFEFF', '').trim();
    if (limpo.isEmpty) return [];

    final linhas = limpo.split(RegExp(r'\r?\n'));
    if (linhas.isEmpty) return [];

    // Detecta delimitador pela frequência na primeira linha
    final primeiraLinha = linhas.first;
    final delimitador =
        ';'.allMatches(primeiraLinha).length >=
                ','.allMatches(primeiraLinha).length
            ? ';'
            : ',';

    // Detecta header por palavras-chave
    final headerLower = primeiraLinha.toLowerCase();
    final temHeader = headerLower.contains('item') ||
        headerLower.contains('código') ||
        headerLower.contains('codigo') ||
        headerLower.contains('code') ||
        headerLower.contains('quantidade') ||
        headerLower.contains('qty');

    // Mapeamento padrão de colunas (formato STOX exportado)
    int colItem = 0;
    int colQtd = 2;
    int colDeposito = 1;

    // Se tem header, mapeia colunas por nome
    if (temHeader) {
      final colunas = _splitLinha(primeiraLinha, delimitador);
      for (int i = 0; i < colunas.length; i++) {
        final col = colunas[i].toLowerCase().trim();
        if (col.contains('item') ||
            col.contains('código') ||
            col.contains('codigo') ||
            col.contains('code')) {
          colItem = i;
        } else if (col.contains('quantidade') ||
            col.contains('qty') ||
            col.contains('quantity') ||
            col.contains('contad')) {
          colQtd = i;
        } else if (col.contains('depósito') ||
            col.contains('deposito') ||
            col.contains('warehouse') ||
            col.contains('wh')) {
          colDeposito = i;
        }
      }
    }

    // Processa as linhas de dados
    final inicio = temHeader ? 1 : 0;
    final itens = <_ItemImportado>[];

    for (int i = inicio; i < linhas.length; i++) {
      final linha = linhas[i].trim();
      if (linha.isEmpty) continue;

      final campos = _splitLinha(linha, delimitador);
      if (campos.length <= colItem) continue;

      final itemCode = campos[colItem].trim().toUpperCase();
      if (itemCode.isEmpty) continue;

      // Quantidade: tenta coluna mapeada, senão coluna 1
      double quantidade = 1.0;
      final idxQtd = colQtd < campos.length ? colQtd : 1;
      if (idxQtd < campos.length) {
        final raw = campos[idxQtd].trim().replaceAll(',', '.');
        quantidade = double.tryParse(raw) ?? 1.0;
      }

      // Depósito: tenta coluna mapeada, senão default '01'
      // Ignora valores que parecem ser data (contém / ou :)
      String deposito = '01';
      if (colDeposito < campos.length &&
          colDeposito != colItem &&
          colDeposito != colQtd) {
        final raw = campos[colDeposito].trim();
        if (raw.isNotEmpty &&
            !raw.contains('/') &&
            !raw.contains(':')) {
          deposito = raw;
        }
      }

      if (quantidade > 0) {
        itens.add(_ItemImportado(
          itemCode: itemCode,
          quantidade: quantidade,
          warehouseCode: deposito,
        ));
      }
    }

    return itens;
  }

  /// Divide uma linha CSV respeitando aspas duplas como delimitador de campo.
  ///
  /// Ex: `"Item com;ponto";10;01` → `['Item com;ponto', '10', '01']`
  List<String> _splitLinha(String linha, String delimitador) {
    final campos = <String>[];
    final buffer = StringBuffer();
    bool dentroAspas = false;

    for (int i = 0; i < linha.length; i++) {
      final c = linha[i];
      if (c == '"') {
        dentroAspas = !dentroAspas;
      } else if (c == delimitador && !dentroAspas) {
        campos.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    campos.add(buffer.toString());
    return campos;
  }

  // ── Importação para SQLite ────────────────────────────────────────────────

  /// Confirma com o operador e insere todos os itens no banco local.
  ///
  /// Após importação, retorna ao painel ([Navigator.pop]) para sincronizar.
  Future<void> _importarContagens() async {
    if (_itens.isEmpty) return;

    final confirmar = await StoxDialog.confirmar(
      context,
      titulo: 'Importar ${_itens.length} itens',
      mensagem:
          'As contagens serão adicionadas ao banco local '
          'e ficarão pendentes para sincronização.\n\n'
          'Deseja continuar?',
      labelConfirmar: 'IMPORTAR',
    );
    if (!confirmar) return;

    HapticFeedback.lightImpact();
    setState(() => _carregando = true);

    try {
      int importados = 0;
      for (final item in _itens) {
        await DatabaseHelper.instance.inserirContagem(
          item.itemCode,
          item.quantidade,
          warehouseCode: item.warehouseCode,
        );
        importados++;
      }

      await StoxAudio.play('sounds/check.mp3');
      if (!mounted) return;

      setState(() => _carregando = false);

      StoxSnackbar.sucesso(
        context,
        '$importados '
        '${importados == 1 ? 'item importado' : 'itens importados'} '
        'com sucesso!',
      );

      Navigator.pop(context);
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (kDebugMode) debugPrint('ImportPage._importarContagens: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Erro ao importar: $e';
      });
    }
  }

  /// Remove um item individual do preview antes de importar.
  void _removerItem(int index) {
    HapticFeedback.selectionClick();
    setState(() => _itens.removeAt(index));
  }

  /// Limpa todo o estado e volta ao estado inicial da tela.
  void _limparTudo() {
    HapticFeedback.selectionClick();
    setState(() {
      _itens.clear();
      _nomeArquivo = null;
      _importado = false;
      _erro = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Contagem'),
        actions: [
          if (_itens.isNotEmpty && !_importado)
            IconButton(
              tooltip: 'Limpar tudo',
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: Colors.red.shade400,
              ),
              onPressed: _limparTudo,
            ),
        ],
      ),
      body: SafeArea(
        child: _carregando
            ? const StoxLoadingSpinner(mensagem: 'Processando...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInstrucoes(theme),
                    const SizedBox(height: 24),
                    _buildBotaoSelecionar(),
                    if (_erro != null) ...[
                      const SizedBox(height: 16),
                      _buildErro(),
                    ],
                    if (_nomeArquivo != null && _itens.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildResumoArquivo(theme),
                      const SizedBox(height: 16),
                      _buildListaItens(theme),
                      const SizedBox(height: 32),
                      if (!_importado)
                        StoxButton(
                          label: 'IMPORTAR ${_itens.length} '
                              '${_itens.length == 1 ? 'ITEM' : 'ITENS'}',
                          icon: Icons.download_rounded,
                          onPressed: _importarContagens,
                        ),
                      if (_importado) _buildSucessoImportacao(),
                    ],
                    if (_itens.isEmpty &&
                        _nomeArquivo == null &&
                        _erro == null)
                      _buildEmptyState(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Subwidgets ────────────────────────────────────────────────────────────

  Widget _buildInstrucoes(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Como importar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Importe contagens feitas em outro dispositivo ou coletor.\n'
            'Aceita CSV exportado pelo STOX ou em formato simples '
            '(ItemCode;Quantidade;Depósito).',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoSelecionar() {
    return StoxButton(
      label: _itens.isEmpty
          ? 'SELECIONAR ARQUIVO CSV'
          : 'TROCAR ARQUIVO',
      icon: Icons.file_open_rounded,
      onPressed: _selecionarArquivo,
    );
  }

  Widget _buildErro() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _erro!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoArquivo(ThemeData theme) {
    final qtdTotal =
        _itens.fold(0.0, (sum, item) => sum + item.quantidade);
    final depositos = _itens.map((i) => i.warehouseCode).toSet();

    return StoxCard(
      padding: const EdgeInsets.all(16),
      borderColor: theme.primaryColor.withAlpha(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nome do arquivo ──
          Row(
            children: [
              Icon(Icons.description_rounded,
                  color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _nomeArquivo ?? 'arquivo.csv',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Chips de resumo ──
          Row(
            children: [
              _buildChipResumo(
                '${_itens.length} itens',
                Icons.inventory_2_rounded,
                theme.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildChipResumo(
                'Qtd: ${qtdTotal % 1 == 0 ? qtdTotal.toInt() : qtdTotal.toStringAsFixed(1)}',
                Icons.numbers_rounded,
                Colors.teal.shade600,
              ),
              const SizedBox(width: 8),
              _buildChipResumo(
                '${depositos.length} dep.',
                Icons.warehouse_rounded,
                Colors.orange.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipResumo(String label, IconData icon, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaItens(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_rounded,
                color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Text(
              'Preview dos itens',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_itens.length, (i) {
          final item = _itens[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: StoxCard(
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.primaryColor.withAlpha(26),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  item.itemCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Qtd: ${item.quantidade % 1 == 0 ? item.quantidade.toInt() : item.quantidade}'
                  '  •  Dep: ${item.warehouseCode}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: _importado
                    ? Icon(Icons.check_circle_rounded,
                        color: Colors.green.shade600, size: 20)
                    : IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red.shade400,
                          size: 18,
                        ),
                        onPressed: () => _removerItem(i),
                      ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSucessoImportacao() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.green.shade600, size: 48),
          const SizedBox(height: 12),
          Text(
            'Importação concluída!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Os itens foram adicionados ao banco local.\n'
            'Volte ao Painel e sincronize com o SAP.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.green.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StoxTextButton(
                label: 'Importar outro',
                icon: Icons.file_open_rounded,
                onPressed: _limparTudo,
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text(
                  'VOLTAR AO PAINEL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.upload_file_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Nenhum arquivo selecionado',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione um CSV exportado pelo STOX\n'
              'ou de um coletor de dados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Model ───────────────────────────────────────────────────────────────────

/// Item individual parseado do CSV, pronto para inserção no SQLite.
class _ItemImportado {
  /// Código do item SAP (sempre uppercase).
  final String itemCode;

  /// Quantidade contada (sempre > 0).
  final double quantidade;

  /// Código do depósito (default `'01'`).
  final String warehouseCode;

  const _ItemImportado({
    required this.itemCode,
    required this.quantidade,
    this.warehouseCode = '01',
  });

  @override
  String toString() =>
      '_ItemImportado($itemCode, qtd: $quantidade, dep: $warehouseCode)';
}