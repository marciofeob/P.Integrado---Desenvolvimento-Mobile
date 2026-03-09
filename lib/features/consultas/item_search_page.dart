import 'package:flutter/material.dart';
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
  
  // Alterado para suportar lista de resultados (pesquisa por nome)
  Map<String, dynamic>? _itemData;
  List<dynamic> _searchResults = [];
  
  bool _loading = false;
  bool _scannerProcessando = false;
  final Color primaryColor = const Color(0xFF0A6ED1);

  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 100);
        }
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir som: $e");
    }
  }

  Future<void> _buscar() async {
    final termo = _searchController.text.trim();
    if (termo.isEmpty) return;

    setState(() {
      _loading = true;
      _itemData = null;
      _searchResults = [];
    });

    // Tenta buscar por código exato primeiro ou via busca textual no SAP
    // O Service deve ser capaz de identificar se é código ou nome
    final results = await SapService.searchItems(termo);

    setState(() {
      _loading = false;
      if (results.length == 1) {
        // Se achou apenas 1, já carrega os detalhes direto
        _carregarDetalhes(results.first['ItemCode']);
      } else {
        // Se achou vários, mostra a lista para escolha
        _searchResults = results;
      }
    });

    if (results.isEmpty) {
      await _tocarFeedback('sounds/error_beep.mp3', isError: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nenhum item encontrado."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _carregarDetalhes(String itemCode) async {
    setState(() => _loading = true);
    final data = await SapService.getDetailedItem(itemCode);
    setState(() {
      _itemData = data;
      _searchResults = [];
      _loading = false;
    });
  }

  void _abrirScanner() {
    _scannerProcessando = false;
    final scanWindow = Rect.fromCenter(
      center: Offset(MediaQuery.of(context).size.width / 2,
          (MediaQuery.of(context).size.height * 0.7) / 2 - 50),
      width: 250,
      height: 150,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, color: Colors.grey[300]),
            AppBar(
                title: const Text('Consultar Código'),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    scanWindow: scanWindow,
                    onDetect: (capture) async {
                      if (_scannerProcessando) return;
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        _scannerProcessando = true;
                        final code = barcodes.first.rawValue ?? "";
                        await _tocarFeedback('sounds/beep.mp3');
                        if (!mounted) return;
                        setState(() {
                          _searchController.text = code;
                        });
                        Navigator.of(context).pop();
                        _buscar();
                      }
                    },
                  ),
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(color: Colors.black),
                        Center(
                          child: Container(
                            width: scanWindow.width,
                            height: scanWindow.height,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
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
                        border: Border.all(color: primaryColor, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Alinhe o código de barras"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consultar Item SAP"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loading && _searchResults.isNotEmpty) _buildSearchSuggestions(),
          if (!_loading && _itemData != null) _buildResultList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Código ou Nome do Item",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  onPressed: _abrirScanner,
                ),
              ),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _buscar,
            icon: const Icon(Icons.arrow_forward),
            style: IconButton.styleFrom(backgroundColor: primaryColor),
          ),
        ],
      ),
    );
  }

  // Lista de resultados quando a busca retorna mais de um item
  Widget _buildSearchSuggestions() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.inventory),
              title: Text(item['ItemName'] ?? 'Sem nome'),
              subtitle: Text(item['ItemCode'] ?? ''),
              trailing: const Icon(Icons.chevron_right),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildHeaderCard(),
          _buildStatusFlags(),
          _buildSectionTitle("Estoque por Depósito"),
          _buildWarehouseInfo(),
          _buildSectionTitle("Dados Comerciais"),
          _buildDetailRow("Unidade de Compra", _itemData!['PurchaseUnit'] ?? "N/A"),
          _buildDetailRow("Unidade de Venda", _itemData!['SalesUnit'] ?? "N/A"),
          _buildDetailRow("Embalagem Venda", _itemData!['SalesPackagingUnit'] ?? "N/A"),
          _buildDetailRow("Item Bloqueado",
              _itemData!['Frozen'] == "tYES" ? "SIM" : "NÃO",
              isAlert: _itemData!['Frozen'] == "tYES"),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_itemData!['ItemCode'] ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_itemData!['ItemName'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFlags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? Colors.green : Colors.grey.shade300),
      ),
      child: Text(label,
          style: TextStyle(
              color: active ? Colors.green.shade700 : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }

  Widget _buildWarehouseInfo() {
    final list = (_itemData!['ItemWarehouseInfoCollection'] as List? ?? []);
    final warehousesWithStock = list.where((wh) => (wh['InStock'] ?? 0) > 0).toList();

    if (warehousesWithStock.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Sem estoque disponível.", style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: warehousesWithStock.map((wh) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.warehouse, color: Colors.blueGrey),
            title: Text("Depósito ${wh['WarehouseCode']}"),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("${wh['InStock']} ${_itemData!['InventoryUOM'] ?? ''}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EtiquetaPage(
                          itemData: _itemData!,
                          deposito: wh['WarehouseCode'].toString(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isAlert ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }
}