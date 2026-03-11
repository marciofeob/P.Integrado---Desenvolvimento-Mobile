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
  
  Map<String, dynamic>? _itemData;
  List<dynamic> _searchResults = [];
  
  bool _loading = false;
  bool _scannerProcessando = false;
  final Color primaryColor = const Color(0xFF0A6ED1);

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

    try {
      final results = await SapService.searchItems(termo);

      if (mounted) {
        setState(() {
          _loading = false;
          if (results.length == 1) {
            _carregarDetalhes(results.first['ItemCode']);
          } else {
            _searchResults = results;
          }
        });
      }

      if (results.isEmpty) {
        await _tocarFeedback('sounds/error_beep.mp3', isError: true);
        _mostrarAviso("Nenhum item encontrado.");
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
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _mostrarErro("Erro ao carregar detalhes.");
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarAviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
    );
  }

  void _abrirScanner() {
    _scannerProcessando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutBuilder(builder: (context, constraints) {
        // Adaptamos o tamanho do scanWindow dinamicamente
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, 200),
          width: 250,
          height: 150,
        );

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea( // Crucial para não cortar em celulares com gestos
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, color: Colors.grey[300]),
                AppBar(
                  title: const Text('Escanear Código'),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                  ],
                ),
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
                            _searchController.text = code;
                            Navigator.of(context).pop();
                            _buscar();
                          }
                        },
                      ),
                      // Overlay de Scanner com máscara
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.srcOut),
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
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("Alinhe o código de barras dentro do quadro", style: TextStyle(color: Colors.grey)),
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
      appBar: AppBar(title: const Text("Consultar Item")),
      body: SafeArea( // Protege o corpo do app contra a barra inferior do Android
        child: Column(
          children: [
            _buildSearchBar(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_loading && _searchResults.isNotEmpty) _buildSearchSuggestions(),
            if (!_loading && _itemData != null) _buildResultList(),
            if (!_loading && _itemData == null && _searchResults.isEmpty)
              const Expanded(
                child: Center(
                  child: Text("Busque por código ou nome para começar.", 
                    style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        ),
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
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                hintText: "Código ou Nome",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0A6ED1)),
                  onPressed: _abrirScanner,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 54,
            width: 54,
            child: ElevatedButton(
              onPressed: _buscar,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.arrow_forward),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Padding extra no fundo
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              title: Text(item['ItemName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['ItemCode'] ?? ''),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Garante que o scroll passe da barra do Android
        children: [
          _buildHeaderCard(),
          _buildStatusFlags(),
          _buildSectionTitle("Estoque por Depósito"),
          _buildWarehouseInfo(),
          _buildSectionTitle("Informações Adicionais"),
          _buildDetailRow("Unidade", _itemData!['InventoryUOM'] ?? "UN"),
          _buildDetailRow("Item Bloqueado",
              _itemData!['Frozen'] == "tYES" ? "SIM" : "NÃO",
              isAlert: _itemData!['Frozen'] == "tYES"),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_itemData!['ItemCode'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(_itemData!['ItemName'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatusFlags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Wrap( // Usei Wrap em vez de Row para evitar estouro em telas estreitas
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
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
        color: active ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: active ? Colors.green : Colors.grey.shade300),
      ),
      child: Text(label,
          style: TextStyle(
            color: active ? Colors.green.shade700 : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12)),
    );
  }

  Widget _buildWarehouseInfo() {
    final list = (_itemData!['ItemWarehouseInfoCollection'] as List? ?? []);
    final warehouses = list.where((wh) => (wh['InStock'] ?? 0) > 0).toList();

    if (warehouses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("Sem estoque nos depósitos."),
        ),
      );
    }

    return Column(
      children: warehouses.map((wh) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF0F4F8),
              child: Icon(Icons.warehouse_outlined, color: Colors.blueGrey, size: 20),
            ),
            title: Text("Depósito ${wh['WarehouseCode']}"),
            subtitle: Text("Disponível: ${wh['InStock']}"),
            trailing: IconButton(
              icon: const Icon(Icons.print_outlined, color: Colors.blue),
              onPressed: () {
                // Navegação para a página de etiqueta
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
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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