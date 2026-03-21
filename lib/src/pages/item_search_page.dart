import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_stox.dart';
import '../services/sap_service.dart';
import '../services/ocr_service.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';
import 'etiqueta_page.dart';

/// Filtro de status dos itens na busca.
enum _FiltroItem { todos, ativos, bloqueados }

/// Tela de consulta de itens no SAP Business One.
///
/// Permite busca por código ou nome, filtragem por status,
/// exibe detalhes completos do item e gerencia uma fila de
/// impressão de etiquetas.
class ItemSearchPage extends StatefulWidget {
  const ItemSearchPage({super.key});

  @override
  State<ItemSearchPage> createState() => _ItemSearchPageState();
}

class _ItemSearchPageState extends State<ItemSearchPage> {
  final _searchController = TextEditingController();

  Timer?                 _debounceTimer;
  Map<String, dynamic>?  _itemData;
  List<dynamic>          _resultados   = [];
  bool                   _carregando   = false;
  bool                   _scannerAtivo = false;
  _FiltroItem            _filtro       = _FiltroItem.todos;

  // ── Carrinho de impressão ─────────────────────────────────────────────────

  final Map<String, Map<String, dynamic>> _carrinho = {};

  void _adicionarAoCarrinho(Map<String, dynamic> item) {
    final code = item['ItemCode'] as String;
    HapticFeedback.mediumImpact();
    setState(() => _carrinho[code] = Map<String, dynamic>.from(item));
    StoxSnackbar.sucesso(context, '$code adicionado à fila de impressão.');
  }

  void _removerDoCarrinho(String code) {
    HapticFeedback.selectionClick();
    setState(() => _carrinho.remove(code));
  }

  bool _estaNoCarrinho(String code) => _carrinho.containsKey(code);

  void _irParaImpressao() {
    if (_carrinho.isEmpty) return;
    HapticFeedback.lightImpact();
    final itens = _carrinho.values.toList();
    Navigator.push(
      context,
      StoxApp.transicaoPadrao(EtiquetaPage(
        itemData:  itens.first,
        deposito:  itens.first['_deposito']?.toString() ?? '01',
        itenslote: itens,
      )),
    );
  }

  void _mostrarCarrinho() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CarrinhoSheet(
        carrinho:     _carrinho,
        primaryColor: Theme.of(context).primaryColor,
        onRemover: (code) => setState(() => _carrinho.remove(code)),
        onLimpar:  ()     => setState(() => _carrinho.clear()),
        onImprimir: () {
          Navigator.pop(sheetCtx);
          _irParaImpressao();
        },
      ),
    );
  }

  // ── Filtro ────────────────────────────────────────────────────────────────

  /// Aplica o filtro atual sobre a lista de resultados brutos.
  List<dynamic> get _resultadosFiltrados {
    if (_filtro == _FiltroItem.todos) return _resultados;
    return _resultados.where((item) {
      final frozen = item['Frozen'] ?? 'tNO';
      if (_filtro == _FiltroItem.bloqueados) return frozen == 'tYES';
      return frozen != 'tYES';
    }).toList();
  }

  // ── Busca ─────────────────────────────────────────────────────────────────

  Future<void> _buscar({bool autoSearch = false}) async {
    final termo = _searchController.text.trim();
    if (termo.isEmpty) {
      if (!autoSearch) HapticFeedback.selectionClick();
      return;
    }
    if (!autoSearch) {
      FocusScope.of(context).unfocus();
      HapticFeedback.lightImpact();
    }

    final sessaoAtiva = await SapService.verificarSessao();
    if (!sessaoAtiva) {
      if (!autoSearch && mounted) {
        await StoxAudio.play('sounds/error_beep.mp3', isError: true);
        if (!mounted) return;
        StoxSnackbar.erro(
            context, 'Sessão SAP não encontrada. Faça login antes de pesquisar.');
      }
      return;
    }

    setState(() {
      _carregando = true;
      _itemData   = null;
      _resultados = [];
    });

    try {
      final results = await SapService.searchItems(termo);
      if (!mounted) return;
      setState(() {
        _carregando = false;
        if (results.length == 1) {
          FocusScope.of(context).unfocus();
          _carregarDetalhes(results.first['ItemCode']);
        } else {
          _resultados = results;
          if (results.isNotEmpty && !autoSearch) HapticFeedback.selectionClick();
        }
      });
      if (results.isEmpty && !autoSearch) {
        await StoxAudio.play('sounds/error_beep.mp3', isError: true);
        if (!mounted) return;
        StoxSnackbar.aviso(context, "Nenhum item encontrado para '$termo'.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      if (!autoSearch) {
        await StoxAudio.play('sounds/fail.mp3', isFail: true);
        if (!mounted) return;
        StoxSnackbar.erro(context, 'Erro na busca: $e');
      }
    }
  }

  Future<void> _carregarDetalhes(String itemCode) async {
    setState(() => _carregando = true);
    try {
      final data = await SapService.getDetailedItem(itemCode);
      if (!mounted) return;
      setState(() {
        _itemData   = data;
        _resultados = [];
        _carregando = false;
      });
      await StoxAudio.play('sounds/beep.mp3');
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro ao carregar detalhes do item.');
    }
  }

  Future<void> _escanearTextoIA() async {
    HapticFeedback.mediumImpact();
    final resultado = await OcrService.lerAnotacaoDaCamera();
    if (!mounted) return;
    if (resultado != null && resultado['itemCode']!.isNotEmpty) {
      setState(() => _searchController.text = resultado['itemCode']!);
      await StoxAudio.play('sounds/beep.mp3');
      _buscar();
    } else {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Nenhum código reconhecido pela câmera.');
    }
  }

  void _abrirScanner() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _scannerAtivo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LayoutBuilder(
        builder: (_, constraints) {
          final scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, 200),
            width: 280,
            height: 180,
          );
          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                ),
                AppBar(
                  title: const Text('Escanear Código',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MobileScanner(
                        scanWindow: scanWindow,
                        onDetect: (capture) async {
                          if (_scannerAtivo) return;
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final code = barcodes.first.rawValue ?? '';
                          if (code.isEmpty) return;
                          _scannerAtivo = true;
                          await StoxAudio.play('sounds/beep.mp3');
                          if (!mounted) return;
                          _searchController.text = code;
                          // ignore: use_build_context_synchronously
                          Navigator.of(sheetCtx).pop();
                          _buscar();
                        },
                      ),
                    ),
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withAlpha(179), BlendMode.srcOut),
                      child: Stack(children: [
                        Container(
                            decoration: const BoxDecoration(
                                color: Colors.black,
                                backgroundBlendMode: BlendMode.dstOut)),
                        Center(
                          child: Container(
                            width: scanWindow.width,
                            height: scanWindow.height,
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ]),
                    ),
                    Center(
                      child: Container(
                        width: scanWindow.width,
                        height: scanWindow.height,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(sheetCtx).primaryColor,
                              width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Alinhe o código de barras dentro do quadro',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultar Item'),
        actions: [
          StoxBadge(
            count: _carrinho.length,
            child: IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Fila de impressão',
              onPressed: _mostrarCarrinho,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          if (_carregando) const StoxLinearLoading(),

          StoxSearchBar(
            controller: _searchController,
            onSearch:   _buscar,
            onIA:       _escanearTextoIA,
            onScanner:  _abrirScanner,
            onChanged: (value) {
              if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                if (value.trim().isNotEmpty) _buscar(autoSearch: true);
              });
            },
          ),

          // ── Chips de filtro (só aparecem com resultados) ──
          if (!_carregando && _resultados.length > 1)
            _buildFiltroChips(),

          if (!_carregando && _resultadosFiltrados.isNotEmpty)
            _buildSugestoesBusca(),
          if (!_carregando && _itemData != null)
            _buildDetalheItem(),
          if (!_carregando && _itemData == null && _resultados.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Busque por código ou nome.',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Chips de filtro ───────────────────────────────────────────────────────

  Widget _buildFiltroChips() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _buildChip('Todos',      _FiltroItem.todos,      theme),
        const SizedBox(width: 8),
        _buildChip('Ativos',     _FiltroItem.ativos,     theme),
        const SizedBox(width: 8),
        _buildChip('Bloqueados', _FiltroItem.bloqueados, theme),
        const Spacer(),
        Text(
          '${_resultadosFiltrados.length} resultado${_resultadosFiltrados.length != 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  Widget _buildChip(String label, _FiltroItem valor, ThemeData theme) {
    final selecionado = _filtro == valor;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selecionado ? Colors.white : Colors.grey.shade700,
          )),
      selected: selecionado,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _filtro = valor);
      },
      selectedColor: theme.primaryColor,
      backgroundColor: Colors.grey.shade100,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selecionado ? theme.primaryColor : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Subwidgets ────────────────────────────────────────────────────────────

  Widget _buildSugestoesBusca() {
    final theme    = Theme.of(context);
    final filtrado = _resultadosFiltrados;

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: filtrado.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item       = filtrado[index] as Map<String, dynamic>;
          final code       = item['ItemCode'] as String;
          final noCarrinho = _estaNoCarrinho(code);

          return StoxCard(
            borderColor: noCarrinho
                ? theme.primaryColor.withAlpha(80)
                : Colors.grey.shade300,
            child: Container(
              color: noCarrinho ? theme.primaryColor.withAlpha(8) : Colors.white,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.primaryColor.withAlpha(20),
                  child: Icon(Icons.inventory_2_outlined,
                      color: theme.primaryColor, size: 18),
                ),
                title: Text(item['ItemName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(code,
                    style: TextStyle(color: Colors.grey.shade600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        noCarrinho
                            ? Icons.print_disabled_rounded
                            : Icons.add_to_queue_rounded,
                        color: noCarrinho
                            ? Colors.red.shade400
                            : theme.primaryColor,
                      ),
                      tooltip: noCarrinho ? 'Remover da fila' : 'Adicionar à fila',
                      onPressed: () => noCarrinho
                          ? _removerDoCarrinho(code)
                          : _adicionarAoCarrinho(item),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.grey.shade400),
                  ],
                ),
                onTap: () => _carregarDetalhes(code),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetalheItem() {
    final noCarrinho = _estaNoCarrinho(_itemData!['ItemCode'] ?? '');
    final qtd    = num.tryParse(_itemData!['QuantityOnStock']?.toString() ?? '0') ?? 0;
    final minimo = num.tryParse(_itemData!['MinInventory']?.toString()   ?? '0') ?? 0;
    final maximo = num.tryParse(_itemData!['MaxInventory']?.toString()   ?? '0') ?? 0;

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StoxItemHeaderCard(
            itemCode:            _itemData!['ItemCode'] ?? '',
            itemName:            _itemData!['ItemName'] ?? '',
            quantidadeEmEstoque: qtd,
            estoqueMinimo:       minimo,
            estoqueMaximo:       maximo,
            unidadeMedida:       _itemData!['InventoryUOM']?.toString() ?? '',
          ),
          const SizedBox(height: 12),
          noCarrinho
              ? StoxDestructiveButton(
                  label:     'REMOVER DA FILA DE IMPRESSÃO',
                  icon:      Icons.remove_circle_outline,
                  onPressed: () => _removerDoCarrinho(_itemData!['ItemCode']),
                  height:    48,
                )
              : StoxButton(
                  label:     'ADICIONAR À FILA DE IMPRESSÃO',
                  icon:      Icons.add_to_queue_rounded,
                  onPressed: () => _adicionarAoCarrinho(_itemData!),
                  height:    48,
                ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              spacing: 12,
              children: [
                StoxStatusChip('Estoque',
                    active: _itemData!['InventoryItem'] == 'tYES'),
                StoxStatusChip('Venda',
                    active: _itemData!['SalesItem'] == 'tYES'),
                StoxStatusChip('Compra',
                    active: _itemData!['PurchaseItem'] == 'tYES'),
              ],
            ),
          ),
          _buildInfoDepositos(),
          StoxSectionCard(
            titulo: 'Identificação',
            linhas: [
              StoxDetailRow('Unidade de Medida', _itemData!['InventoryUOM']?.toString()),
              StoxDetailRow('Embalagem',          _itemData!['SalesPackagingUnit']?.toString()),
              StoxDetailRow('Código de Barras (EAN)', _itemData!['BarCode']?.toString()),
              StoxDetailRow('Código Adicional (SWW)', _itemData!['SWW']?.toString()),
              StoxDetailRow('Nome Estrangeiro',   _itemData!['ForeignName']?.toString()),
              StoxDetailRow('Grupo (código)',      _itemData!['ItemsGroupCode']?.toString()),
              StoxDetailRow('NCM',                 _itemData!['NCMCode']?.toString()),
            ],
          ),
          StoxSectionCard(
            titulo: 'Controle de Estoque',
            linhas: [
              StoxDetailRow('Estoque Total',
                  _formatNum(_itemData!['QuantityOnStock']), destaque: true),
              StoxDetailRow('Pedidos de Clientes',
                  _formatNum(_itemData!['QuantityOrderedByCustomers'])),
              StoxDetailRow('Pedidos a Fornecedores',
                  _formatNum(_itemData!['QuantityOrderedFromVendors'])),
              StoxDetailRow('Estoque Mínimo',
                  _formatNum(_itemData!['MinInventory'])),
              StoxDetailRow('Estoque Máximo',
                  _formatNum(_itemData!['MaxInventory'])),
              StoxDetailRow('Qtd. Mínima de Pedido',
                  _formatNum(_itemData!['MinOrderQuantity'])),
              StoxDetailRow('Controle por Lote',
                  _itemData!['ManageBatchNumbers'] == 'tYES' ? 'Sim' : 'Não'),
              StoxDetailRow('Controle por Nº de Série',
                  _itemData!['ManageSerialNumbers'] == 'tYES' ? 'Sim' : 'Não'),
            ],
          ),
          StoxSectionCard(
            titulo: 'Fornecimento e Preços',
            linhas: [
              StoxDetailRow('Fornecedor Principal',
                  _itemData!['Mainsupplier']?.toString()),
              StoxDetailRow('Fabricante (código)',
                  _itemData!['Manufacturer']?.toString()),
              StoxDetailRow('Preço Médio Móvel',
                  _formatPreco(_itemData!['MovingAveragePrice'])),
              StoxDetailRow('Preço Médio / Padrão',
                  _formatPreco(_itemData!['AvgStdPrice'])),
              StoxDetailRow('Preço Lista 1', _formatPrecoLista(1)),
            ],
          ),
          StoxSectionCard(
            titulo: 'Dimensões e Peso',
            linhas: [
              StoxDetailRow('Peso',
                  _formatMedida(_itemData!['SalesUnitWeight'], 'kg')),
              StoxDetailRow('Altura',
                  _formatMedida(_itemData!['SalesUnitHeight'], 'm')),
              StoxDetailRow('Largura',
                  _formatMedida(_itemData!['SalesUnitWidth'], 'm')),
              StoxDetailRow('Comprimento',
                  _formatMedida(_itemData!['SalesUnitLength'], 'm')),
            ],
          ),
          StoxSectionCard(
            titulo: 'Status',
            linhas: [
              StoxDetailRow(
                'Item Bloqueado',
                _itemData!['Frozen'] == 'tYES' ? 'SIM' : 'NÃO',
                isAlert: _itemData!['Frozen'] == 'tYES',
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInfoDepositos() {
    final lista      = _itemData!['ItemWarehouseInfoCollection'] as List? ?? [];
    final depositos  = lista.where((wh) => (wh['InStock'] ?? 0) > 0).toList();

    if (depositos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Sem estoque disponível em nenhum depósito.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 8),
          child: Text('Estoque por Depósito',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        ...depositos.map((wh) => StoxCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.warehouse_rounded,
                      color: Colors.blue.shade700, size: 20),
                ),
                title: Text('Depósito ${wh['WarehouseCode']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Disponível: ${wh['InStock']}  •  '
                  'Comprometido: ${wh['Committed'] ?? 0}  •  '
                  'Pedido: ${wh['Ordered'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'Imprimir etiqueta deste depósito',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      StoxApp.transicaoPadrao(EtiquetaPage(
                        itemData: _itemData!,
                        deposito: wh['WarehouseCode'].toString(),
                      )),
                    );
                  },
                ),
              ),
            )),
      ],
    );
  }

  // ── Formatação ────────────────────────────────────────────────────────────

  String? _formatPrecoLista(int lista) {
    final prices = _itemData!['ItemPrices'] as List? ?? [];
    try {
      final entry = prices
          .firstWhere((p) => p['PriceList'] == lista && (p['Price'] ?? 0) > 0);
      return _formatPreco(entry['Price']);
    } catch (_) {
      return null;
    }
  }

  String? _formatNum(dynamic val) {
    if (val == null) return null;
    final n = num.tryParse(val.toString());
    if (n == null || n == 0) return null;
    return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  }

  String? _formatPreco(dynamic val) {
    if (val == null) return null;
    final n = num.tryParse(val.toString());
    if (n == null || n == 0) return null;
    return 'R\$ ${n.toStringAsFixed(2)}';
  }

  String? _formatMedida(dynamic val, String unidade) {
    if (val == null) return null;
    final n = num.tryParse(val.toString());
    if (n == null || n == 0) return null;
    return '${n.toStringAsFixed(3)} $unidade';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

// ── Sheet do carrinho de impressão ───────────────────────────────────────────

class _CarrinhoSheet extends StatefulWidget {
  final Map<String, Map<String, dynamic>> carrinho;
  final Color        primaryColor;
  final void Function(String code) onRemover;
  final VoidCallback onLimpar;
  final VoidCallback onImprimir;

  const _CarrinhoSheet({
    required this.carrinho,
    required this.primaryColor,
    required this.onRemover,
    required this.onLimpar,
    required this.onImprimir,
  });

  @override
  State<_CarrinhoSheet> createState() => _CarrinhoSheetState();
}

class _CarrinhoSheetState extends State<_CarrinhoSheet> {
  late List<String> _keys;

  @override
  void initState() {
    super.initState();
    _keys = widget.carrinho.keys.toList();
  }

  void _remover(String code) {
    widget.onRemover(code);
    setState(() => _keys.remove(code));
    HapticFeedback.selectionClick();
  }

  void _limpar() {
    widget.onLimpar();
    setState(() => _keys.clear());
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 48,
          height: 6,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(children: [
            Icon(Icons.print_rounded, color: widget.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fila de impressão (${_keys.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (_keys.isNotEmpty)
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Limpar fila'),
                    content:
                        const Text('Remover todos os itens da fila de impressão?'),
                    actions: [
                      StoxTextButton(
                        label:     'CANCELAR',
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          _limpar();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600),
                        child: const Text('LIMPAR TUDO'),
                      ),
                    ],
                  ),
                ),
                icon: Icon(Icons.delete_sweep_rounded,
                    color: Colors.red.shade600, size: 18),
                label: Text('Limpar',
                    style: TextStyle(color: Colors.red.shade600)),
              ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _keys.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print_disabled_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Nenhum item na fila.',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text('Adicione itens pela busca.',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _keys.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final code = _keys[index];
                    final item = widget.carrinho[code]!;
                    return Dismissible(
                      key: Key(code),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_rounded,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => _remover(code),
                      child: StoxCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: widget.primaryColor.withAlpha(20),
                            child: Icon(Icons.label_rounded,
                                color: widget.primaryColor, size: 18),
                          ),
                          title: Text(code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            item['ItemName'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade400),
                            tooltip: 'Remover da fila',
                            onPressed: () => _remover(code),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_keys.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: StoxButton(
              label: 'Imprimir ${_keys.length} '
                  '${_keys.length == 1 ? "etiqueta" : "etiquetas"}',
              icon:      Icons.print_rounded,
              onPressed: widget.onImprimir,
              height:    52,
            ),
          ),
      ]),
    );
  }
}