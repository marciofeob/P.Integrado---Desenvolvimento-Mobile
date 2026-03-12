import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

import '../../services/sap_service.dart';
import '../../services/ocr_service.dart'; // Serviço de IA/OCR importado
import 'etiqueta_page.dart';

class ItemSearchPage extends StatefulWidget {
  const ItemSearchPage({super.key});

  @override
  State<ItemSearchPage> createState() => _ItemSearchPageState();
}

class _ItemSearchPageState extends State<ItemSearchPage> {
  final _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Timer? _debounceTimer;
  Map<String, dynamic>? _itemData;
  List<dynamic> _searchResults = [];
  
  bool _loading = false;
  bool _scannerProcessando = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE FEEDBACK E BUSCA ---

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 100);
        }
      } else {
        isError ? HapticFeedback.vibrate() : HapticFeedback.lightImpact();
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir som ou vibrar: $e");
    }
  }

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

    setState(() {
      _loading = true;
      _itemData = null;
      _searchResults = [];
    });

    try {
      final results = await SapService.searchItems(termo);

      if (mounted) {
        setState(() {
          _loading = false;
          if (results.length == 1) {
            FocusScope.of(context).unfocus();
            _carregarDetalhes(results.first['ItemCode']);
          } else {
            _searchResults = results;
            if (results.isNotEmpty && !autoSearch) HapticFeedback.selectionClick();
          }
        });
      }

      if (results.isEmpty && !autoSearch) {
        await _tocarFeedback('sounds/error_beep.mp3', isError: true);
        _mostrarAviso("Nenhum item encontrado para '$termo'.");
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (!autoSearch) _mostrarErro("Erro na busca: $e");
    }
  }

  Future<void> _carregarDetalhes(String itemCode) async {
    setState(() => _loading = true);
    try {
      final data = await SapService.getDetailedItem(itemCode);
      if (mounted) {
        setState(() {
          _itemData = data;
          _searchResults = [];
          _loading = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _mostrarErro("Erro ao carregar detalhes do item.");
    }
  }

  // --- FUNÇÃO: ESCANEAR TEXTO COM IA (OCR) ---
  Future<void> _escanearTextoIA() async {
    HapticFeedback.mediumImpact();
    
    // Chama o serviço de OCR
    final resultado = await OcrService.lerAnotacaoDaCamera();
    
    // Validação segura para evitar quebra caso 'itemCode' seja null
    if (resultado != null && resultado['itemCode'] != null && resultado['itemCode']!.isNotEmpty) {
      setState(() {
        _searchController.text = resultado['itemCode']!;
      });
      // Toca um feedback de sucesso e inicia a busca
      await _tocarFeedback('sounds/beep.mp3');
      _buscar();
    }
  }

  // --- INTERFACE DE AVISOS ---

  void _mostrarErro(String msg) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _mostrarAviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // --- SCANNER DE CÓDIGO DE BARRAS ---

  void _abrirScanner() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _scannerProcessando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutBuilder(builder: (context, constraints) {
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, 200),
          width: 280,
          height: 180,
        );

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48, height: 6, 
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
                AppBar(
                  title: const Text('Escanear Código', style: TextStyle(fontWeight: FontWeight.bold)),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded), 
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileScanner(
                          scanWindow: scanWindow,
                          onDetect: (capture) async {
                            if (_scannerProcessando) return;
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              final code = barcodes.first.rawValue ?? "";
                              if (code.isEmpty) return;
                              
                              _scannerProcessando = true;
                              await _tocarFeedback('sounds/beep.mp3');
                              
                              if (!mounted) return;
                              _searchController.text = code;
                              // ignore: use_build_context_synchronously
                              Navigator.of(context).pop(); // Fecha o modal do scanner
                              _buscar();
                            }
                          },
                        ),
                      ),
                      // Overlay do Scanner (Visual)
                      ColorFiltered(
                        // ignore: deprecated_member_use
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.srcOut),
                        child: Stack(
                          children: [
                            Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                            Center(
                              child: Container(
                                width: scanWindow.width,
                                height: scanWindow.height,
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          width: scanWindow.width,
                          height: scanWindow.height,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).primaryColor, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text("Alinhe o código de barras dentro do quadro"),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Consultar Item")),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_loading && _searchResults.isNotEmpty) _buildSearchSuggestions(),
            if (!_loading && _itemData != null) _buildResultList(),
            if (!_loading && _itemData == null && _searchResults.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Busque por código, nome ou use a IA.", style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              onChanged: (value) {
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                  if (value.trim().isNotEmpty) _buscar(autoSearch: true);
                });
              },
              decoration: InputDecoration(
                hintText: "Código ou Nome",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min, // Garante que a Row não ocupe todo o TextField
                  children: [
                    // BOTÃO DA IA (OCR)
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                      tooltip: "Ler texto com IA",
                      onPressed: _escanearTextoIA,
                    ),
                    // BOTÃO DO SCANNER (BARCODE)
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner_rounded, color: theme.primaryColor),
                      tooltip: "Escanear código de barras",
                      onPressed: _abrirScanner,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56, width: 56,
            child: ElevatedButton(
              onPressed: () => _buscar(),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              title: Text(item['ItemName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['ItemCode'] ?? ''),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _carregarDetalhes(item['ItemCode']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultList() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          _buildStatusFlags(),
          _buildSectionTitle("Estoque por Depósito"),
          _buildWarehouseInfo(),
          _buildSectionTitle("Informações Adicionais"),
          _buildDetailRow("Unidade de Medida", _itemData!['InventoryUOM'] ?? "UN"),
          _buildDetailRow(
            "Item Bloqueado",
            _itemData!['Frozen'] == "tYES" ? "SIM" : "NÃO",
            isAlert: _itemData!['Frozen'] == "tYES",
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_itemData!['ItemCode'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_itemData!['ItemName'] ?? '', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildStatusFlags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Wrap(
        spacing: 12,
        children: [
          _statusChip("Estoque", _itemData!['InventoryItem'] == 'tYES'),
          _statusChip("Venda", _itemData!['SalesItem'] == 'tYES'),
          _statusChip("Compra", _itemData!['PurchaseItem'] == 'tYES'),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool active) {
    return Chip(
      label: Text(label),
      backgroundColor: active ? Colors.green.shade50 : Colors.grey.shade100,
      avatar: Icon(active ? Icons.check_circle : Icons.cancel, size: 16, color: active ? Colors.green : Colors.grey),
    );
  }

  Widget _buildWarehouseInfo() {
    final list = (_itemData!['ItemWarehouseInfoCollection'] as List? ?? []);
    final warehouses = list.where((wh) => (wh['InStock'] ?? 0) > 0).toList();

    if (warehouses.isEmpty) return const Text("Sem estoque disponível.");

    return Column(
      children: warehouses.map((wh) => Card(
        child: ListTile(
          leading: const Icon(Icons.warehouse),
          title: Text("Depósito ${wh['WarehouseCode']}"),
          subtitle: Text("Disponível: ${wh['InStock']}"),
          trailing: IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EtiquetaPage(itemData: _itemData!, deposito: wh['WarehouseCode'].toString()))),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAlert = false}) {
    return ListTile(
      title: Text(label),
      trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isAlert ? Colors.red : Colors.black)),
    );
  }
}