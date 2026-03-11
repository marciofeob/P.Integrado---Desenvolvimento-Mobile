import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../services/sap_service.dart';
import 'etiqueta_page.dart';

class ItemSearchPage extends StatefulWidget {
  const ItemSearchPage({super.key});

  @override
  State<ItemSearchPage> createState() => _ItemSearchPageState();
}

class _ItemSearchPageState extends State<ItemSearchPage> {
  final _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Map<String, dynamic>? _itemData;
  List<dynamic> _searchResults = [];
  
  bool _loading = false;
  bool _scannerProcessando = false;

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 100);
        }
      } else {
        // Fallback caso não tenha motor de vibração customizável
        isError ? HapticFeedback.vibrate() : HapticFeedback.lightImpact();
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir som ou vibrar: $e");
    }
  }

  Future<void> _buscar() async {
    final termo = _searchController.text.trim();
    if (termo.isEmpty) {
      HapticFeedback.selectionClick();
      return;
    }

    FocusScope.of(context).unfocus(); // Recolhe o teclado
    HapticFeedback.lightImpact();

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
            _carregarDetalhes(results.first['ItemCode']);
          } else {
            _searchResults = results;
            if (results.isNotEmpty) HapticFeedback.selectionClick();
          }
        });
      }

      if (results.isEmpty) {
        await _tocarFeedback('sounds/error_beep.mp3', isError: true);
        _mostrarAviso("Nenhum item encontrado para '$termo'.");
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _mostrarErro("Erro na busca: $e");
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
                  width: 48, 
                  height: 6, 
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
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
                              _scannerProcessando = true;
                              final code = barcodes.first.rawValue ?? "";
                              await _tocarFeedback('sounds/beep.mp3');
                              
                              if (!mounted) return;
                              _searchController.text = code;
                              Navigator.of(context).pop();
                              _buscar();
                            }
                          },
                        ),
                      ),
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.srcOut),
                        child: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut),
                            ),
                            Center(
                              child: Container(
                                width: scanWindow.width,
                                height: scanWindow.height,
                                decoration: BoxDecoration(
                                  color: Colors.red, // Parte vazada pelo SRC_OUT
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "Alinhe o código de barras dentro do quadro", 
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consultar Item"),
      ),
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
                      Text(
                        "Busque por código ou nome para começar.", 
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
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
              decoration: InputDecoration(
                hintText: "Código ou Nome do Item",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code_scanner_rounded, color: theme.primaryColor),
                  onPressed: _abrirScanner,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 56,
            width: 56,
            child: ElevatedButton(
              onPressed: _buscar,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 28),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(item['ItemName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item['ItemCode'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).primaryColor),
              onTap: () {
                HapticFeedback.selectionClick();
                _carregarDetalhes(item['ItemCode']);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultList() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
          const SizedBox(height: 30),
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
        boxShadow: [
          BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _itemData!['ItemCode'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            _itemData!['ItemName'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFlags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.start,
        children: [
          _statusChip("Estoque", _itemData!['InventoryItem'] == 'tYES'),
          _statusChip("Venda", _itemData!['SalesItem'] == 'tYES'),
          _statusChip("Compra", _itemData!['PurchaseItem'] == 'tYES'),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: active ? Colors.green.shade400 : Colors.grey.shade300, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.cancel_rounded, 
            size: 16, 
            color: active ? Colors.green.shade600 : Colors.grey.shade500
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.green.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseInfo() {
    final list = (_itemData!['ItemWarehouseInfoCollection'] as List? ?? []);
    final warehouses = list.where((wh) => (wh['InStock'] ?? 0) > 0).toList();

    if (warehouses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text("Sem estoque disponível nos depósitos.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
      );
    }

    return Column(
      children: warehouses.map((wh) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              radius: 24,
              child: Icon(Icons.warehouse_rounded, color: Theme.of(context).primaryColor, size: 24),
            ),
            title: Text("Depósito ${wh['WarehouseCode']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Disponível: ${wh['InStock']}", 
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.print_rounded, color: Theme.of(context).primaryColor),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EtiquetaPage(
                      itemData: _itemData!,
                      deposito: wh['WarehouseCode'].toString(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAlert ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isAlert ? Colors.red.shade700 : Colors.grey.shade700, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isAlert ? Colors.red.shade700 : Colors.black87,
            )
          ),
        ],
      ),
    );
  }
}