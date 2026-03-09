import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

class EtiquetaPage extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final String deposito;

  const EtiquetaPage({super.key, required this.itemData, required this.deposito});

  @override
  State<EtiquetaPage> createState() => _EtiquetaPageState();
}

class _EtiquetaPageState extends State<EtiquetaPage> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // Solicita permissões necessárias para o Bluetooth no Android moderno
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothConnect]!.isGranted) {
      _getBluetoothDevices();
    }
  }

  void _getBluetoothDevices() async {
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      debugPrint("Erro ao buscar dispositivos: $e");
    }
  }

  void _imprimir() async {
    if (_selectedDevice == null) return;

    setState(() => _isPrinting = true);

    try {
      bool? isConnected = await bluetooth.isConnected;
      if (!isConnected!) {
        await bluetooth.connect(_selectedDevice!);
      }

      // --- COMANDOS ESC/POS ---
      bluetooth.printNewLine();
      bluetooth.printCustom("STOX - ALGODAO", 2, 1); // Nome da empresa/App
      bluetooth.printCustom(widget.itemData['ItemName'] ?? "ITEM", 1, 1);
      bluetooth.printNewLine();
      
      // CORREÇÃO: Usando QR Code porque a v1.2.3 não possui printBarcode
      String codigo = widget.itemData['ItemCode'] ?? "000";
      bluetooth.printQRcode(codigo, 150, 150, 1);
      
      bluetooth.printNewLine();
      bluetooth.printLeftRight("COD: $codigo", "DEP: ${widget.deposito}", 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      
      // Cortar ou avançar papel
      await bluetooth.disconnect();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impressão enviada!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Impressão de Etiqueta"),
        backgroundColor: const Color(0xFF0A6ED1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildDeviceSelector(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: _buildVisualEtiqueta()),
              ),
            ),
          ),
          _buildPrintButton(),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(Icons.print_rounded, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BluetoothDevice>(
                isExpanded: true,
                hint: const Text("Selecione a Impressora"),
                value: _selectedDevice,
                items: _devices.map((device) {
                  return DropdownMenuItem(
                    value: device,
                    child: Text(device.name ?? "Dispositivo Desconhecido"),
                  );
                }).toList(),
                onChanged: (device) => setState(() => _selectedDevice = device),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getBluetoothDevices,
          )
        ],
      ),
    );
  }

  Widget _buildPrintButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: (_selectedDevice == null || _isPrinting) ? null : _imprimir,
          icon: _isPrinting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print),
          label: Text(_isPrinting ? "IMPRIMINDO..." : "IMPRIMIR ETIQUETA"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A6ED1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualEtiqueta() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("STOX AGRO", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(),
          Text(widget.itemData['ItemName'] ?? '', 
               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          BarcodeWidget(
            barcode: Barcode.code128(),
            data: widget.itemData['ItemCode'] ?? '000',
            width: 200,
            height: 80,
            drawText: false,
          ),
          const SizedBox(height: 10),
          Text(widget.itemData['ItemCode'] ?? '', style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DEPÓSITO: ${widget.deposito}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Text("VER. 1.0", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}